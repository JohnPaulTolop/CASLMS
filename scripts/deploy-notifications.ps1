$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    & npx.cmd firebase-tools deploy --only firestore:rules --project soloapp-52a6b
    if ($LASTEXITCODE -ne 0) { throw 'Firestore rules deployment failed. Stopping.' }
    foreach ($functionName in @('assessment-submission', 'instructor-approval', 'semester-grades', 'live-class')) {
        & npx.cmd supabase functions deploy $functionName --project-ref jymjlterjhznsxrwpjqz --no-verify-jwt
        if ($LASTEXITCODE -ne 0) { throw "Deployment failed: $functionName. Stopping." }
    }
    Write-Host 'Notification rules and functions deployed. Rebuild and test a Vercel preview next.'
} finally { Pop-Location }
