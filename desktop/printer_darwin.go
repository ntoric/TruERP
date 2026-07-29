//go:build darwin

package main

import (
	"bytes"
	"fmt"
	"os/exec"
	"strings"
)

func listSystemPrinters() ([]PrinterInfo, error) {
	out, err := exec.Command("lpstat", "-p", "-d").CombinedOutput()
	if err != nil {
		if bytes.Contains(out, []byte("no destinations")) || bytes.Contains(out, []byte("No destinations")) {
			return []PrinterInfo{}, nil
		}
		return nil, fmt.Errorf("lpstat: %w (%s)", err, strings.TrimSpace(string(out)))
	}

	defaultName := ""
	var printers []PrinterInfo
	for _, line := range strings.Split(string(out), "\n") {
		line = strings.TrimSpace(line)
		if strings.HasPrefix(line, "system default destination:") {
			defaultName = strings.TrimSpace(strings.TrimPrefix(line, "system default destination:"))
			continue
		}
		if strings.HasPrefix(line, "printer ") {
			rest := strings.TrimPrefix(line, "printer ")
			name := strings.Fields(rest)
			if len(name) == 0 {
				continue
			}
			printers = append(printers, PrinterInfo{Name: name[0]})
		}
	}
	for i := range printers {
		if printers[i].Name == defaultName {
			printers[i].IsDefault = true
		}
	}
	return printers, nil
}

func printPDFFile(path, printerName, title string) error {
	args := []string{"-t", title, "-o", "fit-to-page"}
	if printerName != "" {
		args = append([]string{"-d", printerName}, args...)
	}
	args = append(args, path)
	out, err := exec.Command("lp", args...).CombinedOutput()
	if err != nil {
		return fmt.Errorf("lp: %w (%s)", err, strings.TrimSpace(string(out)))
	}
	return nil
}
