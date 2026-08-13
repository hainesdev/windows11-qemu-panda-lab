function Assert-PandaMonitorResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Command,
        [AllowEmptyString()]
        [string]$Text,
        [bool]$PromptReceived
    )

    if (-not $PromptReceived) {
        throw "Timed out waiting for QEMU monitor command completion: $Command"
    }

    $failurePattern = '(?im)(?:^|\r?\n)\s*(?:Error(?::|\s)|unknown command:|invalid parameter|could not\b|failed to\b|migration failed\b)|does not support snapshots|duplicate id'
    if ($Text -match $failurePattern) {
        throw "QEMU monitor rejected '$Command': $($Text.Trim())"
    }
    $Text
}
