function Resolve-LabWorkPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,
        [Parameter(Mandatory)]
        [string]$Path
    )

    $workRoot = [IO.Path]::GetFullPath([string]$Config.WorkRoot).TrimEnd([char[]]'\/')
    $candidate = if ([IO.Path]::IsPathRooted($Path)) {
        [IO.Path]::GetFullPath($Path)
    } else {
        [IO.Path]::GetFullPath((Join-Path $workRoot $Path))
    }

    $rootPrefix = $workRoot + [IO.Path]::DirectorySeparatorChar
    if (-not $candidate.Equals($workRoot, [StringComparison]::OrdinalIgnoreCase) -and
        -not $candidate.StartsWith($rootPrefix, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Generated path must remain under WorkRoot ($workRoot): $candidate"
    }
    $candidate
}

function ConvertTo-LabContainerPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Config,
        [Parameter(Mandatory)]
        [string]$Path
    )

    $hostPath = Resolve-LabWorkPath -Config $Config -Path $Path
    $workRoot = [IO.Path]::GetFullPath([string]$Config.WorkRoot).TrimEnd([char[]]'\/')
    $relative = $hostPath.Substring($workRoot.Length).TrimStart([char[]]'\/')
    if ([string]::IsNullOrWhiteSpace($relative)) {
        throw 'WorkRoot itself cannot be used as a container file path.'
    }
    '/work/' + $relative.Replace('\', '/')
}
