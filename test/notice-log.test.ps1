$ErrorActionPreference = 'Stop'
$source = Join-Path (Split-Path -Parent $PSScriptRoot) 'CodexQuotaWidget.ps1'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Widget script has parse errors' }
$definition = $ast.FindAll({ param($node)
  $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
  $node.Name -eq 'Write-NoticeEvent'
}, $true) | Select-Object -First 1
if (-not $definition) { throw 'Write-NoticeEvent was not found' }
Invoke-Expression $definition.Extent.Text

$PreviewPath = $null
$fixture = Join-Path (Split-Path -Parent $PSScriptRoot) 'previews\tests'
[IO.Directory]::CreateDirectory($fixture) | Out-Null
$script:NoticeLogPath = Join-Path $fixture ('notice-' + [Guid]::NewGuid().ToString('N') + '.jsonl')
try {
  Write-NoticeEvent 'requested' 'fiveLow' 9.5 1790000000 'new-window'
  $record = Get-Content -LiteralPath $script:NoticeLogPath -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($record.event -ne 'requested' -or $record.notice -ne 'fiveLow' -or
      $record.remainingPercent -ne 9.5 -or $record.reason -ne 'new-window') {
    throw 'Notification event fields were not written correctly'
  }
  if (@($record.PSObject.Properties.Name | Where-Object {
      $_ -notin @('utc','event','notice','remainingPercent','resetsAt','reason') }).Count -ne 0) {
    throw 'Notification log contains an unexpected field'
  }
  [IO.File]::WriteAllText($script:NoticeLogPath, ('x' * 65536))
  Write-NoticeEvent 'rearmed' 'fiveLow' 95 1790010000 'quota-recovered'
  if (-not (Test-Path -LiteralPath ($script:NoticeLogPath + '.old')) -or
      (Get-Content -LiteralPath $script:NoticeLogPath -Raw | ConvertFrom-Json).event -ne 'rearmed') {
    throw 'Notification log rotation failed'
  }
  'Notification diagnostic log passed'
} finally {
  Remove-Item -LiteralPath $script:NoticeLogPath -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath ($script:NoticeLogPath + '.old') -ErrorAction SilentlyContinue
}
