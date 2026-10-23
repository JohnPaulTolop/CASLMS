$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    & npx.cmd supabase functions deploy ai-router --project-ref jymjlterjhznsxrwpjqz --no-verify-jwt
    if ($LASTEXITCODE -ne 0) { throw 'AI router deployment failed.' }
    Write-Host 'AI router deployed. Configure its server secrets before building an enabled preview.'
} finally { Pop-Location }
