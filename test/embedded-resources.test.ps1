$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $root 'CodexQuotaWidget.exe'
$assembly = [Reflection.Assembly]::LoadFile($exe)
$versionSource = Get-Content -LiteralPath (Join-Path $root 'WidgetLauncher.cs') -Raw
$expectedVersion = [regex]::Match($versionSource, 'AssemblyVersion\("([^"]+)"\)').Groups[1].Value
if (-not $expectedVersion -or $assembly.GetName().Version.ToString() -ne $expectedVersion) {
  throw 'Checked-in EXE version differs from launcher source'
}
foreach ($entry in @(
    @{ resource = 'WidgetScript'; file = 'CodexQuotaWidget.ps1' },
    @{ resource = 'WidgetData'; file = 'data.js' },
    @{ resource = 'WidgetIcon'; file = 'CodexQuotaWidget.ico' }
  )) {
  $stream = $assembly.GetManifestResourceStream($entry.resource)
  if (-not $stream) { throw "Missing embedded resource: $($entry.resource)" }
  try {
    $memory = New-Object IO.MemoryStream
    try {
      $stream.CopyTo($memory)
      $hash = [Security.Cryptography.SHA256]::Create()
      try {
        $actual = [BitConverter]::ToString($hash.ComputeHash($memory.ToArray())).Replace('-', '')
      } finally { $hash.Dispose() }
    } finally { $memory.Dispose() }
  } finally { $stream.Dispose() }
  $expected = (Get-FileHash -LiteralPath (Join-Path $root $entry.file) -Algorithm SHA256).Hash
  if ($actual -ne $expected) { throw "EXE resource differs from $($entry.file)" }
}
'Checked-in EXE resources match source'
