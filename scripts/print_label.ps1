param(
    [Parameter(Mandatory = $true)]
    [string]$PayloadPath,

    [Parameter(Mandatory = $false)]
    [string]$PrinterName = "",

    [Parameter(Mandatory = $false)]
    [double]$LabelWidthMm = 62,

    [Parameter(Mandatory = $false)]
    [double]$LabelLengthMm = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-Code128BPatterns {
    param([string]$Text)
    $patterns = @("212222","222122","222221","121223","121322","131222","122213","122312","132212","221213","221312","231212","112232","122132","122231","113222","123122","123221","223211","221132","221231","213212","223112","312131","311222","321122","321221","312212","322112","322211","212123","212321","232121","111323","131123","131321","112313","132113","132311","211313","231113","231311","112133","112331","132131","113123","113321","133121","313121","211331","231131","213113","213311","213131","311123","311321","331121","312113","312311","332111","314111","221411","431111","111224","111422","121124","121421","141122","141221","112214","112412","122114","122411","142112","142211","241211","221114","413111","241112","134111","111242","121142","121241","114212","124112","124211","411212","421112","421211","212141","214121","412121","111143","111341","131141","114113","114311","411113","411311","113141","114131","311141","411131","211412","211214","211232","2331112")
    $values = New-Object System.Collections.Generic.List[int]
    $values.Add(104)
    foreach ($ch in $Text.ToCharArray()) {
        $code = [int][char]$ch
        if ($code -lt 32 -or $code -gt 126) { $code = 32 }
        $values.Add($code - 32)
    }
    $checksum = 104
    for ($i = 1; $i -lt $values.Count; $i++) { $checksum += $values[$i] * $i }
    $values.Add($checksum % 103)
    $values.Add(106)
    $result = New-Object System.Collections.Generic.List[string]
    foreach ($value in $values) { $result.Add($patterns[$value]) }
    return $result
}

function Draw-Code128B {
    param($Graphics, [string]$Text, [int]$X, [int]$Y, [int]$Width, [int]$Height, $Brush)
    if ([string]::IsNullOrWhiteSpace($Text)) { return }
    $patterns = Get-Code128BPatterns -Text $Text
    $modules = 0
    foreach ($pattern in $patterns) {
        foreach ($digit in $pattern.ToCharArray()) { $modules += [int]::Parse($digit.ToString()) }
    }
    $moduleWidth = [Math]::Max(1, [Math]::Floor($Width / $modules))
    $usedWidth = $modules * $moduleWidth
    $left = $X + [Math]::Max(0, [Math]::Floor(($Width - $usedWidth) / 2))
    foreach ($pattern in $patterns) {
        $drawBar = $true
        foreach ($digit in $pattern.ToCharArray()) {
            $w = [int]::Parse($digit.ToString()) * $moduleWidth
            if ($drawBar) { $Graphics.FillRectangle($Brush, $left, $Y, $w, $Height) }
            $left += $w
            $drawBar = -not $drawBar
        }
    }
}

function Get-LayoutOffset {
    param($Payload, [string]$Field)
    $result = [ordered]@{ x = 0; y = 0; scale = 1.0 }
    $layoutProp = $Payload.PSObject.Properties['layout_offsets']
    if ($null -eq $layoutProp) { return $result }
    $fieldProp = $layoutProp.Value.PSObject.Properties[$Field]
    if ($null -eq $fieldProp) { return $result }
    $fieldValue = $fieldProp.Value
    if ($fieldValue.PSObject.Properties['x']) { $result.x = [int]$fieldValue.x }
    if ($fieldValue.PSObject.Properties['y']) { $result.y = [int]$fieldValue.y }
    if ($fieldValue.PSObject.Properties['scale']) { $result.scale = [double]$fieldValue.scale }
    if ($result.scale -lt 0.65) { $result.scale = 0.65 }
    if ($result.scale -gt 1.5) { $result.scale = 1.5 }
    return ,([pscustomobject]$result)
}

function New-ScaledFont {
    param($Font, [double]$Scale)
    return New-Object System.Drawing.Font($Font.FontFamily, [float]($Font.Size * $Scale), $Font.Style)
}

function Send-RawToPrinter {
    param([string]$PrinterName, [string]$DocumentName, [string]$Data)
    $signature = @"
using System;
using System.Runtime.InteropServices;
public class RawPrinterHelper {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Ansi)]
  public class DOCINFOA {
    [MarshalAs(UnmanagedType.LPStr)] public string pDocName;
    [MarshalAs(UnmanagedType.LPStr)] public string pOutputFile;
    [MarshalAs(UnmanagedType.LPStr)] public string pDataType;
  }
  [DllImport("winspool.Drv", EntryPoint="OpenPrinterA", SetLastError=true, CharSet=CharSet.Ansi, ExactSpelling=true, CallingConvention=CallingConvention.StdCall)]
  public static extern bool OpenPrinter(string szPrinter, out IntPtr hPrinter, IntPtr pd);
  [DllImport("winspool.Drv", EntryPoint="ClosePrinter", SetLastError=true, ExactSpelling=true, CallingConvention=CallingConvention.StdCall)]
  public static extern bool ClosePrinter(IntPtr hPrinter);
  [DllImport("winspool.Drv", EntryPoint="StartDocPrinterA", SetLastError=true, CharSet=CharSet.Ansi, ExactSpelling=true, CallingConvention=CallingConvention.StdCall)]
  public static extern bool StartDocPrinter(IntPtr hPrinter, Int32 level, [In, MarshalAs(UnmanagedType.LPStruct)] DOCINFOA di);
  [DllImport("winspool.Drv", EntryPoint="EndDocPrinter", SetLastError=true, ExactSpelling=true, CallingConvention=CallingConvention.StdCall)]
  public static extern bool EndDocPrinter(IntPtr hPrinter);
  [DllImport("winspool.Drv", EntryPoint="StartPagePrinter", SetLastError=true, ExactSpelling=true, CallingConvention=CallingConvention.StdCall)]
  public static extern bool StartPagePrinter(IntPtr hPrinter);
  [DllImport("winspool.Drv", EntryPoint="EndPagePrinter", SetLastError=true, ExactSpelling=true, CallingConvention=CallingConvention.StdCall)]
  public static extern bool EndPagePrinter(IntPtr hPrinter);
  [DllImport("winspool.Drv", EntryPoint="WritePrinter", SetLastError=true, ExactSpelling=true, CallingConvention=CallingConvention.StdCall)]
  public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes, Int32 dwCount, out Int32 dwWritten);
}
"@
    if (-not ([System.Management.Automation.PSTypeName]'RawPrinterHelper').Type) {
        Add-Type -TypeDefinition $signature
    }
    $bytes = [System.Text.Encoding]::ASCII.GetBytes($Data)
    $ptr = [Runtime.InteropServices.Marshal]::AllocCoTaskMem($bytes.Length)
    [Runtime.InteropServices.Marshal]::Copy($bytes, 0, $ptr, $bytes.Length)
    $handle = [IntPtr]::Zero
    try {
        if (-not [RawPrinterHelper]::OpenPrinter($PrinterName, [ref]$handle, [IntPtr]::Zero)) { throw "Could not open printer: $PrinterName" }
        $doc = New-Object RawPrinterHelper+DOCINFOA
        $doc.pDocName = $DocumentName
        $doc.pDataType = "RAW"
        if (-not [RawPrinterHelper]::StartDocPrinter($handle, 1, $doc)) { throw "Could not start RAW print document" }
        [RawPrinterHelper]::StartPagePrinter($handle) | Out-Null
        $written = 0
        if (-not [RawPrinterHelper]::WritePrinter($handle, $ptr, $bytes.Length, [ref]$written)) { throw "Could not write RAW print data" }
        [RawPrinterHelper]::EndPagePrinter($handle) | Out-Null
        [RawPrinterHelper]::EndDocPrinter($handle) | Out-Null
    }
    finally {
        if ($handle -ne [IntPtr]::Zero) { [RawPrinterHelper]::ClosePrinter($handle) | Out-Null }
        [Runtime.InteropServices.Marshal]::FreeCoTaskMem($ptr)
    }
}

try {
    Add-Type -AssemblyName System.Drawing

    $payload = Get-Content -LiteralPath $PayloadPath -Raw | ConvertFrom-Json

    $settings = New-Object System.Drawing.Printing.PrinterSettings
    if ($PrinterName -and $PrinterName.Trim().Length -gt 0) {
        $settings.PrinterName = $PrinterName
    }

    if (-not $settings.IsValid) {
        throw "Printer is not valid or not installed: $PrinterName"
    }

    $printerProfile = if ($payload.printer_profile) { $payload.printer_profile.ToString() } else { "brother_ql_windows" }

    if ($printerProfile -eq "zebra_zpl") {
        $dpi = if ($payload.PSObject.Properties['zpl_dpi'] -and $payload.zpl_dpi) { [int]$payload.zpl_dpi } else { 203 }
        if ($dpi -ne 300) { $dpi = 203 }
        $dotsPerMm = $dpi / 25.4
        $labelWidthDots = [int][Math]::Round($LabelWidthMm * $dotsPerMm)
        $labelLengthDots = [int][Math]::Round($LabelLengthMm * $dotsPerMm)
        $productName = if ($payload.product_name) { $payload.product_name.ToString() } else { "Product" }
        $productNumber = if ($payload.product_number) { $payload.product_number.ToString() } else { "" }
        $quantity = if ($payload.quantity) { $payload.quantity.ToString() } else { "" }
        $itemType = if ($payload.item_type) { $payload.item_type.ToString() } else { "" }
        $weight = if ($payload.weight) { $payload.weight.ToString() } else { "" }
        $barcode = if ($payload.barcode) { $payload.barcode.ToString() } else { $productNumber }
        $notes = if ($payload.notes) { $payload.notes.ToString() } else { "" }
        $barcodeHeight = [int][Math]::Round($labelLengthDots * 0.34)
        if ($barcodeHeight -lt 70) { $barcodeHeight = 70 }
        if ($barcodeHeight -gt 150) { $barcodeHeight = 150 }
        $safeBarcode = ($barcode -replace '[\^~]', '')
        $zpl = "^XA`n"
        $zpl += "^CI28`n^PW$labelWidthDots`n^LL$labelLengthDots`n^LH0,0`n"
        $zpl += "^FO20,18^A0N,30,30^FD$productNumber^FS`n"
        $zpl += "^FO20,52^A0N,24,24^FB$($labelWidthDots - 40),2,0,L,0^FD$productName^FS`n"
        $zpl += "^FO20,105^BY2,2,$barcodeHeight^BCN,$barcodeHeight,Y,N,N^FD$safeBarcode^FS`n"
        $zpl += "^FO20,$($barcodeHeight + 185)^A0N,20,20^FDQTY $quantity   TYPE $itemType   WT $weight^FS`n"
        if ($notes.Length -gt 0) { $zpl += "^FO20,$($barcodeHeight + 212)^A0N,18,18^FB$($labelWidthDots - 40),2,0,L,0^FD$notes^FS`n" }
        $zpl += "^XZ`n"
        Send-RawToPrinter -PrinterName $settings.PrinterName -DocumentName "Product label ZPL" -Data $zpl
        [ordered]@{ status = "printed"; printer = $settings.PrinterName; printer_profile = $printerProfile; zpl_dpi = $dpi; label_width_mm = $LabelWidthMm; label_length_mm = $LabelLengthMm } | ConvertTo-Json -Depth 10
        exit 0
    }

    $doc = New-Object System.Drawing.Printing.PrintDocument
    $doc.PrinterSettings = $settings
    $doc.DocumentName = "Product label"

    # Brother DK-2205 is 62mm continuous tape. PrintDocument uses hundredths of an inch.
    # Paper width is the roll width; paper height is the cut length. Landscape makes text run along the label length.
    $labelWidthHi = [int][Math]::Round(($LabelWidthMm / 25.4) * 100)
    $labelLengthHi = [int][Math]::Round(($LabelLengthMm / 25.4) * 100)
    $paperSize = $null
    $printerProfile = if ($payload.PSObject.Properties['printer_profile'] -and $payload.printer_profile) { $payload.printer_profile.ToString() } else { "brother_ql_windows" }
    $driverMediaName = if ($payload.PSObject.Properties['driver_media_name'] -and $payload.driver_media_name) { $payload.driver_media_name.ToString() } else { "" }
    if ([string]::IsNullOrWhiteSpace($driverMediaName) -and $printerProfile -eq "brother_ql_windows") { $driverMediaName = "${LabelWidthMm}mm" }

    if ($printerProfile -eq "zebra_zpl") {
        throw "Zebra ZPL profile is planned but not active yet. Select Brother QL or Generic Windows."
    }

    # Prefer the exact driver media selected in the interface.
    # For Brother DK continuous tape, media is "62mm" and cut/design length is controlled by page height.
    if (-not [string]::IsNullOrWhiteSpace($driverMediaName)) {
        foreach ($size in $settings.PaperSizes) {
            if ($size.PaperName -eq $driverMediaName) {
                if ($driverMediaName -match '^\d+mm$') {
                    $paperSize = New-Object System.Drawing.Printing.PaperSize($size.PaperName, $labelWidthHi, $labelLengthHi)
                    try { $paperSize.RawKind = $size.RawKind } catch { }
                } else {
                    $paperSize = $size
                }
                break
            }
        }
    }

    if ($null -eq $paperSize) {
        foreach ($size in $settings.PaperSizes) {
            $widthMatches = [Math]::Abs($size.Width - $labelWidthHi) -le 2
            $lengthMatches = [Math]::Abs($size.Height - $labelLengthHi) -le 4
            if ($widthMatches -and $lengthMatches) {
                $paperSize = $size
                break
            }
        }
    }

    if ($null -eq $paperSize) {
        $paperName = if ($printerProfile -eq "brother_ql_windows") { "${LabelWidthMm}mm continuous" } else { "${LabelWidthMm}mm x ${LabelLengthMm}mm" }
        $paperSize = New-Object System.Drawing.Printing.PaperSize($paperName, $labelWidthHi, $labelLengthHi)
    }

    $doc.DefaultPageSettings.PaperSize = $paperSize
    $doc.DefaultPageSettings.Landscape = $true
    $doc.DefaultPageSettings.Margins = New-Object System.Drawing.Printing.Margins(0, 0, 0, 0)

    $fontTitle = New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Bold)
    $fontSku = New-Object System.Drawing.Font("Consolas", 10, [System.Drawing.FontStyle]::Bold)
    $fontText = New-Object System.Drawing.Font("Arial", 7, [System.Drawing.FontStyle]::Regular)
    $fontSmall = New-Object System.Drawing.Font("Arial", 6, [System.Drawing.FontStyle]::Regular)
    $fontBarcode = New-Object System.Drawing.Font("Consolas", 7, [System.Drawing.FontStyle]::Bold)
    $black = [System.Drawing.Brushes]::Black

    $handler = [System.Drawing.Printing.PrintPageEventHandler] {
        param($sender, $e)

        $g = $e.Graphics
        $g.Clear([System.Drawing.Color]::White)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit

        $x = 10
        $y = 8
        $line = 16
        $pageWidth = $e.PageBounds.Width
        $contentWidth = [Math]::Max(100, $pageWidth - 20)

        $productName = if ($payload.product_name) { $payload.product_name.ToString() } else { "Product" }
        $productNumber = if ($payload.product_number) { $payload.product_number.ToString() } else { "" }
        $quantity = if ($payload.quantity) { $payload.quantity.ToString() } else { "" }
        $itemType = if ($payload.item_type) { $payload.item_type.ToString() } else { "" }
        $weight = if ($payload.weight) { $payload.weight.ToString() } else { "" }
        $barcode = if ($payload.barcode) { $payload.barcode.ToString() } else { "" }
        $notes = if ($payload.notes) { $payload.notes.ToString() } else { "" }
        $offProductNumber = Get-LayoutOffset -Payload $payload -Field "product_number"
        $offProductName = Get-LayoutOffset -Payload $payload -Field "product_name"
        $offBarcode = Get-LayoutOffset -Payload $payload -Field "barcode"
        $offDetails = Get-LayoutOffset -Payload $payload -Field "details"
        $offNotes = Get-LayoutOffset -Payload $payload -Field "notes"
        $layoutPreset = if ($payload.PSObject.Properties['layout_preset'] -and $payload.layout_preset) { $payload.layout_preset.ToString() } else { "compact_right" }
        $barcodeWidthPct = if ($payload.PSObject.Properties['barcode_width_pct'] -and $payload.barcode_width_pct) { [int]$payload.barcode_width_pct } else { 42 }
        if ($barcodeWidthPct -lt 30) { $barcodeWidthPct = 30 }
        if ($barcodeWidthPct -gt 55) { $barcodeWidthPct = 55 }

        if ($layoutPreset -eq "stacked") {
            $g.DrawString($productNumber, $fontSku, $black, $x, $y)
            $titleYStack = $y + 15
            $titleRectStack = New-Object System.Drawing.RectangleF($x, $titleYStack, $contentWidth, 24)
            $g.DrawString($productName, $fontTitle, $black, $titleRectStack)
            $y += 42
            $stackBarcodeWidth = [Math]::Min($contentWidth, [Math]::Max(90, [int]($contentWidth * (($barcodeWidthPct + 45) / 100))))
            $stackBarcodeX = $x + [Math]::Floor(($contentWidth - $stackBarcodeWidth) / 2)
            Draw-Code128B -Graphics $g -Text $barcode -X $stackBarcodeX -Y $y -Width $stackBarcodeWidth -Height 36 -Brush $black
            $barcodeTextYStack = $y + 38
            $barcodeTextRectStack = New-Object System.Drawing.RectangleF($stackBarcodeX, $barcodeTextYStack, $stackBarcodeWidth, 10)
            $barcodeFormatStack = New-Object System.Drawing.StringFormat
            $barcodeFormatStack.Alignment = [System.Drawing.StringAlignment]::Center
            $g.DrawString($barcode, $fontBarcode, $black, $barcodeTextRectStack, $barcodeFormatStack)
            $y += 52
            $colWStack = [Math]::Floor($contentWidth / 3)
            $g.DrawString("QTY $quantity", $fontSmall, $black, $x, $y)
            $g.DrawString("TYPE $itemType", $fontSmall, $black, $x + $colWStack, $y)
            $g.DrawString("WT $weight", $fontSmall, $black, $x + ($colWStack * 2), $y)
            $y += 12
            if ($notes.Length -gt 0) {
                $rectStack = New-Object System.Drawing.RectangleF($x, $y, $contentWidth, 22)
                $g.DrawString("Notes: $notes", $fontSmall, $black, $rectStack)
            }
            $e.HasMorePages = $false
            return
        }

        if ($layoutPreset -eq "barcode_bottom") {
            $g.DrawString($productNumber, $fontSku, $black, $x, $y)
            $titleYBottom = $y + 15
            $titleRectBottom = New-Object System.Drawing.RectangleF($x, $titleYBottom, $contentWidth, 22)
            $g.DrawString($productName, $fontTitle, $black, $titleRectBottom)
            $y += 38
            $colWBottom = [Math]::Floor($contentWidth / 3)
            $g.DrawString("QTY $quantity", $fontSmall, $black, $x, $y)
            $g.DrawString("TYPE $itemType", $fontSmall, $black, $x + $colWBottom, $y)
            $g.DrawString("WT $weight", $fontSmall, $black, $x + ($colWBottom * 2), $y)
            $y += 12
            $wideBarcodeWidth = [Math]::Min($contentWidth, [Math]::Max(90, [int]($contentWidth * (($barcodeWidthPct + 45) / 100))))
            $wideBarcodeX = $x + [Math]::Floor(($contentWidth - $wideBarcodeWidth) / 2)
            Draw-Code128B -Graphics $g -Text $barcode -X $wideBarcodeX -Y $y -Width $wideBarcodeWidth -Height 34 -Brush $black
            $barcodeTextYBottom = $y + 36
            $barcodeTextRectBottom = New-Object System.Drawing.RectangleF($wideBarcodeX, $barcodeTextYBottom, $wideBarcodeWidth, 10)
            $barcodeFormatBottom = New-Object System.Drawing.StringFormat
            $barcodeFormatBottom.Alignment = [System.Drawing.StringAlignment]::Center
            $g.DrawString($barcode, $fontBarcode, $black, $barcodeTextRectBottom, $barcodeFormatBottom)
            $e.HasMorePages = $false
            return
        }

        if ($layoutPreset -eq "minimal") {
            $skuWidth = $contentWidth
            $g.DrawString($productNumber, $fontSku, $black, $x, $y)
            $y += 22
            $minimalBarcodeWidth = [Math]::Min($skuWidth, [Math]::Max(90, [int]($skuWidth * (($barcodeWidthPct + 45) / 100))))
            $minimalBarcodeX = $x + [Math]::Floor(($skuWidth - $minimalBarcodeWidth) / 2)
            Draw-Code128B -Graphics $g -Text $barcode -X $minimalBarcodeX -Y $y -Width $minimalBarcodeWidth -Height 44 -Brush $black
            $barcodeTextYMinimal = $y + 46
            $barcodeTextRectMinimal = New-Object System.Drawing.RectangleF($minimalBarcodeX, $barcodeTextYMinimal, $minimalBarcodeWidth, 10)
            $barcodeFormatMinimal = New-Object System.Drawing.StringFormat
            $barcodeFormatMinimal.Alignment = [System.Drawing.StringAlignment]::Center
            $g.DrawString($barcode, $fontBarcode, $black, $barcodeTextRectMinimal, $barcodeFormatMinimal)
            $e.HasMorePages = $false
            return
        }

        $barcodeWidth = [Math]::Min(130, [Math]::Max(88, [int]($contentWidth * ($barcodeWidthPct / 100))))
        $leftWidth = $contentWidth - $barcodeWidth - 6
        $barcodeX = $x + $leftWidth + 6
        $textX = $x

        if ($layoutPreset -eq "barcode_left") {
            $barcodeX = $x
            $textX = $x + $barcodeWidth + 6
            $leftWidth = $contentWidth - $barcodeWidth - 6
        }

        $opnX = [int]$offProductNumber.x; $opnY = [int]$offProductNumber.y; $opnS = [double]$offProductNumber.scale
        $opdX = [int]$offProductName.x; $opdY = [int]$offProductName.y; $opdS = [double]$offProductName.scale
        $obcX = [int]$offBarcode.x; $obcY = [int]$offBarcode.y; $obcS = [double]$offBarcode.scale
        $odtX = [int]$offDetails.x; $odtY = [int]$offDetails.y; $odtS = [double]$offDetails.scale
        $ontX = [int]$offNotes.x; $ontY = [int]$offNotes.y; $ontS = [double]$offNotes.scale

        $skuFont = New-ScaledFont -Font $fontSku -Scale $opnS
        $titleFont = New-ScaledFont -Font $fontTitle -Scale $opdS
        $detailsFont = New-ScaledFont -Font $fontSmall -Scale $odtS
        $notesFont = New-ScaledFont -Font $fontSmall -Scale $ontS
        $barcodeFontScaled = New-ScaledFont -Font $fontBarcode -Scale $obcS

        $skuX = [int]($textX + $opnX); $skuY = [int]($y + $opnY)
        $g.DrawString($productNumber, $skuFont, $black, $skuX, $skuY)
        $titleY = [int]($y + 16 + $opdY)
        $titleX = [int]($textX + $opdX)
        $titleRect = New-Object System.Drawing.RectangleF($titleX, $titleY, $leftWidth, 28)
        $g.DrawString($productName, $titleFont, $black, $titleRect)

        $barcodeDrawWidth = [int]($barcodeWidth * $obcS)
        $barcodeDrawHeight = [int](40 * $obcS)
        $barcodeDrawX = [int]($barcodeX + $obcX)
        $barcodeDrawY = [int]($y + $obcY)
        Draw-Code128B -Graphics $g -Text $barcode -X $barcodeDrawX -Y $barcodeDrawY -Width $barcodeDrawWidth -Height $barcodeDrawHeight -Brush $black
        $barcodeTextY = [int]($y + $obcY + $barcodeDrawHeight + 2)
        $barcodeTextRect = New-Object System.Drawing.RectangleF($barcodeDrawX, $barcodeTextY, $barcodeDrawWidth, 12)
        $barcodeFormat = New-Object System.Drawing.StringFormat
        $barcodeFormat.Alignment = [System.Drawing.StringAlignment]::Center
        $g.DrawString($barcode, $barcodeFontScaled, $black, $barcodeTextRect, $barcodeFormat)

        $y += 52
        $colW = [Math]::Floor($contentWidth / 3)
        $detailsX = [int]($x + $odtX)
        $detailsY = [int]($y + $odtY)
        $g.DrawString("QTY $quantity", $detailsFont, $black, $detailsX, $detailsY)
        $g.DrawString("TYPE $itemType", $detailsFont, $black, [int]($detailsX + $colW), $detailsY)
        $g.DrawString("WT $weight", $detailsFont, $black, [int]($detailsX + ($colW * 2)), $detailsY)
        $y += 12

        if ($notes.Length -gt 0) {
            $notesX = [int]($x + $ontX); $notesY = [int]($y + $ontY)
            $rect = New-Object System.Drawing.RectangleF($notesX, $notesY, $contentWidth, 26)
            $g.DrawString("Notes: $notes", $notesFont, $black, $rect)
        }

        $e.HasMorePages = $false
    }

    $doc.add_PrintPage($handler)
    $doc.Print()

    $printerUsed = $doc.PrinterSettings.PrinterName
    $result = [ordered]@{
        status = "printed"
        printer = $printerUsed
        label_width_mm = $LabelWidthMm
        label_length_mm = $LabelLengthMm
        paper_size = $doc.DefaultPageSettings.PaperSize.PaperName
        paper_raw_kind = $doc.DefaultPageSettings.PaperSize.RawKind
        driver_media_name = $driverMediaName
        printer_profile = $printerProfile
    }
    $result | ConvertTo-Json -Depth 10
    exit 0
}
catch {
    $result = [ordered]@{
        status = "error"
        error = $_.Exception.Message
    }
    $result | ConvertTo-Json -Depth 10
    exit 1
}
