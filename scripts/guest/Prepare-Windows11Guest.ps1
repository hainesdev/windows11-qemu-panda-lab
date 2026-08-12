#Requires -RunAsAdministrator
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$authorizedKeyValue = '__PUBLIC_KEY__'
$logPath = 'C:\panda-guest-setup.log'

if ($authorizedKeyValue -eq '__PUBLIC_KEY__') {
    throw 'Generate this bootstrap with scripts\host\New-GuestBootstrap.ps1. Do not run the template directly.'
}
if ($authorizedKeyValue -notmatch '^ssh-ed25519\s+[A-Za-z0-9+/=]+(?:\s+.*)?$') {
    throw 'The embedded SSH public key is invalid.'
}

Start-Transcript -Path $logPath -Append -Force
try {
    Write-Host 'Preparing Windows for PANDA and key-only SSH control...'

    & bcdedit.exe /set hypervisorlaunchtype off
    if ($LASTEXITCODE -ne 0) { throw 'Failed to disable the guest Hyper-V launch.' }
    & bcdedit.exe /set vsmlaunchtype off
    if ($LASTEXITCODE -ne 0) { throw 'Failed to disable the guest VSM launch.' }

    $registryValues = @(
        @{ SubKey = 'SYSTEM\CurrentControlSet\Control\DeviceGuard'; Name = 'EnableVirtualizationBasedSecurity'; Value = 0 },
        @{ SubKey = 'SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity'; Name = 'Enabled'; Value = 0 },
        @{ SubKey = 'SYSTEM\CurrentControlSet\Control\Lsa'; Name = 'LsaCfgFlags'; Value = 0 },
        @{ SubKey = 'SYSTEM\CurrentControlSet\Control\CrashControl'; Name = 'AutoReboot'; Value = 0 }
    )

    foreach ($entry in $registryValues) {
        $key = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey($entry.SubKey)
        try {
            $key.SetValue($entry.Name, $entry.Value, [Microsoft.Win32.RegistryValueKind]::DWord)
        }
        finally {
            $key.Dispose()
        }
    }

    foreach ($feature in 'Microsoft-Hyper-V-All', 'VirtualMachinePlatform', 'HypervisorPlatform') {
        $state = Get-WindowsOptionalFeature -Online -FeatureName $feature -ErrorAction SilentlyContinue
        if ($state -and $state.State -ne 'Disabled') {
            Disable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart | Out-Null
        }
    }

    $serverCapability = Get-WindowsCapability -Online |
        Where-Object Name -Like 'OpenSSH.Server*' |
        Select-Object -First 1
    if (-not $serverCapability) { throw 'The OpenSSH.Server capability was not found.' }
    if ($serverCapability.State -ne 'Installed') {
        Add-WindowsCapability -Online -Name $serverCapability.Name | Out-Null
    }

    if (-not (Get-LocalUser -Name 'panda' -ErrorAction SilentlyContinue)) {
        $passwordBytes = New-Object byte[] 36
        $rng = [Security.Cryptography.RandomNumberGenerator]::Create()
        try { $rng.GetBytes($passwordBytes) } finally { $rng.Dispose() }
        $password = [Convert]::ToBase64String($passwordBytes) |
            ConvertTo-SecureString -AsPlainText -Force
        New-LocalUser -Name 'panda' -Password $password -AccountNeverExpires `
            -PasswordNeverExpires -Description 'Local PANDA analysis administrator' | Out-Null
    }

    $administrators = Get-LocalGroup -SID 'S-1-5-32-544'
    $isAdministrator = Get-LocalGroupMember -Group $administrators -ErrorAction SilentlyContinue |
        Where-Object Name -Match '\\panda$'
    if (-not $isAdministrator) {
        Add-LocalGroupMember -Group $administrators -Member 'panda'
    }

    $sshRoot = Join-Path $env:ProgramData 'ssh'
    New-Item -ItemType Directory -Path $sshRoot -Force | Out-Null
    $authorizedKeys = Join-Path $sshRoot 'administrators_authorized_keys'
    Set-Content -LiteralPath $authorizedKeys -Encoding ascii -Value $authorizedKeyValue
    & icacls.exe $authorizedKeys /inheritance:r | Out-Null
    & icacls.exe $authorizedKeys /grant '*S-1-5-18:F' '*S-1-5-32-544:F' | Out-Null

    $sshdConfig = Join-Path $sshRoot 'sshd_config'
    $sshdText = Get-Content -LiteralPath $sshdConfig -Raw
    if ($sshdText -match '(?im)^\s*#?\s*PasswordAuthentication\s+\S+\s*$') {
        $sshdText = $sshdText -replace '(?im)^\s*#?\s*PasswordAuthentication\s+\S+\s*$', 'PasswordAuthentication no'
    } else {
        $sshdText += "`r`nPasswordAuthentication no`r`n"
    }
    if ($sshdText -match '(?im)^\s*#?\s*PubkeyAuthentication\s+\S+\s*$') {
        $sshdText = $sshdText -replace '(?im)^\s*#?\s*PubkeyAuthentication\s+\S+\s*$', 'PubkeyAuthentication yes'
    } else {
        $sshdText += "PubkeyAuthentication yes`r`n"
    }
    Set-Content -LiteralPath $sshdConfig -Value $sshdText -Encoding ascii

    $openSshKey = [Microsoft.Win32.Registry]::LocalMachine.CreateSubKey('SOFTWARE\OpenSSH')
    try {
        $openSshKey.SetValue(
            'DefaultShell',
            'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe',
            [Microsoft.Win32.RegistryValueKind]::String
        )
    }
    finally {
        $openSshKey.Dispose()
    }

    Set-Service -Name sshd -StartupType Automatic
    Restart-Service -Name sshd

    if (-not (Get-NetFirewallRule -Name 'PANDA-OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule -Name 'PANDA-OpenSSH-Server-In-TCP' `
            -DisplayName 'PANDA OpenSSH Server (sshd)' -Enabled True `
            -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 | Out-Null
    }

    Write-Host 'Guest preparation complete. Reboot Windows, validate SSH, then shut down cleanly.'
}
finally {
    Stop-Transcript
}
