# Product Label App - Handoff

## What this project does

Local Windows web app for creating product labels and printing them to a Brother label printer.

Stack:

- Backend: Rust + Axum on `http://localhost:9000`
- Frontend dev server: Vue 3 + Vite on `http://localhost:5173`
- Production Windows build: single `LabelsControlPro.exe` serving both API and frontend on `http://localhost:9000`
- Printing bridge: Windows PowerShell/Python scripts using installed Windows printers

Current UI supports:

- Product number
- Product name
- Quantity
- Item type
- Weight
- Barcode
- Notes
- Printer selection
- Print now toggle
- Print density control
- Printer online/offline status display
- Real-time label preview

## How to run

### Local single-port Windows run

Use this when you want the app to behave like the production Windows app without creating a packaged build:

```bat
run-local.bat
```

This builds the frontend, starts the Rust backend, serves the UI and API together, and opens:

```text
http://localhost:9000
```

### Development with hot reload

Preferred dev startup while editing frontend code:

```bat
run-dev.bat
```

This starts backend and frontend in two terminal windows and opens the browser.

Manual startup:

```bash
cd backend
cargo run
```

```bash
cd frontend
npm run dev
```

Open:

```text
http://localhost:5173
```

### Windows production build

```bat
build-windows.bat
```

This creates:

```text
dist-windows\LabelsControlPro.exe
dist-windows\Start-LabelsControlPro.bat
```

Run `dist-windows\Start-LabelsControlPro.bat`, then open:

```text
http://localhost:9000
```

## Main files

```text
backend/src/main.rs              Rust API, printer listing, print endpoint
frontend/src/App.vue             Main Vue app and UI logic
frontend/src/style.css           Dark industrial theme and label preview styling
scripts/print_label.ps1          Windows printing bridge
run-local.bat                    One-click single-port local Windows launcher
run-dev.bat                      One-click dev launcher with frontend hot reload
build-windows.bat                One-click Windows production build launcher
scripts/build-windows.ps1        Windows build/package script
```

## API

### GET `/health`

Returns backend status.

### GET `/printers`

Lists installed Windows printers using PowerShell `Get-Printer`.

### POST `/label`

Accepts label JSON. If `print` is `true`, backend calls `scripts/print_label.ps1`.

Example payload:

```json
{
  "product_number": "BR-99042-X",
  "product_name": "Industrial Coupler - 36mm Brass",
  "quantity": 500,
  "item_type": "METALLIC COMPONENT",
  "weight": "1.450 KG",
  "barcode": "99042X-36MM",
  "notes": "ISO-9001 COMPLIANT",
  "print": false,
  "printer_name": "Brother QL-820NWB",
  "print_density": 5
}
```

## Current status

Done:

- Rust Axum backend works
- Vue 3 frontend works
- CORS configured
- Backend serves built frontend for single-app Windows production builds
- Printer list endpoint added
- Windows print bridge added
- One-click `run-dev.bat` added
- Dark industrial UI added
- Real-time label preview added
- Printer online/offline UI added
- Print density UI added

Known limitation:

- Brother QL-820NWB was not detected on this machine during development.
- Current print path is generic Windows printing, not Brother Raster/SDK yet.
- Print density is captured in the app/API, but not yet applied to Brother hardware output.

## Next planned tasks

Priority order:

1. Install/configure Brother QL-820NWB Windows driver.
2. Confirm Brother appears in `/printers` and frontend dropdown.
3. Tune printed label size for actual media, e.g. DK roll size / 62mm / 36mm.
4. Implement real Brother-specific output path if generic Windows print is not enough:
   - Brother Raster commands, or
   - Brother SDK, or
   - driver-specific printing preferences.
5. Apply real print density, cut mode, label length, and quality settings.
6. Add real barcode/QR generation instead of visual placeholder bars.
7. Optional later: Ollama label text/template generation.
8. Optional later: Windows installer/service packaging.

## How to continue with an AI coding agent

Give the agent this file first and ask it to continue from here.

Good prompt:

```text
Read docs/PROJECT_HANDOFF.md and inspect the project. Continue from the next planned task. The goal is a local Rust + Vue app for Brother QL-820NWB product label printing on Windows.
```

If Brother printer is already installed, ask:

```text
Brother printer is installed now. Check /printers, verify it appears, then help tune real label printing size and density.
```
