$ErrorActionPreference = 'Stop'
$directory = Split-Path -Parent $MyInvocation.MyCommand.Path
$framework = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $framework)) {
  $framework = Join-Path $env:WINDIR 'Microsoft.NET\Framework\v4.0.30319\csc.exe'
}
if (-not (Test-Path -LiteralPath $framework)) { throw '未找到 .NET Framework C# 编译器。' }
$source = Join-Path $directory 'WidgetLauncher.cs'
$icon = Join-Path $directory 'CodexQuotaWidget.ico'
$output = Join-Path $directory 'CodexQuotaWidget.exe'
& $framework '/nologo' '/target:winexe' '/platform:anycpu' ('/out:' + $output) `
  ('/win32icon:' + $icon) '/r:System.Windows.Forms.dll' $source
if ($LASTEXITCODE -ne 0) { throw '编译失败。' }
Write-Output $output
