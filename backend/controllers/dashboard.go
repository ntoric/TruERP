package controllers

import (
	"billbook/models"
	"billbook/utils"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

func GetDashboardStats(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var stats models.DashboardStats

	// Total sales
	utils.DB.Model(&models.Invoice{}).Where("user_id = ? AND status = ?", userID, "paid").Select("COALESCE(SUM(total_amount), 0)").Scan(&stats.TotalSales)
	utils.DB.Model(&models.Invoice{}).Where("user_id = ?", userID).Count(&stats.TotalInvoices)
	utils.DB.Model(&models.Party{}).Where("user_id = ?", userID).Count(&stats.TotalParties)

	// Pending amount (unpaid invoices)
	utils.DB.Model(&models.Invoice{}).Where("user_id = ? AND status IN ?", userID, []string{"sent", "overdue"}).Select("COALESCE(SUM(total_amount - amount_paid), 0)").Scan(&stats.PendingAmount)

	// Today's sales
	today := time.Now().Format("2006-01-02")
	utils.DB.Model(&models.Invoice{}).Where("user_id = ? AND DATE(date) = ? AND status = ?", userID, today, "paid").Select("COALESCE(SUM(total_amount), 0)").Scan(&stats.TodaySales)
	utils.DB.Model(&models.Invoice{}).Where("user_id = ? AND DATE(date) = ?", userID, today).Count(&stats.TodayInvoices)

	// Overdue invoices
	utils.DB.Model(&models.Invoice{}).Where("user_id = ? AND status = ? AND due_date < ?", userID, "sent", time.Now()).Count(&stats.OverdueInvoices)

	c.JSON(http.StatusOK, stats)
}

func GetRecentInvoices(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var invoices []models.Invoice
	if err := utils.DB.Where("user_id = ?", userID).Preload("Party").Order("created_at DESC").Limit(5).Find(&invoices).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch recent invoices"})
		return
	}

	c.JSON(http.StatusOK, invoices)
}

func GetRecentPayments(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var payments []models.Payment
	if err := utils.DB.Where("user_id = ?", userID).Order("created_at DESC").Limit(5).Find(&payments).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch recent payments"})
		return
	}

	c.JSON(http.StatusOK, payments)
}

func GetSalesReport(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	period := c.DefaultQuery("period", "monthly") // daily, weekly, monthly, yearly

	type ReportItem struct {
		Period string  `json:"period"`
		Sales  float64 `json:"sales"`
		Count  int64   `json:"count"`
	}

	var results []ReportItem
	var query string

	switch period {
	case "daily":
		query = "SELECT DATE(date) as period, COALESCE(SUM(total_amount), 0) as sales, COUNT(*) as count FROM invoices WHERE user_id = ? AND status = 'paid' GROUP BY DATE(date) ORDER BY period DESC LIMIT 30"
	case "weekly":
		query = "SELECT strftime('%Y-W%W', date) as period, COALESCE(SUM(total_amount), 0) as sales, COUNT(*) as count FROM invoices WHERE user_id = ? AND status = 'paid' GROUP BY strftime('%Y-W%W', date) ORDER BY period DESC LIMIT 12"
	case "yearly":
		query = "SELECT strftime('%Y', date) as period, COALESCE(SUM(total_amount), 0) as sales, COUNT(*) as count FROM invoices WHERE user_id = ? AND status = 'paid' GROUP BY strftime('%Y', date) ORDER BY period DESC LIMIT 5"
	default: // monthly
		query = "SELECT strftime('%Y-%m', date) as period, COALESCE(SUM(total_amount), 0) as sales, COUNT(*) as count FROM invoices WHERE user_id = ? AND status = 'paid' GROUP BY strftime('%Y-%m', date) ORDER BY period DESC LIMIT 12"
	}

	if err := utils.DB.Raw(query, userID).Scan(&results).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate sales report"})
		return
	}

	c.JSON(http.StatusOK, results)
}

func GetGSTReport(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var reports []models.GSTReport
	query := `
		SELECT 
			strftime('%Y-%m', date) as month,
			COALESCE(SUM(cgst_total), 0) as cgst,
			COALESCE(SUM(sgst_total), 0) as sgst,
			COALESCE(SUM(igst_total), 0) as igst,
			COALESCE(SUM(cgst_total + sgst_total + igst_total), 0) as total_tax,
			COALESCE(SUM(total_amount), 0) as total_value
		FROM invoices 
		WHERE user_id = ? AND status IN ('paid', 'sent')
		GROUP BY strftime('%Y-%m', date)
		ORDER BY month DESC
		LIMIT 12
	`

	if err := utils.DB.Raw(query, userID).Scan(&reports).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate GST report"})
		return
	}

	c.JSON(http.StatusOK, reports)
}

func GetTopParties(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	type TopParty struct {
		PartyID     uuid.UUID `json:"party_id"`
		Name        string    `json:"name"`
		TotalSales  float64   `json:"total_sales"`
		InvoiceCount int64   `json:"invoice_count"`
	}

	var results []TopParty
	query := `
		SELECT 
			p.id as party_id,
			p.name,
			COALESCE(SUM(i.total_amount), 0) as total_sales,
			COUNT(i.id) as invoice_count
		FROM parties p
		LEFT JOIN invoices i ON p.id = i.party_id AND i.status = 'paid'
		WHERE p.user_id = ?
		GROUP BY p.id, p.name
		ORDER BY total_sales DESC
		LIMIT 5
	`

	if err := utils.DB.Raw(query, userID).Scan(&results).Error; err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch top parties"})
		return
	}

	c.JSON(http.StatusOK, results)
}
