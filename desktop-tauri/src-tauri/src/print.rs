use base64::Engine;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use std::process::Command;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PrinterInfo {
    pub name: String,
    pub is_default: bool,
}

#[tauri::command]
pub fn has_native_printing() -> bool {
    true
}

#[tauri::command]
pub fn list_printers() -> Result<Vec<PrinterInfo>, String> {
    list_system_printers()
}

#[tauri::command]
pub fn print_pdf(pdf_base64: String, printer_name: String, job_title: String) -> Result<(), String> {
    let mut raw = pdf_base64.trim().to_string();
    if raw.is_empty() {
        return Err("empty PDF content".into());
    }
    if let Some(i) = raw.find("base64,") {
        raw = raw[i + "base64,".len()..].to_string();
    }
    let data = base64::engine::general_purpose::STANDARD
        .decode(raw.as_bytes())
        .map_err(|e| format!("invalid PDF base64: {e}"))?;
    if data.len() < 5 || &data[..4] != b"%PDF" {
        return Err("content is not a PDF".into());
    }

    let title = {
        let t = job_title.trim();
        if t.is_empty() {
            "TruERP Document".to_string()
        } else {
            t.to_string()
        }
    };
    let path = write_temp_print_file(&format!("{}.pdf", sanitize_file_stem(&title)), &data)?;
    let result = print_pdf_file(&path, printer_name.trim(), &title);
    let _ = fs::remove_file(&path);
    result
}

fn write_temp_print_file(name: &str, data: &[u8]) -> Result<PathBuf, String> {
    let dir = std::env::temp_dir().join("truerp-print");
    fs::create_dir_all(&dir).map_err(|e| format!("temp dir: {e}"))?;
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_nanos())
        .unwrap_or(0);
    let path = dir.join(format!("{nanos}-{name}"));
    fs::write(&path, data).map_err(|e| format!("write temp pdf: {e}"))?;
    Ok(path)
}

fn sanitize_file_stem(s: &str) -> String {
    let mut out = String::new();
    for ch in s.chars() {
        match ch {
            'a'..='z' | 'A'..='Z' | '0'..='9' | '-' | '_' => out.push(ch),
            _ => out.push('-'),
        }
    }
    let trimmed = out.trim_matches('-');
    if trimmed.is_empty() {
        "print".into()
    } else if trimmed.len() > 48 {
        trimmed[..48].into()
    } else {
        trimmed.into()
    }
}

#[cfg(target_os = "macos")]
fn list_system_printers() -> Result<Vec<PrinterInfo>, String> {
    let output = Command::new("lpstat")
        .args(["-p", "-d"])
        .output()
        .map_err(|e| format!("lpstat: {e}"))?;
    let text = String::from_utf8_lossy(&output.stdout);
    let err = String::from_utf8_lossy(&output.stderr);
    if !output.status.success() {
        if err.contains("no destinations") || text.contains("no destinations") {
            return Ok(vec![]);
        }
        return Err(format!("lpstat failed: {}", err.trim()));
    }

    let mut default_name = String::new();
    let mut printers = Vec::new();
    for line in text.lines() {
        let line = line.trim();
        if let Some(rest) = line.strip_prefix("system default destination:") {
            default_name = rest.trim().to_string();
            continue;
        }
        if let Some(rest) = line.strip_prefix("printer ") {
            if let Some(name) = rest.split_whitespace().next() {
                printers.push(PrinterInfo {
                    name: name.to_string(),
                    is_default: false,
                });
            }
        }
    }
    for p in &mut printers {
        if p.name == default_name {
            p.is_default = true;
        }
    }
    Ok(printers)
}

#[cfg(target_os = "macos")]
fn print_pdf_file(path: &std::path::Path, printer_name: &str, title: &str) -> Result<(), String> {
    let mut args = vec!["-t".to_string(), title.to_string(), "-o".to_string(), "fit-to-page".to_string()];
    if !printer_name.is_empty() {
        args.insert(0, "-d".to_string());
        args.insert(1, printer_name.to_string());
    }
    args.push(path.display().to_string());
    let output = Command::new("lp")
        .args(&args)
        .output()
        .map_err(|e| format!("lp: {e}"))?;
    if !output.status.success() {
        return Err(format!(
            "lp: {}",
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }
    Ok(())
}

#[cfg(target_os = "windows")]
fn list_system_printers() -> Result<Vec<PrinterInfo>, String> {
    let ps = r#"
$ErrorActionPreference = 'Stop'
$default = (Get-CimInstance -ClassName Win32_Printer | Where-Object { $_.Default }).Name
Get-CimInstance -ClassName Win32_Printer | ForEach-Object {
  [PSCustomObject]@{ name = $_.Name; is_default = ($_.Name -eq $default) }
} | ConvertTo-Json -Compress
"#;
    let output = Command::new("powershell")
        .args(["-NoProfile", "-Command", ps])
        .output()
        .map_err(|e| format!("powershell Get-Printer: {e}"))?;
    if !output.status.success() {
        return Err(format!(
            "powershell Get-Printer: {}",
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }
    let trimmed = String::from_utf8_lossy(&output.stdout).trim().to_string();
    if trimmed.is_empty() || trimmed == "null" {
        return Ok(vec![]);
    }
    if trimmed.starts_with('{') {
        let one: PrinterInfo =
            serde_json::from_str(&trimmed).map_err(|e| format!("parse printer: {e}"))?;
        return Ok(vec![one]);
    }
    serde_json::from_str(&trimmed).map_err(|e| format!("parse printers: {e}"))
}

#[cfg(target_os = "windows")]
fn print_pdf_file(path: &std::path::Path, printer_name: &str, _title: &str) -> Result<(), String> {
    let path_s = path.display().to_string().replace('\'', "''");
    if !printer_name.is_empty() {
        let printer = printer_name.replace('\'', "''");
        let ps = format!(
            "$ErrorActionPreference = 'Stop'\nStart-Process -FilePath '{path_s}' -Verb PrintTo -ArgumentList '{printer}' -WindowStyle Hidden\nStart-Sleep -Seconds 2\n"
        );
        let output = Command::new("powershell")
            .args(["-NoProfile", "-Command", &ps])
            .output()
            .map_err(|e| format!("print pdf: {e}"))?;
        if output.status.success() {
            return Ok(());
        }
    }
    let ps = format!(
        "$ErrorActionPreference = 'Stop'\nStart-Process -FilePath '{path_s}' -Verb Print -WindowStyle Hidden\nStart-Sleep -Seconds 2\n"
    );
    let output = Command::new("powershell")
        .args(["-NoProfile", "-Command", &ps])
        .output()
        .map_err(|e| format!("print pdf: {e}"))?;
    if !output.status.success() {
        return Err(format!(
            "print pdf: {}",
            String::from_utf8_lossy(&output.stderr).trim()
        ));
    }
    Ok(())
}

#[cfg(not(any(target_os = "macos", target_os = "windows")))]
fn list_system_printers() -> Result<Vec<PrinterInfo>, String> {
    Ok(vec![])
}

#[cfg(not(any(target_os = "macos", target_os = "windows")))]
fn print_pdf_file(_path: &std::path::Path, _printer_name: &str, _title: &str) -> Result<(), String> {
    Err("native printing is not supported on this platform".into())
}
