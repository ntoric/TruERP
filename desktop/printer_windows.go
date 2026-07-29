//go:build windows

package main

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
)

func listSystemPrinters() ([]PrinterInfo, error) {
	ps := `
$ErrorActionPreference = 'Stop'
$default = (Get-CimInstance -ClassName Win32_Printer | Where-Object { $_.Default }).Name
Get-CimInstance -ClassName Win32_Printer | ForEach-Object {
  [PSCustomObject]@{ name = $_.Name; is_default = ($_.Name -eq $default) }
} | ConvertTo-Json -Compress
`
	out, err := exec.Command("powershell", "-NoProfile", "-Command", ps).CombinedOutput()
	if err != nil {
		return nil, fmt.Errorf("powershell Get-Printer: %w (%s)", err, strings.TrimSpace(string(out)))
	}
	trimmed := strings.TrimSpace(string(out))
	if trimmed == "" || trimmed == "null" {
		return []PrinterInfo{}, nil
	}
	if strings.HasPrefix(trimmed, "{") {
		var one PrinterInfo
		if err := json.Unmarshal([]byte(trimmed), &one); err != nil {
			return nil, err
		}
		return []PrinterInfo{one}, nil
	}
	var list []PrinterInfo
	if err := json.Unmarshal([]byte(trimmed), &list); err != nil {
		return nil, err
	}
	return list, nil
}

func psQuote(s string) string {
	return "'" + strings.ReplaceAll(s, "'", "''") + "'"
}

func printPDFFile(path, printerName, _ string) error {
	// Prefer PrintTo for a named printer; otherwise Print verb (default printer).
	if printerName != "" {
		ps := fmt.Sprintf(`
$ErrorActionPreference = 'Stop'
Start-Process -FilePath %s -Verb PrintTo -ArgumentList %s -WindowStyle Hidden
Start-Sleep -Seconds 2
`, psQuote(path), psQuote(printerName))
		out, err := exec.Command("powershell", "-NoProfile", "-Command", ps).CombinedOutput()
		if err == nil {
			return nil
		}
		_ = out
	}

	ps := fmt.Sprintf(`
$ErrorActionPreference = 'Stop'
Start-Process -FilePath %s -Verb Print -WindowStyle Hidden
Start-Sleep -Seconds 2
`, psQuote(path))
	out, err := exec.Command("powershell", "-NoProfile", "-Command", ps).CombinedOutput()
	if err != nil {
		return fmt.Errorf("print pdf: %w (%s)", err, strings.TrimSpace(string(out)))
	}
	return nil
}
