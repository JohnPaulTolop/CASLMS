[CmdletBinding()]
param(
    [ValidateRange(1024, 65535)]
    [int]$Port = 8088,

    [string]$ConfigPath = ''
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot

function Write-JsonUtf8NoBom {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [object]$Value
    )

    $json = $Value | ConvertTo-Json -Depth 10
    [System.IO.File]::WriteAllText(
        $Path,
        $json,
        [System.Text.UTF8Encoding]::new($false)
    )
}

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $localConfig = Join-Path $projectRoot 'config\local.json'
    $productionConfig = Join-Path $projectRoot 'config\production.json'

    if (-not (Test-Path -LiteralPath $localConfig)) {
        if (-not (Test-Path -LiteralPath $productionConfig)) {
            throw 'No Dart define file was found. Restore config\production.json.'
        }

        $localSettings = Get-Content -Raw -LiteralPath $productionConfig | ConvertFrom-Json
        $localSettings | Add-Member -NotePropertyName 'FIREBASE_APPCHECK_DEBUG_TOKEN' -NotePropertyValue ([guid]::NewGuid().ToString()) -Force
        Write-JsonUtf8NoBom -Path $localConfig -Value $localSettings
        Write-Host 'Created ignored local development configuration: config\local.json' -ForegroundColor Cyan
    }

    $existingSettings = Get-Content -Raw -LiteralPath $localConfig | ConvertFrom-Json
    if (-not $existingSettings.PSObject.Properties['FIREBASE_APPCHECK_DEBUG_TOKEN'] -or
        [string]::IsNullOrWhiteSpace([string]$existingSettings.FIREBASE_APPCHECK_DEBUG_TOKEN)) {
        $existingSettings | Add-Member -NotePropertyName 'FIREBASE_APPCHECK_DEBUG_TOKEN' -NotePropertyValue ([guid]::NewGuid().ToString()) -Force
        Write-JsonUtf8NoBom -Path $localConfig -Value $existingSettings
    }

    $ConfigPath = $localConfig
}
elseif (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Dart define file not found: $ConfigPath"
}

$resolvedConfig = (Resolve-Path -LiteralPath $ConfigPath).Path
$resolvedSettings = Get-Content -Raw -LiteralPath $resolvedConfig | ConvertFrom-Json
$debugToken = [string]$resolvedSettings.FIREBASE_APPCHECK_DEBUG_TOKEN
if ([string]::IsNullOrWhiteSpace($debugToken)) {
    Write-Warning 'FIREBASE_APPCHECK_DEBUG_TOKEN is missing. Each browser will generate its own token.'
}

$portInUse = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue
if ($portInUse) {
    throw "Port $Port is already in use. Stop the existing process or run this script with -Port <another-port>."
}

$flutter = Get-Command flutter.bat -ErrorAction SilentlyContinue
if (-not $flutter) {
    $flutter = Get-Command flutter -ErrorAction SilentlyContinue
}
if (-not $flutter) {
    throw 'Flutter was not found in PATH.'
}

$lanAddress = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {
        $_.IPAddress -notlike '127.*' -and
        $_.IPAddress -notlike '169.254.*' -and
        $_.PrefixOrigin -ne 'WellKnown'
    } |
    Sort-Object -Property InterfaceMetric |
    Select-Object -First 1 -ExpandProperty IPAddress

if (-not $lanAddress) {
    $ipconfigText = (ipconfig | Out-String)
    $ipv4Matches = [regex]::Matches(
        $ipconfigText,
        '(?im)IPv4 Address[^:]*:\s*(?<ip>(?:\d{1,3}\.){3}\d{1,3})'
    )
    $lanAddress = $ipv4Matches |
        ForEach-Object { $_.Groups['ip'].Value } |
        Where-Object { $_ -notlike '127.*' -and $_ -notlike '169.254.*' } |
        Select-Object -First 1
}

Write-Host ''
Write-Host 'CAS LMS local development server' -ForegroundColor Cyan
Write-Host "This computer:  http://localhost:$Port/#/auth" -ForegroundColor Green
if (-not [string]::IsNullOrWhiteSpace($env:COMPUTERNAME)) {
    Write-Host "Team hostname:  http://${env:COMPUTERNAME}:$Port/#/auth" -ForegroundColor Green
}
if ($lanAddress) {
    Write-Host "LAN fallback:    http://${lanAddress}:$Port/#/auth" -ForegroundColor Green
}
else {
    Write-Warning 'No LAN IPv4 address was detected. Connect to the same network and run ipconfig.'
}
Write-Host "Configuration:   $resolvedConfig"
if (-not [string]::IsNullOrWhiteSpace($debugToken)) {
    Write-Host ''
    Write-Host 'One-time Firebase App Check setup:' -ForegroundColor Magenta
    Write-Host 'Firebase Console > App Check > your Web app > Manage debug tokens' -ForegroundColor Magenta
    Write-Host "Debug token: $debugToken" -ForegroundColor Magenta
}
Write-Host ''
Write-Host 'Keep this PowerShell window open while other devices use the app.' -ForegroundColor Yellow
Write-Host 'The shared local App Check token only needs to be registered once.' -ForegroundColor Yellow
Write-Host ''

& $flutter.Source run `
    -d web-server `
    --web-hostname 0.0.0.0 `
    --web-port $Port `
    "--dart-define-from-file=$resolvedConfig"

if ($LASTEXITCODE -ne 0) {
    throw "Flutter exited with code $LASTEXITCODE."
}
