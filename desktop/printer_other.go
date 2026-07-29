//go:build !darwin && !windows

package main

import (
	"fmt"
	"os/exec"
	"strings"
)

func listSystemPrinters() ([]PrinterInfo, error) {
	out, err := exec.Command("lpstat", "-a").CombinedOutput()
	if err != nil {
		return []PrinterInfo{}, nil
	}
	var printers []PrinterInfo
	for _, line := range strings.Split(string(out), "\n") {
		fields := strings.Fields(strings.TrimSpace(line))
		if len(fields) == 0 {
			continue
		}
		printers = append(printers, PrinterInfo{Name: fields[0]})
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
