param([string]$PreviewPath)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$script:AppDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:DataScript = Join-Path $script:AppDirectory 'data.js'
$script:IconPath = Join-Path $script:AppDirectory 'CodexQuotaWidget.ico'
$script:SettingsPath = Join-Path $script:AppDirectory 'settings.json'
$script:Skin = 'ring'
$script:Scale = 1.0
$script:TrackMode = 'remaining'
$script:TaskbarPosition = 0.53
$script:PaletteId = 'sea'
$script:Palettes = @{
  sea = @{ Name='海盐青蓝'; Surface='#202631'; Border='#465063'; Track='#394655'; Outer='#64D8B8'; Inner='#86B7FF'; Text='#F0F5F9'; OuterText='#E8FFF7'; InnerText='#AFCBFF'; Card='#2B3441'; Muted='#A9B8C8'; Button='#303B4B'; Metric='#8FCFBF' }
  dusk = @{ Name='暮光紫粉'; Surface='#252032'; Border='#59496A'; Track='#483A59'; Outer='#C4A0F8'; Inner='#FFB4C7'; Text='#F9F3FF'; OuterText='#F5E8FF'; InnerText='#FFD4DE'; Card='#332B42'; Muted='#C1B3D0'; Button='#453852'; Metric='#D4B6FF' }
  moss = @{ Name='苔石金绿'; Surface='#1F2825'; Border='#4B6155'; Track='#364B42'; Outer='#F0C879'; Inner='#8BDCC6'; Text='#FFF9EA'; OuterText='#FFF1CC'; InnerText='#CAF6E8'; Card='#2C3A33'; Muted='#B5C9BB'; Button='#3C5044'; Metric='#F0C879' }
  cream = @{ Name='奶油珊瑚'; Surface='#FFF8F1'; Border='#B39E94'; Track='#DECEC5'; Outer='#BE655B'; Inner='#526EAA'; Text='#3D343A'; OuterText='#5B3030'; InnerText='#324D7A'; Card='#F3E9E3'; Muted='#6E6268'; Button='#E8D9D2'; Metric='#9D4944' }
}
$script:NeedsSettingsMigration = $false
if (Test-Path -LiteralPath $script:SettingsPath) {
  try {
    $saved = Get-Content -LiteralPath $script:SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($saved.skin -in @('ring','track','taskbar')) { $script:Skin = [string]$saved.skin }
    if ($null -ne $saved.taskbarPosition -and [double]$saved.taskbarPosition -ge 0 -and [double]$saved.taskbarPosition -le 1) {
      $script:TaskbarPosition = [double]$saved.taskbarPosition
    }
    if ($saved.palette -and $script:Palettes.ContainsKey([string]$saved.palette)) { $script:PaletteId = [string]$saved.palette }
    if ([double]$saved.version -ge 2 -and [double]$saved.scale -ge 0.5 -and [double]$saved.scale -le 1.5) {
      $script:Scale = [double]$saved.scale
    } elseif ([double]$saved.scale -in @(0.75,1.0,1.25,1.5)) {
      $script:Scale = [Math]::Min(1.5, [double]$saved.scale + 0.25)
      $script:NeedsSettingsMigration = $true
    }
  } catch { }
}
if ($PreviewPath) {
  if ($env:CODEX_WIDGET_PREVIEW_SKIN -in @('ring','track','taskbar')) { $script:Skin = $env:CODEX_WIDGET_PREVIEW_SKIN }
  if ($env:CODEX_WIDGET_PREVIEW_PALETTE -and $script:Palettes.ContainsKey($env:CODEX_WIDGET_PREVIEW_PALETTE)) { $script:PaletteId = $env:CODEX_WIDGET_PREVIEW_PALETTE }
  if ($env:CODEX_WIDGET_PREVIEW_SCALE) {
    try { $script:Scale = [Math]::Max(0.5,[Math]::Min(1.5,[double]$env:CODEX_WIDGET_PREVIEW_SCALE)) } catch { }
  }
}
$nodeCommand = Get-Command node.exe -ErrorAction SilentlyContinue
$script:NodePath = if ($nodeCommand) { $nodeCommand.Source } else { 'C:\Program Files\nodejs\node.exe' }
$mutexName = if ($PreviewPath -or $env:CODEX_WIDGET_SELFTEST -eq '1') { 'Local\CodexQuotaWidgetPreview' } else { 'Local\CodexQuotaWidget' }
$script:WidgetMutex = New-Object System.Threading.Mutex($false, $mutexName)
if (-not $script:WidgetMutex.WaitOne(0)) { exit }

[xml]$miniXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Codex 额度" Width="104" Height="104"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ResizeMode="NoResize" Topmost="True" ShowInTaskbar="False"
        WindowStartupLocation="Manual" FontFamily="Microsoft YaHei UI">
  <Grid Background="Transparent">
    <Viewbox x:Name="RingView" Stretch="Fill">
      <Grid Width="104" Height="104">
        <Ellipse x:Name="RingSurface" Width="102" Height="102" Fill="#202631" Stroke="#465063" StrokeThickness="1"/>
        <Ellipse x:Name="RingOuterBase" Width="86" Height="86" Stroke="#394655" StrokeThickness="6"/>
        <Ellipse x:Name="OuterFull" Width="86" Height="86" Stroke="#64D8B8" StrokeThickness="6" Visibility="Collapsed"/>
        <Path x:Name="OuterArc" Width="104" Height="104" Stretch="None"
              Stroke="#64D8B8" StrokeThickness="6" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
        <Ellipse x:Name="RingInnerBase" Width="62" Height="62" Stroke="#394655" StrokeThickness="6"/>
        <Ellipse x:Name="InnerFull" Width="62" Height="62" Stroke="#86B7FF" StrokeThickness="6" Visibility="Collapsed"/>
        <Path x:Name="InnerArc" Width="104" Height="104" Stretch="None"
              Stroke="#86B7FF" StrokeThickness="6" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
        <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center" Cursor="Hand">
          <TextBlock x:Name="OuterText" Text="—" Foreground="#E7FFF7" FontSize="15" FontWeight="Bold" TextAlignment="Center"/>
          <TextBlock x:Name="InnerText" Text="周 —" Foreground="#AFCBFF" FontSize="8.5" TextAlignment="Center"/>
        </StackPanel>
      </Grid>
    </Viewbox>
    <Viewbox x:Name="TrackView" Stretch="Fill" Visibility="Collapsed">
      <Grid Width="132" Height="64">
        <Rectangle x:Name="TrackSurface" Width="130" Height="62" RadiusX="31" RadiusY="31" Fill="#202631" Stroke="#465063" StrokeThickness="1"/>
        <Rectangle x:Name="TrackOuterBase" Width="120" Height="54" RadiusX="27" RadiusY="27" Stroke="#394655" StrokeThickness="4.5"/>
        <Path x:Name="TrackOuterArc" Width="132" Height="64" Stretch="None"
              Stroke="#64D8B8" StrokeThickness="4.5" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
        <Rectangle x:Name="TrackInnerBase" Width="100" Height="36" RadiusX="18" RadiusY="18" Stroke="#394655" StrokeThickness="4"/>
        <Path x:Name="TrackInnerArc" Width="132" Height="64" Stretch="None"
              Stroke="#86B7FF" StrokeThickness="4" StrokeStartLineCap="Round" StrokeEndLineCap="Round"/>
        <StackPanel HorizontalAlignment="Center" VerticalAlignment="Center" Cursor="Hand">
          <TextBlock x:Name="TrackLine1" Text="5小时 —" Foreground="#E8FFF7" FontSize="9.4" FontWeight="SemiBold" TextAlignment="Center"/>
          <TextBlock x:Name="TrackLine2" Text="一周 —" Foreground="#AFCBFF" FontSize="9.4" FontWeight="SemiBold" TextAlignment="Center"/>
        </StackPanel>
      </Grid>
    </Viewbox>
    <Viewbox x:Name="TaskbarView" Stretch="Fill" Visibility="Collapsed">
      <Border x:Name="TaskbarSurface" Width="224" Height="30" CornerRadius="15"
              Background="#202631" BorderBrush="#465063" BorderThickness="1" Cursor="Hand">
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
          <TextBlock x:Name="TaskbarLine1" Text="5小时 —" Foreground="#E8FFF7"
                     FontSize="11" FontWeight="SemiBold" TextTrimming="CharacterEllipsis" MaxWidth="108"/>
          <TextBlock x:Name="TaskbarDivider" Text="  ·  " Foreground="#A9B8C8" FontSize="11"/>
          <TextBlock x:Name="TaskbarLine2" Text="一周 —" Foreground="#AFCBFF"
                     FontSize="11" FontWeight="SemiBold" TextTrimming="CharacterEllipsis" MaxWidth="108"/>
        </StackPanel>
      </Border>
    </Viewbox>
  </Grid>
</Window>
'@

[xml]$detailXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Codex 任务 Token" Width="290" Height="360"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ResizeMode="NoResize" Topmost="True" ShowInTaskbar="False"
        WindowStartupLocation="Manual" FontFamily="Microsoft YaHei UI">
  <Viewbox Stretch="Fill">
  <Border x:Name="DetailSurface" Width="290" Height="360" Background="#202631" BorderBrush="#465063" BorderThickness="1" CornerRadius="13" Padding="14">
    <Grid>
      <Grid.RowDefinitions><RowDefinition Height="35"/><RowDefinition Height="*"/><RowDefinition Height="29"/></Grid.RowDefinitions>
      <Grid Grid.Row="0">
        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
        <TextBlock x:Name="DetailDrag" Text="任务 Token" Foreground="#F0F5F9" FontSize="14" FontWeight="SemiBold" Cursor="SizeAll"/>
        <Button x:Name="DetailRefresh" Grid.Column="1" Content="↻" Width="26" Height="25" Margin="0,0,5,0"
                Background="#303B4B" Foreground="#DCE6F1" BorderThickness="0" Cursor="Hand"/>
        <Button x:Name="DetailClose" Grid.Column="2" Content="×" Width="26" Height="25"
                Background="#303B4B" Foreground="#DCE6F1" BorderThickness="0" Cursor="Hand"/>
      </Grid>
      <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Disabled">
        <StackPanel x:Name="TaskList"/>
      </ScrollViewer>
      <TextBlock x:Name="DetailStatus" Grid.Row="2" Text="正在读取…" Foreground="#91A3B7" FontSize="10" VerticalAlignment="Bottom"/>
    </Grid>
  </Border>
  </Viewbox>
</Window>
'@

$script:Mini = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $miniXaml))
$script:Detail = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $detailXaml))
if (Test-Path -LiteralPath $script:IconPath) {
  try {
    $script:Mini.Icon = [Windows.Media.Imaging.BitmapFrame]::Create([Uri]::new($script:IconPath))
    $script:Detail.Icon = $script:Mini.Icon
  } catch { }
}
foreach ($name in @('RingView','TrackView','TaskbarView','RingSurface','RingOuterBase','RingInnerBase',
  'TrackSurface','TrackOuterBase','TrackInnerBase','OuterFull','OuterArc','InnerFull','InnerArc',
  'OuterText','InnerText','TrackOuterArc','TrackInnerArc','TrackLine1','TrackLine2',
  'TaskbarSurface','TaskbarLine1','TaskbarLine2','TaskbarDivider')) {
  Set-Variable -Scope Script -Name $name -Value $script:Mini.FindName($name)
}
foreach ($name in @('DetailSurface','DetailDrag','DetailRefresh','DetailClose','TaskList','DetailStatus')) {
  Set-Variable -Scope Script -Name $name -Value $script:Detail.FindName($name)
}

function Start-DataProcess {
  if (-not (Test-Path -LiteralPath $script:NodePath)) { throw '未找到 Node.js' }
  $start = New-Object System.Diagnostics.ProcessStartInfo
  $start.FileName = $script:NodePath
  $start.Arguments = '"' + $script:DataScript + '"'
  $start.WorkingDirectory = $script:AppDirectory
  $start.UseShellExecute = $false
  $start.CreateNoWindow = $true
  $start.RedirectStandardOutput = $true
  $start.RedirectStandardError = $true
  $start.StandardOutputEncoding = [Text.Encoding]::UTF8
  $start.StandardErrorEncoding = [Text.Encoding]::UTF8
  return [System.Diagnostics.Process]::Start($start)
}

function Read-Data {
  if ($PreviewPath -and $env:CODEX_WIDGET_LIVEPREVIEW -ne '1') {
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    return (@{
      checkedAt = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
      quota = @{
        primary = @{ remainingPercent = 72; windowDurationMins = 300; resetsAt = $now + 7200 }
        secondary = @{ remainingPercent = 91; windowDurationMins = 10080; resetsAt = $now + 345600 }
        error = $null
      }
      tasks = @(
        @{ title = '设计额度与 Token 用量工具'; totalTokens = 128540; inputTokens = 103290; outputTokens = 25250; cachedInputTokens = 52440 }
        @{ title = '整理项目方案'; totalTokens = 78620; inputTokens = 65410; outputTokens = 13210; cachedInputTokens = 20520 }
      )
    } | ConvertTo-Json -Depth 6 | ConvertFrom-Json)
  }
  $process = Start-DataProcess
  try {
    $outputTask = $process.StandardOutput.ReadToEndAsync()
    $errorTask = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit(15000)) {
      $process.Kill()
      throw '读取超时'
    }
    $output = $outputTask.GetAwaiter().GetResult()
    if (-not $output) { throw '数据接口未返回内容' }
    try { return ConvertFrom-Json -InputObject $output -ErrorAction Stop }
    catch { throw '数据格式异常，请刷新重试' }
  } finally { $process.Dispose() }
}

function Set-Arc($path, $full, [double]$percent, [double]$radius) {
  $percent = [Math]::Max(0, [Math]::Min(100, $percent))
  if ($percent -ge 99.99) {
    $full.Visibility = [Windows.Visibility]::Visible
    $path.Visibility = [Windows.Visibility]::Collapsed
    return
  }
  $full.Visibility = [Windows.Visibility]::Collapsed
  if ($percent -le 0) {
    $path.Visibility = [Windows.Visibility]::Collapsed
    return
  }
  $path.Visibility = [Windows.Visibility]::Visible
  $angle = 2 * [Math]::PI * $percent / 100
  $end = New-Object Windows.Point((52 + $radius * [Math]::Sin($angle)), (52 - $radius * [Math]::Cos($angle)))
  $segment = New-Object System.Windows.Media.ArcSegment
  $segment.Point = $end
  $segment.Size = New-Object Windows.Size($radius, $radius)
  $segment.IsLargeArc = $percent -gt 50
  $segment.SweepDirection = [Windows.Media.SweepDirection]::Clockwise
  $figure = New-Object System.Windows.Media.PathFigure
  $figure.StartPoint = New-Object Windows.Point(52, (52 - $radius))
  [void]$figure.Segments.Add($segment)
  $geometry = New-Object System.Windows.Media.PathGeometry
  [void]$geometry.Figures.Add($figure)
  $path.Data = $geometry
}

function Track-Point([double]$distance, [double]$width, [double]$radius) {
  $cx = 66.0; $cy = 32.0
  $halfStraight = ($width - 2 * $radius) / 2
  $right = $cx + $halfStraight; $left = $cx - $halfStraight
  $top = $cy - $radius; $bottom = $cy + $radius
  $halfArc = [Math]::PI * $radius
  if ($distance -le $halfStraight) { return (New-Object Windows.Point(($cx + $distance), $top)) }
  $distance -= $halfStraight
  if ($distance -le $halfArc) {
    $angle = -[Math]::PI / 2 + $distance / $radius
    return (New-Object Windows.Point(($right + $radius * [Math]::Cos($angle)), ($cy + $radius * [Math]::Sin($angle))))
  }
  $distance -= $halfArc
  if ($distance -le 2 * $halfStraight) { return (New-Object Windows.Point(($right - $distance), $bottom)) }
  $distance -= 2 * $halfStraight
  if ($distance -le $halfArc) {
    $angle = [Math]::PI / 2 + $distance / $radius
    return (New-Object Windows.Point(($left + $radius * [Math]::Cos($angle)), ($cy + $radius * [Math]::Sin($angle))))
  }
  $distance -= $halfArc
  return (New-Object Windows.Point(($left + $distance), $top))
}

function Set-TrackArc($path, [double]$percent, [double]$width, [double]$radius) {
  $percent = [Math]::Max(0, [Math]::Min(100, $percent))
  if ($percent -le 0) { $path.Visibility = [Windows.Visibility]::Collapsed; return }
  $path.Visibility = [Windows.Visibility]::Visible
  $length = 2 * ($width - 2 * $radius) + 2 * [Math]::PI * $radius
  $end = $length * $percent / 100
  $steps = [Math]::Max(2, [int][Math]::Ceiling($end / 2))
  $figure = New-Object System.Windows.Media.PathFigure
  $figure.StartPoint = Track-Point 0 $width $radius
  for ($i = 1; $i -le $steps; $i++) {
    $point = Track-Point ($end * $i / $steps) $width $radius
    [void]$figure.Segments.Add(([Windows.Media.LineSegment]::new($point, $true)))
  }
  $geometry = New-Object System.Windows.Media.PathGeometry
  [void]$geometry.Figures.Add($figure)
  $path.Data = $geometry
}

function Quota-Percent($quota) {
  if ($null -eq $quota) { return '未知' }
  return ('{0:0}%' -f [double]$quota.remainingPercent)
}

function Update-TrackText {
  if ($script:TrackMode -eq 'reset') {
    $script:TrackLine1.Text = ('5小时 {0}' -f (Reset-Text $script:ShortQuota))
    $script:TrackLine2.Text = ('一周 {0}' -f (Reset-Text $script:WeekQuota))
    $script:TaskbarLine1.Text = ('5小时 {0}' -f (Reset-Text $script:ShortQuota))
    $script:TaskbarLine2.Text = ('一周 {0}' -f (Reset-Text $script:WeekQuota))
  } else {
    $script:TrackLine1.Text = ('5小时 {0}' -f (Quota-Percent $script:ShortQuota))
    $script:TrackLine2.Text = ('一周 {0}' -f (Quota-Percent $script:WeekQuota))
    $script:TaskbarLine1.Text = ('5小时 {0}' -f (Quota-Percent $script:ShortQuota))
    $script:TaskbarLine2.Text = ('一周 {0}' -f (Quota-Percent $script:WeekQuota))
  }
}

function Save-Settings {
  @{ version = 2; skin = $script:Skin; scale = $script:Scale; palette = $script:PaletteId;
     taskbarPosition = $script:TaskbarPosition } | ConvertTo-Json -Compress |
    Set-Content -LiteralPath $script:SettingsPath -Encoding UTF8
}

function Place-TaskbarStrip {
  if ($script:Skin -ne 'taskbar') { return }
  $area = [Windows.SystemParameters]::WorkArea
  $screenBottom = [Windows.SystemParameters]::PrimaryScreenHeight
  $taskbarHeight = $screenBottom - $area.Bottom
  if ($taskbarHeight -ge 24 -and $taskbarHeight -le 120) {
    $script:Mini.Top = $area.Bottom + [Math]::Max(0, ($taskbarHeight - $script:Mini.Height) / 2)
  } else {
    $script:Mini.Top = $area.Bottom - $script:Mini.Height - 4
  }
  $availableWidth = [Math]::Max(0, $area.Width - $script:Mini.Width)
  $script:Mini.Left = $area.Left + $availableWidth * $script:TaskbarPosition
}

function Save-TaskbarPosition {
  $area = [Windows.SystemParameters]::WorkArea
  $availableWidth = [Math]::Max(1, $area.Width - $script:Mini.Width)
  $script:TaskbarPosition = [Math]::Max(0, [Math]::Min(1,
    ($script:Mini.Left - $area.Left) / $availableWidth))
  Place-TaskbarStrip
  Save-Settings
}

function Color-Brush([string]$value) {
  return [Windows.Media.BrushConverter]::new().ConvertFromString($value)
}

function Set-SkinScale([string]$skin, [double]$scale, [bool]$save) {
  if ($skin -notin @('ring','track','taskbar')) { return }
  $scale = [Math]::Max(0.5, [Math]::Min(1.5, $scale))
  $wasVisible = $script:Mini.IsVisible
  $oldLeft = $script:Mini.Left
  $oldTop = $script:Mini.Top
  $centerX = $script:Mini.Left + $script:Mini.Width / 2
  $centerY = $script:Mini.Top + $script:Mini.Height / 2
  $script:Skin = $skin; $script:Scale = $scale
  $script:RingView.Visibility = if ($skin -eq 'ring') { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
  $script:TrackView.Visibility = if ($skin -eq 'track') { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
  $script:TaskbarView.Visibility = if ($skin -eq 'taskbar') { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
  $script:Mini.Width = $(if ($skin -eq 'ring') { 78 } elseif ($skin -eq 'track') { 132 } else { 224 }) * $scale
  $script:Mini.Height = $(if ($skin -eq 'ring') { 78 } elseif ($skin -eq 'track') { 64 } else { 30 }) * $scale
  if ($wasVisible) {
    $area = [Windows.SystemParameters]::WorkArea
    if ($skin -eq 'taskbar') { Place-TaskbarStrip }
    else {
      $newLeft = if ($script:ResizingFromSlider) { $oldLeft } else { $centerX - $script:Mini.Width / 2 }
      $newTop = if ($script:ResizingFromSlider) { $oldTop } else { $centerY - $script:Mini.Height / 2 }
      $script:Mini.Left = [Math]::Max($area.Left + 4, [Math]::Min($newLeft, $area.Right - $script:Mini.Width - 4))
      $script:Mini.Top = [Math]::Max($area.Top + 4, [Math]::Min($newTop, $area.Bottom - $script:Mini.Height - 4))
    }
    if ($script:Detail.IsVisible) {
      $script:Detail.Left = [Math]::Max($area.Left + 4, [Math]::Min($script:Detail.Left, $area.Right - $script:Detail.Width - 4))
      $script:Detail.Top = [Math]::Max($area.Top + 4, [Math]::Min($script:Detail.Top, $area.Bottom - $script:Detail.Height - 4))
    }
  }
  if ($save) { Save-Settings }
}

function Reset-Text($value) {
  if ($null -ne $value -and $value.PSObject.Properties['resetsAt']) { $value = $value.resetsAt }
  if (-not $value) { return '未知' }
  try { return [DateTimeOffset]::FromUnixTimeSeconds([long]$value).ToLocalTime().ToString('M/d HH:mm') }
  catch { return '未知' }
}

function Format-Number([long]$value) { return $value.ToString('N0') }

function Add-Task($task) {
  $row = New-Object Windows.Controls.Border
  $row.Background = Color-Brush $script:Palette.Card
  $row.CornerRadius = New-Object Windows.CornerRadius(8)
  $row.Padding = New-Object Windows.Thickness(9,7,9,7)
  $row.Margin = New-Object Windows.Thickness(0,0,0,6)
  $stack = New-Object Windows.Controls.StackPanel
  $title = New-Object Windows.Controls.TextBlock
  $title.Text = [string]$task.title
  $title.ToolTip = [string]$task.title
  $title.TextTrimming = [Windows.TextTrimming]::CharacterEllipsis
  $title.Foreground = Color-Brush $script:Palette.Text
  $title.FontSize = 11
  $title.MaxWidth = 247
  [void]$stack.Children.Add($title)
  $total = New-Object Windows.Controls.TextBlock
  $total.Text = ('总 {0}  ·  输入 {1}  ·  输出 {2}' -f
    (Format-Number ([long]$task.totalTokens)),
    (Format-Number ([long]$task.inputTokens)),
    (Format-Number ([long]$task.outputTokens)))
  $total.Foreground = Color-Brush $script:Palette.Metric
  $total.FontSize = 9
  $total.Margin = New-Object Windows.Thickness(0,4,0,0)
  [void]$stack.Children.Add($total)
  $row.Child = $stack
  [void]$script:TaskList.Children.Add($row)
}

function Render-Tasks {
  $script:TaskList.Children.Clear()
  if ($null -eq $script:CurrentTasks) { return }
  foreach ($task in $script:CurrentTasks) { Add-Task $task }
  if (@($script:CurrentTasks).Count -eq 0) {
    $empty = New-Object Windows.Controls.TextBlock
    $empty.Text = '暂无本机 Token 记录'
    $empty.Foreground = Color-Brush $script:Palette.Muted
    [void]$script:TaskList.Children.Add($empty)
  }
  $script:TasksDirty = $false
}

function Apply-Palette([string]$paletteId, [bool]$save) {
  if (-not $script:Palettes.ContainsKey($paletteId)) { return }
  $script:PaletteId = $paletteId
  $script:Palette = $script:Palettes[$paletteId]
  $script:RingSurface.Fill = Color-Brush $script:Palette.Surface
  $script:RingSurface.Stroke = Color-Brush $script:Palette.Border
  $script:TrackSurface.Fill = Color-Brush $script:Palette.Surface
  $script:TrackSurface.Stroke = Color-Brush $script:Palette.Border
  $script:TaskbarSurface.Background = Color-Brush $script:Palette.Surface
  $script:TaskbarSurface.BorderBrush = Color-Brush $script:Palette.Border
  foreach ($shape in @($script:RingOuterBase,$script:RingInnerBase,$script:TrackOuterBase,$script:TrackInnerBase)) {
    $shape.Stroke = Color-Brush $script:Palette.Track
  }
  foreach ($shape in @($script:OuterFull,$script:OuterArc,$script:TrackOuterArc)) {
    $shape.Stroke = Color-Brush $script:Palette.Outer
  }
  foreach ($shape in @($script:InnerFull,$script:InnerArc,$script:TrackInnerArc)) {
    $shape.Stroke = Color-Brush $script:Palette.Inner
  }
  $script:OuterText.Foreground = Color-Brush $script:Palette.OuterText
  $script:TrackLine1.Foreground = Color-Brush $script:Palette.OuterText
  $script:TaskbarLine1.Foreground = Color-Brush $script:Palette.OuterText
  $script:InnerText.Foreground = Color-Brush $script:Palette.InnerText
  $script:TrackLine2.Foreground = Color-Brush $script:Palette.InnerText
  $script:TaskbarLine2.Foreground = Color-Brush $script:Palette.InnerText
  $script:TaskbarDivider.Foreground = Color-Brush $script:Palette.Muted
  $script:DetailSurface.Background = Color-Brush $script:Palette.Surface
  $script:DetailSurface.BorderBrush = Color-Brush $script:Palette.Border
  $script:DetailDrag.Foreground = Color-Brush $script:Palette.Text
  $script:DetailStatus.Foreground = Color-Brush $script:Palette.Muted
  foreach ($button in @($script:DetailRefresh,$script:DetailClose)) {
    $button.Background = Color-Brush $script:Palette.Button
    $button.Foreground = Color-Brush $script:Palette.Text
  }
  $script:TasksDirty = $true
  if ($script:Detail.IsVisible) { Render-Tasks }
  if ($save) { Save-Settings }
}

function Apply-Data($data) {
  try {
    $short = $data.quota.primary
    $week = $data.quota.secondary
    $script:ShortQuota = $short
    $script:WeekQuota = $week
    if ($short) {
      $script:OuterText.Text = ('{0:0}%' -f [double]$short.remainingPercent)
      Set-Arc $script:OuterArc $script:OuterFull ([double]$short.remainingPercent) 43
      Set-TrackArc $script:TrackOuterArc ([double]$short.remainingPercent) 120 27
    } else {
      $script:OuterText.Text = '—'
      Set-Arc $script:OuterArc $script:OuterFull 0 43
      Set-TrackArc $script:TrackOuterArc 0 120 27
    }
    if ($week) {
      $script:InnerText.Text = ('周 {0:0}%' -f [double]$week.remainingPercent)
      Set-Arc $script:InnerArc $script:InnerFull ([double]$week.remainingPercent) 31
      Set-TrackArc $script:TrackInnerArc ([double]$week.remainingPercent) 100 18
    } else {
      $script:InnerText.Text = '周 —'
      Set-Arc $script:InnerArc $script:InnerFull 0 31
      Set-TrackArc $script:TrackInnerArc 0 100 18
    }
    Update-TrackText
    $script:Mini.ToolTip = ("5 小时剩余 {0}，{1} 重置`n一周剩余 {2}，{3} 重置" -f
      $(if ($short) { '{0:0}%' -f [double]$short.remainingPercent } else { '未知' }),
      (Reset-Text $short.resetsAt),
      $(if ($week) { '{0:0}%' -f [double]$week.remainingPercent } else { '未知' }),
      (Reset-Text $week.resetsAt))
    $taskSignature = ConvertTo-Json -InputObject $data.tasks -Depth 4 -Compress
    if ($taskSignature -ne $script:TaskSignature) {
      $script:CurrentTasks = @($data.tasks)
      $script:TaskSignature = $taskSignature
      $script:TasksDirty = $true
      if ($script:Detail.IsVisible) { Render-Tasks }
    }
    $status = '{0} 更新 · {1} 个本机任务' -f [DateTime]::Now.ToString('HH:mm'), @($data.tasks).Count
    if ($data.quota.error) { $status += ' · 额度暂不可用' }
    $script:DetailStatus.Text = $status
    if ($script:TrayIcon) {
      $script:TrayIcon.Text = ('Codex 额度  5小时 {0}  一周 {1}' -f (Quota-Percent $short), (Quota-Percent $week))
    }
  } catch { Show-ReadError $_.Exception.Message }
}

function Show-ReadError([string]$message) {
    $script:OuterText.Text = '—'
    $script:InnerText.Text = '周 —'
    Set-Arc $script:OuterArc $script:OuterFull 0 43
    Set-Arc $script:InnerArc $script:InnerFull 0 31
    Set-TrackArc $script:TrackOuterArc 0 120 27
    Set-TrackArc $script:TrackInnerArc 0 100 18
    $script:TrackLine1.Text = '5小时 —'
    $script:TrackLine2.Text = '一周 —'
    $script:TaskbarLine1.Text = '5小时 —'
    $script:TaskbarLine2.Text = '一周 —'
    $script:Mini.ToolTip = '读取失败，右键刷新'
    $script:DetailStatus.Text = ('读取失败：{0}' -f $message)
    if ($script:TrayIcon) { $script:TrayIcon.Text = 'Codex 额度 · 读取失败' }
}

function Refresh-Data {
  if ($script:ReadProcess) { return }
  $script:DetailStatus.Text = '正在读取…'
  try {
    $script:ReadProcess = Start-DataProcess
    $script:ReadOutput = $script:ReadProcess.StandardOutput.ReadToEndAsync()
    $script:ReadError = $script:ReadProcess.StandardError.ReadToEndAsync()
    $script:ReadStarted = [DateTime]::UtcNow
    $script:ReadPollTimer.Start()
  } catch {
    if ($script:ReadProcess) {
      try { if (-not $script:ReadProcess.HasExited) { $script:ReadProcess.Kill() } } catch { }
      $script:ReadProcess.Dispose()
      $script:ReadProcess = $null
    }
    Show-ReadError $_.Exception.Message
  }
}

function Complete-Read {
  $process = $script:ReadProcess
  if (-not $process) { return }
  if (-not $process.HasExited -or -not $script:ReadOutput.IsCompleted -or -not $script:ReadError.IsCompleted) {
    if (([DateTime]::UtcNow - $script:ReadStarted).TotalSeconds -lt 15) { return }
    try { $process.Kill() } catch { }
    Show-ReadError '读取超时'
    $script:ReadPollTimer.Stop()
    $process.Dispose()
    $script:ReadProcess = $null
    $script:ReadOutput = $null
    $script:ReadError = $null
    return
  }
  try {
    $output = $script:ReadOutput.GetAwaiter().GetResult()
    if (-not $output) {
      $errorText = $script:ReadError.GetAwaiter().GetResult()
      if ($errorText) { throw $errorText.Trim() }
      throw '数据接口未返回内容'
    }
    try { $data = ConvertFrom-Json -InputObject $output -ErrorAction Stop }
    catch { throw '数据格式异常，请刷新重试' }
    Apply-Data $data
  } catch { Show-ReadError $_.Exception.Message }
  finally {
    $script:ReadPollTimer.Stop()
    $process.Dispose()
    $script:ReadProcess = $null
    $script:ReadOutput = $null
    $script:ReadError = $null
  }
}

function Show-Details {
  $area = [Windows.SystemParameters]::WorkArea
  $left = $script:Mini.Left - $script:Detail.Width - 8
  if ($left -lt $area.Left + 8) { $left = $script:Mini.Left + $script:Mini.Width + 8 }
  $script:Detail.Left = [Math]::Min($left, $area.Right - $script:Detail.Width - 8)
  $script:Detail.Top = [Math]::Min([Math]::Max($script:Mini.Top, $area.Top + 8), $area.Bottom - $script:Detail.Height - 8)
  $script:Detail.Topmost = $script:Mini.Topmost
  if ($script:TasksDirty) { Render-Tasks }
  if (-not $script:Detail.IsVisible) { $script:Detail.Show() }
  [void]$script:Detail.Activate()
}

function Is-CenterHit($position) {
  if ($script:Skin -eq 'ring') {
    $x = $position.X / ($script:Scale * 0.75)
    $y = $position.Y / ($script:Scale * 0.75)
    return (($x - 52) * ($x - 52) + ($y - 52) * ($y - 52)) -le (25 * 25)
  }
  $x = $position.X / $script:Scale
  $y = $position.Y / $script:Scale
  if ($script:Skin -eq 'taskbar') { return $true }
  if ($y -lt 18 -or $y -gt 46 -or $x -lt 20 -or $x -gt 112) { return $false }
  if ($x -ge 34 -and $x -le 98) { return $true }
  $arcX = if ($x -lt 34) { 34 } else { 98 }
  return (([Math]::Pow(($x - $arcX) / 14, 2) + [Math]::Pow(($y - 32) / 14, 2)) -le 1)
}

$script:Mini.Add_PreviewMouseLeftButtonDown({
  $script:PointerDown = $true
  $script:DragStarted = $false
  $script:PointerStart = $_.GetPosition($script:Mini)
})
$script:Mini.Add_PreviewMouseMove({
  if (-not $script:PointerDown -or $_.LeftButton -ne [Windows.Input.MouseButtonState]::Pressed) { return }
  $point = $_.GetPosition($script:Mini)
  if ([Math]::Abs($point.X - $script:PointerStart.X) -lt 5 -and
      [Math]::Abs($point.Y - $script:PointerStart.Y) -lt 5) { return }
  $script:DragStarted = $true
  $script:PointerDown = $false
  try { $script:Mini.DragMove() } catch { }
  finally { if ($script:Skin -eq 'taskbar') { Save-TaskbarPosition } }
})
$script:Mini.Add_PreviewMouseLeftButtonUp({
  if (-not $script:PointerDown -or $script:DragStarted) { return }
  $script:PointerDown = $false
  if (Is-CenterHit ($_.GetPosition($script:Mini))) {
    if ($script:Skin -in @('track','taskbar')) {
      $script:TrackMode = if ($script:TrackMode -eq 'remaining') { 'reset' } else { 'remaining' }
      Update-TrackText
    } else { Show-Details }
  }
})
$script:Mini.Add_MouseLeave({ if ([Windows.Input.Mouse]::LeftButton -ne [Windows.Input.MouseButtonState]::Pressed) { $script:PointerDown = $false } })
$script:DetailDrag.Add_MouseLeftButtonDown({ $script:Detail.DragMove() })
$script:DetailClose.Add_Click({ $script:Detail.Hide() })
$script:DetailRefresh.Add_Click({ Refresh-Data })

$menu = New-Object Windows.Controls.ContextMenu
$openItem = New-Object Windows.Controls.MenuItem
$openItem.Header = '查看任务 Token'
$openItem.Add_Click({ Show-Details })
[void]$menu.Items.Add($openItem)
$refreshItem = New-Object Windows.Controls.MenuItem
$refreshItem.Header = '刷新额度'
$refreshItem.Add_Click({ Refresh-Data })
[void]$menu.Items.Add($refreshItem)
$skinMenu = New-Object Windows.Controls.MenuItem
$skinMenu.Header = '皮肤'
foreach ($entry in @(@('ring','双圆环'),@('track','跑道'),@('taskbar','任务栏横条'))) {
  $item = New-Object Windows.Controls.MenuItem
  $item.Header = $entry[1]
  $item.Tag = $entry[0]
  $item.IsCheckable = $true
  $item.IsChecked = $script:Skin -eq $entry[0]
  $item.Add_Click({
    param($sender, $args)
    Set-SkinScale ([string]$sender.Tag) $script:Scale $true
    foreach ($choice in $skinMenu.Items) { $choice.IsChecked = [string]$choice.Tag -eq $script:Skin }
  })
  [void]$skinMenu.Items.Add($item)
}
[void]$menu.Items.Add($skinMenu)
$paletteMenu = New-Object Windows.Controls.MenuItem
$paletteMenu.Header = '配色'
foreach ($paletteChoiceId in @('sea','dusk','moss','cream')) {
  $paletteOption = $script:Palettes[$paletteChoiceId]
  $item = New-Object Windows.Controls.MenuItem
  $item.Tag = $paletteChoiceId
  $item.IsCheckable = $true
  $item.IsChecked = $script:PaletteId -eq $paletteChoiceId
  $swatches = New-Object Windows.Controls.StackPanel
  $swatches.Orientation = [Windows.Controls.Orientation]::Horizontal
  foreach ($color in @($paletteOption.Outer,$paletteOption.Inner)) {
    $dot = New-Object Windows.Controls.Border
    $dot.Width = 11; $dot.Height = 11
    $dot.CornerRadius = New-Object Windows.CornerRadius(5.5)
    $dot.Background = Color-Brush $color
    $dot.Margin = New-Object Windows.Thickness(0,0,4,0)
    [void]$swatches.Children.Add($dot)
  }
  $label = New-Object Windows.Controls.TextBlock
  $label.Text = $paletteOption.Name
  $label.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, [Windows.SystemColors]::MenuTextBrushKey)
  $label.VerticalAlignment = [Windows.VerticalAlignment]::Center
  $label.Margin = New-Object Windows.Thickness(3,0,0,0)
  [void]$swatches.Children.Add($label)
  $item.Header = $swatches
  $item.Add_Click({
    param($sender, $args)
    Apply-Palette ([string]$sender.Tag) $true
    foreach ($choice in $paletteMenu.Items) { $choice.IsChecked = [string]$choice.Tag -eq $script:PaletteId }
  })
  [void]$paletteMenu.Items.Add($item)
}
[void]$menu.Items.Add($paletteMenu)
$sizeMenu = New-Object Windows.Controls.MenuItem
$sizeMenu.Header = '大小'
$sizeItem = New-Object Windows.Controls.MenuItem
$sizeItem.StaysOpenOnClick = $true
$sizePanel = New-Object Windows.Controls.StackPanel
$sizePanel.Width = 190
$sizePanel.Margin = New-Object Windows.Thickness(9,6,9,6)
$script:SizeLabel = New-Object Windows.Controls.TextBlock
$script:SizeLabel.Text = ('大小 {0:0}%' -f ($script:Scale * 100))
$script:SizeLabel.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, [Windows.SystemColors]::MenuTextBrushKey)
$script:SizeLabel.Margin = New-Object Windows.Thickness(0,0,0,6)
[void]$sizePanel.Children.Add($script:SizeLabel)
$script:SizeSlider = New-Object Windows.Controls.Slider
$script:SizeSlider.Minimum = 50
$script:SizeSlider.Maximum = 150
$script:SizeSlider.Value = $script:Scale * 100
$script:SizeSlider.SmallChange = 1
$script:SizeSlider.LargeChange = 10
$script:SizeSlider.IsSnapToTickEnabled = $false
$script:SizeSlider.IsMoveToPointEnabled = $true
$script:SizeSlider.Width = 180
[void]$sizePanel.Children.Add($script:SizeSlider)
$sizeEnds = New-Object Windows.Controls.DockPanel
$sizeEnds.LastChildFill = $false
$sizeEnds.Margin = New-Object Windows.Thickness(0,3,0,0)
$minLabel = New-Object Windows.Controls.TextBlock
$minLabel.Text = '50%'
$minLabel.FontSize = 10
$minLabel.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, [Windows.SystemColors]::MenuTextBrushKey)
[Windows.Controls.DockPanel]::SetDock($minLabel, [Windows.Controls.Dock]::Left)
[void]$sizeEnds.Children.Add($minLabel)
$maxLabel = New-Object Windows.Controls.TextBlock
$maxLabel.Text = '150%'
$maxLabel.FontSize = 10
$maxLabel.SetResourceReference([Windows.Controls.TextBlock]::ForegroundProperty, [Windows.SystemColors]::MenuTextBrushKey)
[Windows.Controls.DockPanel]::SetDock($maxLabel, [Windows.Controls.Dock]::Right)
[void]$sizeEnds.Children.Add($maxLabel)
[void]$sizePanel.Children.Add($sizeEnds)
$sizeItem.Header = $sizePanel
[void]$sizeMenu.Items.Add($sizeItem)
$script:SizeSlider.Add_ValueChanged({
  param($sender, $args)
  if ([Math]::Abs($sender.Value / 100 - $script:Scale) -lt 0.0001) { return }
  $script:ResizingFromSlider = $true
  try { Set-SkinScale $script:Skin ($sender.Value / 100) $false }
  finally { $script:ResizingFromSlider = $false }
  $script:SizeLabel.Text = ('大小 {0:0}%' -f $sender.Value)
  $script:SizeDirty = $true
})
$script:SizeSlider.Add_PreviewMouseLeftButtonUp({
  if ($script:SizeDirty) { Save-Settings; $script:SizeDirty = $false }
})
$sizeMenu.Add_SubmenuClosed({
  if ($script:SizeDirty) { Save-Settings; $script:SizeDirty = $false }
})
[void]$menu.Items.Add($sizeMenu)
$menu.Add_Closed({
  if ($script:SizeDirty) { Save-Settings; $script:SizeDirty = $false }
})
$pinItem = New-Object Windows.Controls.MenuItem
$pinItem.Header = '取消置顶'
$pinItem.Add_Click({
  $script:Mini.Topmost = -not $script:Mini.Topmost
  $script:Detail.Topmost = $script:Mini.Topmost
  $pinItem.Header = if ($script:Mini.Topmost) { '取消置顶' } else { '置顶' }
})
[void]$menu.Items.Add($pinItem)
$closeItem = New-Object Windows.Controls.MenuItem
$closeItem.Header = '退出'
$closeItem.Add_Click({ $script:Mini.Close() })
[void]$menu.Items.Add($closeItem)
$script:Mini.ContextMenu = $menu
Set-SkinScale $script:Skin $script:Scale $false
Apply-Palette $script:PaletteId $false
if ($script:NeedsSettingsMigration -and -not $PreviewPath) { Save-Settings }

if (-not $PreviewPath -and $env:CODEX_WIDGET_SELFTEST -ne '1') {
  try {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $script:TrayImage = if (Test-Path -LiteralPath $script:IconPath) {
      [Drawing.Icon]::new($script:IconPath)
    } else { [Drawing.SystemIcons]::Application }
    $script:TrayMenu = New-Object System.Windows.Forms.ContextMenuStrip
    $trayOpen = $script:TrayMenu.Items.Add('显示小组件')
    $trayOpen.Add_Click({ [void]$script:Mini.Dispatcher.BeginInvoke([Action]{ [void]$script:Mini.Activate() }) })
    $trayRefresh = $script:TrayMenu.Items.Add('刷新额度')
    $trayRefresh.Add_Click({ [void]$script:Mini.Dispatcher.BeginInvoke([Action]{ Refresh-Data }) })
    $trayExit = $script:TrayMenu.Items.Add('退出')
    $trayExit.Add_Click({ [void]$script:Mini.Dispatcher.BeginInvoke([Action]{ $script:Mini.Close() }) })
    $script:TrayIcon = New-Object System.Windows.Forms.NotifyIcon
    $script:TrayIcon.Icon = $script:TrayImage
    $script:TrayIcon.Text = 'Codex 额度'
    $script:TrayIcon.ContextMenuStrip = $script:TrayMenu
    $script:TrayIcon.Add_DoubleClick({ [void]$script:Mini.Dispatcher.BeginInvoke([Action]{ [void]$script:Mini.Activate() }) })
    $script:TrayIcon.Visible = $true
  } catch {
    if ($script:TrayIcon) { $script:TrayIcon.Dispose(); $script:TrayIcon = $null }
    if ($script:TrayMenu) { $script:TrayMenu.Dispose(); $script:TrayMenu = $null }
  }
}

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(60)
$timer.Add_Tick({
  if ($script:Skin -eq 'taskbar') { Place-TaskbarStrip }
  Refresh-Data
})
$timer.Start()
$script:ReadPollTimer = New-Object Windows.Threading.DispatcherTimer
$script:ReadPollTimer.Interval = [TimeSpan]::FromMilliseconds(120)
$script:ReadPollTimer.Add_Tick({ Complete-Read })
$script:Mini.Add_Loaded({
  $area = [Windows.SystemParameters]::WorkArea
  $script:Mini.Left = $area.Right - $script:Mini.Width - 12
  $script:Mini.Top = $area.Bottom - $script:Mini.Height - 12
  if ($script:Skin -eq 'taskbar') { Place-TaskbarStrip }
  if (-not $PreviewPath) {
    [void]$script:Mini.Dispatcher.BeginInvoke([Action]{ Refresh-Data }, [Windows.Threading.DispatcherPriority]::ApplicationIdle)
  }
})
$script:Mini.Add_Closed({
  $timer.Stop()
  $script:ReadPollTimer.Stop()
  if ($script:ReadProcess) {
    try { if (-not $script:ReadProcess.HasExited) { $script:ReadProcess.Kill() } } catch { }
    $script:ReadProcess.Dispose()
    $script:ReadProcess = $null
  }
  if ($script:TrayIcon) { $script:TrayIcon.Visible = $false; $script:TrayIcon.Dispose() }
  if ($script:TrayMenu) { $script:TrayMenu.Dispose() }
  if ($script:TrayImage -and $script:TrayImage -ne [Drawing.SystemIcons]::Application) { $script:TrayImage.Dispose() }
  if ($script:Detail.IsVisible) { $script:Detail.Close() }
  $script:WidgetMutex.ReleaseMutex()
  $script:WidgetMutex.Dispose()
})

if ($env:CODEX_WIDGET_SELFTEST -eq '1') {
  $startWatch = [Diagnostics.Stopwatch]::StartNew()
  Refresh-Data
  $startWatch.Stop()
  while ($script:ReadProcess) {
    Start-Sleep -Milliseconds 100
    Complete-Read
  }
  Write-Output ('startMs={0}; primary={1}; secondary={2}; tasks={3}; status={4}' -f
    $startWatch.ElapsedMilliseconds,
    $script:ShortQuota.remainingPercent,
    $script:WeekQuota.remainingPercent,
    @($script:CurrentTasks).Count,
    $script:DetailStatus.Text)
  $script:WidgetMutex.ReleaseMutex()
  $script:WidgetMutex.Dispose()
  exit
}

if ($PreviewPath) {
  $script:Mini.Show()
  try { Apply-Data (Read-Data) } catch { Show-ReadError $_.Exception.Message }
  if ($env:CODEX_WIDGET_PREVIEW_SLIDER) { $script:SizeSlider.Value = [double]$env:CODEX_WIDGET_PREVIEW_SLIDER }
  if ($env:CODEX_WIDGET_PREVIEW_SWITCH_PALETTE) { Apply-Palette $env:CODEX_WIDGET_PREVIEW_SWITCH_PALETTE $false }
  if ($env:CODEX_WIDGET_PREVIEW_MODE -eq 'reset') {
    $script:TrackMode = 'reset'
    Update-TrackText
  }
  $script:Mini.UpdateLayout()
  $bitmap = New-Object Windows.Media.Imaging.RenderTargetBitmap ([int][Math]::Ceiling($script:Mini.Width)),([int][Math]::Ceiling($script:Mini.Height)),96,96,([Windows.Media.PixelFormats]::Pbgra32)
  $bitmap.Render($script:Mini)
  $encoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
  $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
  $stream = [IO.File]::Create($PreviewPath)
  try { $encoder.Save($stream) } finally { $stream.Dispose() }
  if ($env:CODEX_WIDGET_LIVEPREVIEW -ne '1') {
    Show-Details
    $script:Detail.UpdateLayout()
    $detailBitmap = New-Object Windows.Media.Imaging.RenderTargetBitmap ([int][Math]::Ceiling($script:Detail.Width)),([int][Math]::Ceiling($script:Detail.Height)),96,96,([Windows.Media.PixelFormats]::Pbgra32)
    $detailBitmap.Render($script:Detail)
    $detailEncoder = New-Object Windows.Media.Imaging.PngBitmapEncoder
    $detailEncoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($detailBitmap))
    $detailPreviewPath = [IO.Path]::Combine([IO.Path]::GetDirectoryName($PreviewPath),
      ([IO.Path]::GetFileNameWithoutExtension($PreviewPath) + '-details.png'))
    $detailStream = [IO.File]::Create($detailPreviewPath)
    try { $detailEncoder.Save($detailStream) } finally { $detailStream.Dispose() }
  }
  $script:Mini.Close()
} else {
  [void]$script:Mini.ShowDialog()
}
