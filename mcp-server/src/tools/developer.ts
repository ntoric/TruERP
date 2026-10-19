import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { endpoint, custom, zUuid, type Ctx } from "./helpers.js";

export function registerDeveloperTools(server: McpServer, ctx: Ctx) {
  // ---- Developer Settings ----
  endpoint(server, ctx, "get_developer_settings", "Get platform developer configuration (super admin).", "GET", "/api/v1/developer-settings");
  endpoint(
    server,
    ctx,
    "update_developer_settings",
    "Update platform developer configuration (super admin).",
    "PUT",
    "/api/v1/developer-settings",
    {
      smtp_host: z.string().optional(),
      smtp_port: z.number().int().optional(),
      smtp_username: z.string().optional(),
      smtp_password: z.string().optional(),
      smtp_from_email: z.string().optional(),
      smtp_from_name: z.string().optional(),
      smtp_encryption: z.string().optional(),
      twilio_account_sid: z.string().optional(),
      twilio_auth_token: z.string().optional(),
      twilio_from_number: z.string().optional(),
      whatsapp_access_token: z.string().optional(),
      whatsapp_phone_number_id: z.string().optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "test_developer_email",
    "Test email server connection and sending.",
    "POST",
    "/api/v1/developer-settings/test-email",
    { to_email: z.string().email() },
  );
  endpoint(
    server,
    ctx,
    "test_developer_whatsapp",
    "Test WhatsApp API connection and message sending.",
    "POST",
    "/api/v1/developer-settings/test-whatsapp",
    { to_phone: z.string() },
  );
  endpoint(
    server,
    ctx,
    "test_developer_sms",
    "Test SMS gateway connection and message sending.",
    "POST",
    "/api/v1/developer-settings/test-sms",
    { to_phone: z.string() },
  );

  // ---- DB Maintenance ----
  endpoint(server, ctx, "get_db_maintenance_settings", "Get database maintenance (VACUUM/bloat cleanup) settings.", "GET", "/api/v1/developer-settings/db-maintenance");
  endpoint(
    server,
    ctx,
    "update_db_maintenance_settings",
    "Update database maintenance schedule and settings.",
    "PUT",
    "/api/v1/developer-settings/db-maintenance",
    {
      enabled: z.boolean().optional(),
      schedule_time_ist: z.string().optional(),
      vacuum_full: z.boolean().optional(),
    },
  );
  endpoint(server, ctx, "run_db_maintenance_now", "Trigger database maintenance (VACUUM / re-index) immediately.", "POST", "/api/v1/developer-settings/db-maintenance/run-now");

  // ---- DB Backups ----
  endpoint(server, ctx, "get_db_backup_settings", "Get database backup schedule and cloud storage destination settings.", "GET", "/api/v1/developer-settings/db-backup");
  endpoint(
    server,
    ctx,
    "update_db_backup_settings",
    "Update database backup settings and cloud destination (S3/Mega/Google Drive).",
    "PUT",
    "/api/v1/developer-settings/db-backup",
    {
      enabled: z.boolean().optional(),
      frequency: z.string().optional().describe("daily, weekly, monthly"),
      destination_type: z.string().optional().describe("local, s3, gdrive, mega"),
      retention_days: z.number().int().optional(),
    },
  );
  endpoint(server, ctx, "run_db_backup_now", "Trigger a database backup snapshot immediately.", "POST", "/api/v1/developer-settings/db-backup/run-now");
  endpoint(server, ctx, "test_db_backup_destination", "Test connection to the configured database backup cloud destination.", "POST", "/api/v1/developer-settings/db-backup/test-destination");

  custom(
    server,
    "download_db_backup_record",
    "Download a database backup archive file by record ID (returns base64 encoded archive).",
    { id: zUuid },
    async ({ id }) => {
      const { base64, mimeType } = await ctx.api.download(`/api/v1/developer-settings/db-backup/records/${id}/download`);
      return {
        id,
        mimeType,
        base64Length: base64.length,
        base64Data: base64,
      };
    },
    { readOnly: true },
  );

  endpoint(server, ctx, "delete_db_backup_record", "Delete a database backup record and its archive file.", "DELETE", "/api/v1/developer-settings/db-backup/records/:id", { id: zUuid }, { destructive: true });
}
