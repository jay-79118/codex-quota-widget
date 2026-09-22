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
Save-Logo 'ProviderAssets\Quota_Icon.png' 32 32

$shot = New-Object Drawing.Bitmap(300,304)
$graphics = [Drawing.Graphics]::FromImage($shot)
try {
  $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.Clear([Drawing.Color]::Transparent)
  $card = New-Object Drawing.Drawing2D.GraphicsPath
  $card.AddArc(0,0,32,32,180,90)
  $card.AddArc(268,0,32,32,270,90)
  $card.AddArc(268,272,32,32,0,90)
  $card.AddArc(0,272,32,32,90,90)
  $card.CloseFigure()
  $background = New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#202631'))
  $graphics.FillPath($background,$card)
  $title = New-Object Drawing.Font('Microsoft YaHei UI',15,[Drawing.FontStyle]::Bold)
  $label = New-Object Drawing.Font('Microsoft YaHei UI',11,[Drawing.FontStyle]::Regular)
  $number = New-Object Drawing.Font('Segoe UI',29,[Drawing.FontStyle]::Bold)
  $brush = New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#F0F5F9'))
  $muted = New-Object Drawing.SolidBrush([Drawing.ColorTranslator]::FromHtml('#BBC6D4'))
  try {
    $graphics.DrawString('额度剩余',$title,$brush,22,21)
    $graphics.DrawString('5 小时',$label,$muted,22,82)
    $graphics.DrawString('一周',$label,$muted,163,82)
    $graphics.DrawString('72%',$number,$brush,20,107)
    $graphics.DrawString('91%',$number,$brush,160,107)
    $graphics.DrawString('9/22 14:25',$label,$muted,22,173)
    $graphics.DrawString('9/29 09:25',$label,$muted,163,173)
    $graphics.DrawString('14:25 更新',$label,$muted,22,238)
  } finally { $muted.Dispose(); $brush.Dispose(); $title.Dispose(); $label.Dispose(); $number.Dispose(); $background.Dispose(); $card.Dispose() }
  $shot.Save((Join-Path $root 'ProviderAssets\Quota_Screenshot.png'),[Drawing.Imaging.ImageFormat]::Png)
} finally { $graphics.Dispose(); $shot.Dispose() }
