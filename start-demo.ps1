# One-shot start for a demo session: the FastAPI backend + a Cloudflare quick
# tunnel in front of it. Prints the public HTTPS URL to use for that session.
#
# The URL changes every run (this is a "quick tunnel" - no Cloudflare domain
# attached), so it's printed loudly rather than written anywhere durable.
#
# Run from anywhere: powershell -File start-demo.ps1

$ErrorActionPreference = "Stop"
$repoRoot = $PSScriptRoot
$backendDir = Join-Path $repoRoot "backend"
$venvPython = Join-Path $repoRoot ".venv\Scripts\python.exe"

$cloudflared = (Get-Command cloudflared -ErrorAction SilentlyContinue).Source
if (-not $cloudflared) {
    $cloudflared = "C:\Program Files (x86)\cloudflared\cloudflared.exe"
}
if (-not (Test-Path $cloudflared)) {
    Write-Host "cloudflared not found. Install it first: winget install --id Cloudflare.cloudflared -e"
    exit 1
}

# 1. Start the backend if it isn't already answering.
$backendUp = $false
try {
    Invoke-WebRequest -Uri "http://localhost:8000/health" -TimeoutSec 2 -UseBasicParsing | Out-Null
    $backendUp = $true
    Write-Host "Backend already running on :8000"
} catch {
    Write-Host "Starting backend..."
    Start-Process -FilePath $venvPython `
        -ArgumentList "-m", "uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000" `
        -WorkingDirectory $backendDir
}

# 2. Start the Cloudflare quick tunnel, logging to temp files (its logs go to
# stderr; check both since that has varied across cloudflared versions).
$tunnelOutLog = Join-Path $env:TEMP "cloudflared-demo.out.log"
$tunnelErrLog = Join-Path $env:TEMP "cloudflared-demo.err.log"
Remove-Item $tunnelOutLog, $tunnelErrLog -ErrorAction SilentlyContinue

Start-Process -FilePath $cloudflared `
    -ArgumentList "tunnel", "--url", "http://localhost:8000" `
    -RedirectStandardOutput $tunnelOutLog -RedirectStandardError $tunnelErrLog `
    -WindowStyle Hidden

# 3. Wait for the model to finish loading (if we just started it) and for the
# tunnel to announce its URL.
if (-not $backendUp) {
    Write-Host "Waiting for models to finish loading (can take a couple of minutes)..."
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Seconds 2
        try {
            $health = Invoke-WebRequest -Uri "http://localhost:8000/health" -TimeoutSec 2 -UseBasicParsing
            $body = $health.Content | ConvertFrom-Json
            if ($body.status -eq "ready") { Write-Host "Models ready."; break }
        } catch {}
    }
}

Write-Host "Waiting for tunnel URL..."
$url = $null
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 2
    foreach ($log in @($tunnelOutLog, $tunnelErrLog)) {
        if (Test-Path $log) {
            $match = Select-String -Path $log -Pattern "https://[a-zA-Z0-9.-]+\.trycloudflare\.com" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($match) { $url = $match.Matches[0].Value }
        }
    }
    if ($url) { break }
}

if (-not $url) {
    Write-Host "Could not find the tunnel URL. Check $tunnelOutLog / $tunnelErrLog"
    exit 1
}

Write-Host ""
Write-Host "==================================================================="
Write-Host " Public URL: $url"
Write-Host "==================================================================="
Write-Host ""
Write-Host "Run the Flutter app against it:"
Write-Host "  flutter run -d chrome --dart-define=MOCA_BACKEND_BASE_URL=$url"
Write-Host ""
Write-Host "Health check:"
Write-Host "  curl $url/health"
Write-Host ""
Write-Host "To stop: Stop-Process -Name cloudflared, and close the backend window."
