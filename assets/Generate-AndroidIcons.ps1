# Build Android launcher icons from the downloaded og-mark logo.
#
#  - mipmap-*/ic_launcher.png            legacy icon (API < 26)
#  - mipmap-*/ic_launcher_round.png      round variant
#  - mipmap-*/ic_launcher_foreground.png adaptive-icon foreground layer
#  - mipmap-anydpi-v26/*.xml             adaptive icon (API 26+)
Add-Type -AssemblyName System.Drawing

$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcPath = Join-Path $here 'og-mark-1024.png'
$resDir  = Join-Path (Split-Path -Parent $here) 'android\app\src\main\res'

$Bg = [System.Drawing.Color]::FromArgb(255, 14, 15, 18)

$srcBytes = [System.IO.File]::ReadAllBytes($srcPath)
$srcMs    = [System.IO.MemoryStream]::new($srcBytes)
$srcImg   = [System.Drawing.Image]::fromStream($srcMs)

function New-Canvas([int]$side) {
    return [System.Drawing.Bitmap]::new($side, $side, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
}

function Get-graphics([System.Drawing.Bitmap]$bmp) {
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)
    return $g
}

# --- Legacy icon: dark tile with the mark inset ----------------------------
$LegacyMaster = 1024
$legacy = New-Canvas $LegacyMaster
$g = Get-graphics $legacy
$g.Clear($Bg)
$pad = [int]($LegacyMaster * 0.13)
$g.DrawImage($srcImg, [System.Drawing.Rectangle]::new($pad, $pad, $LegacyMaster - 2 * $pad, $LegacyMaster - 2 * $pad),
             0, 0, $srcImg.Width, $srcImg.Height, [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()

# --- Adaptive foreground: mark centred inside the 66/108 safe zone ---------
$FgMaster = 1024
$fg = New-Canvas $FgMaster
$g = Get-graphics $fg
$inner = [int]($FgMaster * 0.55)          # ~60% of the 108dp canvas
$off   = [int](($FgMaster - $inner) / 2)
$g.DrawImage($srcImg, [System.Drawing.Rectangle]::new($off, $off, $inner, $inner),
             0, 0, $srcImg.Width, $srcImg.Height, [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()

# --- Density buckets -------------------------------------------------------
$densities = [ordered]@{
    'mipmap-mdpi'    = @{ legacy = 48;  fg = 108 }
    'mipmap-hdpi'    = @{ legacy = 72;  fg = 162 }
    'mipmap-xhdpi'   = @{ legacy = 96;  fg = 216 }
    'mipmap-xxhdpi'  = @{ legacy = 144; fg = 324 }
    'mipmap-xxxhdpi' = @{ legacy = 192; fg = 432 }
}

function Save-Scaled([System.Drawing.Bitmap]$master, [int]$size, [string]$path) {
    $bmp = New-Canvas $size
    $g = Get-graphics $bmp
    $g.DrawImage($master, [System.Drawing.Rectangle]::new(0, 0, $size, $size),
                 0, 0, $master.Width, $master.Height, [System.Drawing.GraphicsUnit]::Pixel)
    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

$made = @()
foreach ($folder in $densities.Keys) {
    $dir = Join-Path $resDir $folder
    New-Item -ItemType Directory -Force -Path $dir | Out-Null

    $l = $densities[$folder].legacy
    $f = $densities[$folder].fg

    Save-Scaled $legacy $l (Join-Path $dir 'ic_launcher.png')
        $made += "$folder\ic_launcher.png ($l)"
    Copy-Item (Join-Path $dir 'ic_launcher.png') (Join-Path $dir 'ic_launcher_round.png') -Force
        $made += "$folder\ic_launcher_round.png ($l)"
    Save-Scaled $fg $f (Join-Path $dir 'ic_launcher_foreground.png')
        $made += "$folder\ic_launcher_foreground.png ($f)"
}

# --- Adaptive icon definitions (API 26+) -----------------------------------
$anydpi = Join-Path $resDir 'mipmap-anydpi-v26'
New-Item -ItemType Directory -Force -Path $anydpi | Out-Null

$adaptive = @'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
'@
Set-Content -Path (Join-Path $anydpi 'ic_launcher.xml')        -Value $adaptive -Encoding UTF8
Set-Content -Path (Join-Path $anydpi 'ic_launcher_round.xml')  -Value $adaptive -Encoding UTF8
$made += "mipmap-anydpi-v26\ic_launcher.xml"
$made += "mipmap-anydpi-v26\ic_launcher_round.xml"

$legacy.Dispose(); $fg.Dispose(); $srcImg.Dispose(); $srcMs.Dispose()

"icons written to: $resDir"
$made | ForEach-Object { "  $_" }
