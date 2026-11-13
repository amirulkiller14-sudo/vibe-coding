# Rasterize the downloaded WebP logos to PNGs using headless Chrome.
# Natural sizes are measured by Chrome itself (see probe.html) rather than
# parsed from the WebP header, which proved unreliable here.
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$profile = Join-Path $env:TEMP 'og-chrome-render'

function Render-Logo([string]$logo, [string]$outName, [int]$w, [int]$h) {
    $htmlPath = Join-Path $here "render_$([IO.Path]::GetFileNameWithoutExtension($logo)).html"
    $html = (Get-Content (Join-Path $here 'render.html') -Raw) -replace 'LOGO_FILE', $logo
    Set-Content -Path $htmlPath -Value $html -Encoding UTF8

    $out = Join-Path $here $outName
    if (Test-Path $out) { Remove-Item $out -Force }

    $uri = "file:///" + ($htmlPath -replace '\\', '/') + "?w=$w&h=$h"

    # The call operator keeps a path containing spaces as a single argument.
    & $chrome --headless=new --disable-gpu --hide-scrollbars `
        --force-device-scale-factor=1 `
        --user-data-dir="$profile" `
        --default-background-color=00000000 `
        --screenshot="$out" `
        --window-size="$w,$h" `
        --virtual-time-budget=4000 `
        $uri | Out-Null

    # Chrome detaches from the console, so wait for the PNG to land on disk.
    $deadline = (Get-Date).AddSeconds(45)
    while (-not (Test-Path $out) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 250 }

    if (Test-Path $out) {
        "$outName -> ${w}x${h} ($((Get-Item $out).Length) bytes)"
    } else {
        "$outName -> FAILED"
    }
    Remove-Item $htmlPath -Force -ErrorAction SilentlyContinue
}

# Square mark: source 1254x1254 - used for the .exe icon and window icon.
Render-Logo 'og-mark.webp' 'og-mark-512.png'   512 512
Render-Logo 'og-mark.webp' 'og-mark-1024.png' 1024 1024

# Horizontal lockup: source 1983x793 - used for the offline/splash screen.
Render-Logo 'og-lockup.webp' 'og-lockup-1024.png' 1024 406
