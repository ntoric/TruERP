/**
 * REST client for the TruERP backend supporting both standard JWT
 * and OAuth 2.0 authentication flows (Client Credentials, Refresh Token,
 * Resource Owner Password, and pre-issued Bearer tokens).
 *
 * Store scoping for super-admin users is done through the X-Store-ID header.
 */

export interface ClientConfig {
  baseUrl: string;
  email?: string;
  password?: string;
  totpCode?: string;
  token?: string;
  storeId?: string;

  // OAuth 2.0 configuration
  oauthToken?: string;
  oauthClientId?: string;
  oauthClientSecret?: string;
  oauthRefreshToken?: string;
  oauthTokenUrl?: string;
  oauthScopes?: string;
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
  const baseUrl = (process.env.TRUERP_API_URL || "http://localhost:8088").replace(/\/+$/, "");
  return {
    baseUrl,
    email: process.env.TRUERP_EMAIL,
    password: process.env.TRUERP_PASSWORD,
    totpCode: process.env.TRUERP_TOTP_CODE,
    token: process.env.TRUERP_TOKEN || process.env.TRUERP_OAUTH_TOKEN,
    storeId: process.env.TRUERP_STORE_ID,
    oauthToken: process.env.TRUERP_OAUTH_TOKEN,
    oauthClientId: process.env.TRUERP_OAUTH_CLIENT_ID || process.env.TRUERP_CLIENT_ID,
    oauthClientSecret: process.env.TRUERP_OAUTH_CLIENT_SECRET || process.env.TRUERP_CLIENT_SECRET,
    oauthRefreshToken: process.env.TRUERP_OAUTH_REFRESH_TOKEN,
    oauthTokenUrl: process.env.TRUERP_OAUTH_TOKEN_URL || `${baseUrl}/api/v1/oauth/token`,
    oauthScopes: process.env.TRUERP_OAUTH_SCOPES || "read write admin erp",
  };
}

export class TrueRPClient {
  private token?: string;
  private refreshToken?: string;
  private loginPromise?: Promise<string>;

  constructor(private cfg: ClientConfig) {
    this.token = cfg.oauthToken || cfg.token;
    this.refreshToken = cfg.oauthRefreshToken;
  }

  get baseUrl(): string {
    return this.cfg.baseUrl;
  }

  get currentToken(): string | undefined {
    return this.token;
  }

  setToken(token: string, refreshToken?: string) {
    this.token = token;
    if (refreshToken) {
      this.refreshToken = refreshToken;
    }
  }

  /**
   * Authenticate via OAuth 2.0 or legacy /api/v1/auth/login.
   */
  private async authenticate(): Promise<string> {
    if (!this.loginPromise) {
      this.loginPromise = (async () => {
        // 1. Try OAuth Refresh Token grant if available
        if (this.refreshToken) {
          try {
            const tokenUrl = this.cfg.oauthTokenUrl || `${this.cfg.baseUrl}/api/v1/oauth/token`;
            const body = new URLSearchParams({
              grant_type: "refresh_token",
              refresh_token: this.refreshToken,
            });
            if (this.cfg.oauthClientId) body.set("client_id", this.cfg.oauthClientId);
            if (this.cfg.oauthClientSecret) body.set("client_secret", this.cfg.oauthClientSecret);

            const res = await fetch(tokenUrl, {
              method: "POST",
              headers: { "Content-Type": "application/x-www-form-urlencoded" },
              body: body.toString(),
            });
            if (res.ok) {
              const data = (await res.json()) as { access_token?: string; refresh_token?: string };
              if (data.access_token) {
                this.token = data.access_token;
                if (data.refresh_token) this.refreshToken = data.refresh_token;
                return data.access_token;
              }
            }
          } catch {
            // Fall through to other auth methods
          }
        }

        // 2. Try OAuth Client Credentials grant if client credentials are provided
        if (this.cfg.oauthClientId && this.cfg.oauthClientSecret) {
          try {
            const tokenUrl = this.cfg.oauthTokenUrl || `${this.cfg.baseUrl}/api/v1/oauth/token`;
            const body = new URLSearchParams({
              grant_type: "client_credentials",
              client_id: this.cfg.oauthClientId,
              client_secret: this.cfg.oauthClientSecret,
              scope: this.cfg.oauthScopes || "read write admin erp",
            });

            const res = await fetch(tokenUrl, {
              method: "POST",
              headers: { "Content-Type": "application/x-www-form-urlencoded" },
              body: body.toString(),
            });
            if (res.ok) {
              const data = (await res.json()) as { access_token?: string; refresh_token?: string };
              if (data.access_token) {
                this.token = data.access_token;
                if (data.refresh_token) this.refreshToken = data.refresh_token;
                return data.access_token;
              }
            }
          } catch {
            // Fall through to password auth
          }
        }

        // 3. Try OAuth Password Grant if email and password are provided
        if (this.cfg.email && this.cfg.password) {
          try {
            const tokenUrl = this.cfg.oauthTokenUrl || `${this.cfg.baseUrl}/api/v1/oauth/token`;
            const body = new URLSearchParams({
              grant_type: "password",
              username: this.cfg.email,
              password: this.cfg.password,
              client_id: this.cfg.oauthClientId || "truerp-mcp-client",
              client_secret: this.cfg.oauthClientSecret || "truerp-mcp-secret",
            });
            if (this.cfg.totpCode) body.set("totp_code", this.cfg.totpCode);

            const res = await fetch(tokenUrl, {
              method: "POST",
              headers: { "Content-Type": "application/x-www-form-urlencoded" },
              body: body.toString(),
            });
            if (res.ok) {
              const data = (await res.json()) as { access_token?: string; refresh_token?: string };
              if (data.access_token) {
                this.token = data.access_token;
                if (data.refresh_token) this.refreshToken = data.refresh_token;
                return data.access_token;
              }
            }
          } catch {
            // Fall through to standard login
          }

          // 4. Fallback to /api/v1/auth/login
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
        }

        throw new Error(
          "Not authenticated. Configure TRUERP_OAUTH_TOKEN, TRUERP_TOKEN, or OAuth client credentials (TRUERP_OAUTH_CLIENT_ID + TRUERP_OAUTH_CLIENT_SECRET), or login credentials (TRUERP_EMAIL + TRUERP_PASSWORD).",
        );
      })().finally(() => {
        this.loginPromise = undefined;
      });
    }
    return this.loginPromise;
  }

  private async authToken(): Promise<string> {
    if (this.token) return this.token;
    return this.authenticate();
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
   * Perform an API request. On 401, drops token, re-authenticates once and retries.
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

    if (res.status === 401 && retry) {
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
