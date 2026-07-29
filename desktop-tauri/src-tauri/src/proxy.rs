use crate::processes::{API_ADDR, FRONTEND_ADDR, PROXY_ADDR};
use bytes::Bytes;
use http_body_util::{BodyExt, Full};
use hyper::body::Incoming;
use hyper::header::{HeaderMap, HeaderName, HeaderValue, HOST};
use hyper::server::conn::http1;
use hyper::service::service_fn;
use hyper::{Request, Response, StatusCode, Uri};
use hyper_util::rt::TokioIo;
use std::convert::Infallible;
use std::net::SocketAddr;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use tokio::net::TcpListener;

pub async fn run_proxy(frontend_ready: Arc<AtomicBool>) -> Result<(), String> {
    let addr: SocketAddr = PROXY_ADDR
        .parse()
        .map_err(|e| format!("invalid proxy addr: {e}"))?;
    let listener = TcpListener::bind(addr)
        .await
        .map_err(|e| format!("bind proxy {PROXY_ADDR}: {e}"))?;
    log::info!("TruERP reverse proxy listening on http://{PROXY_ADDR}");

    loop {
        let (stream, _) = listener
            .accept()
            .await
            .map_err(|e| format!("proxy accept: {e}"))?;
        let ready = Arc::clone(&frontend_ready);
        tokio::spawn(async move {
            let io = TokioIo::new(stream);
            let service = service_fn(move |req| {
                let ready = Arc::clone(&ready);
                async move { handle(req, ready).await }
            });
            if let Err(err) = http1::Builder::new().serve_connection(io, service).await {
                log::warn!("proxy connection error: {err}");
            }
        });
    }
}

async fn handle(
    req: Request<Incoming>,
    frontend_ready: Arc<AtomicBool>,
) -> Result<Response<Full<Bytes>>, Infallible> {
    let path = req.uri().path().to_string();

    if path == "/__truerp/ready" {
        if frontend_ready.load(Ordering::SeqCst) {
            return Ok(Response::builder()
                .status(StatusCode::NO_CONTENT)
                .body(Full::new(Bytes::new()))
                .unwrap());
        }
        return Ok(status_text(
            StatusCode::SERVICE_UNAVAILABLE,
            "starting",
        ));
    }

    if is_api_path(&path) {
        return Ok(proxy_to(req, API_ADDR).await);
    }

    if frontend_ready.load(Ordering::SeqCst) {
        return Ok(proxy_to(req, FRONTEND_ADDR).await);
    }

    Ok(status_text(
        StatusCode::SERVICE_UNAVAILABLE,
        "TruERP UI is starting",
    ))
}

fn is_api_path(path: &str) -> bool {
    path.starts_with("/api/") || path.starts_with("/uploads/") || path == "/health"
}

async fn proxy_to(req: Request<Incoming>, target_host: &str) -> Response<Full<Bytes>> {
    let method = req.method().clone();
    let headers = req.headers().clone();
    let path_and_query = req
        .uri()
        .path_and_query()
        .map(|pq| pq.as_str())
        .unwrap_or("/");

    let target: Uri = match format!("http://{target_host}{path_and_query}").parse() {
        Ok(u) => u,
        Err(_) => return status_text(StatusCode::BAD_GATEWAY, "invalid upstream URL"),
    };

    let body_bytes = match req.collect().await {
        Ok(collected) => collected.to_bytes(),
        Err(err) => {
            log::warn!("read request body: {err}");
            return status_text(StatusCode::BAD_REQUEST, "failed to read body");
        }
    };

    let mut builder = Request::builder().method(method).uri(target);
    copy_headers(headers, builder.headers_mut().unwrap(), target_host);

    let upstream_req = match builder.body(Full::new(body_bytes)) {
        Ok(r) => r,
        Err(_) => return status_text(StatusCode::BAD_GATEWAY, "failed to build upstream request"),
    };

    match hyper_client_request(upstream_req).await {
        Ok(resp) => resp,
        Err(err) => {
            log::warn!("upstream {target_host} error: {err}");
            status_text(StatusCode::BAD_GATEWAY, "TruERP upstream is unavailable")
        }
    }
}

fn copy_headers(src: HeaderMap, dst: &mut HeaderMap, target_host: &str) {
    for (key, value) in src.iter() {
        if key == HOST {
            continue;
        }
        // hop-by-hop
        if matches!(
            key.as_str(),
            "connection"
                | "keep-alive"
                | "proxy-authenticate"
                | "proxy-authorization"
                | "te"
                | "trailers"
                | "transfer-encoding"
                | "upgrade"
        ) {
            continue;
        }
        dst.append(key, value.clone());
    }
    if let Ok(v) = HeaderValue::from_str(target_host) {
        dst.insert(HOST, v);
    }
    let _ = HeaderName::from_static("x-forwarded-host");
}

async fn hyper_client_request(
    req: Request<Full<Bytes>>,
) -> Result<Response<Full<Bytes>>, String> {
    use hyper_util::client::legacy::connect::HttpConnector;
    use hyper_util::client::legacy::Client;
    use hyper_util::rt::TokioExecutor;

    let client = Client::builder(TokioExecutor::new()).build(HttpConnector::new());
    let resp = client
        .request(req)
        .await
        .map_err(|e| format!("request failed: {e}"))?;

    let status = resp.status();
    let headers = resp.headers().clone();
    let body = resp
        .collect()
        .await
        .map_err(|e| format!("read response: {e}"))?
        .to_bytes();

    let mut out = Response::builder().status(status);
    if let Some(h) = out.headers_mut() {
        for (k, v) in headers.iter() {
            if matches!(
                k.as_str(),
                "transfer-encoding" | "connection" | "content-length"
            ) {
                continue;
            }
            h.append(k, v.clone());
        }
    }
    out.body(Full::new(body))
        .map_err(|e| format!("build response: {e}"))
}

fn status_text(status: StatusCode, msg: &str) -> Response<Full<Bytes>> {
    Response::builder()
        .status(status)
        .header(hyper::header::CONTENT_TYPE, "text/plain; charset=utf-8")
        .body(Full::new(Bytes::from(msg.to_string())))
        .unwrap()
}
