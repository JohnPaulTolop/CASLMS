[CmdletBinding()]
param(
    [ValidateRange(1024, 65535)]
    [int]$Port = 8088
)

$ErrorActionPreference = 'Stop'

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = [Security.Principal.WindowsPrincipal]::new($identity)
$isAdministrator = $principal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

if (-not $isAdministrator) {
    throw 'Run this script once from a PowerShell window opened as Administrator.'
}

$ruleName = 'CAS LMS Flutter local development'
$existingRule = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue

if ($existingRule) {
    $existingRule | Set-NetFirewallRule `
        -Enabled True `
        -Profile Private `
        -Direction Inbound `
        -Action Allow
    $existingRule | Get-NetFirewallPortFilter | Set-NetFirewallPortFilter `
        -Protocol TCP `
        -LocalPort $Port
    $existingRule | Get-NetFirewallAddressFilter | Set-NetFirewallAddressFilter `
        -RemoteAddress LocalSubnet
}
else {
    New-NetFirewallRule `
        -DisplayName $ruleName `
        -Description 'Allows the CAS LMS Flutter debug server from the local subnet only.' `
        -Direction Inbound `
        -Action Allow `
        -Protocol TCP `
        -LocalPort $Port `
        -Profile Private `
        -RemoteAddress LocalSubnet | Out-Null
}

Write-Host "Windows Firewall now allows local-subnet access to TCP port $Port." -ForegroundColor Green
