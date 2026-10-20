$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    & npx.cmd supabase functions deploy semester-grades --project-ref jymjlterjhznsxrwpjqz --no-verify-jwt
    if ($LASTEXITCODE -ne 0) { throw 'Grades function deployment failed.' }
    & firebase.cmd deploy --only firestore:rules --project soloapp-52a6b
    if ($LASTEXITCODE -ne 0) { throw 'Firestore rule deployment failed.' }
    Write-Host 'Grades backend and rules deployed. Build and test a Vercel preview before promotion.'
} finally { Pop-Location }
