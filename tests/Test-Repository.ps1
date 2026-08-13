[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$failures = [Collections.Generic.List[string]]::new()

$powerShellFiles = Get-ChildItem -LiteralPath $repoRoot -Recurse -File |
    Where-Object Extension -In '.ps1', '.psd1'
foreach ($file in $powerShellFiles) {
    $tokens = $null
    $errors = $null
    [Management.Automation.Language.Parser]::ParseFile(
        $file.FullName,
        [ref]$tokens,
        [ref]$errors
    ) | Out-Null
    foreach ($error in $errors) {
        $failures.Add("PowerShell parse error in $($file.FullName): $($error.Message)")
    }
}

$textFiles = Get-ChildItem -LiteralPath $repoRoot -Recurse -File |
    Where-Object Extension -In '.md', '.ps1', '.psd1', '.sh', '.yml', '.yaml'
$forbiddenPatterns = [ordered]@{
    'Personal user path' = 'C:\\Users\\[^\\]+'
    'Originating VM path' = 'D:\\VirtualBox VMs'
    'Originating target name' = '(?i)' + 'da' + 'hua'
    'Private key material' = 'BEGIN (?:OPENSSH|RSA|EC) PRIVATE KEY'
    'GitHub token' = 'gh[opusr]_[A-Za-z0-9]{20,}'
}

foreach ($file in $textFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    foreach ($entry in $forbiddenPatterns.GetEnumerator()) {
        if ($content -match $entry.Value) {
            $failures.Add("$($entry.Key) found in $($file.FullName)")
        }
    }
}

$markdownFiles = Get-ChildItem -LiteralPath $repoRoot -Recurse -Filter '*.md' -File
foreach ($file in $markdownFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    $matches = [regex]::Matches($content, '\[[^\]]+\]\((?!https?://|#)([^)]+)\)')
    foreach ($match in $matches) {
        $target = [Uri]::UnescapeDataString($match.Groups[1].Value.Split('#')[0])
        if ([string]::IsNullOrWhiteSpace($target)) { continue }
        $resolved = Join-Path $file.DirectoryName $target
        if (-not (Test-Path -LiteralPath $resolved)) {
            $failures.Add("Broken local Markdown link in $($file.FullName): $target")
        }
    }
}

$exampleConfigPath = Join-Path $repoRoot 'config\panda.example.psd1'
$exampleConfig = Import-PowerShellDataFile -LiteralPath $exampleConfigPath
$requiredConfigKeys = @(
    'Image', 'Container', 'VmRoot', 'BaseDisk', 'WorkRoot', 'PrepOverlay',
    'PrepVars', 'SeedDisk', 'ActiveDisk', 'PandaCode', 'PandaVars',
    'QemuSystem', 'QemuImg', 'HostOvmfCode', 'HostOvmfVars', 'MonitorPort',
    'NoVncPort', 'SshPort', 'QmpPort'
)
foreach ($key in $requiredConfigKeys) {
    if (-not $exampleConfig.ContainsKey($key)) {
        $failures.Add("Example configuration is missing: $key")
    }
}

. (Join-Path $repoRoot 'scripts\host\LabPaths.ps1')
$pathTestConfig = @{ WorkRoot = 'C:\Panda Test\work' }
$containerPath = ConvertTo-LabContainerPath -Config $pathTestConfig -Path 'nested\disk.qcow2'
if ($containerPath -ne '/work/nested/disk.qcow2') {
    $failures.Add("Nested work path mapped incorrectly: $containerPath")
}
try {
    $null = Resolve-LabWorkPath -Config $pathTestConfig -Path '..\escape.qcow2'
    $failures.Add('WorkRoot path traversal was not rejected.')
} catch {
    if ($_.Exception.Message -notmatch 'must remain under WorkRoot') { throw }
}

. (Join-Path $repoRoot 'scripts\host\MonitorProtocol.ps1')
$monitorSuccess = Assert-PandaMonitorResponse `
    -Command 'info status' `
    -Text "VM status: running`r`n(qemu) " `
    -PromptReceived $true
if ($monitorSuccess -notmatch 'VM status: running') {
    $failures.Add('Successful monitor response was not returned.')
}
foreach ($badResponse in @(
    'Error while writing VM state',
    'unknown command: begin_recrd',
    'Device pflash does not support snapshots'
)) {
    try {
        $null = Assert-PandaMonitorResponse -Command 'test' -Text $badResponse -PromptReceived $true
        $failures.Add("Monitor failure response was accepted: $badResponse")
    } catch {
        if ($_.Exception.Message -notmatch 'QEMU monitor rejected') { throw }
    }
}
try {
    $null = Assert-PandaMonitorResponse -Command 'test' -Text '' -PromptReceived $false
    $failures.Add('Monitor timeout response was accepted.')
} catch {
    if ($_.Exception.Message -notmatch 'Timed out') { throw }
}

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    throw "$($failures.Count) repository validation check(s) failed."
}

Write-Host "Validated $($powerShellFiles.Count) PowerShell files and $($textFiles.Count) public text files."
