package main

import (
	"billbook/controllers"
	"billbook/routes"
	"billbook/services"
	"billbook/utils"
	"log"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

func main() {
	// Initialize database
	utils.InitDatabase()
	controllers.EnsureDefaultSuperAdmin()

	// Initialize storage service
	_ = services.GetDefaultStorageService()

	// Setup Gin
	gin.SetMode(gin.ReleaseMode)
	r := gin.Default()

	// CORS
	config := cors.DefaultConfig()
	config.AllowOrigins = []string{"*"}
	config.AllowHeaders = []string{"Origin", "Content-Type", "Accept", "Authorization"}
	r.Use(cors.New(config))

	// Serve static files (uploads directory) - only for local storage
	storageConfig := services.GetStorageConfig()
	if storageConfig.Type == services.StorageTypeLocal {
		r.Static("/uploads", storageConfig.LocalPath)
	}

	// Setup routes
	routes.SetupRoutes(r)

	log.Println("Server starting on :8088")
	log.Printf("Storage type: %s", storageConfig.Type)
	if err := r.Run(":8088"); err != nil {
		log.Fatal("Failed to start server:", err)
	}
}
