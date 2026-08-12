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

if ($failures.Count -gt 0) {
    $failures | ForEach-Object { Write-Error $_ }
    throw "$($failures.Count) repository validation check(s) failed."
}

Write-Host "Validated $($powerShellFiles.Count) PowerShell files and $($textFiles.Count) public text files."
