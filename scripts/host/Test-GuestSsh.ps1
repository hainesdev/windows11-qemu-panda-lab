[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot 'Get-LabConfig.ps1')
$key = Join-Path $config.WorkRoot 'ssh\panda-win11-ed25519'
$knownHosts = Join-Path $config.WorkRoot 'ssh\known_hosts'

if (-not (Test-Path -LiteralPath $key)) {
    throw "SSH private key not found: $key"
}

& ssh -p $config.SshPort -i $key `
    -o "UserKnownHostsFile=$knownHosts" `
    -o 'StrictHostKeyChecking=accept-new' `
    -o 'BatchMode=yes' `
    -o 'ConnectTimeout=15' `
    panda@127.0.0.1 `
    'whoami; hostname; powershell -NoProfile -Command "Get-Service sshd | Select-Object Status,StartType"'
if ($LASTEXITCODE -ne 0) { throw 'Guest SSH validation failed.' }
