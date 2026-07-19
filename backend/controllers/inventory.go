package controllers

import (
	"billbook/models"
	"billbook/utils"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type StockBalance struct {
	ProductID   uuid.UUID `json:"product_id"`
	ProductName string    `json:"product_name"`
	SKU         string    `json:"sku"`
	StockQty    float64   `json:"stock_qty"`
	CostPrice   float64   `json:"cost_price"`
	Value       float64   `json:"value"`
	OutletID    uuid.UUID `json:"outlet_id"`
	OutletName  string    `json:"outlet_name"`
}

func GetStockBalance(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	outletID := c.Query("outlet_id")

	fmt.Printf("[DEBUG] GetStockBalance - UserID: %s, OutletID: %s\n", userID, outletID)

	var stocks []models.InventoryStock
	query := utils.DB.Where("user_id = ?", userID).Preload("Product")

	if outletID != "" {
		query = query.Where("outlet_id = ?", outletID)
	}

	if err := query.Find(&stocks).Error; err != nil {
		fmt.Printf("[DEBUG] GetStockBalance - DB error: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch stock balance"})
		return
	}

	fmt.Printf("[DEBUG] GetStockBalance - Found %d stocks\n", len(stocks))

	// Fetch outlet names
	var outletIDs []uuid.UUID
	for _, stock := range stocks {
		outletIDs = append(outletIDs, stock.OutletID)
	}
	var warehouses []models.Warehouse
	if len(outletIDs) > 0 {
		utils.DB.Where("id IN ?", outletIDs).Find(&warehouses)
	}
	warehouseMap := make(map[uuid.UUID]string)
	for _, wh := range warehouses {
		warehouseMap[wh.ID] = wh.Name
	}

	var balances []StockBalance
	for _, stock := range stocks {
		balances = append(balances, StockBalance{
			ProductID:   stock.ProductID,
			ProductName: stock.Product.Name,
			SKU:         stock.Product.SKU,
			StockQty:    stock.Quantity,
			CostPrice:   stock.AverageCost,
			Value:       stock.Quantity * stock.AverageCost,
			OutletID:    stock.OutletID,
			OutletName:  warehouseMap[stock.OutletID],
		})
	}

	c.JSON(http.StatusOK, gin.H{"data": balances})
}

func GetStockEntries(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	productID := c.Query("product_id")
	entryType := c.Query("entry_type")
	outletID := c.Query("outlet_id")
	fromDate := c.Query("from_date")
	toDate := c.Query("to_date")

	fmt.Printf("[DEBUG] GetStockEntries - UserID: %s, ProductID: %s, EntryType: %s, OutletID: %s\n", userID, productID, entryType, outletID)

	var entries []models.StockEntry
	query := utils.DB.Where("user_id = ?", userID).Preload("Product")

	if productID != "" {
		query = query.Where("product_id = ?", productID)
	}

	if entryType != "" {
		query = query.Where("entry_type = ?", entryType)
	}

	if outletID != "" {
		query = query.Where("outlet_id = ?", outletID)
	}

	if fromDate != "" {
		query = query.Where("entry_date >= ?", fromDate)
	}
	if toDate != "" {
		query = query.Where("entry_date <= ?", toDate)
	}

	if err := query.Order("entry_date DESC").Find(&entries).Error; err != nil {
		fmt.Printf("[DEBUG] GetStockEntries - DB error: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch entries"})
		return
	}

	fmt.Printf("[DEBUG] GetStockEntries - Found %d entries\n", len(entries))

	// Fetch outlet names
	var outletIDs []uuid.UUID
	for _, entry := range entries {
		outletIDs = append(outletIDs, entry.OutletID)
	}
	var warehouses []models.Warehouse
	if len(outletIDs) > 0 {
		utils.DB.Where("id IN ?", outletIDs).Find(&warehouses)
	}
	warehouseMap := make(map[uuid.UUID]string)
	for _, wh := range warehouses {
		warehouseMap[wh.ID] = wh.Name
	}

	// Add outlet names to entries
	type StockEntryWithDetails struct {
		models.StockEntry
		OutletName string `json:"outlet_name"`
	}
	var entriesWithDetails []StockEntryWithDetails
	for _, entry := range entries {
		entriesWithDetails = append(entriesWithDetails, StockEntryWithDetails{
			StockEntry: entry,
			OutletName: warehouseMap[entry.OutletID],
		})
	}

	c.JSON(http.StatusOK, gin.H{"data": entriesWithDetails})
}

func CreateStockEntry(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var input struct {
		ItemName      string     `json:"item_name" binding:"required"`
		ProductID     *uuid.UUID `json:"product_id"`
		OutletID      uuid.UUID  `json:"outlet_id" binding:"required"`
		EntryType     string     `json:"entry_type" binding:"required,oneof=purchase sale adjustment transfer opening"`
		Quantity      float64    `json:"quantity" binding:"required"`
		CostPrice     float64    `json:"cost_price"`
		BatchNo       string     `json:"batch_no"`
		ItemCode      string     `json:"item_code"`
		MfgDate       *time.Time `json:"mfg_date"`
		ExpDate       *time.Time `json:"exp_date"`
		Notes         string     `json:"notes"`
		ReferenceID   uuid.UUID  `json:"reference_id"`
		ReferenceType string     `json:"reference_type"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		fmt.Printf("[DEBUG] CreateStockEntry - JSON bind error: %v\n", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	fmt.Printf("[DEBUG] CreateStockEntry - UserID: %s, ItemName: %s, EntryType: %s, Quantity: %f\n", userID, input.ItemName, input.EntryType, input.Quantity)

	// Verify product exists if provided
	if input.ProductID != nil {
		var product models.Product
		if err := utils.DB.Where("user_id = ? AND id = ?", userID, *input.ProductID).First(&product).Error; err != nil {
			fmt.Printf("[DEBUG] CreateStockEntry - Product not found: %v\n", err)
			c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
			return
		}
	}

	entry := models.StockEntry{
		ID:            uuid.New(),
		UserID:        userID,
		ItemName:      input.ItemName,
		ProductID:     input.ProductID,
		OutletID:      input.OutletID,
		EntryType:     input.EntryType,
		Quantity:      input.Quantity,
		BalanceQty:    0,
		CostPrice:     input.CostPrice,
		BatchNo:       input.BatchNo,
		ItemCode:      input.ItemCode,
		MfgDate:       input.MfgDate,
		ExpDate:       input.ExpDate,
		ReferenceID:   input.ReferenceID,
		ReferenceType: input.ReferenceType,
		Notes:         input.Notes,
		EntryDate:     time.Now(),
	}

	if err := utils.DB.Create(&entry).Error; err != nil {
		fmt.Printf("[DEBUG] CreateStockEntry - DB create error: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create entry"})
		return
	}

	fmt.Printf("[DEBUG] CreateStockEntry - Entry created successfully: %s\n", entry.ID)

	// Update inventory stock if product is linked
	if input.ProductID != nil {
		updateInventoryStock(userID, *input.ProductID, input.OutletID, input.EntryType, input.Quantity, input.CostPrice)
	}

	c.JSON(http.StatusCreated, entry)
}

func UpdateStockEntry(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	id := c.Param("id")

	fmt.Printf("[DEBUG] UpdateStockEntry - ID: %s, UserID: %s\n", id, userID)

	var entry models.StockEntry
	if err := utils.DB.Where("user_id = ? AND id = ?", userID, id).First(&entry).Error; err != nil {
		fmt.Printf("[DEBUG] UpdateStockEntry - Entry not found: %v\n", err)
		c.JSON(http.StatusNotFound, gin.H{"error": "Stock entry not found"})
		return
	}

	var input struct {
		Quantity  float64 `json:"quantity"`
		CostPrice float64 `json:"cost_price"`
		BatchNo   string  `json:"batch_no"`
		ItemCode  string  `json:"item_code"`
		MfgDate   string  `json:"mfg_date"`
		ExpDate   string  `json:"exp_date"`
		Notes     string  `json:"notes"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		fmt.Printf("[DEBUG] UpdateStockEntry - JSON bind error: %v\n", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Parse date strings to time.Time
	var mfgDate, expDate *time.Time
	if input.MfgDate != "" {
		if t, err := time.Parse("2006-01-02", input.MfgDate); err == nil {
			mfgDate = &t
		}
	}
	if input.ExpDate != "" {
		if t, err := time.Parse("2006-01-02", input.ExpDate); err == nil {
			expDate = &t
		}
	}

	// Calculate the difference in quantity
	quantityDiff := input.Quantity - entry.Quantity

	// Update the entry
	updates := map[string]interface{}{
		"quantity":   input.Quantity,
		"cost_price": input.CostPrice,
		"batch_no":   input.BatchNo,
		"item_code":  input.ItemCode,
		"notes":      input.Notes,
	}
	
	// Only include dates if they are provided
	if mfgDate != nil {
		updates["mfg_date"] = mfgDate
	}
	if expDate != nil {
		updates["exp_date"] = expDate
	}

	if err := utils.DB.Model(&entry).Updates(updates).Error; err != nil {
		fmt.Printf("[DEBUG] UpdateStockEntry - DB update error: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update entry"})
		return
	}

	// Update inventory stock if product is linked
	if entry.ProductID != nil {
		// Adjust the inventory stock by the difference
		updateInventoryStock(userID, *entry.ProductID, entry.OutletID, "adjustment", quantityDiff, input.CostPrice)
	}

	fmt.Printf("[DEBUG] UpdateStockEntry - Entry updated successfully: %s\n", entry.ID)
	c.JSON(http.StatusOK, entry)
}

func updateInventoryStock(userID, productID, outletID uuid.UUID, entryType string, quantity, costPrice float64) {
	fmt.Printf("[DEBUG] updateInventoryStock - UserID: %s, ProductID: %s, OutletID: %s, EntryType: %s, Quantity: %f\n", userID, productID, outletID, entryType, quantity)

	var stock models.InventoryStock
	err := utils.DB.Where("user_id = ? AND product_id = ? AND outlet_id = ?", userID, productID, outletID).First(&stock).Error

	if err != nil {
		fmt.Printf("[DEBUG] updateInventoryStock - Creating new stock record\n")
		// Create new stock record
		stock = models.InventoryStock{
			ID:           uuid.New(),
			UserID:       userID,
			ProductID:    productID,
			OutletID:     outletID,
			Quantity:     0,
			ReservedQty:  0,
			AvailableQty: 0,
			AverageCost:  costPrice,
			LastUpdated:  time.Now(),
		}
	}

	// Update quantity based on entry type
	switch entryType {
	case "purchase", "opening", "adjustment":
		stock.Quantity += quantity
		// Update weighted average cost
		if stock.Quantity > 0 && costPrice > 0 {
			stock.AverageCost = ((stock.AverageCost * (stock.Quantity - quantity)) + (costPrice * quantity)) / stock.Quantity
		}
	case "sale", "transfer":
		stock.Quantity -= quantity
	}

	stock.AvailableQty = stock.Quantity - stock.ReservedQty
	stock.LastUpdated = time.Now()

	if err := utils.DB.Save(&stock).Error; err != nil {
		fmt.Printf("[DEBUG] updateInventoryStock - DB save error: %v\n", err)
	} else {
		fmt.Printf("[DEBUG] updateInventoryStock - Stock updated successfully: Quantity=%f, Available=%f\n", stock.Quantity, stock.AvailableQty)
	}
}

func GetStockTransfers(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	status := c.Query("status")

	fmt.Printf("[DEBUG] GetStockTransfers - UserID: %s, Status: %s\n", userID, status)

	var transfers []models.StockTransfer
	query := utils.DB.Where("user_id = ?", userID).Preload("Items")

	if status != "" {
		query = query.Where("status = ?", status)
	}

	if err := query.Order("created_at DESC").Find(&transfers).Error; err != nil {
		fmt.Printf("[DEBUG] GetStockTransfers - DB error: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch transfers"})
		return
	}

	fmt.Printf("[DEBUG] GetStockTransfers - Found %d transfers\n", len(transfers))
	c.JSON(http.StatusOK, transfers)
}

func GetStockTransfer(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	id := c.Param("id")

	fmt.Printf("[DEBUG] GetStockTransfer - UserID: %s, ID: %s\n", userID, id)

	var transfer models.StockTransfer
	if err := utils.DB.Where("user_id = ? AND id = ?", userID, id).Preload("Items").First(&transfer).Error; err != nil {
		fmt.Printf("[DEBUG] GetStockTransfer - Transfer not found: %v\n", err)
		c.JSON(http.StatusNotFound, gin.H{"error": "Transfer not found"})
		return
	}

	c.JSON(http.StatusOK, transfer)
}

func CreateStockTransfer(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var input struct {
		FromOutletID uuid.UUID `json:"from_outlet_id"`
		ToOutletID   uuid.UUID `json:"to_outlet_id" binding:"required"`
		Notes        string    `json:"notes"`
		Items        []struct {
			ProductID uuid.UUID `json:"product_id" binding:"required"`
			Quantity  float64   `json:"quantity" binding:"required,gt=0"`
		} `json:"items" binding:"required,min=1"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		fmt.Printf("[DEBUG] CreateStockTransfer - JSON bind error: %v\n", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	fmt.Printf("[DEBUG] CreateStockTransfer - UserID: %s, ToOutletID: %s, Items: %d\n", userID, input.ToOutletID, len(input.Items))

	transfer := models.StockTransfer{
		ID:            uuid.New(),
		UserID:        userID,
		FromOutletID:  input.FromOutletID,
		ToOutletID:    input.ToOutletID,
		Status:        "draft",
		TotalItems:    len(input.Items),
		Notes:         input.Notes,
	}

	for _, item := range input.Items {
		// Verify product exists
		var product models.Product
		if err := utils.DB.Where("user_id = ? AND id = ?", userID, item.ProductID).First(&product).Error; err == nil {
			transfer.Items = append(transfer.Items, models.StockTransferItem{
				ID:        uuid.New(),
				TransferID: transfer.ID,
				ProductID: item.ProductID,
				Quantity:  item.Quantity,
			})
			transfer.TotalQuantity += item.Quantity
		}
	}

	if err := utils.DB.Create(&transfer).Error; err != nil {
		fmt.Printf("[DEBUG] CreateStockTransfer - DB create error: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create transfer"})
		return
	}

	fmt.Printf("[DEBUG] CreateStockTransfer - Transfer created successfully: %s\n", transfer.ID)
	c.JSON(http.StatusCreated, transfer)
}

func SubmitStockTransfer(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	id := c.Param("id")

	fmt.Printf("[DEBUG] SubmitStockTransfer - UserID: %s, ID: %s\n", userID, id)

	var transfer models.StockTransfer
	if err := utils.DB.Where("user_id = ? AND id = ?", userID, id).Preload("Items").First(&transfer).Error; err != nil {
		fmt.Printf("[DEBUG] SubmitStockTransfer - Transfer not found: %v\n", err)
		c.JSON(http.StatusNotFound, gin.H{"error": "Transfer not found"})
		return
	}

	if transfer.Status != "draft" {
		fmt.Printf("[DEBUG] SubmitStockTransfer - Transfer already submitted, status: %s\n", transfer.Status)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Transfer already submitted"})
		return
	}

	now := time.Now()
	transfer.Status = "submitted"
	transfer.SentDate = &now

	for _, item := range transfer.Items {
		item.SentQuantity = item.Quantity
		utils.DB.Save(&item)
	}

	utils.DB.Save(&transfer)
	fmt.Printf("[DEBUG] SubmitStockTransfer - Transfer submitted successfully: %s\n", id)
	c.JSON(http.StatusOK, transfer)
}

func ReceiveStockTransfer(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	id := c.Param("id")

	fmt.Printf("[DEBUG] ReceiveStockTransfer - UserID: %s, ID: %s\n", userID, id)

	var transfer models.StockTransfer
	if err := utils.DB.Where("user_id = ? AND id = ?", userID, id).Preload("Items").First(&transfer).Error; err != nil {
		fmt.Printf("[DEBUG] ReceiveStockTransfer - Transfer not found: %v\n", err)
		c.JSON(http.StatusNotFound, gin.H{"error": "Transfer not found"})
		return
	}

	if transfer.Status != "submitted" {
		fmt.Printf("[DEBUG] ReceiveStockTransfer - Transfer not ready for receipt, status: %s\n", transfer.Status)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Transfer not ready for receipt"})
		return
	}

	now := time.Now()
	transfer.Status = "received"
	transfer.ReceivedDate = &now

	for _, item := range transfer.Items {
		item.ReceivedQuantity = item.SentQuantity
		utils.DB.Save(&item)
	}

	utils.DB.Save(&transfer)
	fmt.Printf("[DEBUG] ReceiveStockTransfer - Transfer received successfully: %s\n", id)
	c.JSON(http.StatusOK, transfer)
}

func GetInventoryValuation(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	outletID := c.Query("outlet_id")

	fmt.Printf("[DEBUG] GetInventoryValuation - UserID: %s, OutletID: %s\n", userID, outletID)

	var stocks []models.InventoryStock
	query := utils.DB.Where("user_id = ?", userID).Preload("Product")

	if outletID != "" {
		query = query.Where("outlet_id = ?", outletID)
	}

	if err := query.Find(&stocks).Error; err != nil {
		fmt.Printf("[DEBUG] GetInventoryValuation - DB error: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch valuation"})
		return
	}

	type ValuationResult struct {
		ProductID   uuid.UUID `json:"product_id"`
		ProductName string    `json:"product_name"`
		SKU         string    `json:"sku"`
		StockQty    float64   `json:"stock_qty"`
		CostPrice   float64   `json:"cost_price"`
		TotalValue  float64   `json:"total_value"`
		OutletID    uuid.UUID `json:"outlet_id"`
		OutletName  string    `json:"outlet_name"`
	}

	var results []ValuationResult
	var totalValue float64

	// Fetch outlet names
	var outletIDs []uuid.UUID
	for _, stock := range stocks {
		outletIDs = append(outletIDs, stock.OutletID)
	}
	var warehouses []models.Warehouse
	if len(outletIDs) > 0 {
		utils.DB.Where("id IN ?", outletIDs).Find(&warehouses)
	}
	warehouseMap := make(map[uuid.UUID]string)
	for _, wh := range warehouses {
		warehouseMap[wh.ID] = wh.Name
	}

	for _, stock := range stocks {
		itemValue := stock.Quantity * stock.AverageCost
		totalValue += itemValue
		results = append(results, ValuationResult{
			ProductID:   stock.ProductID,
			ProductName: stock.Product.Name,
			SKU:         stock.Product.SKU,
			StockQty:    stock.Quantity,
			CostPrice:   stock.AverageCost,
			TotalValue:  itemValue,
			OutletID:    stock.OutletID,
			OutletName:  warehouseMap[stock.OutletID],
		})
	}

	fmt.Printf("[DEBUG] GetInventoryValuation - Total value: %f, Items: %d\n", totalValue, len(results))
	c.JSON(http.StatusOK, gin.H{
		"items":       results,
		"total_value": totalValue,
	})
}

// Inventory Stock Management
func GetInventoryStocks(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	productID := c.Query("product_id")
	outletID := c.Query("outlet_id")

	fmt.Printf("[DEBUG] GetInventoryStocks - UserID: %s, ProductID: %s, OutletID: %s\n", userID, productID, outletID)

	var stocks []models.InventoryStock
	query := utils.DB.Where("user_id = ?", userID).Preload("Product")

	if productID != "" {
		query = query.Where("product_id = ?", productID)
	}
	if outletID != "" {
		query = query.Where("outlet_id = ?", outletID)
	}

	if err := query.Find(&stocks).Error; err != nil {
		fmt.Printf("[DEBUG] GetInventoryStocks - DB error: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch inventory stocks"})
		return
	}

	fmt.Printf("[DEBUG] GetInventoryStocks - Found %d stocks\n", len(stocks))

	// Fetch outlet names
	var outletIDs []uuid.UUID
	for _, stock := range stocks {
		outletIDs = append(outletIDs, stock.OutletID)
	}
	var warehouses []models.Warehouse
	if len(outletIDs) > 0 {
		utils.DB.Where("id IN ?", outletIDs).Find(&warehouses)
	}
	warehouseMap := make(map[uuid.UUID]string)
	for _, wh := range warehouses {
		warehouseMap[wh.ID] = wh.Name
	}

	// Add outlet names to stocks
	type InventoryStockWithOutlet struct {
		models.InventoryStock
		OutletName string `json:"outlet_name"`
	}
	var stocksWithOutlet []InventoryStockWithOutlet
	for _, stock := range stocks {
		stocksWithOutlet = append(stocksWithOutlet, InventoryStockWithOutlet{
			InventoryStock: stock,
			OutletName:     warehouseMap[stock.OutletID],
		})
	}

	c.JSON(http.StatusOK, stocksWithOutlet)
}

func GetProductStock(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	productID := c.Param("id")

	fmt.Printf("[DEBUG] GetProductStock - UserID: %s, ProductID: %s\n", userID, productID)

	var stocks []models.InventoryStock
	if err := utils.DB.Where("user_id = ? AND product_id = ?", userID, productID).Find(&stocks).Error; err != nil {
		fmt.Printf("[DEBUG] GetProductStock - DB error: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch product stock"})
		return
	}
}

func SearchByItemCode(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)
	itemCode := strings.TrimSpace(c.Query("item_code"))
	if itemCode == "" {
		itemCode = strings.TrimSpace(c.Query("barcode"))
	}
	outletID := c.Query("outlet_id")

	fmt.Printf("[DEBUG] SearchByItemCode - UserID: %s, ItemCode: %s, OutletID: %s\n", userID, itemCode, outletID)

	if itemCode == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Item code is required"})
		return
	}

	var entries []models.StockEntry
	query := utils.DB.Where("user_id = ? AND TRIM(item_code) = ?", userID, itemCode).Preload("Product")

	if outletID != "" {
		query = query.Where("outlet_id = ?", outletID)
	}

	if err := query.Find(&entries).Error; err != nil {
		fmt.Printf("[DEBUG] SearchByItemCode - DB error: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to search by item code"})
		return
	}

	fmt.Printf("[DEBUG] SearchByItemCode - Found %d entries\n", len(entries))

	if len(entries) == 0 {
		var products []models.Product
		if err := utils.DB.Where(
			"user_id = ? AND (TRIM(item_code) = ? OR TRIM(sku) = ?)",
			userID, itemCode, itemCode,
		).Find(&products).Error; err != nil {
			fmt.Printf("[DEBUG] SearchByItemCode - Product fallback error: %v\n", err)
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to search by item code"})
			return
		}
		if len(products) == 0 {
			c.JSON(http.StatusNotFound, gin.H{"error": "No products found with this item code"})
			return
		}
		results := make([]map[string]interface{}, 0, len(products))
		for _, product := range products {
			results = append(results, map[string]interface{}{
				"product_id":     product.ID,
				"product_name":   product.Name,
				"sku":            product.SKU,
				"item_code":      product.ItemCode,
				"unit":           product.Unit,
				"purchase_price": product.PurchasePrice,
				"sale_price":     product.SalePrice,
				"tax_rate":       product.TaxRate,
				"hsn_code":       product.HSNCode,
			})
		}
		c.JSON(http.StatusOK, gin.H{"data": results})
		return
	}

	// Transform to product list with entry information
	results := make([]map[string]interface{}, 0)
	for _, entry := range entries {
		result := map[string]interface{}{
			"product_id":   entry.ProductID,
			"product_name": entry.Product.Name,
			"sku":          entry.Product.SKU,
			"item_code":    entry.ItemCode,
			"outlet_id":    entry.OutletID,
			"quantity":     entry.Quantity,
			"cost_price":   entry.CostPrice,
			"batch_no":     entry.BatchNo,
			"unit":         entry.Product.Unit,
			"purchase_price": entry.Product.PurchasePrice,
			"sale_price":   entry.Product.SalePrice,
			"tax_rate":     entry.Product.TaxRate,
			"hsn_code":     entry.Product.HSNCode,
		}
		results = append(results, result)
	}

	c.JSON(http.StatusOK, gin.H{"data": results})
}

func AdjustStock(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var input struct {
		ItemName  string     `json:"item_name" binding:"required"`
		ProductID *uuid.UUID `json:"product_id"`
		OutletID  uuid.UUID  `json:"outlet_id" binding:"required"`
		Quantity  float64   `json:"quantity" binding:"required"`
		Reason    string     `json:"reason"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		fmt.Printf("[DEBUG] AdjustStock - JSON bind error: %v\n", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	fmt.Printf("[DEBUG] AdjustStock - UserID: %s, ItemName: %s, Quantity: %f\n", userID, input.ItemName, input.Quantity)

	// Verify product exists if provided
	if input.ProductID != nil {
		var product models.Product
		if err := utils.DB.Where("user_id = ? AND id = ?", userID, *input.ProductID).First(&product).Error; err != nil {
			fmt.Printf("[DEBUG] AdjustStock - Product not found: %v\n", err)
			c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
			return
		}
	}

	// Create stock entry
	entry := models.StockEntry{
		ID:         uuid.New(),
		UserID:     userID,
		ItemName:   input.ItemName,
		ProductID:  input.ProductID,
		OutletID:   input.OutletID,
		EntryType:  "adjustment",
		Quantity:   input.Quantity,
		BalanceQty: 0,
		Notes:      input.Reason,
		EntryDate:  time.Now(),
	}

	if err := utils.DB.Create(&entry).Error; err != nil {
		fmt.Printf("[DEBUG] AdjustStock - DB create error: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create adjustment entry"})
		return
	}

	fmt.Printf("[DEBUG] AdjustStock - Entry created successfully: %s\n", entry.ID)

	// Update inventory stock if product is linked
	if input.ProductID != nil {
		updateInventoryStock(userID, *input.ProductID, input.OutletID, "adjustment", input.Quantity, 0)
	}

	c.JSON(http.StatusCreated, entry)
}

func ReserveStock(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var input struct {
		ProductID uuid.UUID `json:"product_id" binding:"required"`
		OutletID  uuid.UUID `json:"outlet_id" binding:"required"`
		Quantity  float64  `json:"quantity" binding:"required"`
		Reason    string    `json:"reason"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		fmt.Printf("[DEBUG] ReserveStock - JSON bind error: %v\n", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	fmt.Printf("[DEBUG] ReserveStock - UserID: %s, ProductID: %s, OutletID: %s, Quantity: %f\n", userID, input.ProductID, input.OutletID, input.Quantity)

	// Verify product exists
	var product models.Product
	if err := utils.DB.Where("user_id = ? AND id = ?", userID, input.ProductID).First(&product).Error; err != nil {
		fmt.Printf("[DEBUG] ReserveStock - Product not found: %v\n", err)
		c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
		return
	}

	// Get inventory stock
	var stock models.InventoryStock
	if err := utils.DB.Where("user_id = ? AND product_id = ? AND outlet_id = ?", userID, input.ProductID, input.OutletID).First(&stock).Error; err != nil {
		fmt.Printf("[DEBUG] ReserveStock - Stock not found: %v\n", err)
		c.JSON(http.StatusNotFound, gin.H{"error": "Stock not found for this product and outlet"})
		return
	}

	// Check if enough available stock
	if stock.AvailableQty < input.Quantity {
		fmt.Printf("[DEBUG] ReserveStock - Insufficient stock: Available=%f, Requested=%f\n", stock.AvailableQty, input.Quantity)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Insufficient available stock"})
		return
	}

	// Update reserved quantity
	if err := utils.DB.Model(&stock).Update("reserved_qty", stock.ReservedQty+input.Quantity).Error; err != nil {
		fmt.Printf("[DEBUG] ReserveStock - DB update error: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to reserve stock"})
		return
	}

	// Create stock entry for reservation
	entry := models.StockEntry{
		ID:         uuid.New(),
		UserID:     userID,
		ItemName:   product.Name,
		ProductID:  &input.ProductID,
		OutletID:   input.OutletID,
		EntryType:  "reservation",
		Quantity:   -input.Quantity,
		BalanceQty: 0,
		CostPrice:  stock.AverageCost,
		Notes:      input.Reason,
		EntryDate:  time.Now(),
	}

	if err := utils.DB.Create(&entry).Error; err != nil {
		fmt.Printf("[DEBUG] ReserveStock - Failed to create entry: %v\n", err)
	}

	fmt.Printf("[DEBUG] ReserveStock - Stock reserved successfully\n")
	c.JSON(http.StatusOK, gin.H{"message": "Stock reserved successfully", "reserved_qty": stock.ReservedQty + input.Quantity})
}

func ReleaseStock(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	var input struct {
		ProductID uuid.UUID `json:"product_id" binding:"required"`
		OutletID  uuid.UUID `json:"outlet_id" binding:"required"`
		Quantity  float64  `json:"quantity" binding:"required"`
		Reason    string    `json:"reason"`
	}

	if err := c.ShouldBindJSON(&input); err != nil {
		fmt.Printf("[DEBUG] ReleaseStock - JSON bind error: %v\n", err)
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	fmt.Printf("[DEBUG] ReleaseStock - UserID: %s, ProductID: %s, OutletID: %s, Quantity: %f\n", userID, input.ProductID, input.OutletID, input.Quantity)

	// Verify product exists
	var product models.Product
	if err := utils.DB.Where("user_id = ? AND id = ?", userID, input.ProductID).First(&product).Error; err != nil {
		fmt.Printf("[DEBUG] ReleaseStock - Product not found: %v\n", err)
		c.JSON(http.StatusNotFound, gin.H{"error": "Product not found"})
		return
	}

	// Get inventory stock
	var stock models.InventoryStock
	if err := utils.DB.Where("user_id = ? AND product_id = ? AND outlet_id = ?", userID, input.ProductID, input.OutletID).First(&stock).Error; err != nil {
		fmt.Printf("[DEBUG] ReleaseStock - Stock not found: %v\n", err)
		c.JSON(http.StatusNotFound, gin.H{"error": "Stock not found for this product and outlet"})
		return
	}

	// Check if enough reserved stock
	if stock.ReservedQty < input.Quantity {
		fmt.Printf("[DEBUG] ReleaseStock - Insufficient reserved stock: Reserved=%f, Requested=%f\n", stock.ReservedQty, input.Quantity)
		c.JSON(http.StatusBadRequest, gin.H{"error": "Insufficient reserved stock"})
		return
	}

	// Update reserved quantity
	if err := utils.DB.Model(&stock).Update("reserved_qty", stock.ReservedQty-input.Quantity).Error; err != nil {
		fmt.Printf("[DEBUG] ReleaseStock - DB update error: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to release stock"})
		return
	}

	// Create stock entry for release
	entry := models.StockEntry{
		ID:         uuid.New(),
		UserID:     userID,
		ItemName:   product.Name,
		ProductID:  &input.ProductID,
		OutletID:   input.OutletID,
		EntryType:  "release",
		Quantity:   input.Quantity,
		BalanceQty: 0,
		CostPrice:  stock.AverageCost,
		Notes:      input.Reason,
		EntryDate:  time.Now(),
	}

	if err := utils.DB.Create(&entry).Error; err != nil {
		fmt.Printf("[DEBUG] ReleaseStock - Failed to create entry: %v\n", err)
	}

	fmt.Printf("[DEBUG] ReleaseStock - Stock released successfully\n")
	c.JSON(http.StatusOK, gin.H{"message": "Stock released successfully", "reserved_qty": stock.ReservedQty - input.Quantity})
}

func GetLowStockAlerts(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	fmt.Printf("[DEBUG] GetLowStockAlerts - UserID: %s\n", userID)

	type LowStockItem struct {
		ProductID    uuid.UUID `json:"product_id"`
		ProductName  string    `json:"product_name"`
		SKU          string    `json:"sku"`
		CurrentStock float64   `json:"current_stock"`
		MinStock     float64   `json:"min_stock"`
		OutletID     uuid.UUID `json:"outlet_id"`
		OutletName   string    `json:"outlet_name"`
	}

	var results []LowStockItem
	query := `
		SELECT p.id as product_id, p.name as product_name, p.sku, p.min_stock, s.outlet_id, s.quantity as current_stock, w.name as outlet_name
		FROM products p
		INNER JOIN inventory_stocks s ON p.id = s.product_id
		LEFT JOIN warehouses w ON s.outlet_id = w.id
		WHERE p.user_id = ? AND p.low_stock_alert = true AND s.quantity <= p.min_stock
	`

	if err := utils.DB.Raw(query, userID).Scan(&results).Error; err != nil {
		fmt.Printf("[DEBUG] GetLowStockAlerts - DB error: %v\n", err)
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to fetch low stock alerts"})
		return
	}

	fmt.Printf("[DEBUG] GetLowStockAlerts - Found %d low stock alerts\n", len(results))
	c.JSON(http.StatusOK, results)
}

// GetInventoryItems returns all items (products and standalone stock entries) for dropdown selection
func GetInventoryItems(c *gin.Context) {
	userID := c.MustGet("user_id").(uuid.UUID)

	fmt.Printf("[DEBUG] GetInventoryItems - UserID: %s\n", userID)

	type InventoryItem struct {
		ID       uuid.UUID `json:"id"`
		Name     string    `json:"name"`
		SKU      string    `json:"sku"`
		Type     string    `json:"type"` // "product" or "standalone"
		IsActive bool      `json:"is_active"`
	}

	var items []InventoryItem

	// Get all active products
	var products []models.Product
	if err := utils.DB.Where("user_id = ? AND is_active = ?", userID, true).Find(&products).Error; err != nil {
		fmt.Printf("[DEBUG] GetInventoryItems - Failed to fetch products: %v\n", err)
	} else {
		for _, p := range products {
			items = append(items, InventoryItem{
				ID:       p.ID,
				Name:     p.Name,
				SKU:      p.SKU,
				Type:     "product",
				IsActive: p.IsActive,
			})
		}
	}

	// Get standalone stock entries (entries without product_id)
	var standaloneEntries []models.StockEntry
	if err := utils.DB.Where("user_id = ? AND product_id IS NULL", userID).Group("item_name").Find(&standaloneEntries).Error; err != nil {
		fmt.Printf("[DEBUG] GetInventoryItems - Failed to fetch standalone entries: %v\n", err)
	} else {
		for _, entry := range standaloneEntries {
			items = append(items, InventoryItem{
				ID:       entry.ID,
				Name:     entry.ItemName,
				SKU:      "",
				Type:     "standalone",
				IsActive: true,
			})
		}
	}

	fmt.Printf("[DEBUG] GetInventoryItems - Found %d items\n", len(items))
	c.JSON(http.StatusOK, items)
}
