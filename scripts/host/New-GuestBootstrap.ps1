[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot 'Get-LabConfig.ps1')
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$template = Join-Path $repoRoot 'scripts\guest\Prepare-Windows11Guest.ps1'
$sshRoot = Join-Path $config.WorkRoot 'ssh'
$bootstrapRoot = Join-Path $config.WorkRoot 'bootstrap'
$privateKey = Join-Path $sshRoot 'panda-win11-ed25519'
$publicKey = "$privateKey.pub"
$bootstrap = Join-Path $bootstrapRoot 's'

foreach ($command in 'ssh-keygen.exe', 'python.exe') {
    if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
        throw "Required command not found: $command"
    }
}
if (-not (Test-Path -LiteralPath $template)) { throw "Guest template not found: $template" }

New-Item -ItemType Directory -Path $sshRoot, $bootstrapRoot -Force | Out-Null

if (-not (Test-Path -LiteralPath $privateKey)) {
    $keyArguments = "-q -t ed25519 -N `"`" -C `"panda-win11-local`" -f `"$privateKey`""
    $keyProcess = Start-Process -FilePath (Get-Command ssh-keygen.exe).Source -ArgumentList $keyArguments -PassThru -Wait
    if ($keyProcess.ExitCode -ne 0) { throw 'ssh-keygen failed.' }
}

$authorizedKey = (Get-Content -LiteralPath $publicKey -Raw).Trim()
if ($authorizedKey -notmatch '^ssh-ed25519\s+[A-Za-z0-9+/=]+(?:\s+.*)?$') {
    throw 'The generated public key is not a valid single-line Ed25519 key.'
}

$escapedKey = $authorizedKey.Replace("'", "''")
$guestScript = (Get-Content -LiteralPath $template -Raw).Replace('__PUBLIC_KEY__', $escapedKey)
Set-Content -LiteralPath $bootstrap -Value $guestScript -Encoding utf8

Write-Host "Private key: $privateKey"
Write-Host "Generated guest bootstrap: $bootstrap"
Write-Host ''
Write-Host 'Start the temporary host server in this PowerShell window:'
Write-Host "python -m http.server 8000 --bind 0.0.0.0 --directory `"$bootstrapRoot`""
Write-Host ''
Write-Host 'Then run this short command in elevated Windows PowerShell in the guest:'
Write-Host 'irm http://10.0.2.2:8000/s|iex'
