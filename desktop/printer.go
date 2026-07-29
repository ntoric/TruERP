package main

import (
	"encoding/base64"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// PrinterInfo describes an OS-installed printer.
type PrinterInfo struct {
	Name      string `json:"name"`
	IsDefault bool   `json:"is_default"`
}

// ListPrinters returns installed printers available to the desktop shell.
func (a *App) ListPrinters() ([]PrinterInfo, error) {
	return listSystemPrinters()
}

// PrintPDF sends a PDF document (base64) to the given printer (empty = default).
// This prints a proper page — not HTML.
func (a *App) PrintPDF(pdfBase64 string, printerName string, jobTitle string) error {
	raw := strings.TrimSpace(pdfBase64)
	if raw == "" {
		return fmt.Errorf("empty PDF content")
	}
	// Allow data-URL prefix from callers.
	if i := strings.Index(raw, "base64,"); i >= 0 {
		raw = raw[i+len("base64,"):]
	}
	data, err := base64.StdEncoding.DecodeString(raw)
	if err != nil {
		return fmt.Errorf("invalid PDF base64: %w", err)
	}
	if len(data) < 5 || string(data[:4]) != "%PDF" {
		return fmt.Errorf("content is not a PDF")
	}

	title := strings.TrimSpace(jobTitle)
	if title == "" {
		title = "TruERP Document"
	}
	path, err := writeTempPrintFile(sanitizeFileStem(title)+".pdf", data)
	if err != nil {
		return err
	}
	defer os.Remove(path)

	return printPDFFile(path, strings.TrimSpace(printerName), title)
}

// HasNativePrinting reports that this process exposes OS printer APIs.
func (a *App) HasNativePrinting() bool {
	return true
}

func writeTempPrintFile(name string, data []byte) (string, error) {
	dir := filepath.Join(os.TempDir(), "truerp-print")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}
	path := filepath.Join(dir, fmt.Sprintf("%d-%s", time.Now().UnixNano(), name))
	if err := os.WriteFile(path, data, 0o644); err != nil {
		return "", err
	}
	return path, nil
}

func sanitizeFileStem(s string) string {
	s = strings.TrimSpace(s)
	if s == "" {
		return "print"
	}
	var b strings.Builder
	for _, r := range s {
		switch {
		case r >= 'a' && r <= 'z', r >= 'A' && r <= 'Z', r >= '0' && r <= '9':
			b.WriteRune(r)
		case r == '-' || r == '_':
			b.WriteRune(r)
		default:
			b.WriteByte('-')
		}
	}
	out := strings.Trim(b.String(), "-")
	if out == "" {
		return "print"
	}
	if len(out) > 48 {
		out = out[:48]
	}
	return out
}
