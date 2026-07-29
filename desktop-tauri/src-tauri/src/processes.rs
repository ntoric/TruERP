use crate::paths::{
    ensure_runtime_cwd, find_api_binary, find_node_binary, find_server_dir, resource_roots,
};
use std::path::PathBuf;
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant};
use tauri::AppHandle;

pub const API_ADDR: &str = "127.0.0.1:8088";
pub const FRONTEND_ADDR: &str = "127.0.0.1:3000";
pub const PROXY_ADDR: &str = "127.0.0.1:17888";

pub struct RuntimeProcesses {
    pub data_root: PathBuf,
    pub frontend_ready: Arc<AtomicBool>,
    api_child: Mutex<Option<Child>>,
    frontend_child: Mutex<Option<Child>>,
}

impl RuntimeProcesses {
    pub fn new(data_root: PathBuf) -> Self {
        Self {
            data_root,
            frontend_ready: Arc::new(AtomicBool::new(false)),
            api_child: Mutex::new(None),
            frontend_child: Mutex::new(None),
        }
    }

    pub fn stop(&self) {
        if let Ok(mut guard) = self.frontend_child.lock() {
            if let Some(mut child) = guard.take() {
                let _ = child.kill();
                let _ = child.wait();
            }
        }
        if let Ok(mut guard) = self.api_child.lock() {
            if let Some(mut child) = guard.take() {
                let _ = child.kill();
                let _ = child.wait();
            }
        }
    }
}

impl Drop for RuntimeProcesses {
    fn drop(&mut self) {
        self.stop();
    }
}

pub fn configure_data_dirs() -> Result<PathBuf, String> {
    let config_dir =
        dirs::config_dir().ok_or_else(|| "cannot resolve user config dir".to_string())?;
    let data_root = config_dir.join("TruERP");
    let uploads = data_root.join("uploads");
    std::fs::create_dir_all(&uploads).map_err(|e| format!("create data dirs: {e}"))?;

    let db_path = data_root.join("truerp.db");
    std::env::set_var("DATABASE_PATH", &db_path);
    std::env::set_var("STORAGE_TYPE", "local");
    std::env::set_var("LOCAL_STORAGE_PATH", &uploads);
    std::env::set_var("LOCAL_STORAGE_BASE_URL", "/uploads");
    std::env::set_var("FRONTEND_URL", format!("http://{FRONTEND_ADDR}"));

    if std::env::var_os("SUPER_ADMIN_EMAIL").is_none() {
        std::env::set_var("SUPER_ADMIN_EMAIL", "admin@truerp.local");
    }
    if std::env::var_os("SUPER_ADMIN_PASSWORD").is_none() {
        std::env::set_var("SUPER_ADMIN_PASSWORD", "change-me-in-production");
    }
    if std::env::var_os("SUPER_ADMIN_NAME").is_none() {
        std::env::set_var("SUPER_ADMIN_NAME", "Super Admin");
    }

    Ok(data_root)
}

pub fn start_runtime_into(app: &AppHandle, runtime: &RuntimeProcesses) -> Result<(), String> {
    let roots = resource_roots(app);
    let _ = ensure_runtime_cwd(&roots).map_err(|e| format!("runtime cwd: {e}"))?;
    log::info!("TruERP data directory: {}", runtime.data_root.display());
    start_api(runtime, &roots)?;
    start_frontend(runtime, &roots)?;
    Ok(())
}

fn start_api(runtime: &RuntimeProcesses, roots: &[PathBuf]) -> Result<(), String> {
    let api_bin = find_api_binary(roots).ok_or_else(|| {
        "TruERP API binary not found. Run ./scripts/prepare-api.sh".to_string()
    })?;

    log::info!("Starting API: {}", api_bin.display());
    let mut cmd = Command::new(&api_bin);
    cmd.env("DATABASE_PATH", runtime.data_root.join("truerp.db"))
        .env("STORAGE_TYPE", "local")
        .env("LOCAL_STORAGE_PATH", runtime.data_root.join("uploads"))
        .env("LOCAL_STORAGE_BASE_URL", "/uploads")
        .env("FRONTEND_URL", format!("http://{FRONTEND_ADDR}"))
        .env(
            "SUPER_ADMIN_EMAIL",
            std::env::var("SUPER_ADMIN_EMAIL").unwrap_or_else(|_| "admin@truerp.local".into()),
        )
        .env(
            "SUPER_ADMIN_PASSWORD",
            std::env::var("SUPER_ADMIN_PASSWORD")
                .unwrap_or_else(|_| "change-me-in-production".into()),
        )
        .env(
            "SUPER_ADMIN_NAME",
            std::env::var("SUPER_ADMIN_NAME").unwrap_or_else(|_| "Super Admin".into()),
        )
        .stdout(Stdio::null())
        .stderr(Stdio::null());

    let child = cmd
        .spawn()
        .map_err(|e| format!("failed to start API ({}): {e}", api_bin.display()))?;

    *runtime
        .api_child
        .lock()
        .map_err(|_| "api child lock poisoned".to_string())? = Some(child);

    wait_http(&format!("http://{API_ADDR}/health"), Duration::from_secs(45))?;
    log::info!("TruERP API listening on http://{API_ADDR}");
    Ok(())
}

fn start_frontend(runtime: &RuntimeProcesses, roots: &[PathBuf]) -> Result<(), String> {
    let server_dir = find_server_dir(roots).ok_or_else(|| {
        "Next.js standalone server not found. Run ./scripts/prepare-frontend.sh".to_string()
    })?;
    let node_bin = find_node_binary(roots).ok_or_else(|| {
        "Node.js binary not found. Run ./scripts/prepare-bundle.sh or install Node.js".to_string()
    })?;

    log::info!(
        "Starting UI: {} (node {})",
        server_dir.display(),
        node_bin.display()
    );

    let mut cmd = Command::new(&node_bin);
    cmd.arg("server.js")
        .current_dir(&server_dir)
        .env("PORT", "3000")
        .env("HOSTNAME", "127.0.0.1")
        .env("HOST", "127.0.0.1")
        .stdout(Stdio::null())
        .stderr(Stdio::null());

    let child = cmd
        .spawn()
        .map_err(|e| format!("failed to start Next.js: {e}"))?;

    *runtime
        .frontend_child
        .lock()
        .map_err(|_| "frontend child lock poisoned".to_string())? = Some(child);

    wait_http(&format!("http://{FRONTEND_ADDR}"), Duration::from_secs(90))?;
    runtime.frontend_ready.store(true, Ordering::SeqCst);
    log::info!("TruERP UI listening on http://{FRONTEND_ADDR}");
    Ok(())
}

fn wait_http(url: &str, timeout: Duration) -> Result<(), String> {
    let deadline = Instant::now() + timeout;
    while Instant::now() < deadline {
        if http_status(url).is_ok_and(|code| (200..500).contains(&code)) {
            return Ok(());
        }
        std::thread::sleep(Duration::from_millis(200));
    }
    Err(format!("service did not become ready at {url}"))
}

fn http_status(url: &str) -> Result<u16, ()> {
    use std::io::{Read, Write};
    use std::net::TcpStream;

    let url = url.strip_prefix("http://").ok_or(())?;
    let (host_port, path) = match url.split_once('/') {
        Some((hp, p)) => (hp, format!("/{p}")),
        None => (url, "/".to_string()),
    };
    let mut stream = TcpStream::connect(host_port).map_err(|_| ())?;
    stream
        .set_read_timeout(Some(Duration::from_secs(2)))
        .map_err(|_| ())?;
    stream
        .set_write_timeout(Some(Duration::from_secs(2)))
        .map_err(|_| ())?;
    let req = format!("GET {path} HTTP/1.1\r\nHost: {host_port}\r\nConnection: close\r\n\r\n");
    stream.write_all(req.as_bytes()).map_err(|_| ())?;
    let mut buf = [0u8; 64];
    let n = stream.read(&mut buf).map_err(|_| ())?;
    let head = String::from_utf8_lossy(&buf[..n]);
    head.split_whitespace()
        .nth(1)
        .and_then(|s| s.parse::<u16>().ok())
        .ok_or(())
}
