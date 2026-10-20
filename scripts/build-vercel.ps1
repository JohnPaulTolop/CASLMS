$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    & flutter.bat build web --release --dart-define-from-file=config/production.json
    if ($LASTEXITCODE -ne 0) { throw 'Flutter release build failed. Packaging stopped.' }

    $outputDirectory = [IO.Path]::GetFullPath((Join-Path $projectRoot '.vercel\output'))
    $expectedDirectory = [IO.Path]::Combine([IO.Path]::GetFullPath($projectRoot), '.vercel', 'output')
    if ($outputDirectory -ne $expectedDirectory) { throw 'Unexpected Vercel output path.' }
    if (Test-Path -LiteralPath $outputDirectory) {
        Remove-Item -LiteralPath $outputDirectory -Recurse -Force
    }
    $staticDirectory = Join-Path $outputDirectory 'static'
    New-Item -ItemType Directory -Path $staticDirectory -Force | Out-Null
    Copy-Item -Path (Join-Path $projectRoot 'build\web\*') -Destination $staticDirectory -Recurse -Force

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
