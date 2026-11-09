param([switch]$EnableAiGateway)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    $productionConfig = Get-Content -LiteralPath 'config/production.json' -Raw | ConvertFrom-Json
    $appCheckSiteKey = $productionConfig.FIREBASE_APPCHECK_WEB_SITE_KEY
    if ([string]::IsNullOrWhiteSpace($appCheckSiteKey)) {
        throw 'Production App Check site key is missing. Build and deployment stopped.'
    }
    $flutterArguments = @('build', 'web', '--release', '--dart-define-from-file=config/production.json')
    if ($EnableAiGateway) { $flutterArguments += '--dart-define=CASLMS_AI_GATEWAY_ENABLED=true' }
    & flutter.bat @flutterArguments
    if ($LASTEXITCODE -ne 0) { throw 'Flutter release build failed. Packaging stopped.' }
    $compiledApp = [IO.File]::ReadAllText((Join-Path $projectRoot 'build/web/main.dart.js'))
    if (-not $compiledApp.Contains($appCheckSiteKey)) {
        throw 'Compiled app is missing the production App Check site key. Packaging stopped.'
    }

    $outputDirectory = [IO.Path]::GetFullPath((Join-Path $projectRoot '.vercel\output'))
    $expectedDirectory = [IO.Path]::Combine([IO.Path]::GetFullPath($projectRoot), '.vercel', 'output')
    if ($outputDirectory -ne $expectedDirectory) { throw 'Unexpected Vercel output path.' }
    if (Test-Path -LiteralPath $outputDirectory) {
        Remove-Item -LiteralPath $outputDirectory -Recurse -Force
    }
    $staticDirectory = Join-Path $outputDirectory 'static'
    New-Item -ItemType Directory -Path $staticDirectory -Force | Out-Null
    # Vercel tooling can leave local credentials and project metadata in a
    # previously linked build directory. Never publish those dotfiles.
    Get-ChildItem -LiteralPath (Join-Path $projectRoot 'build\web') -Force |
        Where-Object { -not $_.Name.StartsWith('.') } |
        ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $staticDirectory -Recurse -Force }

    # Build Output API serves only compiled assets. Runtime dependencies and
    # source directories are not uploaded by `vercel deploy --prebuilt`.
    $configuration = @{
        version = 3
        routes = @(
            @{
                src = '/(index.html|flutter_bootstrap.js|flutter_service_worker.js|version.json)'
                headers = @{ 'Cache-Control' = 'no-cache, max-age=0, must-revalidate' }
                continue = $true
            },
            @{ handle = 'filesystem' },
            @{
                src = '/.*'
                dest = '/index.html'
                headers = @{ 'Cache-Control' = 'no-cache, max-age=0, must-revalidate' }
            }
        )
    }
    $configuration | ConvertTo-Json -Depth 6 |
        Set-Content -LiteralPath (Join-Path $outputDirectory 'config.json') -Encoding ascii
    Write-Host 'Release packaged. Create a preview with: npx.cmd vercel deploy --prebuilt'
} finally {
    Pop-Location
}
