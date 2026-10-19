import { z } from "zod";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { endpoint, zUuid, zDate, zPage, zPerPage, zSearch, type Ctx } from "./helpers.js";

const staffFields = {
  name: z.string(),
  phone: z.string().optional(),
  email: z.string().optional(),
  address: z.string().optional(),
  designation: z.string().optional(),
  department: z.string().optional(),
  joining_date: zDate.optional(),
  salary: z.number().optional(),
  salary_type: z.string().optional().describe("monthly|daily|hourly"),
  bank_name: z.string().optional(),
  account_number: z.string().optional(),
  ifsc_code: z.string().optional(),
  aadhar_number: z.string().optional(),
  pan_number: z.string().optional(),
  is_active: z.boolean().optional(),
  notes: z.string().optional(),
};

const zAttendanceStatus = z
  .enum(["present", "absent", "half_day", "paid_leave", "weekly_off"])
  .describe("Attendance status");

const zPayrollPaymentFields = {
  amount: z.number().positive(),
  payment_date: zDate.optional(),
  payment_mode: z.string().optional().describe("cash|bank_transfer|upi|cheque"),
  bank_account_id: zUuid.optional().describe("Bank account ID; omit for cash-in-hand"),
  reference: z.string().optional(),
  notes: z.string().optional(),
};

export function registerHRTools(server: McpServer, ctx: Ctx) {
  // ---------- Staff ----------
  endpoint(server, ctx, "list_staff", "List staff members.", "GET", "/api/v1/staff", { search: zSearch });
  endpoint(server, ctx, "get_staff", "Get a staff member by ID.", "GET", "/api/v1/staff/:id", { id: zUuid });
  endpoint(server, ctx, "create_staff", "Create a staff member.", "POST", "/api/v1/staff", staffFields);
  endpoint(
    server,
    ctx,
    "update_staff",
    "Update a staff member.",
    "PUT",
    "/api/v1/staff/:id",
    { id: zUuid, ...Object.fromEntries(Object.entries(staffFields).map(([k, v]) => [k, (v as z.ZodTypeAny).optional()])) },
  );
  endpoint(server, ctx, "delete_staff", "Delete a staff member.", "DELETE", "/api/v1/staff/:id", { id: zUuid }, { destructive: true });
  endpoint(server, ctx, "bulk_delete_staff", "Delete many staff members.", "POST", "/api/v1/staff/bulk/delete", { ids: z.array(zUuid) }, { destructive: true });
  endpoint(server, ctx, "bulk_update_staff_status", "Activate/deactivate many staff members.", "POST", "/api/v1/staff/bulk/update-status", { ids: z.array(zUuid), is_active: z.boolean() });
  endpoint(server, ctx, "get_staff_balance", "Get a staff member's outstanding salary/advance balance.", "GET", "/api/v1/staff/:id/balance", { id: zUuid });
  endpoint(server, ctx, "list_staff_balances", "Balances for all staff.", "GET", "/api/v1/staff/balances");

  // ---------- Attendance ----------
  endpoint(
    server,
    ctx,
    "list_attendance",
    "List attendance records (filter by staff and/or date range).",
    "GET",
    "/api/v1/attendance",
    { staff_id: zUuid.optional(), start_date: zDate.optional(), end_date: zDate.optional(), page: zPage, per_page: zPerPage },
  );
  endpoint(server, ctx, "get_attendance_stats", "Attendance stats for a date (present/absent/leave counts).", "GET", "/api/v1/attendance/stats", { date: zDate.optional() });
  endpoint(
    server,
    ctx,
    "mark_attendance",
    "Mark attendance for one staff member on a date.",
    "POST",
    "/api/v1/attendance",
    {
      staff_id: zUuid,
      date: zDate.describe("YYYY-MM-DD"),
      status: zAttendanceStatus,
      check_in_time: zDate.optional(),
      check_out_time: zDate.optional(),
      work_hours: z.number().optional(),
      notes: z.string().optional(),
    },
  );
  endpoint(
    server,
    ctx,
    "bulk_mark_attendance",
    "Mark attendance for many staff on one date.",
    "POST",
    "/api/v1/attendance/bulk",
    {
      date: zDate.describe("YYYY-MM-DD"),
      attendance: z
        .array(
          z.object({
            staff_id: zUuid,
            status: zAttendanceStatus,
            check_in_time: zDate.optional(),
            check_out_time: zDate.optional(),
            work_hours: z.number().optional(),
            notes: z.string().optional(),
          }),
        )
        .min(1),
    },
  );
  endpoint(server, ctx, "get_staff_attendance", "Attendance history for one staff member.", "GET", "/api/v1/attendance/staff/:staff_id", { staff_id: zUuid, start_date: zDate.optional(), end_date: zDate.optional() });
  endpoint(server, ctx, "delete_attendance", "Delete an attendance record.", "DELETE", "/api/v1/attendance/:id", { id: zUuid }, { destructive: true });
  endpoint(server, ctx, "bulk_delete_attendance", "Delete many attendance records.", "POST", "/api/v1/attendance/bulk/delete", { ids: z.array(zUuid) }, { destructive: true });

  // ---------- Payroll ----------
  endpoint(
    server,
    ctx,
    "list_payrolls",
    "List payroll records (salary payments) with staff/date filters.",
    "GET",
    "/api/v1/payroll",
    { staff_id: zUuid.optional(), status: z.string().optional().describe("paid|partial|pending"), start_date: zDate.optional(), end_date: zDate.optional(), page: zPage, per_page: zPerPage },
  );
  endpoint(server, ctx, "get_payroll_stats", "Payroll stats: total paid, payroll count, this month.", "GET", "/api/v1/payroll/stats");
  endpoint(server, ctx, "get_next_payroll_number", "Preview the next payroll payment number.", "GET", "/api/v1/payroll/next-number");
  endpoint(
    server,
    ctx,
    "calculate_payroll",
    "Preview payroll for a staff member over a period — attendance-derived days, deductions, advances and net salary. Does not persist.",
    "GET",
    "/api/v1/payroll/calculate",
    { staff_id: zUuid, start_date: zDate, end_date: zDate },
  );
  endpoint(
    server,
    ctx,
    "create_payroll",
    "Create a payroll run for a staff member (use calculate_payroll first to preview). Set pay_all_due to settle all accumulated dues.",
    "POST",
    "/api/v1/payroll",
    {
      staff_id: zUuid,
      payment_date: zDate,
      start_date: zDate.optional().describe("Period start (required unless pay_all_due)"),
      end_date: zDate.optional().describe("Period end (required unless pay_all_due)"),
      basic_salary: z.number().optional(),
      deductions: z.number().optional(),
      bonus: z.number().optional(),
      paid_amount: z.number().optional().describe("Amount paid now (≤ net salary)"),
      payment_mode: z.string().optional().describe("cash|bank_transfer|upi|cheque"),
      bank_account_id: zUuid.optional(),
      pay_all_due: z.boolean().optional().describe("Settle all outstanding dues instead of a period"),
      status: z.string().optional(),
      reference: z.string().optional(),
      notes: z.string().optional(),
    },
  );
  endpoint(server, ctx, "get_payroll", "Get a payroll record with its payments.", "GET", "/api/v1/payroll/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "update_payroll",
    "Update a payroll record.",
    "PUT",
    "/api/v1/payroll/:id",
    { id: zUuid, payment_date: zDate.optional(), deductions: z.number().optional(), bonus: z.number().optional(), payment_mode: z.string().optional(), bank_account_id: zUuid.optional(), reference: z.string().optional(), notes: z.string().optional(), status: z.string().optional() },
  );
  endpoint(server, ctx, "delete_payroll", "Delete a payroll record.", "DELETE", "/api/v1/payroll/:id", { id: zUuid }, { destructive: true });
  endpoint(server, ctx, "cancel_payroll", "Cancel a payroll record.", "POST", "/api/v1/payroll/:id/cancel", { id: zUuid });
  endpoint(server, ctx, "bulk_delete_payrolls", "Delete many payroll records.", "POST", "/api/v1/payroll/bulk/delete", { ids: z.array(zUuid) }, { destructive: true });
  endpoint(server, ctx, "bulk_update_payroll_status", "Update status on many payroll records.", "POST", "/api/v1/payroll/bulk/update-status", { ids: z.array(zUuid), status: z.string() });
  endpoint(server, ctx, "list_payroll_payments", "List payments made against a payroll.", "GET", "/api/v1/payroll/:id/payments", { id: zUuid });
  endpoint(
    server,
    ctx,
    "create_payroll_payment",
    "Record a (partial) payment against a payroll — posts expense + cash entry.",
    "POST",
    "/api/v1/payroll/:id/payments",
    { id: zUuid.describe("Payroll ID"), ...zPayrollPaymentFields },
  );
  endpoint(server, ctx, "delete_payroll_payment", "Delete a payroll payment.", "DELETE", "/api/v1/payroll/:id/payments/:paymentId", { id: zUuid, paymentId: zUuid }, { destructive: true });

  // ---------- Staff deductions ----------
  endpoint(server, ctx, "list_staff_deductions", "List staff deductions (loan, penalty, tax, insurance…).", "GET", "/api/v1/staff/deductions", { staff_id: zUuid.optional(), deduction_type: z.string().optional(), status: z.string().optional(), from: zDate.optional(), to: zDate.optional(), search: zSearch, page: zPage, per_page: zPerPage });
  endpoint(server, ctx, "get_staff_deduction_stats", "Deduction stats: total, active, completed, this month.", "GET", "/api/v1/staff/deductions/stats");
  endpoint(server, ctx, "get_next_deduction_number", "Preview the next deduction number.", "GET", "/api/v1/staff/deductions/next-number");
  endpoint(
    server,
    ctx,
    "create_staff_deduction",
    "Create a staff deduction.",
    "POST",
    "/api/v1/staff/deductions",
    {
      staff_id: zUuid,
      deduction_type: z.string().describe("loan|penalty|advance_recovery|tax|insurance|other"),
      amount: z.number().positive(),
      deduction_date: zDate,
      description: z.string().optional(),
      is_recurring: z.boolean().optional(),
      recurring_period: z.string().optional().describe("monthly|weekly|biweekly"),
      total_installments: z.number().int().optional(),
      notes: z.string().optional(),
    },
  );
  endpoint(server, ctx, "get_staff_deduction", "Get a staff deduction.", "GET", "/api/v1/staff/deductions/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "update_staff_deduction",
    "Update a staff deduction.",
    "PUT",
    "/api/v1/staff/deductions/:id",
    { id: zUuid, deduction_type: z.string().optional(), amount: z.number().optional(), description: z.string().optional(), deduction_date: zDate.optional(), is_recurring: z.boolean().optional(), recurring_period: z.string().optional(), total_installments: z.number().int().optional(), installments_paid: z.number().int().optional(), status: z.string().optional(), notes: z.string().optional() },
  );
  endpoint(server, ctx, "delete_staff_deduction", "Delete a staff deduction.", "DELETE", "/api/v1/staff/deductions/:id", { id: zUuid }, { destructive: true });

  // ---------- Staff advances ----------
  endpoint(server, ctx, "list_staff_advances", "List salary advances paid to staff.", "GET", "/api/v1/staff/advances", { staff_id: zUuid.optional(), status: z.string().optional().describe("pending|partial|recovered"), from: zDate.optional(), to: zDate.optional(), search: zSearch, page: zPage, per_page: zPerPage });
  endpoint(server, ctx, "get_staff_advance_stats", "Advance stats: total, recovered, pending.", "GET", "/api/v1/staff/advances/stats");
  endpoint(server, ctx, "get_next_advance_number", "Preview the next advance number.", "GET", "/api/v1/staff/advances/next-number");
  endpoint(
    server,
    ctx,
    "create_staff_advance",
    "Record a salary advance paid to a staff member (posts expense + cash entry).",
    "POST",
    "/api/v1/staff/advances",
    {
      staff_id: zUuid,
      amount: z.number().positive(),
      advance_date: zDate,
      reason: z.string().optional(),
      expected_recovery_date: zDate.optional(),
      payment_mode: z.string().optional().describe("cash|bank_transfer|upi|cheque"),
      reference: z.string().optional(),
      notes: z.string().optional(),
    },
  );
  endpoint(server, ctx, "get_staff_advance", "Get a staff advance.", "GET", "/api/v1/staff/advances/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "update_staff_advance",
    "Update a staff advance.",
    "PUT",
    "/api/v1/staff/advances/:id",
    { id: zUuid, amount: z.number().optional(), reason: z.string().optional(), advance_date: zDate.optional(), expected_recovery_date: zDate.optional(), payment_mode: z.string().optional(), status: z.string().optional(), notes: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "recover_staff_advance",
    "Record a recovery amount against an advance.",
    "POST",
    "/api/v1/staff/advances/:id/recover",
    { id: zUuid, recovery_amount: z.number().positive(), notes: z.string().optional() },
  );
  endpoint(server, ctx, "delete_staff_advance", "Delete a staff advance.", "DELETE", "/api/v1/staff/advances/:id", { id: zUuid }, { destructive: true });

  // ---------- Staff extra amounts ----------
  endpoint(server, ctx, "list_staff_extras", "List staff extra amounts (direction add=owed to staff, deduct=drawn by staff).", "GET", "/api/v1/staff/extras", { staff_id: zUuid.optional(), direction: z.string().optional(), status: z.string().optional(), from: zDate.optional(), to: zDate.optional(), search: zSearch, page: zPage, per_page: zPerPage });
  endpoint(server, ctx, "get_next_extra_number", "Preview the next extra amount number.", "GET", "/api/v1/staff/extras/next-number");
  endpoint(
    server,
    ctx,
    "create_staff_extra",
    "Create a staff extra amount. direction=add (incentive/reimbursement owed to staff) or deduct (draw owed by staff). redeem_now pays immediately.",
    "POST",
    "/api/v1/staff/extras",
    {
      staff_id: zUuid,
      direction: z.enum(["add", "deduct"]),
      amount: z.number().positive(),
      entry_date: zDate,
      reason: z.string().optional(),
      redeem_now: z.boolean().optional().describe("Pay/settle immediately instead of via payroll"),
      payment_mode: z.string().optional(),
      bank_account_id: zUuid.optional(),
      reference: z.string().optional(),
      notes: z.string().optional(),
    },
  );
  endpoint(server, ctx, "get_staff_extra", "Get a staff extra amount.", "GET", "/api/v1/staff/extras/:id", { id: zUuid });
  endpoint(
    server,
    ctx,
    "update_staff_extra",
    "Update a staff extra amount.",
    "PUT",
    "/api/v1/staff/extras/:id",
    { id: zUuid, direction: z.enum(["add", "deduct"]).optional(), amount: z.number().optional(), reason: z.string().optional(), entry_date: zDate.optional(), status: z.string().optional(), reference: z.string().optional(), notes: z.string().optional() },
  );
  endpoint(
    server,
    ctx,
    "redeem_staff_extra",
    "Redeem/pay out a pending staff extra amount.",
    "POST",
    "/api/v1/staff/extras/:id/redeem",
    { id: zUuid, payment_date: zDate.optional(), payment_mode: z.string().optional(), bank_account_id: zUuid.optional(), reference: z.string().optional(), notes: z.string().optional() },
  );
  endpoint(server, ctx, "delete_staff_extra", "Delete a staff extra amount.", "DELETE", "/api/v1/staff/extras/:id", { id: zUuid }, { destructive: true });
}
