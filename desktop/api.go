package main

import (
	"context"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"time"

	"truerp/controllers"
	"truerp/routes"
	"truerp/services"
	"truerp/utils"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
)

const apiAddr = "127.0.0.1:8088"

func (a *App) configureDataDirs() (string, error) {
	configDir, err := os.UserConfigDir()
	if err != nil {
		return "", fmt.Errorf("user config dir: %w", err)
	}

	dataRoot := filepath.Join(configDir, "TruERP")
	uploadsDir := filepath.Join(dataRoot, "uploads")
	dbPath := filepath.Join(dataRoot, "truerp.db")

	if err := os.MkdirAll(uploadsDir, 0o755); err != nil {
		return "", fmt.Errorf("create data dirs: %w", err)
	}

	_ = os.Setenv("DATABASE_PATH", dbPath)
	_ = os.Setenv("STORAGE_TYPE", "local")
	_ = os.Setenv("LOCAL_STORAGE_PATH", uploadsDir)
	_ = os.Setenv("LOCAL_STORAGE_BASE_URL", "/uploads")
	_ = os.Setenv("FRONTEND_URL", "http://127.0.0.1:3000")

	if os.Getenv("SUPER_ADMIN_EMAIL") == "" {
		_ = os.Setenv("SUPER_ADMIN_EMAIL", "admin@truerp.local")
	}
	if os.Getenv("SUPER_ADMIN_PASSWORD") == "" {
		_ = os.Setenv("SUPER_ADMIN_PASSWORD", "change-me-in-production")
	}
	if os.Getenv("SUPER_ADMIN_NAME") == "" {
		_ = os.Setenv("SUPER_ADMIN_NAME", "Super Admin")
	}

	return dataRoot, nil
}

// prepareRuntimeCwd sets the process working directory so backend relative
// paths (e.g. ../HSN_DATASET.csv) resolve from the app resource root.
// On macOS that is Contents/Resources; on Windows it is the exe directory.
func (a *App) prepareRuntimeCwd() error {
	var runtimeDir string
	for _, root := range appResourceRoots() {
		candidate := filepath.Join(root, "runtime")
		if _, err := os.Stat(candidate); err == nil {
			runtimeDir = candidate
			break
		}
		if _, err := os.Stat(filepath.Join(root, "HSN_DATASET.csv")); err == nil {
			runtimeDir = candidate
			break
		}
	}
	if runtimeDir == "" {
		exe, err := os.Executable()
		if err != nil {
			return err
		}
		exeDir := filepath.Dir(exe)
		if runtime.GOOS == "darwin" {
			runtimeDir = filepath.Clean(filepath.Join(exeDir, "..", "Resources", "runtime"))
		} else {
			runtimeDir = filepath.Join(exeDir, "runtime")
		}
	}
	if err := os.MkdirAll(runtimeDir, 0o755); err != nil {
		return err
	}
	return os.Chdir(runtimeDir)
}

func (a *App) startAPI(ctx context.Context) error {
	if err := a.prepareRuntimeCwd(); err != nil {
		log.Printf("warning: runtime cwd: %v", err)
	}

	dataRoot, err := a.configureDataDirs()
	if err != nil {
		return err
	}
	a.dataRoot = dataRoot
	log.Printf("TruERP data directory: %s", dataRoot)

	utils.InitDatabase()
	controllers.EnsureDefaultSuperAdmin()
	_ = services.GetDefaultStorageService()

	gin.SetMode(gin.ReleaseMode)
	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(gin.Logger())

	config := cors.DefaultConfig()
	config.AllowOrigins = []string{"*"}
	config.AllowHeaders = []string{"Origin", "Content-Type", "Accept", "Authorization"}
	r.Use(cors.New(config))

	storageConfig := services.GetStorageConfig()
	if storageConfig.Type == services.StorageTypeLocal {
		r.Static("/uploads", storageConfig.LocalPath)
	}

	routes.SetupRoutes(r)

	a.httpServer = &http.Server{
		Addr:              apiAddr,
		Handler:           r,
		ReadHeaderTimeout: 10 * time.Second,
	}

	ln, err := net.Listen("tcp", apiAddr)
	if err != nil {
		return fmt.Errorf("listen %s: %w", apiAddr, err)
	}

	go func() {
		log.Printf("TruERP API listening on http://%s", apiAddr)
		if err := a.httpServer.Serve(ln); err != nil && err != http.ErrServerClosed {
			log.Printf("API server error: %v", err)
		}
	}()

	if err := waitForAPI(ctx, "http://"+apiAddr+"/health", 30*time.Second); err != nil {
		return err
	}
	return nil
}

func (a *App) stopAPI() {
	if a.httpServer == nil {
		return
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := a.httpServer.Shutdown(ctx); err != nil {
		log.Printf("API shutdown: %v", err)
	}
}

func waitForAPI(ctx context.Context, url string, timeout time.Duration) error {
	deadline := time.Now().Add(timeout)
	client := &http.Client{Timeout: 2 * time.Second}
	for time.Now().Before(deadline) {
		select {
		case <-ctx.Done():
			return ctx.Err()
		default:
		}
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, url, nil)
		if err != nil {
			return err
		}
		resp, err := client.Do(req)
		if err == nil {
			_ = resp.Body.Close()
			if resp.StatusCode >= 200 && resp.StatusCode < 500 {
				return nil
			}
		}
		time.Sleep(200 * time.Millisecond)
	}
	return fmt.Errorf("API did not become ready at %s", url)
}
