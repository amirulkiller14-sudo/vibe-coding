# Parse an .ico and dump each embedded image so we can validate it.
Add-Type -AssemblyName System.Drawing

$icoPath = 'D:\Obisidian Games App\src\ObsidianGamesAdminTool\app.ico'
$dumpDir = Join-Path $env:TEMP 'ico-dump'
New-Item -ItemType Directory -Force -Path $dumpDir | Out-Null
Get-ChildItem $dumpDir -File -ErrorAction SilentlyContinue | Remove-Item -Force

$bytes = [System.IO.File]::ReadAllBytes($icoPath)
$br = [System.IO.BinaryReader]::new([System.IO.MemoryStream]::new($bytes))

$reserved = $br.ReadUInt16()
$type     = $br.ReadUInt16()
$count    = $br.ReadUInt16()
"header: reserved=$reserved type=$type count=$count total=$($bytes.Length) bytes"

$entries = @()
for ($i = 0; $i -lt $count; $i++) {
    $w      = $br.ReadByte()
    $h      = $br.ReadByte()
    $colors = $br.ReadByte()
    $res    = $br.ReadByte()
    $planes = $br.ReadUInt16()
    $bpp    = $br.ReadUInt16()
    $size   = $br.ReadUInt32()
    $offset = $br.ReadUInt32()
    $entries += [pscustomobject]@{ i = $i; w = $w; h = $h; planes = $planes; bpp = $bpp; size = $size; offset = $offset }
}

foreach ($e in $entries) {
    $actualW = if ($e.w -eq 0) { 256 } else { $e.w }
    $sig = ''
    if ($e.offset + 8 -le $bytes.Length) {
        $sig = [System.Text.Encoding]::ASCII.GetString($bytes, $e.offset, 4)
        if ($sig -notmatch 'PNG|BM') { $sig = "header=0x" + ([BitConverter]::ToString($bytes, $e.offset, 4)) }
    }
    $inRange = ($e.offset + $e.size) -le $bytes.Length
    "entry $($e.i): ${actualW}x$($actualW) bpp=$($e.bpp) size=$($e.size) offset=$($e.offset) sig=$sig inRange=$inRange"

    # Extract for visual inspection.
    $imgBytes = New-Object byte[] $e.size
    [Array]::Copy($bytes, $e.offset, $imgBytes, 0, $e.size)
    [System.IO.File]::WriteAllBytes((Join-Path $dumpDir "entry$($e.i)_${actualW}.bin"), $imgBytes)

    if ($sig -eq "PNG`n`n`n" -or $imgBytes[0] -eq 0x89) {
        try {
            $ms = [System.IO.MemoryStream]::new($imgBytes)
            $img = [System.Drawing.Image]::fromStream($ms)
            "    -> decodes as PNG: $($img.Width)x$($img.Height)"
            $img.Dispose()
        } catch { "    -> PNG DECODE FAILED: $($_.Exception.Message)" }
    } else {
        # BMP/DIB entry: BITMAPINFOHEADER, biHeight is doubled.
        $hdrSize = [BitConverter]::ToInt32($imgBytes, 0)
        $w2 = [BitConverter]::ToInt32($imgBytes, 4)
        $h2 = [BitConverter]::ToInt32($imgBytes, 8)
        $planes2 = [BitConverter]::ToInt16($imgBytes, 12)
        $bpp2 = [BitConverter]::ToInt16($imgBytes, 14)
        "    -> DIB header=$hdrSize w=$w2 h=$h2 (xor=$(( [Math]::Abs($h2) / 2 ))) planes=$planes2 bpp=$bpp2"
        $expected = 40 + ([Math]::Abs($h2) / 2) * $w2 * 4 + (((([Math]::Abs($h2) / 2) + 31) -band (-bnot 31)) / 8) * $w2
        "    -> expected bytes=$expected actual=$($e.size)"
    }
}
$br.Dispose()
