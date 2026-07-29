package main

import (
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"time"
)

const frontendAddr = "127.0.0.1:3000"

func singleHostProxy(targetURL, label string) http.Handler {
	target, err := url.Parse(targetURL)
	if err != nil {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			http.Error(w, "invalid "+label+" URL", http.StatusInternalServerError)
		})
	}
	proxy := httputil.NewSingleHostReverseProxy(target)
	originalDirector := proxy.Director
	proxy.Director = func(r *http.Request) {
		originalDirector(r)
		r.Host = target.Host
	}
	proxy.ErrorHandler = func(w http.ResponseWriter, r *http.Request, err error) {
		log.Printf("%s proxy error: %v", label, err)
		http.Error(w, "TruERP "+label+" is unavailable", http.StatusBadGateway)
	}
	return proxy
}

func (a *App) frontendProxy() http.Handler {
	return singleHostProxy("http://"+frontendAddr, "UI")
}

func (a *App) apiProxy() http.Handler {
	return singleHostProxy("http://"+apiAddr, "API")
}

func isAPIPath(path string) bool {
	return strings.HasPrefix(path, "/api/") ||
		strings.HasPrefix(path, "/uploads/") ||
		path == "/health"
}

// assetMiddleware serves the splash assets until Next.js is ready, then proxies
// UI requests to Next.js. API traffic is always proxied same-origin to Gin so
// the WebView never has to call localhost:8088 directly (which hangs/fails).
func (a *App) assetMiddleware(next http.Handler) http.Handler {
	uiProxy := a.frontendProxy()
	apiProxy := a.apiProxy()
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/__truerp/ready" {
			if a.frontendReady.Load() {
				w.WriteHeader(http.StatusNoContent)
				return
			}
			http.Error(w, "starting", http.StatusServiceUnavailable)
			return
		}
		if isAPIPath(r.URL.Path) {
			apiProxy.ServeHTTP(w, r)
			return
		}
		if a.frontendReady.Load() {
			uiProxy.ServeHTTP(w, r)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func (a *App) startFrontend(ctx context.Context) error {
	serverDir, nodeBin, err := resolveFrontendRuntime()
	if err != nil {
		return err
	}

	cmd := exec.CommandContext(ctx, nodeBin, "server.js")
	cmd.Dir = serverDir
	cmd.Env = append(os.Environ(),
		"PORT=3000",
		"HOSTNAME=127.0.0.1",
		"HOST=127.0.0.1",
	)
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	stderr, err := cmd.StderrPipe()
	if err != nil {
		return err
	}
	go pipeLog("next", stdout)
	go pipeLog("next", stderr)

	if err := cmd.Start(); err != nil {
		return fmt.Errorf("start Next.js server: %w", err)
	}
	a.frontendCmd = cmd

	go func() {
		if err := cmd.Wait(); err != nil {
			log.Printf("Next.js server exited: %v", err)
		}
	}()

	if err := waitForAPI(ctx, "http://"+frontendAddr, 60*time.Second); err != nil {
		return fmt.Errorf("frontend ready check: %w", err)
	}
	a.frontendReady.Store(true)
	log.Printf("TruERP UI listening on http://%s", frontendAddr)
	return nil
}

func (a *App) stopFrontend() {
	if a.frontendCmd == nil || a.frontendCmd.Process == nil {
		return
	}
	_ = a.frontendCmd.Process.Kill()
	_, _ = a.frontendCmd.Process.Wait()
	a.frontendCmd = nil
}

func appResourceRoots() []string {
	roots := []string{}
	exe, err := os.Executable()
	if err == nil {
		exeDir := filepath.Dir(exe)
		roots = append(roots, exeDir)
		// macOS app bundle: Contents/MacOS/TruERP → Contents/Resources
		resources := filepath.Clean(filepath.Join(exeDir, "..", "Resources"))
		roots = append(roots, resources)
	}
	if wd, wdErr := os.Getwd(); wdErr == nil {
		roots = append(roots, wd, filepath.Join(wd, "bundle"))
	}
	return roots
}

func resolveFrontendRuntime() (serverDir, nodeBin string, err error) {
	roots := appResourceRoots()

	candidates := []string{}
	for _, root := range roots {
		candidates = append(candidates,
			filepath.Join(root, "server"),
			filepath.Join(root, "frontend", "server"),
		)
	}
	if wd, wdErr := os.Getwd(); wdErr == nil {
		candidates = append(candidates,
			filepath.Join(wd, "frontend", "server"),
			filepath.Join(wd, "..", "desktop", "frontend", "server"),
		)
	}

	for _, dir := range candidates {
		if _, statErr := os.Stat(filepath.Join(dir, "server.js")); statErr == nil {
			serverDir = dir
			break
		}
	}
	if serverDir == "" {
		return "", "", fmt.Errorf("Next.js standalone server not found (run ./scripts/prepare-frontend.sh)")
	}

	nodeCandidates := []string{}
	for _, root := range roots {
		if runtime.GOOS == "windows" {
			nodeCandidates = append(nodeCandidates, filepath.Join(root, "node", "node.exe"))
		} else {
			nodeCandidates = append(nodeCandidates, filepath.Join(root, "node", "bin", "node"))
		}
	}
	// Prefer bundled Node, else system Node on PATH.
	for _, candidate := range nodeCandidates {
		if _, statErr := os.Stat(candidate); statErr == nil {
			nodeBin = candidate
			break
		}
	}
	if nodeBin == "" {
		if path, lookErr := exec.LookPath("node"); lookErr == nil {
			nodeBin = path
		}
	}
	if nodeBin == "" {
		return "", "", fmt.Errorf("node binary not found (bundle Node via ./scripts/prepare-bundle.sh or install Node.js)")
	}

	return serverDir, nodeBin, nil
}

func pipeLog(prefix string, r io.Reader) {
	buf := make([]byte, 4096)
	for {
		n, err := r.Read(buf)
		if n > 0 {
			log.Printf("[%s] %s", prefix, string(buf[:n]))
		}
		if err != nil {
			return
		}
	}
}
