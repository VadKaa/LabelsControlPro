# Font Management Guide

## Current font setup

This app does **not** save or bundle custom font files in the project.

The font dropdown uses system/common font names only:

- Arial
- Helvetica
- Times New Roman
- sans-serif
- serif
- monospace
- Consolas
- Courier New
- Verdana
- Tahoma
- Trebuchet MS
- Georgia

This means:

- Preview uses fonts available in the browser/Windows.
- Brother/Epson/Generic Windows printing uses fonts available to Windows/.NET.
- There are no extra font license files currently stored/needed in the repo.

## Where font options are defined

### Frontend dropdown

File:

```text
frontend/src/App.vue
```

Search for:

```ts
const fontFamilies = [
```

Add the new font name to that list.

Example:

```ts
const fontFamilies = ['Arial', 'Helvetica', 'Times New Roman', 'My Custom Font']
```

### Windows printing whitelist

File:

```text
scripts/print_label.ps1
```

Search for:

```powershell
$allowedFamilies = @(
```

Add the same font name there too.

Example:

```powershell
$allowedFamilies = @("Arial", "Helvetica", "Times New Roman", "My Custom Font")
```

If you only add the font in `App.vue`, it may appear in the preview but can be rejected by the print script.

## Adding a font manually using Windows-installed fonts

This is the easiest method.

1. Install the font in Windows.
2. Confirm the exact font family name.
3. Add that name to `fontFamilies` in:

```text
frontend/src/App.vue
```

4. Add the same name to `$allowedFamilies` in:

```text
scripts/print_label.ps1
```

5. Restart the frontend/backend if already running.
6. Select the font in the app.
7. Test preview and print.

## Replacing a font option

If you want to replace an existing option, update both places.

Example: replace `Georgia` with `Cambria`.

In `frontend/src/App.vue`:

```ts
const fontFamilies = [..., 'Cambria']
```

In `scripts/print_label.ps1`:

```powershell
$allowedFamilies = @(..., "Cambria")
```

## Adding bundled project fonts later

If you want the app to carry its own font files instead of depending on Windows fonts, use this structure:

```text
frontend/src/assets/fonts/
printer/fonts/
```

Recommended file types:

- `.ttf`
- `.otf`

Example:

```text
frontend/src/assets/fonts/MyFont-Regular.ttf
printer/fonts/MyFont-Regular.ttf
```

### Frontend bundled font CSS

Add `@font-face` rules in:

```text
frontend/src/style.css
```

Example:

```css
@font-face {
  font-family: 'My Custom Font';
  src: url('./assets/fonts/MyFont-Regular.ttf') format('truetype');
  font-weight: 400;
  font-style: normal;
}
```

Then add `My Custom Font` to `fontFamilies` in `frontend/src/App.vue`.

### Printing bundled fonts

The current print script does not yet load bundled font files from `printer/fonts/`.

Currently, Windows printing expects the font to be installed in Windows. If you copy a font only into the project folder, preview can use it after adding `@font-face`, but printing may not use it until the PowerShell script is extended to load private fonts.

## Important notes about licenses

Only add fonts you are allowed to use/distribute.

Safest options:

- Windows built-in fonts used only by name
- Open-source fonts with SIL OFL or Apache license
- Your own licensed fonts

Do not copy commercial font files into the repo unless the license allows it.

## Quick checklist for adding a normal Windows font

1. Install font in Windows.
2. Add name to `frontend/src/App.vue` `fontFamilies`.
3. Add name to `scripts/print_label.ps1` `$allowedFamilies`.
4. Run:

```bash
cd frontend && npm run build
cd backend && cargo check
```

5. Test one printed label before batch printing.
