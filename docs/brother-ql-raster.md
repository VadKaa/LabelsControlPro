# Brother QL Raster Direct Printing

This app now includes an experimental **Brother QL Raster Direct** print profile.

It is intended to avoid the Windows/Brother driver layout problems by:

1. Capturing the app preview image.
2. Converting it to Brother QL raster commands with the `brother_ql` Python package.
3. Sending the raster bytes to the selected Windows printer queue as RAW data.

This should bypass Windows GDI scaling/layout and reduce dependence on Brother Printing Preferences.

## Requirements

Python is required on Windows.

Install Python from:

```text
https://www.python.org/downloads/windows/
```

During install, enable:

```text
Add python.exe to PATH
```

Then run the setup script from the project folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File printer\setup-brother-raster.ps1
```

The setup files are stored with the printer/driver files:

```text
printer/setup-brother-raster.ps1
printer/requirements-brother-ql.txt
```

The script installs Python 3.12 with winget if needed, then installs the Python dependencies.

## App setting

In the app, set printer profile to:

```text
Brother QL Raster Direct
```

Keep Windows Printer selected as:

```text
Brother QL-820NWB
```

## Files

```text
scripts/print_label_brother_ql.py
scripts/requirements-brother-ql.txt
printer/setup-brother-raster.ps1
printer/requirements-brother-ql.txt
```

Backend support is in:

```text
backend/src/main.rs
```

Frontend profile option is in:

```text
frontend/src/App.vue
```

## Notes

- This still uses the Windows printer queue, but sends RAW Brother commands.
- It should not change Brother Printing Preferences.
- If dependencies are missing, the app will show an install message.
- This profile is currently experimental and should be tested with one label first.
