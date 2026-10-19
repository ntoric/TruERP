/**
 * Minimal REST client for the TruERP backend.
 *
 * Auth: JWT obtained via POST /api/v1/auth/login (or a pre-issued token via
 * TRUERP_TOKEN). Tokens are re-fetched automatically on 401 responses.
 * Store scoping for super-admin users is done through the X-Store-ID header.
 */

export interface ClientConfig {
  baseUrl: string;
  email?: string;
  password?: string;
  totpCode?: string;
  token?: string;
  storeId?: string;
}

export class ApiError extends Error {
  constructor(
    public status: number,
    public statusText: string,
    public body: unknown,
    public url: string,
  ) {
    super(`API ${status} ${statusText} on ${url}: ${summarize(body)}`);
    this.name = "ApiError";
  }
}

function summarize(body: unknown): string {
  const s = typeof body === "string" ? body : JSON.stringify(body);
  if (!s) return "(empty body)";
  return s.length > 800 ? s.slice(0, 800) + "…" : s;
}

export function loadConfigFromEnv(): ClientConfig {
  return {
    baseUrl: (process.env.TRUERP_API_URL || "http://localhost:8088").replace(/\/+$/, ""),
    email: process.env.TRUERP_EMAIL,
    password: process.env.TRUERP_PASSWORD,
    totpCode: process.env.TRUERP_TOTP_CODE,
    token: process.env.TRUERP_TOKEN,
    storeId: process.env.TRUERP_STORE_ID,
  };
}

export class TrueRPClient {
  private token?: string;
  private loginPromise?: Promise<string>;

  constructor(private cfg: ClientConfig) {
    this.token = cfg.token;
  }

  get baseUrl(): string {
    return this.cfg.baseUrl;
  }

  private async login(): Promise<string> {
    if (!this.cfg.email || !this.cfg.password) {
      throw new Error(
        "Not authenticated. Set TRUERP_TOKEN, or TRUERP_EMAIL + TRUERP_PASSWORD environment variables.",
      );
    }
    // De-dupe concurrent logins.
    if (!this.loginPromise) {
      this.loginPromise = (async () => {
        const res = await fetch(`${this.cfg.baseUrl}/api/v1/auth/login`, {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            email: this.cfg.email,
            password: this.cfg.password,
            totp_code: this.cfg.totpCode || undefined,
          }),
        });
        const data = await res.json().catch(() => ({}));
        if (!res.ok) {
          throw new ApiError(res.status, res.statusText, data, "/api/v1/auth/login");
        }
        const token = (data as { token?: string }).token;
        if (!token) throw new Error("Login succeeded but no token was returned");
        this.token = token;
        return token;
      })().finally(() => {
        this.loginPromise = undefined;
      });
    }
    return this.loginPromise;
  }

  private async authToken(): Promise<string> {
    if (this.token) return this.token;
    return this.login();
  }

  private headers(token: string): Record<string, string> {
    const h: Record<string, string> = {
      Authorization: `Bearer ${token}`,
      Accept: "application/json",
    };
    if (this.cfg.storeId) h["X-Store-ID"] = this.cfg.storeId;
    return h;
  }

  /**
   * Perform an API request. On 401, drops the token, re-logs in once and
   * retries. Returns the parsed JSON body (or text when non-JSON).
   */
  async request(
    method: string,
    path: string,
    opts: { query?: Record<string, unknown>; body?: unknown } = {},
    retry = true,
  ): Promise<unknown> {
    const token = await this.authToken();
    const url = new URL(this.cfg.baseUrl + path);
    if (opts.query) {
      for (const [k, v] of Object.entries(opts.query)) {
        if (v === undefined || v === null || v === "") continue;
        if (Array.isArray(v)) {
          for (const item of v) url.searchParams.append(k, String(item));
        } else {
          url.searchParams.set(k, String(v));
        }
      }
    }

    const init: RequestInit = {
      method,
      headers: this.headers(token),
    };
    if (opts.body !== undefined) {
      (init.headers as Record<string, string>)["Content-Type"] = "application/json";
      init.body = JSON.stringify(opts.body);
    }

    const res = await fetch(url, init);

    if (res.status === 401 && retry && !this.cfg.token) {
      // Token may have expired — re-login once.
      this.token = undefined;
      return this.request(method, path, opts, false);
    }

    const contentType = res.headers.get("content-type") || "";
    let data: unknown;
    if (contentType.includes("application/json")) {
      data = await res.json().catch(() => ({}));
    } else {
      data = await res.text();
    }

    if (!res.ok) {
      throw new ApiError(res.status, res.statusText, data, path);
    }
    return data;
  }

  get(path: string, query?: Record<string, unknown>) {
    return this.request("GET", path, { query });
  }
  post(path: string, body?: unknown, query?: Record<string, unknown>) {
    return this.request("POST", path, { body, query });
  }
  put(path: string, body?: unknown) {
    return this.request("PUT", path, { body });
  }
  patch(path: string, body?: unknown) {
    return this.request("PATCH", path, { body });
  }
  del(path: string) {
    return this.request("DELETE", path);
  }

  /** Download a binary endpoint (e.g. PDF) and return base64 + mime type. */
  async download(path: string, query?: Record<string, unknown>): Promise<{ base64: string; mimeType: string }> {
    const token = await this.authToken();
    const url = new URL(this.cfg.baseUrl + path);
    if (query) {
      for (const [k, v] of Object.entries(query)) {
        if (v !== undefined && v !== null && v !== "") url.searchParams.set(k, String(v));
      }
    }
    const res = await fetch(url, { headers: this.headers(token) });
    if (!res.ok) {
      const text = await res.text().catch(() => "");
      throw new ApiError(res.status, res.statusText, text, path);
    }
    const buf = Buffer.from(await res.arrayBuffer());
    const mimeType = res.headers.get("content-type")?.split(";")[0] || "application/octet-stream";
    return { base64: buf.toString("base64"), mimeType };
  }
}
