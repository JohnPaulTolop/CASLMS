$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    & npx.cmd supabase functions deploy student-registration --project-ref jymjlterjhznsxrwpjqz --no-verify-jwt
    if ($LASTEXITCODE -ne 0) { throw 'Student profile email-sync deployment failed. Stop before publishing the new web client.' }
    Write-Host 'Verified-email synchronization deployed. Existing registration and activation actions remain available.'
    Write-Host 'Rebuild and test a Vercel preview next.'
} finally {
    Pop-Location
}
