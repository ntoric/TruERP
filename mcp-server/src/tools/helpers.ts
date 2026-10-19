import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import type { TrueRPClient } from "../client.js";

export type Ctx = { api: TrueRPClient };

type Method = "GET" | "POST" | "PUT" | "PATCH" | "DELETE";

const MAX_RESULT_CHARS = 60_000;

function asResult(data: unknown) {
  let text = typeof data === "string" ? data : JSON.stringify(data, null, 2);
  if (text.length > MAX_RESULT_CHARS) {
    text = text.slice(0, MAX_RESULT_CHARS) + "\n…[truncated]";
  }
  return { content: [{ type: "text" as const, text }] };
}

function asError(err: unknown) {
  const message = err instanceof Error ? err.message : String(err);
  return { content: [{ type: "text" as const, text: `Error: ${message}` }], isError: true };
}

/** Replace :param placeholders in a path with values from args. */
function fillPath(path: string, args: Record<string, unknown>): { path: string; rest: Record<string, unknown> } {
  const rest = { ...args };
  const filled = path.replace(/:([A-Za-z0-9_-]+)/g, (_, key: string) => {
    // Hyphenated route params (:product-id) map to underscored args (product_id).
    const argKey = key in rest ? key : key.replace(/-/g, "_");
    const v = rest[argKey];
    delete rest[argKey];
    if (v === undefined || v === null) throw new Error(`Missing path parameter: ${key}`);
    return encodeURIComponent(String(v));
  });
  return { path: filled, rest };
}

interface ToolOpts {
  /** Marks the tool read-only in MCP annotations. */
  readOnly?: boolean;
  /** Marks the tool destructive in MCP annotations. */
  destructive?: boolean;
  /** Force where non-path params go. Default: GET→query, others→body. */
  paramStyle?: "auto" | "query" | "body";
}

/**
 * Register one MCP tool backed by a single REST endpoint.
 * Path params (:id) are pulled from args; remaining args become the query
 * string for GET/DELETE or the JSON body for POST/PUT/PATCH.
 */
export function endpoint(
  server: McpServer,
  ctx: Ctx,
  name: string,
  description: string,
  method: Method,
  path: string,
  shape: Record<string, z.ZodTypeAny> = {},
  opts: ToolOpts = {},
) {
  server.registerTool(
    name,
    {
      description,
      inputSchema: shape,
      annotations: {
        readOnlyHint: opts.readOnly ?? method === "GET",
        destructiveHint: opts.destructive ?? method === "DELETE",
      },
    },
    async (args: Record<string, unknown>) => {
      try {
        const { path: filled, rest } = fillPath(path, args);
        const style = opts.paramStyle ?? "auto";
        const toQuery = style === "query" || (style === "auto" && (method === "GET" || method === "DELETE"));
        const params = Object.fromEntries(Object.entries(rest).filter(([, v]) => v !== undefined));
        let data: unknown;
        switch (method) {
          case "GET":
            data = await ctx.api.get(filled, params);
            break;
          case "DELETE":
            data = await ctx.api.del(filled);
            break;
          case "POST":
            data = toQuery ? await ctx.api.post(filled, undefined, params) : await ctx.api.post(filled, params);
            break;
          case "PUT":
            data = toQuery ? await ctx.api.request("PUT", filled, { query: params }) : await ctx.api.put(filled, params);
            break;
          case "PATCH":
            data = toQuery ? await ctx.api.request("PATCH", filled, { query: params }) : await ctx.api.patch(filled, params);
            break;
        }
        return asResult(data ?? { ok: true });
      } catch (err) {
        return asError(err);
      }
    },
  );
}

/** Register a tool that downloads a binary endpoint (PDF/Excel) as base64. */
export function downloadEndpoint(
  server: McpServer,
  ctx: Ctx,
  name: string,
  description: string,
  path: string,
  shape: Record<string, z.ZodTypeAny> = {},
  fileName = "document.pdf",
) {
  server.registerTool(
    name,
    { description, inputSchema: shape, annotations: { readOnlyHint: true } },
    async (args: Record<string, unknown>) => {
      try {
        const { path: filled, rest } = fillPath(path, args);
        const { base64, mimeType } = await ctx.api.download(filled, rest);
        return {
          content: [
            {
              type: "resource" as const,
              resource: { uri: `truerp:/${filled}`, mimeType, blob: base64 },
            },
            { type: "text" as const, text: `Downloaded ${fileName} (${mimeType}, ${Math.round((base64.length * 3) / 4 / 1024)} KB) — returned as a base64 blob.` },
          ],
        };
      } catch (err) {
        return asError(err);
      }
    },
  );
}

/** Register a fully custom tool handler. */
export function custom(
  server: McpServer,
  name: string,
  description: string,
  shape: Record<string, z.ZodTypeAny>,
  handler: (args: Record<string, unknown>) => Promise<unknown>,
  opts: ToolOpts = {},
) {
  server.registerTool(
    name,
    {
      description,
      inputSchema: shape,
      annotations: { readOnlyHint: opts.readOnly ?? false, destructiveHint: opts.destructive ?? false },
    },
    async (args: Record<string, unknown>) => {
      try {
        return asResult(await handler(args));
      } catch (err) {
        return asError(err);
      }
    },
  );
}

// ---------- shared zod fragments ----------

export const zUuid = z.string().uuid().describe("UUID");
export const zDate = z
  .string()
  .describe(
    "RFC 3339 datetime (e.g. '2026-10-18T14:30:00+05:30' or '2026-10-18T00:00:00Z'). Bare 'YYYY-MM-DD' is only acceptable on list/date-range filters, not on create/update payloads.",
  );
export const zPage = z.number().int().min(1).optional().describe("Page number (omit for unpaginated full list)");
export const zPerPage = z.number().int().min(1).max(500).optional().describe("Items per page (omit for unpaginated full list)");
export const zSearch = z.string().optional().describe("Free-text search");
export const zFromTo = {
  from: zDate.optional().describe("Start date filter (YYYY-MM-DD)"),
  to: zDate.optional().describe("End date filter (YYYY-MM-DD)"),
};
export const zFromToDate = {
  from_date: zDate.optional().describe("Start date filter (YYYY-MM-DD)"),
  to_date: zDate.optional().describe("End date filter (YYYY-MM-DD)"),
};

/** A labelled charge/discount line, e.g. [{"label":"Freight","amount":50}] */
export const zAdditionalChargeItems = z
  .array(z.object({ label: z.string(), amount: z.number() }).passthrough())
  .optional()
  .describe("Labelled additional charges, e.g. [{label:'Freight',amount:50}]");

export const zPaymentMode = z
  .string()
  .optional()
  .describe("Payment mode: cash, upi, bank_transfer, cheque, card, credit, initial_investment");

export const zPaymentSplits = z
  .array(
    z
      .object({
        mode: z.string().describe("cash, upi, bank_transfer, cheque, card"),
        amount: z.number(),
        bank_account_id: zUuid.optional(),
      })
      .passthrough(),
  )
  .optional()
  .describe("Tender split — list of {mode, amount, bank_account_id?}");

export const zLineItem = z
  .object({
    product_id: zUuid.optional(),
    description: z.string().describe("Line description / item name"),
    quantity: z.number().default(1),
    unit: z.string().optional(),
    unit_price: z.number().default(0),
    discount: z.number().optional().describe("Line discount amount"),
    tax_rate: z.number().optional().describe("Tax % applied to the line"),
    hsn_code: z.string().optional(),
    sac_code: z.string().optional(),
    batch_no: z.string().optional(),
    exp_date: zDate.optional(),
  })
  .passthrough();
