param(
    [int]$Port = 8085,
    [switch]$NoOpen
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$sitePath = Join-Path $repoRoot "demo-site"

if (-not (Test-Path $sitePath)) {
    throw "Demo site folder not found: $sitePath"
}

Set-Location $sitePath

$url = "http://localhost:$Port"
Write-Host "Starting AI Honeypot demo site at $url" -ForegroundColor Cyan
Write-Host "Serving from: $sitePath" -ForegroundColor DarkGray

if (-not $NoOpen) {
    Start-Process $url | Out-Null
}

if (Get-Command py -ErrorAction SilentlyContinue) {
    & py -3.11 -m http.server $Port
}
elseif (Get-Command python -ErrorAction SilentlyContinue) {
    & python -m http.server $Port
}
else {
    throw "Python was not found. Install Python 3.11 and retry."
}
