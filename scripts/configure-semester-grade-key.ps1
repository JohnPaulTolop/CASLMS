$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location -LiteralPath $projectRoot
try {
    $secretOutput = & npx.cmd supabase secrets list --project-ref jymjlterjhznsxrwpjqz --output json
    if ($LASTEXITCODE -ne 0) { throw 'Could not check existing secrets. Nothing was changed.' }
    $existingSecrets = $secretOutput | ConvertFrom-Json
    if ($existingSecrets | Where-Object { $_.name -eq 'SEMESTER_GRADE_ENCRYPTION_KEY' }) {
        Write-Host 'Grade encryption is already configured. Existing key preserved.'
        return
    }
    $keyFile = Join-Path $projectRoot '.env.semester-grades.local'
    if (-not (Test-Path -LiteralPath $keyFile)) {
        $keyBytes = New-Object byte[] 32
        $keyGenerator = [Security.Cryptography.RandomNumberGenerator]::Create()
        try { $keyGenerator.GetBytes($keyBytes) } finally { $keyGenerator.Dispose() }
        [IO.File]::WriteAllText($keyFile, ('SEMESTER_GRADE_ENCRYPTION_KEY=' + [Convert]::ToBase64String($keyBytes) + [Environment]::NewLine))
        [Array]::Clear($keyBytes, 0, $keyBytes.Length)
    }
    $savedKey = [IO.File]::ReadAllText($keyFile).Trim()
    if ($savedKey -notmatch '^SEMESTER_GRADE_ENCRYPTION_KEY=([A-Za-z0-9+/]+={0,2})$') { throw 'The local key file is invalid. It was not uploaded.' }
    if ([Convert]::FromBase64String($Matches[1]).Length -ne 32) { throw 'The local key must contain 32 random bytes.' }
    & npx.cmd supabase secrets set --env-file $keyFile --project-ref jymjlterjhznsxrwpjqz
    if ($LASTEXITCODE -ne 0) { throw 'Could not save the grade encryption key. Local key retained for retry.' }
    Write-Host 'Grade encryption key configured. Keep .env.semester-grades.local as a private backup.'
    Write-Host 'Do not replace this key without migrating encrypted grade records.'
} finally { Pop-Location }
