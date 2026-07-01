use axum::{
    Json, Router,
    extract::{Path, Query},
    routing::{delete, get, post},
};
use serde::{Deserialize, Serialize};
use std::{
    collections::HashMap,
    fs,
    net::SocketAddr,
    path::PathBuf,
    process::Command,
    time::{SystemTime, UNIX_EPOCH},
};
use tower_http::cors::CorsLayer;

#[derive(Clone, Deserialize, Serialize)]
struct LabelRequest {
    product_number: String,
    #[serde(default)]
    product_name: String,
    quantity: u32,
    #[serde(default)]
    item_type: String,
    #[serde(default)]
    weight: String,
    barcode: String,
    #[serde(default)]
    notes: String,
    #[serde(default)]
    print: bool,
    #[serde(default)]
    printer_name: Option<String>,
    #[serde(default = "default_print_density")]
    print_density: u8,
    #[serde(default = "default_label_width_mm")]
    label_width_mm: f64,
    #[serde(default = "default_label_length_mm")]
    label_length_mm: f64,
    #[serde(default = "default_layout_preset")]
    layout_preset: String,
    #[serde(default = "default_barcode_width_pct")]
    barcode_width_pct: u8,
    #[serde(default = "default_barcode_height_pct")]
    barcode_height_pct: u8,
    #[serde(default)]
    show_qr: bool,
    #[serde(default)]
    driver_media_name: Option<String>,
    #[serde(default = "default_printer_profile")]
    printer_profile: String,
    #[serde(default = "default_zpl_dpi")]
    zpl_dpi: u16,
    #[serde(default = "default_print_orientation")]
    print_orientation: String,
    #[serde(default)]
    display_options: serde_json::Value,
    #[serde(default)]
    font_settings: serde_json::Value,
    #[serde(default)]
    layout_offsets: serde_json::Value,
}

fn default_zpl_dpi() -> u16 {
    203
}

fn default_print_orientation() -> String {
    "horizontal".to_string()
}

fn default_printer_profile() -> String {
    "brother_ql_windows".to_string()
}

fn default_layout_preset() -> String {
    "compact_right".to_string()
}

fn default_barcode_width_pct() -> u8 {
    42
}

fn default_barcode_height_pct() -> u8 {
    42
}

fn default_label_width_mm() -> f64 {
    62.0
}

fn default_label_length_mm() -> f64 {
    60.0
}

fn default_print_density() -> u8 {
    5
}

#[derive(Deserialize)]
struct ClearQueueRequest {
    #[serde(default)]
    printer_name: Option<String>,
    #[serde(default)]
    job_id: Option<u32>,
}

#[derive(Deserialize)]
struct SaveTemplateRequest {
    name: String,
    label: LabelRequest,
}

fn templates_dir() -> PathBuf {
    PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("..")
        .join("printer")
        .join("Templates")
}

fn safe_template_id(name: &str) -> String {
    let mut id = String::new();
    for ch in name.chars() {
        if ch.is_ascii_alphanumeric() {
            id.push(ch.to_ascii_lowercase());
        } else if (ch == ' ' || ch == '-' || ch == '_') && !id.ends_with('-') {
            id.push('-');
        }
    }
    let id = id.trim_matches('-').to_string();
    if id.is_empty() { "template".to_string() } else { id }
}

async fn health() -> Json<serde_json::Value> {
    Json(serde_json::json!({ "status": "ok" }))
}

async fn list_printers() -> Json<serde_json::Value> {
    let output = Command::new("powershell.exe")
        .args([
            "-NoProfile",
            "-ExecutionPolicy",
            "Bypass",
            "-Command",
            "Get-Printer | Select-Object Name,DriverName,PortName,PrinterStatus,WorkOffline | ConvertTo-Json -Depth 10",
        ])
        .output();

    match output {
        Ok(output) if output.status.success() => {
            let stdout = String::from_utf8_lossy(&output.stdout);
            let printers = serde_json::from_str::<serde_json::Value>(&stdout)
                .unwrap_or_else(|_| serde_json::json!([]));
            Json(serde_json::json!({ "status": "ok", "printers": printers }))
        }
        Ok(output) => Json(serde_json::json!({
            "status": "error",
            "error": String::from_utf8_lossy(&output.stderr).trim()
        })),
        Err(error) => Json(serde_json::json!({ "status": "error", "error": error.to_string() })),
    }
}

async fn list_printer_media(Query(params): Query<HashMap<String, String>>) -> Json<serde_json::Value> {
    let printer_name = params.get("printer_name").cloned().unwrap_or_default();
    let script = r#"
Add-Type -AssemblyName System.Drawing
$settings = New-Object System.Drawing.Printing.PrinterSettings
if (-not [string]::IsNullOrWhiteSpace($env:PRINTER_NAME)) { $settings.PrinterName = $env:PRINTER_NAME }
if (-not $settings.IsValid) { throw "Printer is not valid: $($settings.PrinterName)" }
$sizes = @()
foreach ($p in $settings.PaperSizes) {
    $wmm = [Math]::Round($p.Width * 25.4 / 100, 1)
    $hmm = [Math]::Round($p.Height * 25.4 / 100, 1)
    $continuous = $p.PaperName -match '^\d+mm$'
    $sizes += [ordered]@{
        name = $p.PaperName
        raw_kind = $p.RawKind
        width_hundredths = $p.Width
        height_hundredths = $p.Height
        width_mm = $wmm
        height_mm = $hmm
        continuous = $continuous
    }
}
[ordered]@{ status = 'ok'; printer_name = $settings.PrinterName; media = $sizes } | ConvertTo-Json -Depth 10
"#;

    let output = Command::new("powershell.exe")
        .arg("-NoProfile")
        .arg("-ExecutionPolicy")
        .arg("Bypass")
        .arg("-Command")
        .arg(script)
        .env("PRINTER_NAME", printer_name)
        .output();

    match output {
        Ok(output) if output.status.success() => {
            let stdout = String::from_utf8_lossy(&output.stdout);
            serde_json::from_str::<serde_json::Value>(&stdout)
                .map(Json)
                .unwrap_or_else(|_| Json(serde_json::json!({ "status": "error", "error": "Could not parse printer media" })))
        }
        Ok(output) => Json(serde_json::json!({
            "status": "error",
            "error": String::from_utf8_lossy(&output.stderr).trim()
        })),
        Err(error) => Json(serde_json::json!({ "status": "error", "error": error.to_string() })),
    }
}

async fn list_print_queue(Query(params): Query<HashMap<String, String>>) -> Json<serde_json::Value> {
    let printer_name = params.get("printer_name").cloned().unwrap_or_default();
    let script = r#"
$printer = $env:PRINTER_NAME
if ([string]::IsNullOrWhiteSpace($printer)) {
    $printer = Get-CimInstance Win32_Printer | Where-Object { $_.Default -eq $true } | Select-Object -First 1 -ExpandProperty Name
}
$jobs = Get-PrintJob -PrinterName $printer -ErrorAction SilentlyContinue | Select-Object ID,DocumentName,JobStatus,SubmittedTime,Size,TotalPages,PagesPrinted,@{Name='PrinterName';Expression={$printer}}
if ($null -eq $jobs) { @() | ConvertTo-Json -Depth 10 } else { $jobs | ConvertTo-Json -Depth 10 }
"#;

    let output = Command::new("powershell.exe")
        .arg("-NoProfile")
        .arg("-ExecutionPolicy")
        .arg("Bypass")
        .arg("-Command")
        .arg(script)
        .env("PRINTER_NAME", printer_name.clone())
        .output();

    match output {
        Ok(output) if output.status.success() => {
            let stdout = String::from_utf8_lossy(&output.stdout);
            let jobs = serde_json::from_str::<serde_json::Value>(&stdout)
                .unwrap_or_else(|_| serde_json::json!([]));
            Json(serde_json::json!({ "status": "ok", "printer_name": printer_name, "jobs": jobs }))
        }
        Ok(output) => Json(serde_json::json!({
            "status": "error",
            "error": String::from_utf8_lossy(&output.stderr).trim()
        })),
        Err(error) => Json(serde_json::json!({ "status": "error", "error": error.to_string() })),
    }
}

async fn clear_print_queue(Json(payload): Json<ClearQueueRequest>) -> Json<serde_json::Value> {
    let printer_name = payload.printer_name.unwrap_or_default();
    let job_id = payload.job_id.map(|id| id.to_string()).unwrap_or_default();
    let script = r#"
$printer = $env:PRINTER_NAME
$jobIdText = $env:JOB_ID
if ([string]::IsNullOrWhiteSpace($printer)) {
    $printer = Get-CimInstance Win32_Printer | Where-Object { $_.Default -eq $true } | Select-Object -First 1 -ExpandProperty Name
}
$removed = @()
if ([string]::IsNullOrWhiteSpace($jobIdText)) {
    $jobs = Get-PrintJob -PrinterName $printer -ErrorAction SilentlyContinue
} else {
    $jobs = Get-PrintJob -PrinterName $printer -ID ([int]$jobIdText) -ErrorAction SilentlyContinue
}
foreach ($job in $jobs) {
    $removed += [ordered]@{ ID = $job.ID; DocumentName = $job.DocumentName; JobStatus = $job.JobStatus }
    Remove-PrintJob -PrinterName $printer -ID $job.ID -ErrorAction SilentlyContinue
}
[ordered]@{ status = 'ok'; printer_name = $printer; removed = $removed } | ConvertTo-Json -Depth 10
"#;

    let output = Command::new("powershell.exe")
        .arg("-NoProfile")
        .arg("-ExecutionPolicy")
        .arg("Bypass")
        .arg("-Command")
        .arg(script)
        .env("PRINTER_NAME", printer_name)
        .env("JOB_ID", job_id)
        .output();

    match output {
        Ok(output) if output.status.success() => {
            let stdout = String::from_utf8_lossy(&output.stdout);
            serde_json::from_str::<serde_json::Value>(&stdout)
                .map(Json)
                .unwrap_or_else(|_| Json(serde_json::json!({ "status": "ok", "stdout": stdout.trim() })))
        }
        Ok(output) => Json(serde_json::json!({
            "status": "error",
            "error": String::from_utf8_lossy(&output.stderr).trim()
        })),
        Err(error) => Json(serde_json::json!({ "status": "error", "error": error.to_string() })),
    }
}

fn launch_driver_tool(file_name: &str, action: &str) -> Json<serde_json::Value> {
    let tool_path = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("..")
        .join("printer")
        .join(file_name);

    if !tool_path.exists() {
        return Json(serde_json::json!({
            "status": "error",
            "error": format!("Driver tool not found: {}", tool_path.display())
        }));
    }

    let script = r#"
$tool = $env:DRIVER_TOOL_PATH
$action = $env:DRIVER_ACTION
Start-Process -FilePath $tool -Verb RunAs
[ordered]@{ status = 'launched'; action = $action; path = $tool; note = 'Approve the Windows UAC prompt and follow the Brother installer window.' } | ConvertTo-Json -Depth 10
"#;

    let output = Command::new("powershell.exe")
        .arg("-NoProfile")
        .arg("-ExecutionPolicy")
        .arg("Bypass")
        .arg("-Command")
        .arg(script)
        .env("DRIVER_TOOL_PATH", tool_path)
        .env("DRIVER_ACTION", action)
        .output();

    match output {
        Ok(output) if output.status.success() => {
            let stdout = String::from_utf8_lossy(&output.stdout);
            serde_json::from_str::<serde_json::Value>(&stdout)
                .map(Json)
                .unwrap_or_else(|_| Json(serde_json::json!({ "status": "launched", "stdout": stdout.trim() })))
        }
        Ok(output) => Json(serde_json::json!({
            "status": "error",
            "error": String::from_utf8_lossy(&output.stderr).trim()
        })),
        Err(error) => Json(serde_json::json!({ "status": "error", "error": error.to_string() })),
    }
}

async fn install_driver() -> Json<serde_json::Value> {
    launch_driver_tool("bsq16aw1101cus-driver-installer.exe", "install")
}

async fn uninstall_driver() -> Json<serde_json::Value> {
    launch_driver_tool("bsq16a-driver-uninstaller.exe", "uninstall")
}

async fn list_templates() -> Json<serde_json::Value> {
    let dir = templates_dir();
    if let Err(error) = fs::create_dir_all(&dir) {
        return Json(serde_json::json!({ "status": "error", "error": error.to_string() }));
    }

    let mut templates = Vec::new();
    match fs::read_dir(&dir) {
        Ok(entries) => {
            for entry in entries.flatten() {
                let path = entry.path();
                if path.extension().and_then(|ext| ext.to_str()) != Some("json") {
                    continue;
                }
                if let Ok(content) = fs::read_to_string(&path) {
                    if let Ok(mut value) = serde_json::from_str::<serde_json::Value>(&content) {
                        let id = path.file_stem().and_then(|stem| stem.to_str()).unwrap_or_default();
                        value["id"] = serde_json::json!(id);
                        templates.push(value);
                    }
                }
            }
        }
        Err(error) => return Json(serde_json::json!({ "status": "error", "error": error.to_string() })),
    }

    Json(serde_json::json!({ "status": "ok", "templates": templates }))
}

async fn save_template(Json(payload): Json<SaveTemplateRequest>) -> Json<serde_json::Value> {
    let dir = templates_dir();
    if let Err(error) = fs::create_dir_all(&dir) {
        return Json(serde_json::json!({ "status": "error", "error": error.to_string() }));
    }

    let id = safe_template_id(&payload.name);
    let path = dir.join(format!("{id}.json"));
    let value = serde_json::json!({
        "id": id,
        "name": payload.name,
        "saved_at": SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or_default(),
        "label": payload.label
    });

    match serde_json::to_string_pretty(&value).ok().and_then(|text| fs::write(&path, text).ok()) {
        Some(_) => Json(serde_json::json!({ "status": "ok", "template": value })),
        None => Json(serde_json::json!({ "status": "error", "error": "Could not save template" })),
    }
}

async fn delete_template(Path(id): Path<String>) -> Json<serde_json::Value> {
    let safe_id = safe_template_id(&id);
    let path = templates_dir().join(format!("{safe_id}.json"));
    match fs::remove_file(&path) {
        Ok(_) => Json(serde_json::json!({ "status": "ok", "deleted": safe_id })),
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Json(serde_json::json!({ "status": "ok", "deleted": safe_id })),
        Err(error) => Json(serde_json::json!({ "status": "error", "error": error.to_string() })),
    }
}

fn print_label(payload: &LabelRequest) -> serde_json::Value {
    let scripts_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("..")
        .join("scripts");
    let script_path = scripts_dir.join("print_label.ps1");

    let timestamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_millis())
        .unwrap_or_default();
    let payload_path = std::env::temp_dir().join(format!("product-label-{timestamp}.json"));

    if let Err(error) = fs::write(
        &payload_path,
        serde_json::to_string_pretty(payload).unwrap_or_default(),
    ) {
        return serde_json::json!({ "status": "error", "error": error.to_string() });
    }

    let printer_name = payload.printer_name.clone().unwrap_or_default();
    let output = Command::new("powershell.exe")
        .arg("-NoProfile")
        .arg("-ExecutionPolicy")
        .arg("Bypass")
        .arg("-File")
        .arg(script_path)
        .arg("-PayloadPath")
        .arg(&payload_path)
        .arg("-PrinterName")
        .arg(printer_name)
        .arg("-LabelWidthMm")
        .arg(payload.label_width_mm.to_string())
        .arg("-LabelLengthMm")
        .arg(payload.label_length_mm.to_string())
        .output();

    let _ = fs::remove_file(payload_path);

    match output {
        Ok(output) => {
            let stdout = String::from_utf8_lossy(&output.stdout);
            let stderr = String::from_utf8_lossy(&output.stderr);
            let parsed = serde_json::from_str::<serde_json::Value>(&stdout).unwrap_or_else(|_| {
                serde_json::json!({
                    "status": if output.status.success() { "printed" } else { "error" },
                    "stdout": stdout.trim(),
                    "stderr": stderr.trim()
                })
            });

            if output.status.success() {
                parsed
            } else {
                serde_json::json!({ "status": "error", "details": parsed, "stderr": stderr.trim() })
            }
        }
        Err(error) => serde_json::json!({ "status": "error", "error": error.to_string() }),
    }
}

async fn create_label(Json(payload): Json<LabelRequest>) -> Json<serde_json::Value> {
    let print_result = if payload.print {
        print_label(&payload)
    } else {
        serde_json::json!({ "status": "skipped" })
    };

    Json(serde_json::json!({
        "status": "ok",
        "print": print_result,
        "label": {
            "product_number": payload.product_number,
            "product_name": payload.product_name,
            "quantity": payload.quantity,
            "item_type": payload.item_type,
            "weight": payload.weight,
            "barcode": payload.barcode,
            "notes": payload.notes,
            "printer_name": payload.printer_name,
            "print_density": payload.print_density,
            "label_width_mm": payload.label_width_mm,
            "label_length_mm": payload.label_length_mm,
            "layout_preset": payload.layout_preset,
            "barcode_width_pct": payload.barcode_width_pct,
            "barcode_height_pct": payload.barcode_height_pct,
            "show_qr": payload.show_qr,
            "driver_media_name": payload.driver_media_name,
            "printer_profile": payload.printer_profile,
            "zpl_dpi": payload.zpl_dpi,
            "print_orientation": payload.print_orientation,
            "display_options": payload.display_options,
            "font_settings": payload.font_settings,
            "layout_offsets": payload.layout_offsets
        }
    }))
}

#[tokio::main]
async fn main() {
    let app = Router::new()
        .route("/health", get(health))
        .route("/printers", get(list_printers))
        .route("/printer-media", get(list_printer_media))
        .route("/print-queue", get(list_print_queue))
        .route("/print-queue/clear", post(clear_print_queue))
        .route("/driver/install", post(install_driver))
        .route("/driver/uninstall", post(uninstall_driver))
        .route("/templates", get(list_templates).post(save_template))
        .route("/templates/:id", delete(delete_template))
        .route("/label", post(create_label))
        .layer(CorsLayer::permissive());

    let addr = SocketAddr::from(([0, 0, 0, 0], 9000));
    println!("Backend running on http://localhost:9000");

    axum::serve(tokio::net::TcpListener::bind(addr).await.unwrap(), app)
        .await
        .unwrap();
}
