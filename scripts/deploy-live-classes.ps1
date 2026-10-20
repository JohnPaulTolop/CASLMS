$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    & npx.cmd supabase functions deploy live-class --project-ref jymjlterjhznsxrwpjqz --no-verify-jwt
    if ($LASTEXITCODE -ne 0) { throw 'Live class deployment failed.' }
    Write-Host 'Live class backend deployed. Configure LIVEKIT_URL, LIVEKIT_API_KEY and LIVEKIT_API_SECRET in Supabase function secrets.'
    Write-Host 'Then run .\scripts\build-vercel.ps1 and deploy a Vercel preview.'
} finally {
    Pop-Location
}
