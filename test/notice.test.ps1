$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms

$source = Join-Path (Split-Path -Parent $PSScriptRoot) 'CodexQuotaWidget.ps1'
$tokens = $null
$errors = $null
$ast = [System.Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
if ($errors.Count) { throw 'Widget script has parse errors' }
foreach ($name in @('Test-ExistingNoticeWindow','Save-NoticeState','Show-QuotaNotices')) {
  $definition = $ast.FindAll({ param($node)
    $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
    $node.Name -eq $name
  }, $true) | Select-Object -First 1
  if (-not $definition) { throw "$name was not found" }
  Invoke-Expression $definition.Extent.Text
}

$script:NoticeEnabled = $true
$script:FiveHourThreshold = 20
$script:WeekThreshold = 10
$script:ResetSoonMinutes = 15
$script:NoticeKeys = @{}
$script:NoticeStateDirty = $false
$script:LastNoticeStateSaveAt = 0L
$script:SaveCount = 0
$script:TrayIcon = [pscustomobject]@{ Count = 0; Messages = @() }
$script:TrayIcon | Add-Member -MemberType ScriptMethod -Name ShowBalloonTip -Value {
  param($duration, $title, $message, $icon)
  $this.Count++
  $this.Messages += [string]$message
}
function Save-Settings { $script:SaveCount++ }
function Reset-Text($value) { return [string]$value }

$now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$data = @{ quota = @{ error = $null;
    primary = @{ remainingPercent = 10; resetsAt = $now + 10800; windowDurationMins = 300 };
    secondary = @{ remainingPercent = 80; resetsAt = $now + 86400; windowDurationMins = 10080 } } }
Show-QuotaNotices $data
if ($script:TrayIcon.Count -ne 1 -or $script:SaveCount -ne 1) {
  throw 'First low-quota event was not recorded once'
}
Show-QuotaNotices $data
if ($script:TrayIcon.Count -ne 1) { throw 'Same window repeated a low-quota notice' }

$data.quota.primary.remainingPercent = 9
for ($i = 0; $i -lt 180; $i++) {
  $data.quota.primary.resetsAt += 60
  Show-QuotaNotices $data
}
if ($script:TrayIcon.Count -ne 1 -or
    $script:NoticeKeys.fiveLow -ne [string]$data.quota.primary.resetsAt) {
  throw 'Gradually changing reset time repeated a low-quota notice'
}
$script:LastNoticeStateSaveAt = $now - 901
$data.quota.primary.resetsAt += 60
Show-QuotaNotices $data
if ($script:TrayIcon.Count -ne 1 -or $script:SaveCount -ne 2) {
  throw 'Shifted reset time was not persisted without a notification'
}

$data.quota.primary.remainingPercent = 95
Show-QuotaNotices $data
if ($script:TrayIcon.Count -ne 1 -or $script:NoticeKeys.ContainsKey('fiveLow')) {
  throw 'Replenished quota did not rearm the next low-quota notice'
}
$data.quota.primary.remainingPercent = 9
Show-QuotaNotices $data
if ($script:TrayIcon.Count -ne 2) { throw 'Low quota after replenishment did not notify' }

$data.quota.primary.resetsAt += 18000
Show-QuotaNotices $data
if ($script:TrayIcon.Count -ne 3) { throw 'Next five-hour window did not notify again' }

$data.quota.secondary.remainingPercent = 8
Show-QuotaNotices $data
if ($script:TrayIcon.Count -ne 4) { throw 'First weekly low-quota event was not sent' }
$data.quota.secondary.resetsAt += 120
Show-QuotaNotices $data
if ($script:TrayIcon.Count -ne 4) { throw 'Small weekly reset shift repeated the notice' }
$data.quota.secondary.resetsAt += 10080 * 60
Show-QuotaNotices $data
if ($script:TrayIcon.Count -ne 5) { throw 'Next weekly window did not notify again' }

$data.quota.primary.remainingPercent = 50
$data.quota.primary.resetsAt = $now + 600
Show-QuotaNotices $data
if ($script:TrayIcon.Count -ne 6) { throw 'Reset-soon notice was not sent' }
$data.quota.primary.resetsAt += 60
Show-QuotaNotices $data
if ($script:TrayIcon.Count -ne 6) { throw 'Reset-soon notice repeated after a small reset shift' }
'Notification window deduplication passed'
