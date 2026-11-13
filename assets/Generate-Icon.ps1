# Build app.ico from the downloaded og-mark logo.
#
# The logo artwork is white-on-transparent, so it is composited onto a dark
# rounded tile - otherwise it would be invisible in a light-themed Explorer.
#
# Small sizes are written as classic 32bpp BMP (DIB) entries rather than
# PNG-compressed entries, because System.Drawing.Icon cannot decode PNG
# entries and renders noise. The 256px entry stays PNG (it is the modern
# standard for that size and keeps the file small).
Add-Type -AssemblyName System.Drawing

$here    = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcPath = Join-Path $here 'og-mark-1024.png'
$outDir  = Split-Path -Parent $here          # project root
$icoPath = Join-Path $outDir 'src\ObsidianGamesAdminTool\app.ico'

# NOTE: PowerShell variable names are case-insensitive, so keep the tile
# size (int) and the tile bitmap (object) clearly distinct.
$Side     = 1024
$Radius   = [int]($Side * 0.20)              # rounded-corner radius
$Inset    = [int]($Side * 0.06)              # artwork padding inside the tile
$Inner    = $Side - 2 * $Inset
$BgColour = [System.Drawing.Color]::FromArgb(255, 14, 15, 18)

$srcBytes = [System.IO.File]::ReadAllBytes($srcPath)
$srcMs    = [System.IO.MemoryStream]::new($srcBytes)
$srcImg   = [System.Drawing.Image]::fromStream($srcMs)

# --- 1024x1024 master tile -------------------------------------------------
$tileBmp = [System.Drawing.Bitmap]::new($Side, $Side, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($tileBmp)
$g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.Clear([System.Drawing.Color]::Transparent)

$path = [System.Drawing.Drawing2D.GraphicsPath]::new()
$path.AddArc(0, 0, 2 * $Radius, 2 * $Radius, 180, 90)
$path.AddArc($Side - 2 * $Radius, 0, 2 * $Radius, 2 * $Radius, 270, 90)
$path.AddArc($Side - 2 * $Radius, $Side - 2 * $Radius, 2 * $Radius, 2 * $Radius, 0, 90)
$path.AddArc(0, $Side - 2 * $Radius, 2 * $Radius, 2 * $Radius, 90, 90)
$path.CloseFigure()

$bgBrush = [System.Drawing.SolidBrush]::new($BgColour)
$g.FillPath($bgBrush, $path)
$g.DrawImage($srcImg, [System.Drawing.Rectangle]::new($Inset, $Inset, $Inner, $Inner),
             0, 0, $srcImg.Width, $srcImg.Height, [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()

# --- Convert a 32bpp ARGB bitmap to a classic icon DIB entry ---------------
function ConvertTo-IconDib([System.Drawing.Bitmap]$bmp) {
    $w = $bmp.Width
    $h = $bmp.Height

    $rect = [System.Drawing.Rectangle]::new(0, 0, $w, $h)
    $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly,
                          [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $stride = $data.Stride
    $raw = New-Object byte[] ($stride * $h)
    [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $raw, 0, $raw.Length)
    $bmp.UnlockBits($data)

    $ms = [System.IO.MemoryStream]::new()
    $bw = [System.IO.BinaryWriter]::new($ms)

    # BITMAPINFOHEADER - biHeight is doubled because it holds XOR + AND.
    $bw.Write([uint32]40)
    $bw.Write([int32]$w)
    $bw.Write([int32]($h * 2))
    $bw.Write([int16]1)            # planes
    $bw.Write([int16]32)           # bit count
    $bw.Write([uint32]0)           # BI_RGB
    $bw.Write([uint32]0)           # image size (may be 0 for BI_RGB)
    $bw.Write([int32]0)            # x ppm
    $bw.Write([int32]0)            # y ppm
    $bw.Write([uint32]0)           # colours used
    $bw.Write([uint32]0)           # colours important

    # XOR bitmap: bottom-up BGRA rows.
    for ($y = $h - 1; $y -ge 0; $y--) {
        $bw.Write($raw, $y * $stride, $w * 4)
    }

    # AND mask: 1 bit per pixel, 1 = transparent, rows padded to 4 bytes.
    $maskRowBytes = ((($w + 31) -shr 5)) * 4
    $maskRow = New-Object byte[] $maskRowBytes
    for ($y = $h - 1; $y -ge 0; $y--) {
        [Array]::Clear($maskRow, 0, $maskRow.Length)
        for ($x = 0; $x -lt $w; $x++) {
            $alpha = $raw[($y * $stride) + ($x * 4) + 3]
            if ($alpha -lt 16) { $maskRow[$x -shr 3] = $maskRow[$x -shr 3] -bor (1 -shl (7 - ($x -band 7))) }
        }
        $bw.Write($maskRow)
    }

    $bw.Flush()
    $bytes = $ms.ToArray()
    $bw.Dispose(); $ms.Dispose()
    return $bytes
}

# --- Down-scale and encode each size ---------------------------------------
# Size => encoding. BMP for everything System.Drawing is likely to pick.
# (An [ordered] hashtable is avoided: PowerShell indexes those positionally
# when given an int key, which silently returns null.)
$plan = @(
    @{ Size = 16;  Kind = 'dib' }
    @{ Size = 24;  Kind = 'dib' }
    @{ Size = 32;  Kind = 'dib' }
    @{ Size = 48;  Kind = 'dib' }
    @{ Size = 64;  Kind = 'dib' }
    @{ Size = 128; Kind = 'dib' }
    @{ Size = 256; Kind = 'png' }
)

$pngs = @()
foreach ($entry in $plan) {
    $s = [int]$entry.Size
    $bmp = [System.Drawing.Bitmap]::new($s, $s, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $sg = [System.Drawing.Graphics]::FromImage($bmp)
    $sg.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $sg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $sg.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $sg.Clear([System.Drawing.Color]::Transparent)
    $sg.DrawImage($tileBmp, [System.Drawing.Rectangle]::new(0, 0, $s, $s),
                  0, 0, $Side, $Side, [System.Drawing.GraphicsUnit]::Pixel)
    $sg.Dispose()

    if ($entry.Kind -eq 'dib') {
        # PowerShell unrolls byte[] when it leaves a function, so cast back.
        $imgBytes = [byte[]](ConvertTo-IconDib $bmp)
    } else {
        $ms2 = [System.IO.MemoryStream]::new()
        $bmp.Save($ms2, [System.Drawing.Imaging.ImageFormat]::Png)
        $imgBytes = $ms2.ToArray()
        $ms2.Dispose()
    }

    $pngs += [pscustomobject]@{ Size = $s; Kind = $entry.Kind; Bytes = $imgBytes }
    $bmp.Dispose()
}

# --- Assemble the .ico -----------------------------------------------------
$dirMs = [System.IO.MemoryStream]::new()
$bw = [System.IO.BinaryWriter]::new($dirMs)
$bw.Write([uint16]0)                 # reserved
$bw.Write([uint16]1)                 # type: icon
$bw.Write([uint16]$pngs.Count)

$offset = 6 + (16 * $pngs.Count)
foreach ($p in $pngs) {
    $dim = if ($p.Size -ge 256) { 0 } else { [byte]$p.Size }
    $bw.Write([byte]$dim)            # width  (0 = 256)
    $bw.Write([byte]$dim)            # height (0 = 256)
    $bw.Write([byte]0)               # colour count
    $bw.Write([byte]0)               # reserved
    $bw.Write([uint16]1)             # colour planes
    $bw.Write([uint16]32)            # bits per pixel
    $bw.Write([uint32]$p.Bytes.Length)
    $bw.Write([uint32]$offset)
    $offset += $p.Bytes.Length
}
foreach ($p in $pngs) { $bw.Write([byte[]]$p.Bytes) }
$bw.Flush()

New-Item -ItemType Directory -Force -Path (Split-Path $icoPath) | Out-Null
[System.IO.File]::WriteAllBytes($icoPath, $dirMs.ToArray())

$srcImg.Dispose(); $srcMs.Dispose(); $tileBmp.Dispose()
$bgBrush.Dispose(); $path.Dispose(); $bw.Dispose(); $dirMs.Dispose()

"icon -> $icoPath ($((Get-Item $icoPath).Length) bytes)"
foreach ($p in $pngs) { "  $($p.Size)x$($p.Size): $($p.Bytes.Length) bytes ($($p.Kind))" }
