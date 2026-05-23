# Generates Google Play store assets from assets/images/logo.png
# Output:
#   deploy/store-listing/app-icon-512.png   (512x512, opaque)
#   deploy/store-listing/feature-graphic-1024x500.png

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

$root      = Split-Path -Parent $PSScriptRoot
$logoPath  = Join-Path $root 'assets\images\logo.png'
$outDir    = Join-Path $root 'deploy\store-listing'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

$iconOut    = Join-Path $outDir 'app-icon-512.png'
$featureOut = Join-Path $outDir 'feature-graphic-1024x500.png'

# Brand colors (match logo background)
$bgColor    = [System.Drawing.ColorTranslator]::FromHtml('#FDF8F3')
$accent     = [System.Drawing.ColorTranslator]::FromHtml('#B08968')

$logo = [System.Drawing.Image]::FromFile($logoPath)

# ---------- 1) APP ICON 512x512 ----------
$icon = New-Object System.Drawing.Bitmap 512, 512
$g    = [System.Drawing.Graphics]::FromImage($icon)
$g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

# solid background (Play requires opaque, no alpha)
$g.Clear($bgColor)

# fit logo with padding
$padding = 24
$max     = 512 - ($padding * 2)
$scale   = [Math]::Min($max / $logo.Width, $max / $logo.Height)
$w       = [int]($logo.Width  * $scale)
$h       = [int]($logo.Height * $scale)
$x       = [int](512 - $w) / 2
$y       = [int](512 - $h) / 2
$g.DrawImage($logo, $x, $y, $w, $h)

$g.Dispose()
$icon.Save($iconOut, [System.Drawing.Imaging.ImageFormat]::Png)
$icon.Dispose()
Write-Host "Created $iconOut"

# ---------- 2) FEATURE GRAPHIC 1024x500 ----------
$feat = New-Object System.Drawing.Bitmap 1024, 500
$g    = [System.Drawing.Graphics]::FromImage($feat)
$g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.TextRenderingHint  = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

# diagonal gradient background
$rect     = New-Object System.Drawing.Rectangle 0, 0, 1024, 500
$c1       = [System.Drawing.ColorTranslator]::FromHtml('#FDF8F3')
$c2       = [System.Drawing.ColorTranslator]::FromHtml('#EAD7C2')
$gradient = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $c1, $c2, 25.0
$g.FillRectangle($gradient, $rect)
$gradient.Dispose()

# subtle decorative circles
$circleBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(40, 176, 137, 104))
$g.FillEllipse($circleBrush, 820, -120, 360, 360)
$g.FillEllipse($circleBrush, -80, 320, 280, 280)
$circleBrush.Dispose()

# logo on left
$logoSize = 380
$lx = 70
$ly = [int]((500 - $logoSize) / 2)
$g.DrawImage($logo, $lx, $ly, $logoSize, $logoSize)

# Arabic title
$titleFont    = New-Object System.Drawing.Font 'Tahoma', 72, ([System.Drawing.FontStyle]::Bold)
$subtitleFont = New-Object System.Drawing.Font 'Segoe UI', 26, ([System.Drawing.FontStyle]::Regular)
$titleBrush   = New-Object System.Drawing.SolidBrush $accent
$subBrush     = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml('#5A4632'))

# Build Arabic title from Unicode codepoints to avoid PS encoding issues
$title    = [string]::new([char[]](0x0623, 0x0641, 0x0631, 0x0627, 0x062D, 0x0646, 0x0627))
$subtitle = 'Plan Your Perfect Wedding'

$textX = 500
$titleRect = New-Object System.Drawing.Rectangle $textX, 160, 500, 140
$subRect   = New-Object System.Drawing.Rectangle $textX, 300, 500, 50

$flags = [System.Windows.Forms.TextFormatFlags]::Left -bor `
         [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor `
         [System.Windows.Forms.TextFormatFlags]::NoPadding -bor `
         [System.Windows.Forms.TextFormatFlags]::RightToLeft

[System.Windows.Forms.TextRenderer]::DrawText($g, $title,    $titleFont,    $titleRect, $accent, $flags)
[System.Windows.Forms.TextRenderer]::DrawText($g, $subtitle, $subtitleFont, $subRect,   [System.Drawing.ColorTranslator]::FromHtml('#5A4632'), [System.Windows.Forms.TextFormatFlags]::Left -bor [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor [System.Windows.Forms.TextFormatFlags]::NoPadding)

# accent line
$pen = New-Object System.Drawing.Pen $accent, 3
$g.DrawLine($pen, $textX, 360, $textX + 220, 360)
$pen.Dispose()

$titleFont.Dispose(); $subtitleFont.Dispose()
$titleBrush.Dispose(); $subBrush.Dispose()
$g.Dispose()

$feat.Save($featureOut, [System.Drawing.Imaging.ImageFormat]::Png)
$feat.Dispose()
Write-Host "Created $featureOut"

$logo.Dispose()
Write-Host "`nDone. Upload these to Google Play:"
Write-Host "  App icon       -> $iconOut"
Write-Host "  Feature graphic-> $featureOut"
