$ErrorActionPreference = 'Stop'

function Invoke-CheckedCommand {
    param([string]$Program, [string[]]$CommandArguments)
    & $Program @CommandArguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Program failed (exit $LASTEXITCODE). Deployment stopped."
    }
}

$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    Write-Host 'Deploying Firebase-native reset support. No bulk account migration is performed.'
    Write-Host 'Eligible reset requests will change the existing Auth email to the registered contact email.'

    # campus-login verifies passwords through Firebase Identity Toolkit. The web
    # API key is not a credential, but it must be present as an Edge Function
    # secret because the function cannot read Flutter's firebase_options.dart.
    $firebaseWebApiKey = 'AIzaSyD42-bjfhqpyyTpBjNCrtghwY6YzVXHzoo'
    Invoke-CheckedCommand 'npx.cmd' @(
        'supabase', 'secrets', 'set',
        "FIREBASE_WEB_API_KEY=$firebaseWebApiKey",
        '--project-ref', 'jymjlterjhznsxrwpjqz'
    )

    # Install the login fallback and ID protections before enabling migration.
    Invoke-CheckedCommand 'npx.cmd' @(
        'supabase', 'functions', 'deploy', 'campus-login',
        '--project-ref', 'jymjlterjhznsxrwpjqz', '--no-verify-jwt'
    )
    Invoke-CheckedCommand 'npx.cmd' @(
        'supabase', 'functions', 'deploy', 'instructor-approval',
        '--project-ref', 'jymjlterjhznsxrwpjqz', '--no-verify-jwt'
    )
    Invoke-CheckedCommand 'firebase.cmd' @(
        'deploy', '--only', 'firestore:rules', '--project', 'soloapp-52a6b'
    )
    Invoke-CheckedCommand 'npx.cmd' @(
        'supabase', 'functions', 'deploy', 'password-reset',
        '--project-ref', 'jymjlterjhznsxrwpjqz', '--no-verify-jwt'
    )
    Write-Host 'Backend deployment finished. Restart the updated app with: flutter run -d edge'
} finally {
    Pop-Location
}
