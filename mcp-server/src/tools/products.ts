import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { endpoint, zUuid, zPage, zPerPage, zSearch, type Ctx } from "./helpers.js";

const productFields = {
  name: z.string().describe("Product/service name"),
  sku: z.string().optional().describe("SKU / barcode"),
  item_code: z.string().optional().describe("Internal item code (auto-generatable via generate_item_code)"),
  plu: z.string().optional().describe("Scale PLU code"),
  category: z.string().optional().describe("Category name"),
  purchase_price: z.number().optional(),
  sale_price: z.number().optional(),
  mrp: z.number().optional(),
  unit: z.string().optional().describe("PCS, KG, LTR, MTR, BOX, etc. (see list_product_units)"),
  min_stock: z.number().optional().describe("Low-stock threshold"),
  tax_rate: z.number().optional().describe("Default GST % (0, 5, 12, 18, 28)"),
  gst_enabled: z.boolean().optional(),
  item_type: z.string().optional().describe("product | service"),
  low_stock_alert: z.boolean().optional(),
  hsn_code: z.string().optional(),
  description: z.string().optional(),
  discount: z.string().optional(),
  enable_batching: z.boolean().optional(),
  sale_price_with_tax: z.boolean().optional().describe("Whether sale_price already includes tax"),
  purchase_price_with_tax: z.boolean().optional(),
  image_url: z.string().optional(),
  is_active: z.boolean().optional(),
};

function optionalize(shape: Record<string, z.ZodTypeAny>) {
  return Object.fromEntries(Object.entries(shape).map(([k, v]) => [k, v.optional()]));
}

export function registerProductTools(server: McpServer, ctx: Ctx) {
  // ---------- Products ----------
  endpoint(
    server,
    ctx,
    "list_products",
    "List products/services with search, category/unit filters and optional pagination. Includes current stock when available.",
    "GET",
    "/api/v1/products",
    {
      search: zSearch,
      category: z.string().optional(),
      unit: z.string().optional(),
      page: zPage,
      per_page: zPerPage,
    },
  );
  endpoint(server, ctx, "get_product", "Get a product by ID (with images and variants).", "GET", "/api/v1/products/:id", { id: zUuid });
  endpoint(server, ctx, "create_product", "Create a product or service item.", "POST", "/api/v1/products", productFields);
  endpoint(
    server,
    ctx,
    "update_product",
    "Update a product.",
    "PUT",
    "/api/v1/products/:id",
    { id: zUuid, ...optionalize(productFields) },
  );
  endpoint(server, ctx, "delete_product", "Delete a product (soft delete).", "DELETE", "/api/v1/products/:id", { id: zUuid }, { destructive: true });

  endpoint(server, ctx, "list_product_units", "List the units of measure configured/used.", "GET", "/api/v1/products/units");
  endpoint(
    server,
    ctx,
    "generate_item_code",
    "Generate the next available item code for a unit prefix.",
    "GET",
    "/api/v1/products/generate-item-code",
    { unit: z.string().optional().describe("Unit prefix, default PCS") },
  );
  endpoint(
    server,
    ctx,
    "check_item_code",
    "Check whether an item code is already in use.",
    "GET",
    "/api/v1/products/check-item-code",
    { item_code: z.string() },
  );
  endpoint(server, ctx, "next_product_plu", "Get the next available scale PLU number.", "GET", "/api/v1/products/next-plu");
  endpoint(
    server,
    ctx,
    "check_product_plu",
    "Check whether a PLU is already assigned.",
    "GET",
    "/api/v1/products/check-plu",
    { plu: z.string() },
  );

  // ---------- Product variants ----------
  endpoint(server, ctx, "list_product_variants", "List variants of a product.", "GET", "/api/v1/products/:id/variants", { id: zUuid });
  endpoint(
    server,
    ctx,
    "create_product_variant",
    "Create a product variant (e.g. size/color).",
    "POST",
    "/api/v1/products/:id/variants",
    {
      id: zUuid.describe("Product ID"),
      variant_name: z.string(),
      variant_sku: z.string().optional(),
      variant_barcode: z.string().optional(),
      attributes: z.record(z.any()).optional().describe("e.g. {color:'red',size:'M'}"),
      stock_qty: z.number().optional(),
      purchase_price: z.number().optional(),
      sale_price: z.number().optional(),
      mrp: z.number().optional(),
      is_active: z.boolean().optional(),
    },
  );
  endpoint(server, ctx, "get_product_variant", "Get a product variant by ID.", "GET", "/api/v1/product-variants/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "update_product_variant",
    "Update a product variant.",
    "PUT",
    "/api/v1/product-variants/:id",
    {
      id: zUuid,
      variant_name: z.string().optional(),
      variant_sku: z.string().optional(),
      variant_barcode: z.string().optional(),
      attributes: z.record(z.any()).optional(),
      stock_qty: z.number().optional(),
      purchase_price: z.number().optional(),
      sale_price: z.number().optional(),
      mrp: z.number().optional(),
      is_active: z.boolean().optional(),
    },
  );
  endpoint(server, ctx, "delete_product_variant", "Delete a product variant.", "DELETE", "/api/v1/product-variants/:id", { id: zUuid }, { destructive: true });

  // ---------- Product images ----------
  endpoint(server, ctx, "list_product_images", "List images attached to a product.", "GET", "/api/v1/products/:id/images", { id: zUuid });
  endpoint(
    server,
    ctx,
    "add_product_image",
    "Attach an image to a product by URL (or uploaded file URL).",
    "POST",
    "/api/v1/products/:id/images",
    {
      id: zUuid.describe("Product ID"),
      image_url: z.string(),
      alt_text: z.string().optional(),
      is_primary: z.boolean().optional(),
      sort_order: z.number().int().optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "update_product_image",
    "Update a product image (alt text, primary flag, order).",
    "PUT",
    "/api/v1/product-images/:id",
    { id: zUuid, alt_text: z.string().optional(), is_primary: z.boolean().optional(), sort_order: z.number().int().optional() },
  );
  endpoint(server, ctx, "delete_product_image", "Delete a product image.", "DELETE", "/api/v1/product-images/:id", { id: zUuid }, { destructive: true });
  endpoint(
    server,
    ctx,
    "reorder_product_images",
    "Reorder a product's images.",
    "POST",
    "/api/v1/product-images/:product-id/reorder",
    { product_id: zUuid.describe("Product ID"), image_ids: z.array(zUuid) },
  );

  // ---------- Categories ----------
  endpoint(
    server,
    ctx,
    "list_categories",
    "List product categories (hierarchical via parent_id).",
    "GET",
    "/api/v1/categories",
    { search: zSearch, page: zPage, per_page: zPerPage },
  );
  endpoint(server, ctx, "get_category", "Get a category by ID.", "GET", "/api/v1/categories/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "create_category",
    "Create a product category.",
    "POST",
    "/api/v1/categories",
    {
      name: z.string(),
      description: z.string().optional(),
      parent_id: zUuid.optional().describe("Parent category for nesting"),
      is_active: z.boolean().optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "update_category",
    "Update a category.",
    "PUT",
    "/api/v1/categories/:id",
    {
      id: zUuid,
      name: z.string().optional(),
      description: z.string().optional(),
      parent_id: zUuid.optional(),
      is_active: z.boolean().optional(),
    },
  );
  endpoint(server, ctx, "delete_category", "Delete a category.", "DELETE", "/api/v1/categories/:id", { id: zUuid }, { destructive: true });
  endpoint(
    server,
    ctx,
    "bulk_delete_categories",
    "Delete many categories at once.",
    "POST",
    "/api/v1/categories/bulk/delete",
    { ids: z.array(zUuid) },
    { destructive: true },
  );
  endpoint(
    server,
    ctx,
    "bulk_update_category_status",
    "Activate/deactivate many categories at once.",
    "POST",
    "/api/v1/categories/bulk/update-status",
    { ids: z.array(zUuid), is_active: z.boolean() },
  );

  // ---------- Expense categories (separate domain, kept here for discoverability) ----------
  endpoint(server, ctx, "list_expense_categories", "List expense categories.", "GET", "/api/v1/expense-categories");
  endpoint(
    server,
    ctx,
    "create_expense_category",
    "Create an expense category.",
    "POST",
    "/api/v1/expense-categories",
    { name: z.string(), description: z.string().optional(), is_active: z.boolean().optional() },
  );
  endpoint(
    server,
    ctx,
    "update_expense_category",
    "Update an expense category.",
    "PUT",
    "/api/v1/expense-categories/:id",
    { id: zUuid, name: z.string().optional(), description: z.string().optional(), is_active: z.boolean().optional() },
  );
  endpoint(server, ctx, "delete_expense_category", "Delete an expense category.", "DELETE", "/api/v1/expense-categories/:id", { id: zUuid }, { destructive: true });
}
