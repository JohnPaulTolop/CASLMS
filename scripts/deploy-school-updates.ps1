param([switch]$RulesOnly)
$ErrorActionPreference = 'Stop'
function Invoke-CheckedCommand {
    param([string]$Program, [string[]]$CommandArguments)
    & $Program @CommandArguments
    if ($LASTEXITCODE -ne 0) { throw "$Program failed. Deployment stopped (exit $LASTEXITCODE)." }
}
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    if ($RulesOnly) {
        Invoke-CheckedCommand 'firebase.cmd' @(
            'deploy', '--only', 'firestore:rules', '--project', 'soloapp-52a6b'
        )
        Write-Host 'Updated rules deployed. Promote the tested new Flutter preview now.'
        return
    }
    foreach ($functionName in @('student-registration', 'manual-grade', 'assessment-submission')) {
        Invoke-CheckedCommand 'npx.cmd' @(
            'supabase', 'functions', 'deploy', $functionName,
            '--project-ref', 'jymjlterjhznsxrwpjqz', '--no-verify-jwt'
        )
    }
    # Defer tightened rules until the new Flutter preview has been tested:
    # the old production signup flow still creates profiles on the client.
    Write-Host 'School endpoints deployed. Firestore rules and the live website were not changed.'
    Write-Host 'Run: .\scripts\build-vercel.ps1'
    Write-Host 'Then: npx.cmd vercel deploy --prebuilt'
    Write-Host 'After preview tests, run this script with -RulesOnly, then promote that preview.'
} finally {
    Pop-Location
}
