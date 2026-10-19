import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { endpoint, custom, zUuid, type Ctx } from "./helpers.js";

export function registerPrinterDocsTools(server: McpServer, ctx: Ctx) {
  // ---- Printer Endpoints ----
  endpoint(
    server,
    ctx,
    "generate_thermal_print",
    "Generate ESC/POS thermal printer receipt data or base64 print format.",
    "POST",
    "/api/v1/printer/thermal",
    {
      invoice_id: zUuid.optional(),
      paper_width_mm: z.number().int().optional().describe("e.g. 58 or 80"),
      custom_text: z.string().optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "generate_document_print",
    "Generate standard formatted print stream for invoices/bills.",
    "POST",
    "/api/v1/printer/document",
    {
      document_type: z.string().describe("invoice, quotation, purchase_bill"),
      document_id: zUuid,
      template_id: z.string().optional(),
    },
  );

  custom(
    server,
    "get_thermal_print_preview",
    "Get HTML preview of thermal receipt.",
    { invoice_id: zUuid.optional() },
    async ({ invoice_id }) => {
      const data = await ctx.api.get("/api/v1/printer/thermal/preview", { invoice_id });
      return data;
    },
    { readOnly: true },
  );

  custom(
    server,
    "get_barcode_print_preview",
    "Get barcode or item label print preview.",
    { product_id: zUuid.optional(), count: z.number().int().optional() },
    async ({ product_id, count }) => {
      const data = await ctx.api.get("/api/v1/printer/barcode/preview", { product_id, count });
      return data;
    },
    { readOnly: true },
  );

  // ---- Documents ----
  endpoint(server, ctx, "list_documents", "List uploaded files and attachments.", "GET", "/api/v1/documents", { entity_type: z.string().optional(), entity_id: zUuid.optional() });
  endpoint(server, ctx, "delete_document", "Delete an uploaded document file.", "DELETE", "/api/v1/documents/:id", { id: zUuid }, { destructive: true });
}
