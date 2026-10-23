$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    & npx.cmd firebase-tools deploy --only 'firestore:rules,firestore:indexes' --project soloapp-52a6b
    if ($LASTEXITCODE -ne 0) { throw 'Admin rules/index deployment failed. Do not publish the new client yet.' }
    Write-Host 'Admin rules and index definitions submitted. Wait for the new indexes to finish building before testing the new web preview.'
    Write-Host 'Keep existing cloud indexes if the CLI offers to delete indexes not listed locally.'
} finally {
    Pop-Location
}
