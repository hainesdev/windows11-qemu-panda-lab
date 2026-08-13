[CmdletBinding()]
param(
    [Parameter(Mandatory, Position = 0)]
    [string]$Command,
    [ValidateRange(1, 300)]
    [int]$TimeoutSeconds = 5
)

$ErrorActionPreference = 'Stop'
$config = & (Join-Path $PSScriptRoot 'Get-LabConfig.ps1')
. (Join-Path $PSScriptRoot 'MonitorProtocol.ps1')
$client = [Net.Sockets.TcpClient]::new()
$client.Connect('127.0.0.1', [int]$config.MonitorPort)
$stream = $client.GetStream()
$stream.ReadTimeout = 1000
$writer = [IO.StreamWriter]::new($stream, [Text.Encoding]::ASCII, 4096, $true)
$writer.NewLine = "`r`n"
$writer.AutoFlush = $true

function Read-MonitorText([int]$TimeoutMs = 3000) {
    $deadline = (Get-Date).AddMilliseconds($TimeoutMs)
    $builder = [Text.StringBuilder]::new()
    $buffer = New-Object byte[] 4096
    do {
        while ($client.Available -gt 0) {
            $count = $stream.Read($buffer, 0, [Math]::Min($buffer.Length, $client.Available))
            if ($count -gt 0) {
                [void]$builder.Append([Text.Encoding]::ASCII.GetString($buffer, 0, $count))
            }
        }
        if ($builder.ToString() -match '\(qemu\)\s*$') { break }
        Start-Sleep -Milliseconds 50
    } while ((Get-Date) -lt $deadline)
    $text = $builder.ToString()
    [pscustomobject]@{
        Text = $text
        PromptReceived = $text -match '\(qemu\)\s*$'
    }
}

try {
    $greeting = Read-MonitorText
    if (-not $greeting.PromptReceived) {
        throw 'Timed out waiting for the initial QEMU monitor prompt.'
    }
    $writer.WriteLine($Command)
    $response = Read-MonitorText -TimeoutMs ($TimeoutSeconds * 1000)
    Assert-PandaMonitorResponse `
        -Command $Command `
        -Text $response.Text `
        -PromptReceived $response.PromptReceived
}
finally {
    $writer.Dispose()
    $stream.Dispose()
    $client.Dispose()
}
