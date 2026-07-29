package main

import (
	"context"
	"log"
	"net/http"
	"os/exec"
	"sync/atomic"
)

// App is the Wails application binding surface.
type App struct {
	ctx           context.Context
	httpServer    *http.Server
	frontendCmd   *exec.Cmd
	dataRoot      string
	frontendReady atomic.Bool
}

// NewApp creates a new App application struct.
func NewApp() *App {
	return &App{}
}

// startup is called when the app starts.
func (a *App) startup(ctx context.Context) {
	a.ctx = ctx

	if err := a.startAPI(ctx); err != nil {
		log.Printf("failed to start TruERP API: %v", err)
		return
	}
	if err := a.startFrontend(ctx); err != nil {
		log.Printf("failed to start TruERP UI server: %v", err)
	}
}

// shutdown is called when the app is closing.
func (a *App) shutdown(ctx context.Context) {
	a.stopFrontend()
	a.stopAPI()
}

// APIStatus reports whether the embedded API is configured.
func (a *App) APIStatus() string {
	if a.httpServer == nil {
		return "stopped"
	}
	return "running"
}

// FrontendReady reports whether the local Next.js UI is accepting requests.
func (a *App) FrontendReady() bool {
	return a.frontendReady.Load()
}

// DataDirectory returns the user config path used for SQLite and uploads.
func (a *App) DataDirectory() string {
	return a.dataRoot
}
