$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $MyInvocation.MyCommand.Path

function Draw-Rings($graphics, [single]$x, [single]$y, [single]$size) {
  $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $track = [Drawing.ColorTranslator]::FromHtml('#465063')
  $outer = [Drawing.ColorTranslator]::FromHtml('#64D8B8')
  $inner = [Drawing.ColorTranslator]::FromHtml('#86B7FF')
  $outerWidth = [Math]::Max(1.5, $size * 0.075)
  $innerWidth = [Math]::Max(1.2, $size * 0.065)
  $outerRect = New-Object Drawing.RectangleF(($x + $outerWidth),($y + $outerWidth),($size - 2 * $outerWidth),($size - 2 * $outerWidth))
  $inset = $size * 0.21
  $innerRect = New-Object Drawing.RectangleF(($x + $inset),($y + $inset),($size - 2 * $inset),($size - 2 * $inset))
  foreach ($entry in @(@($track,$outerWidth,$outerRect,360),@($outer,$outerWidth,$outerRect,259),@($track,$innerWidth,$innerRect,360),@($inner,$innerWidth,$innerRect,328))) {
    $pen = New-Object Drawing.Pen($entry[0],[single]$entry[1])
    try {
      $pen.StartCap = [Drawing.Drawing2D.LineCap]::Round
      $pen.EndCap = [Drawing.Drawing2D.LineCap]::Round
      $graphics.DrawArc($pen,[Drawing.RectangleF]$entry[2],-90,[single]$entry[3])
    } finally { $pen.Dispose() }
  }
}

function Save-Logo([string]$relativePath, [int]$width, [int]$height) {
  $path = Join-Path $root $relativePath
  $bitmap = New-Object Drawing.Bitmap($width,$height)
  $graphics = [Drawing.Graphics]::FromImage($bitmap)
  try {
    $graphics.Clear([Drawing.Color]::Transparent)
    $diameter = [single]([Math]::Min($width,$height) * 0.75)
    Draw-Rings $graphics (($width - $diameter) / 2) (($height - $diameter) / 2) $diameter
    $bitmap.Save($path,[Drawing.Imaging.ImageFormat]::Png)
  } finally { $graphics.Dispose(); $bitmap.Dispose() }
}

Save-Logo 'Assets\StoreLogo.png' 50 50
Save-Logo 'Assets\Square44x44Logo.png' 44 44
Save-Logo 'Assets\Square150x150Logo.png' 150 150
Save-Logo 'Assets\Wide310x150Logo.png' 310 150
Save-Logo 'Assets\SplashScreen.png' 620 300
Save-Logo 'ProviderAssets\Quota_Icon.png' 32 16

$shot = New-Object Drawing.Bitmap(227,126)
$graphics = [Drawing.Graphics]::FromImage($shot)
try {
  $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.Clear([Drawing.ColorTranslator]::FromHtml('#202631'))
  Draw-Rings $graphics 15 31 62
  $title = New-Object Drawing.Font('Segoe UI',11,[Drawing.FontStyle]::Bold)
  $body = New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Regular)
  $brush = New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#F0F5F9'))
  try {
    $graphics.DrawString('Codex quota',$title,$brush,86,20)
    $graphics.DrawString('5h  72%',$body,$brush,86,52)
    $graphics.DrawString('week  91%',$body,$brush,86,76)
  } finally { $brush.Dispose(); $title.Dispose(); $body.Dispose() }
  $shot.Save((Join-Path $root 'ProviderAssets\Quota_Screenshot.png'),[Drawing.Imaging.ImageFormat]::Png)
} finally { $graphics.Dispose(); $shot.Dispose() }
