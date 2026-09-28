param([string]$PreviewPath)

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

$script:AppDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$script:DataScript = Join-Path $script:AppDirectory 'data.js'
$script:IconPath = Join-Path $script:AppDirectory 'CodexQuotaWidget.ico'
$script:SettingsPath = Join-Path $script:AppDirectory 'settings.json'
$script:QuotaCachePath = Join-Path $script:AppDirectory 'quota-cache.json'
$script:NoticeLogPath = Join-Path (Join-Path $env:LOCALAPPDATA 'CodexQuotaWidget') 'notice-events.jsonl'
$script:Skin = 'ring'
$script:Scale = 1.0
$script:TrackMode = 'remaining'
$script:PaletteId = 'cloud'
$script:NoticeEnabled = $true
$script:FiveHourThreshold = 20
$script:WeekThreshold = 10
$script:ResetSoonMinutes = 15
$script:NoticeKeys = @{}
$script:NoticeStateDirty = $false
$script:LastNoticeStateSaveAt = 0L
$script:QuotaStatus = '额度读取中'
$script:TaskStatus = '任务未读取'
$script:TasksLastCheckedAt = 0
$script:LastGoodQuota = $null
$script:LastGoodCheckedAt = 0
$script:FashionPaletteOrder = @('runway','cocoa','oxygen','cloud','rouge','terracotta','poseidon','foxglove','fuchsia')
$script:PaletteOrder = @('sea','dusk','moss','ink','midnight','mono','cream','frost','clay')
$script:Palettes = @{
  runway = @{ Name='钴蓝番茄'; Surface='#F4F0E9'; Border='#AEB0B7'; Track='#CFCDD0'; Outer='#3050C2'; Inner='#BC462F'; Text='#292B31'; OuterText='#263D99'; InnerText='#963B2D'; Card='#E7E4E2'; Muted='#54545B'; Button='#DAD7D7'; Metric='#334BA4' }
  cocoa = @{ Name='葡萄可可'; Surface='#251B22'; Border='#684D5D'; Track='#4D3A49'; Outer='#C797D0'; Inner='#F3AF8D'; Text='#F8EEF1'; OuterText='#F4DFF7'; InnerText='#FBD8C5'; Card='#352630'; Muted='#D1BCCB'; Button='#493340'; Metric='#DDB1E3' }
  oxygen = @{ Name='青柠夜幕'; Surface='#171E17'; Border='#4F5B42'; Track='#3A4934'; Outer='#D4E66C'; Inner='#80D1AE'; Text='#F5F8E9'; OuterText='#F4F8CE'; InnerText='#D5F4E4'; Card='#293528'; Muted='#C5D1BA'; Button='#374633'; Metric='#D6E685' }
  cloud = @{ Name='云白鼠尾草'; Surface='#F6F5F0'; Border='#B8BAB3'; Track='#DBDED6'; Outer='#4F7866'; Inner='#745B95'; Text='#302F36'; OuterText='#355846'; InnerText='#5D4878'; Card='#EBEBE6'; Muted='#5B5E59'; Button='#DDE0D9'; Metric='#416A56' }
  rouge = @{ Name='酒红杏粉'; Surface='#261A20'; Border='#684455'; Track='#4C3440'; Outer='#E8757C'; Inner='#EDB0C1'; Text='#FCF0F3'; OuterText='#FFE0E6'; InnerText='#F2D8E6'; Card='#3A2530'; Muted='#D8BEC9'; Button='#543442'; Metric='#F3A5B6' }
  terracotta = @{ Name='赤陶海绿'; Surface='#F6F0E8'; Border='#BEB5A9'; Track='#DED6CC'; Outer='#287A72'; Inner='#B45538'; Text='#302D2B'; OuterText='#205C56'; InnerText='#873E2A'; Card='#EAE2D8'; Muted='#5F5951'; Button='#DDD1C4'; Metric='#24645D' }
  poseidon = @{ Name='金黄深海'; Surface='#151F32'; Border='#4A617B'; Track='#354963'; Outer='#F3CB69'; Inner='#85B7ED'; Text='#F7F4EC'; OuterText='#FCE6AE'; InnerText='#DBEAF9'; Card='#23324A'; Muted='#BDC9D8'; Button='#30435F'; Metric='#F7D784' }
  foxglove = @{ Name='雾粉橄榄'; Surface='#F3EDE8'; Border='#BDB4A9'; Track='#DDD2CA'; Outer='#667443'; Inner='#A75B72'; Text='#302D31'; OuterText='#4F5D31'; InnerText='#843D55'; Card='#E7DCD6'; Muted='#60585A'; Button='#D9C9C3'; Metric='#586941' }
  fuchsia = @{ Name='霓虹洋红'; Surface='#171821'; Border='#514A64'; Track='#40384F'; Outer='#EF65B4'; Inner='#74C7DF'; Text='#F8F1F8'; OuterText='#FFDCEF'; InnerText='#DBF1F7'; Card='#292531'; Muted='#CBC0CE'; Button='#393248'; Metric='#F4A0CE' }
  sea = @{ Name='深海青'; Surface='#141C24'; Border='#40515F'; Track='#34424D'; Outer='#68D1BE'; Inner='#9EB6F0'; Text='#EDF4F6'; OuterText='#F4FAFB'; InnerText='#D9E7F2'; Card='#20303A'; Muted='#B4C5CF'; Button='#2C3C47'; Metric='#83D8C8' }
  dusk = @{ Name='暮紫灰'; Surface='#211F2A'; Border='#514D62'; Track='#413D50'; Outer='#C4B0E9'; Inner='#E2B9B1'; Text='#F5F1F7'; OuterText='#F5ECFF'; InnerText='#F7DDD8'; Card='#302B3A'; Muted='#CEC2D4'; Button='#3E374A'; Metric='#D2BCEF' }
  moss = @{ Name='松烟绿'; Surface='#17211D'; Border='#47584F'; Track='#37483D'; Outer='#B9CF9A'; Inner='#83C7BA'; Text='#F1F5EE'; OuterText='#F4F9E9'; InnerText='#D2EEE6'; Card='#26322B'; Muted='#BCCBBE'; Button='#34453A'; Metric='#C5D9A9' }
  ink = @{ Name='石墨蓝'; Surface='#171A20'; Border='#505865'; Track='#39414D'; Outer='#AFC7EC'; Inner='#B0C6D2'; Text='#F3F5F7'; OuterText='#E8F0FC'; InnerText='#DBEBF2'; Card='#242B35'; Muted='#BAC4CE'; Button='#313C4A'; Metric='#BED4F1' }
  midnight = @{ Name='午夜蓝'; Surface='#0E1730'; Border='#34517A'; Track='#294366'; Outer='#73BCFF'; Inner='#A58BDB'; Text='#F1F5FF'; OuterText='#DDF0FF'; InnerText='#E7DCFF'; Card='#17294A'; Muted='#BACAE6'; Button='#244166'; Metric='#8ACBFF' }
  mono = @{ Name='黑曜石'; Surface='#121416'; Border='#4B5056'; Track='#33383D'; Outer='#DEE4E8'; Inner='#8898A3'; Text='#F3F5F6'; OuterText='#F5F7F8'; InnerText='#C8D3D9'; Card='#20252A'; Muted='#ACB7BE'; Button='#2D343A'; Metric='#E4EBED' }
  cream = @{ Name='奶油砂岩'; Surface='#F5F1E9'; Border='#B9AEA2'; Track='#D7CDC1'; Outer='#795B35'; Inner='#356D70'; Text='#302F2D'; OuterText='#49351F'; InnerText='#27575A'; Card='#E9E2D8'; Muted='#625A52'; Button='#DCD0C1'; Metric='#6C5434' }
  frost = @{ Name='冰川白'; Surface='#EFF5F6'; Border='#A5BEC3'; Track='#CADCE0'; Outer='#177381'; Inner='#405D9B'; Text='#1B303A'; OuterText='#164E59'; InnerText='#334D83'; Card='#E1EBEE'; Muted='#4A626B'; Button='#D2E3E7'; Metric='#205E69' }
  clay = @{ Name='陶土白'; Surface='#F5EFE8'; Border='#C9B7A8'; Track='#E2D4C8'; Outer='#9D543C'; Inner='#796247'; Text='#382E2A'; OuterText='#78412F'; InnerText='#5E4C37'; Card='#ECE0D6'; Muted='#66594F'; Button='#E1CFC2'; Metric='#814632' }
}
$script:NeedsSettingsMigration = $false
if (Test-Path -LiteralPath $script:SettingsPath) {
  try {
    $saved = Get-Content -LiteralPath $script:SettingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($saved.skin -in @('ring','track')) { $script:Skin = [string]$saved.skin }
    if ($saved.palette -and $script:Palettes.ContainsKey([string]$saved.palette)) { $script:PaletteId = [string]$saved.palette }
    if ($saved.PSObject.Properties.Name -contains 'noticeEnabled') { $script:NoticeEnabled = [bool]$saved.noticeEnabled }
    if ($saved.fiveHourThreshold -in @(0,5,10,15,20,25,30,50)) { $script:FiveHourThreshold = [int]$saved.fiveHourThreshold }
    if ($saved.weekThreshold -in @(0,5,10,15,20,25,30,50)) { $script:WeekThreshold = [int]$saved.weekThreshold }
    if ($saved.resetSoonMinutes -in @(0,5,10,15,30,60)) { $script:ResetSoonMinutes = [int]$saved.resetSoonMinutes }
    if ($saved.noticeKeys) {
      foreach ($property in $saved.noticeKeys.PSObject.Properties) {
        if ($property.Name -in @('fiveLow','weekLow','fiveReset','weekReset')) {
          $script:NoticeKeys[$property.Name] = [string]$property.Value
        }
      }
    }
    if ([double]$saved.version -ge 2 -and [double]$saved.scale -ge 0.5 -and [double]$saved.scale -le 1.5) {
      $script:Scale = [double]$saved.scale
    } elseif ([double]$saved.scale -in @(0.75,1.0,1.25,1.5)) {
      $script:Scale = [Math]::Min(1.5, [double]$saved.scale + 0.25)
      $script:NeedsSettingsMigration = $true
    }
  } catch { }
}
if ($PreviewPath) {
  if ($env:CODEX_WIDGET_PREVIEW_SKIN -in @('ring','track')) { $script:Skin = $env:CODEX_WIDGET_PREVIEW_SKIN }
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
        <Border x:Name="RingStale" Width="13" Height="13" CornerRadius="6.5" Background="#F2AF58"
                HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,10,10,0" Visibility="Collapsed">
          <TextBlock Text="!" Foreground="#35240E" FontSize="9" FontWeight="Bold" TextAlignment="Center"/>
        </Border>
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
        <Border x:Name="TrackStale" Width="9" Height="9" CornerRadius="4.5" Background="#F2AF58"
                HorizontalAlignment="Right" VerticalAlignment="Top" Margin="0,7,8,0" Visibility="Collapsed">
          <TextBlock Text="!" Foreground="#35240E" FontSize="7" FontWeight="Bold" TextAlignment="Center"/>
        </Border>
      </Grid>
    </Viewbox>
  </Grid>
</Window>
'@

[xml]$detailXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Codex 本机任务 Token" Width="290" Height="360"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ResizeMode="NoResize" Topmost="True" ShowInTaskbar="False"
        WindowStartupLocation="Manual" FontFamily="Microsoft YaHei UI">
  <Viewbox Stretch="Fill">
  <Border x:Name="DetailSurface" Width="290" Height="360" Background="#202631" BorderBrush="#465063" BorderThickness="1" CornerRadius="13" Padding="14">
    <Grid>
      <Grid.RowDefinitions><RowDefinition Height="35"/><RowDefinition Height="*"/><RowDefinition Height="29"/></Grid.RowDefinitions>
      <Grid Grid.Row="0">
        <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
        <TextBlock x:Name="DetailDrag" Text="任务 Token · 本机记录" Foreground="#F0F5F9" FontSize="14" FontWeight="SemiBold" Cursor="SizeAll"/>
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
foreach ($name in @('RingView','TrackView','RingSurface','RingOuterBase','RingInnerBase',
  'TrackSurface','TrackOuterBase','TrackInnerBase','OuterFull','OuterArc','InnerFull','InnerArc',
  'OuterText','InnerText','TrackOuterArc','TrackInnerArc','TrackLine1','TrackLine2','RingStale','TrackStale')) {
  Set-Variable -Scope Script -Name $name -Value $script:Mini.FindName($name)
}
foreach ($name in @('DetailSurface','DetailDrag','DetailRefresh','DetailClose','TaskList','DetailStatus')) {
  Set-Variable -Scope Script -Name $name -Value $script:Detail.FindName($name)
}

function Start-DataProcess([string]$mode = 'quota') {
  if (-not (Test-Path -LiteralPath $script:NodePath)) { throw '未找到 Node.js' }
  $start = New-Object System.Diagnostics.ProcessStartInfo
  $start.FileName = $script:NodePath
  $start.Arguments = '"' + $script:DataScript + '" ' + $mode
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
  $process = Start-DataProcess 'quota'
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
  } else {
    $script:TrackLine1.Text = ('5小时 {0}' -f (Quota-Percent $script:ShortQuota))
    $script:TrackLine2.Text = ('一周 {0}' -f (Quota-Percent $script:WeekQuota))
  }
}

function Save-Settings {
  @{ version = 2; skin = $script:Skin; scale = $script:Scale; palette = $script:PaletteId;
     noticeEnabled = $script:NoticeEnabled; fiveHourThreshold = $script:FiveHourThreshold;
     weekThreshold = $script:WeekThreshold; resetSoonMinutes = $script:ResetSoonMinutes;
     noticeKeys = $script:NoticeKeys } | ConvertTo-Json -Compress |
    Set-Content -LiteralPath $script:SettingsPath -Encoding UTF8
}

function Load-QuotaCache {
  if (-not (Test-Path -LiteralPath $script:QuotaCachePath)) { return }
  try {
    $saved = Get-Content -LiteralPath $script:QuotaCachePath -Raw -Encoding UTF8 | ConvertFrom-Json
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    if ([long]$saved.checkedAt -le 0 -or [long]$saved.checkedAt -gt ($now + 60000) -or
        -not $saved.quota) { return }
    $script:LastGoodQuota = $saved.quota
    $script:LastGoodCheckedAt = [long]$saved.checkedAt
  } catch { }
}

function Save-QuotaCache {
  if ($PreviewPath -or $env:CODEX_WIDGET_SELFTEST -eq '1') { return }
  try {
    @{ checkedAt = $script:LastGoodCheckedAt; quota = @{
        primary = $script:LastGoodQuota.primary; secondary = $script:LastGoodQuota.secondary
      } } | ConvertTo-Json -Depth 6 -Compress |
      Set-Content -LiteralPath $script:QuotaCachePath -Encoding UTF8
  } catch { }
}

function Get-CachedWindow($window) {
  if (-not $window) { return $null }
  try {
    if ($null -eq $window.remainingPercent -or $null -eq $window.resetsAt) { return $null }
    $percent = [double]$window.remainingPercent
    $resetAt = [long]$window.resetsAt
    if ([double]::IsNaN($percent) -or $percent -lt 0 -or $percent -gt 100 -or
        $resetAt -le [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) { return $null }
    return $window
  } catch { return $null }
}

function Update-DetailStatus {
  $script:DetailStatus.Text = $script:QuotaStatus + ' · ' + $script:TaskStatus
}

function Test-ExistingNoticeWindow([string]$noticeId, [long]$resetAt, [double]$durationMinutes) {
  if (-not $script:NoticeKeys.ContainsKey($noticeId)) { return $false }
  $previousResetAt = 0L
  try { $previousResetAt = [long]$script:NoticeKeys[$noticeId] } catch { return $false }
  if ($previousResetAt -le 0) { return $false }
  $halfWindowSeconds = [long]([Math]::Max(60, $durationMinutes) * 30)
  if ([Math]::Abs($resetAt - $previousResetAt) -ge $halfWindowSeconds) { return $false }
  if ($resetAt -ne $previousResetAt) {
    $script:NoticeKeys[$noticeId] = [string]$resetAt
    $script:NoticeStateDirty = $true
  }
  return $true
}

function Save-NoticeState([long]$now) {
  try {
    Save-Settings
    $script:NoticeStateDirty = $false
    $script:LastNoticeStateSaveAt = $now
  } catch { }
}

function Write-NoticeEvent([string]$eventName, [string]$noticeId,
    [double]$percent, [long]$resetAt, [string]$reason) {
  if ($PreviewPath -or $env:CODEX_WIDGET_SELFTEST -eq '1') { return }
  try {
    $directory = Split-Path -Parent $script:NoticeLogPath
    [IO.Directory]::CreateDirectory($directory) | Out-Null
    if ([IO.File]::Exists($script:NoticeLogPath) -and
        ([IO.FileInfo]::new($script:NoticeLogPath)).Length -ge 65536) {
      Move-Item -LiteralPath $script:NoticeLogPath -Destination ($script:NoticeLogPath + '.old') -Force
    }
    $line = @{ utc = [DateTimeOffset]::UtcNow.ToString('O'); event = $eventName;
      notice = $noticeId; remainingPercent = [Math]::Round($percent, 1);
      resetsAt = $resetAt; reason = $reason } | ConvertTo-Json -Compress
    [IO.File]::AppendAllText($script:NoticeLogPath, $line + "`n", [Text.UTF8Encoding]::new($false))
  } catch { }
}

function Show-QuotaNotices($data) {
  if ($PreviewPath -or $env:CODEX_WIDGET_SELFTEST -eq '1' -or
      -not $script:NoticeEnabled -or -not $script:TrayIcon -or $data.quota.error) { return }
  $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $lines = New-Object System.Collections.Generic.List[string]
  $pending = @{}
  $events = New-Object System.Collections.Generic.List[object]
  $rearmed = $false
  foreach ($window in @(
      @{ quota = $data.quota.primary; name = '5 小时额度'; lowId = 'fiveLow'; resetId = 'fiveReset'; threshold = $script:FiveHourThreshold; duration = 300 },
      @{ quota = $data.quota.secondary; name = '一周额度'; lowId = 'weekLow'; resetId = 'weekReset'; threshold = $script:WeekThreshold; duration = 10080 }
    )) {
    $quota = $window.quota
    if ($null -eq $quota -or $null -eq $quota.remainingPercent -or $null -eq $quota.resetsAt) { continue }
    try {
      $percent = [double]$quota.remainingPercent
      $resetAt = [long]$quota.resetsAt
    } catch { continue }
    if ([double]::IsNaN($percent) -or $percent -lt 0 -or $percent -gt 100 -or $resetAt -le $now) { continue }
    if ($percent -ge 80) {
      foreach ($noticeId in @($window.lowId, $window.resetId)) {
        if ($script:NoticeKeys.ContainsKey($noticeId)) {
          $script:NoticeKeys.Remove($noticeId)
          $script:NoticeStateDirty = $true
          $rearmed = $true
          Write-NoticeEvent 'rearmed' $noticeId $percent $resetAt 'quota-recovered'
        }
      }
    }
    $duration = [double]$window.duration
    try {
      if ([double]$quota.windowDurationMins -ge 60 -and
          [double]$quota.windowDurationMins -le 10080) {
        $duration = [double]$quota.windowDurationMins
      }
    } catch { }
    $sameLowWindow = Test-ExistingNoticeWindow $window.lowId $resetAt $duration
    $sameResetWindow = Test-ExistingNoticeWindow $window.resetId $resetAt $duration
    if ($window.threshold -gt 0 -and $percent -le $window.threshold -and
        -not $sameLowWindow) {
      $reason = if ($script:NoticeKeys.ContainsKey($window.lowId)) { 'new-window' } else { 'first-or-rearmed' }
      $lines.Add(('{0}仅剩 {1:0}%（阈值 {2}%）' -f $window.name, $percent, $window.threshold))
      $pending[$window.lowId] = [string]$resetAt
      $events.Add(@{ id = $window.lowId; percent = $percent; resetAt = $resetAt; reason = $reason })
    }
    if ($script:ResetSoonMinutes -gt 0 -and ($resetAt - $now) -le ($script:ResetSoonMinutes * 60) -and
        -not $sameResetWindow) {
      $reason = if ($script:NoticeKeys.ContainsKey($window.resetId)) { 'new-window' } else { 'first-or-rearmed' }
      $lines.Add(('{0}将于 {1} 恢复' -f $window.name, (Reset-Text $resetAt)))
      $pending[$window.resetId] = [string]$resetAt
      $events.Add(@{ id = $window.resetId; percent = $percent; resetAt = $resetAt; reason = $reason })
    }
  }
  if ($lines.Count -eq 0) {
    if ($script:NoticeStateDirty -and
        ($rearmed -or ($now - $script:LastNoticeStateSaveAt) -ge 900)) {
      Save-NoticeState $now
    }
    return
  }
  foreach ($key in $pending.Keys) { $script:NoticeKeys[$key] = $pending[$key] }
  Save-NoticeState $now
  $eventName = 'requested'
  try {
    $script:TrayIcon.ShowBalloonTip(10000, 'Codex 额度提醒', ($lines -join "`n"),
      [System.Windows.Forms.ToolTipIcon]::Info)
  } catch { $eventName = 'api-failed' }
  foreach ($entry in $events) {
    Write-NoticeEvent $eventName $entry.id $entry.percent $entry.resetAt $entry.reason
  }
}

function Color-Brush([string]$value) {
  return [Windows.Media.BrushConverter]::new().ConvertFromString($value)
}

function Set-SkinScale([string]$skin, [double]$scale, [bool]$save) {
  if ($skin -notin @('ring','track')) { return }
  $scale = [Math]::Max(0.5, [Math]::Min(1.5, $scale))
  $wasVisible = $script:Mini.IsVisible
  $oldLeft = $script:Mini.Left
  $oldTop = $script:Mini.Top
  $centerX = $script:Mini.Left + $script:Mini.Width / 2
  $centerY = $script:Mini.Top + $script:Mini.Height / 2
  $script:Skin = $skin; $script:Scale = $scale
  $script:RingView.Visibility = if ($skin -eq 'ring') { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
  $script:TrackView.Visibility = if ($skin -eq 'track') { [Windows.Visibility]::Visible } else { [Windows.Visibility]::Collapsed }
  $script:Mini.Width = $(if ($skin -eq 'ring') { 78 } else { 132 }) * $scale
  $script:Mini.Height = $(if ($skin -eq 'ring') { 78 } else { 64 }) * $scale
  if ($wasVisible) {
    $area = [Windows.SystemParameters]::WorkArea
    $newLeft = if ($script:ResizingFromSlider) { $oldLeft } else { $centerX - $script:Mini.Width / 2 }
    $newTop = if ($script:ResizingFromSlider) { $oldTop } else { $centerY - $script:Mini.Height / 2 }
    $script:Mini.Left = [Math]::Max($area.Left + 4, [Math]::Min($newLeft, $area.Right - $script:Mini.Width - 4))
    $script:Mini.Top = [Math]::Max($area.Top + 4, [Math]::Min($newTop, $area.Bottom - $script:Mini.Height - 4))
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
  if ($null -eq $script:CurrentTasks) {
    $hint = New-Object Windows.Controls.TextBlock
    $hint.Text = if ($script:TaskStatus -eq '任务读取失败') { '读取失败，点击右上角重试' } else { '正在读取本机任务…' }
    $hint.Foreground = Color-Brush $script:Palette.Muted
    [void]$script:TaskList.Children.Add($hint)
    $script:TasksDirty = $false
    return
  }
  foreach ($task in $script:CurrentTasks) { Add-Task $task }
  if (@($script:CurrentTasks).Count -eq 0) {
    $empty = New-Object Windows.Controls.TextBlock
    $empty.Text = '暂无本机 Token 记录'
    $empty.Foreground = Color-Brush $script:Palette.Muted
    [void]$script:TaskList.Children.Add($empty)
  }
  $script:TasksDirty = $false
}

function Apply-Tasks($data) {
  if ($data.error) { Show-TaskReadError ([string]$data.error); return }
  if ($null -eq $data.tasks) { Show-TaskReadError '任务数据格式异常'; return }
  $signature = ConvertTo-Json -InputObject $data.tasks -Depth 4 -Compress
  if ($signature -ne $script:TaskSignature) {
    $script:CurrentTasks = @($data.tasks)
    $script:TaskSignature = $signature
    $script:TasksDirty = $true
    if ($script:Detail.IsVisible) { Render-Tasks }
  }
  $script:TasksLastCheckedAt = [long]$data.checkedAt
  $script:TaskStatus = ('{0} 个本机任务' -f @($script:CurrentTasks).Count)
  Update-DetailStatus
}

function Show-TaskReadError([string]$message) {
  $script:TaskStatus = if ($null -eq $script:CurrentTasks) { '任务读取失败' } else { '任务旧数据' }
  $script:DetailStatus.ToolTip = '任务读取失败：' + $message
  Update-DetailStatus
  if ($null -eq $script:CurrentTasks -and $script:Detail.IsVisible) { Render-Tasks }
}

function Apply-Palette([string]$paletteId, [bool]$save) {
  if (-not $script:Palettes.ContainsKey($paletteId)) { return }
  $script:PaletteId = $paletteId
  $script:Palette = $script:Palettes[$paletteId]
  $script:RingSurface.Fill = Color-Brush $script:Palette.Surface
  $script:RingSurface.Stroke = Color-Brush $script:Palette.Border
  $script:TrackSurface.Fill = Color-Brush $script:Palette.Surface
  $script:TrackSurface.Stroke = Color-Brush $script:Palette.Border
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
  $script:InnerText.Foreground = Color-Brush $script:Palette.InnerText
  $script:TrackLine2.Foreground = Color-Brush $script:Palette.InnerText
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
    $errorText = [string]$data.quota.error
    $fresh = -not $errorText -and $data.quota.primary -and $data.quota.secondary
    if (-not $fresh -and -not $errorText) { $errorText = '额度数据不完整' }
    if ($fresh) {
      $short = $data.quota.primary
      $week = $data.quota.secondary
      $script:LastGoodQuota = $data.quota
      $script:LastGoodCheckedAt = if ($data.checkedAt) { [long]$data.checkedAt } else {
        [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
      }
      Save-QuotaCache
    } else {
      $short = Get-CachedWindow $script:LastGoodQuota.primary
      $week = Get-CachedWindow $script:LastGoodQuota.secondary
    }
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
    $tooltip = ("外环：5 小时剩余 {0}，{1} 重置`n内环：一周剩余 {2}，{3} 重置" -f
      $(if ($short) { '{0:0}%' -f [double]$short.remainingPercent } else { '未知' }),
      (Reset-Text $short.resetsAt),
      $(if ($week) { '{0:0}%' -f [double]$week.remainingPercent } else { '未知' }),
      (Reset-Text $week.resetsAt))
    $script:RingStale.Visibility = if ($fresh) { 'Collapsed' } else { 'Visible' }
    $script:TrackStale.Visibility = $script:RingStale.Visibility
    if ($fresh) {
      $script:QuotaStatus = ('额度 {0} 更新' -f [DateTime]::Now.ToString('HH:mm'))
      $script:DetailStatus.ToolTip = $null
    } else {
      $lastTime = if ($script:LastGoodCheckedAt -gt 0) {
        [DateTimeOffset]::FromUnixTimeMilliseconds($script:LastGoodCheckedAt).ToLocalTime().ToString('M/d HH:mm')
      } else { '未知' }
      $tooltip = ("{0}`n上次成功更新：{1}`n{2}" -f $errorText, $lastTime, $tooltip)
      $script:QuotaStatus = if ($short -or $week) { '旧额度 ' + $lastTime } else { '额度读取失败' }
      $script:DetailStatus.ToolTip = $tooltip
    }
    $script:Mini.ToolTip = $tooltip
    if ($script:TrayIcon) {
      $script:TrayIcon.Text = ('Codex 额度{0}  5小时 {1}  一周 {2}' -f
        $(if ($fresh) { '' } else { '（旧）' }), (Quota-Percent $short), (Quota-Percent $week))
    }
    if ($null -ne $data.PSObject.Properties['tasks']) { Apply-Tasks $data }
    Update-DetailStatus
    if ($fresh) { Show-QuotaNotices $data }
  } catch { $script:DetailStatus.Text = ('显示失败：{0}' -f $_.Exception.Message) }
}

function Show-ReadError([string]$message) {
  Apply-Data (@{ checkedAt = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds();
      quota = @{ primary = $null; secondary = $null; error = $message } })
}

function Refresh-Data {
  if ($script:ReadProcess) { return }
  $script:QuotaStatus = '额度读取中'
  Update-DetailStatus
  try {
    $script:ReadProcess = Start-DataProcess 'quota'
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

function Refresh-Tasks {
  if ($script:TaskReadProcess) { return }
  $script:TaskStatus = '任务读取中'
  Update-DetailStatus
  if ($null -eq $script:CurrentTasks -and $script:Detail.IsVisible) { Render-Tasks }
  try {
    $script:TaskReadProcess = Start-DataProcess 'tasks'
    $script:TaskReadOutput = $script:TaskReadProcess.StandardOutput.ReadToEndAsync()
    $script:TaskReadError = $script:TaskReadProcess.StandardError.ReadToEndAsync()
    $script:TaskReadStarted = [DateTime]::UtcNow
    $script:TaskReadPollTimer.Start()
  } catch {
    if ($script:TaskReadProcess) {
      try { if (-not $script:TaskReadProcess.HasExited) { $script:TaskReadProcess.Kill() } } catch { }
      $script:TaskReadProcess.Dispose()
      $script:TaskReadProcess = $null
    }
    Show-TaskReadError $_.Exception.Message
  }
}

function Complete-TaskRead {
  $process = $script:TaskReadProcess
  if (-not $process) { return }
  if (-not $process.HasExited -or -not $script:TaskReadOutput.IsCompleted -or -not $script:TaskReadError.IsCompleted) {
    if (([DateTime]::UtcNow - $script:TaskReadStarted).TotalSeconds -lt 30) { return }
    try { $process.Kill() } catch { }
    Show-TaskReadError '任务读取超时'
    $script:TaskReadPollTimer.Stop()
    $process.Dispose()
    $script:TaskReadProcess = $null
    $script:TaskReadOutput = $null
    $script:TaskReadError = $null
    return
  }
  try {
    $output = $script:TaskReadOutput.GetAwaiter().GetResult()
    if (-not $output) {
      $errorText = $script:TaskReadError.GetAwaiter().GetResult()
      if ($errorText) { throw $errorText.Trim() }
      throw '任务接口未返回内容'
    }
    try { $data = ConvertFrom-Json -InputObject $output -ErrorAction Stop }
    catch { throw '任务数据格式异常' }
    Apply-Tasks $data
  } catch { Show-TaskReadError $_.Exception.Message }
  finally {
    $script:TaskReadPollTimer.Stop()
    $process.Dispose()
    $script:TaskReadProcess = $null
    $script:TaskReadOutput = $null
    $script:TaskReadError = $null
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
  if (-not $PreviewPath -and ($script:TasksLastCheckedAt -le 0 -or
      ([DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds() - $script:TasksLastCheckedAt) -gt 300000)) {
    Refresh-Tasks
  }
}

function Show-MiniWindow {
  if (-not $script:Mini.IsVisible) { $script:Mini.Show() }
  [void]$script:Mini.Activate()
}

function Hide-MiniWindow {
  if ($script:Detail.IsVisible) { $script:Detail.Hide() }
  if ($script:Mini.IsVisible) { $script:Mini.Hide() }
}

function Is-CenterHit($position) {
  if ($script:Skin -eq 'ring') {
    $x = $position.X / ($script:Scale * 0.75)
    $y = $position.Y / ($script:Scale * 0.75)
    return (($x - 52) * ($x - 52) + ($y - 52) * ($y - 52)) -le (25 * 25)
  }
  $x = $position.X / $script:Scale
  $y = $position.Y / $script:Scale
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
})
$script:Mini.Add_PreviewMouseLeftButtonUp({
  if (-not $script:PointerDown -or $script:DragStarted) { return }
  $script:PointerDown = $false
  if (Is-CenterHit ($_.GetPosition($script:Mini))) {
    if ($script:Skin -eq 'track') {
      $script:TrackMode = if ($script:TrackMode -eq 'remaining') { 'reset' } else { 'remaining' }
      Update-TrackText
    } else { Show-Details }
  }
})
$script:Mini.Add_MouseLeave({ if ([Windows.Input.Mouse]::LeftButton -ne [Windows.Input.MouseButtonState]::Pressed) { $script:PointerDown = $false } })
$script:DetailDrag.Add_MouseLeftButtonDown({ $script:Detail.DragMove() })
$script:DetailClose.Add_Click({ $script:Detail.Hide() })
$script:DetailRefresh.Add_Click({ Refresh-Tasks })

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
foreach ($entry in @(@('ring','双圆环'),@('track','跑道'))) {
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
$script:PaletteMenuItems = @()
foreach ($group in @(
    @{ title = '时尚配色'; ids = $script:FashionPaletteOrder },
    @{ title = '简约配色'; ids = $script:PaletteOrder }
  )) {
  $groupMenu = New-Object Windows.Controls.MenuItem
  $groupMenu.Header = $group.title
  foreach ($paletteChoiceId in $group.ids) {
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
      foreach ($choice in $script:PaletteMenuItems) { $choice.IsChecked = [string]$choice.Tag -eq $script:PaletteId }
    })
    [void]$groupMenu.Items.Add($item)
    $script:PaletteMenuItems += $item
  }
  [void]$paletteMenu.Items.Add($groupMenu)
}
[void]$menu.Items.Add($paletteMenu)
$noticeMenu = New-Object Windows.Controls.MenuItem
$noticeMenu.Header = '额度提醒'
$noticeToggle = New-Object Windows.Controls.MenuItem
$noticeToggle.Header = '启用系统通知'
$noticeToggle.IsCheckable = $true
$noticeToggle.IsChecked = $script:NoticeEnabled
$noticeToggle.Add_Click({
  param($sender, $args)
  $script:NoticeEnabled = [bool]$sender.IsChecked
  Save-Settings
})
[void]$noticeMenu.Items.Add($noticeToggle)
foreach ($setting in @(
    @{ title = '5 小时剩余 ≤'; name = 'FiveHourThreshold'; values = @(0,5,10,15,20,25,30,50); suffix = '%' },
    @{ title = '一周剩余 ≤'; name = 'WeekThreshold'; values = @(0,5,10,15,20,25,30,50); suffix = '%' },
    @{ title = '恢复前提醒'; name = 'ResetSoonMinutes'; values = @(0,5,10,15,30,60); suffix = ' 分钟' }
  )) {
  $settingMenu = New-Object Windows.Controls.MenuItem
  $settingMenu.Header = $setting.title
  foreach ($value in $setting.values) {
    $choice = New-Object Windows.Controls.MenuItem
    $choice.Header = if ($value -eq 0) { '关闭' } else { '{0}{1}' -f $value, $setting.suffix }
    $choice.Tag = @{ name = $setting.name; value = [int]$value; menu = $settingMenu }
    $choice.IsCheckable = $true
    $choice.IsChecked = (Get-Variable -Scope Script -Name $setting.name -ValueOnly) -eq $value
    $choice.Add_Click({
      param($sender, $args)
      $selected = $sender.Tag
      Set-Variable -Scope Script -Name $selected.name -Value $selected.value
      foreach ($option in $selected.menu.Items) {
        $option.IsChecked = $option.Tag.value -eq $selected.value
      }
      Save-Settings
    })
    [void]$settingMenu.Items.Add($choice)
  }
  [void]$noticeMenu.Items.Add($settingMenu)
}
[void]$menu.Items.Add($noticeMenu)
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
if (-not $PreviewPath) { Load-QuotaCache }
Set-SkinScale $script:Skin $script:Scale $false
Apply-Palette $script:PaletteId $false
Update-DetailStatus
if ($script:NeedsSettingsMigration -and -not $PreviewPath) { Save-Settings }

if (-not $PreviewPath -and $env:CODEX_WIDGET_SELFTEST -ne '1') {
  try {
    Add-Type -AssemblyName System.Windows.Forms, System.Drawing
    $script:TrayImage = if (Test-Path -LiteralPath $script:IconPath) {
      [Drawing.Icon]::new($script:IconPath)
    } else { [Drawing.SystemIcons]::Application }
    $script:TrayMenu = New-Object System.Windows.Forms.ContextMenuStrip
    $trayOpen = $script:TrayMenu.Items.Add('显示小组件')
    $trayOpen.Add_Click({ [void]$script:Mini.Dispatcher.BeginInvoke([Action]{ Show-MiniWindow }) })
    $trayHide = $script:TrayMenu.Items.Add('隐藏小组件')
    $trayHide.Add_Click({ [void]$script:Mini.Dispatcher.BeginInvoke([Action]{ Hide-MiniWindow }) })
    $trayRefresh = $script:TrayMenu.Items.Add('刷新额度')
    $trayRefresh.Add_Click({ [void]$script:Mini.Dispatcher.BeginInvoke([Action]{ Refresh-Data }) })
    $trayExit = $script:TrayMenu.Items.Add('退出')
    $trayExit.Add_Click({ [void]$script:Mini.Dispatcher.BeginInvoke([Action]{ $script:Mini.Close() }) })
    $script:TrayIcon = New-Object System.Windows.Forms.NotifyIcon
    $script:TrayIcon.Icon = $script:TrayImage
    $script:TrayIcon.Text = 'Codex 额度'
    $script:TrayIcon.ContextMenuStrip = $script:TrayMenu
    $script:TrayIcon.Add_DoubleClick({ [void]$script:Mini.Dispatcher.BeginInvoke([Action]{ Show-MiniWindow }) })
    $script:TrayIcon.Visible = $true
  } catch {
    if ($script:TrayIcon) { $script:TrayIcon.Dispose(); $script:TrayIcon = $null }
    if ($script:TrayMenu) { $script:TrayMenu.Dispose(); $script:TrayMenu = $null }
  }
}

$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromSeconds(60)
$timer.Add_Tick({ Refresh-Data })
$timer.Start()
$script:ReadPollTimer = New-Object Windows.Threading.DispatcherTimer
$script:ReadPollTimer.Interval = [TimeSpan]::FromMilliseconds(120)
$script:ReadPollTimer.Add_Tick({ Complete-Read })
$script:TaskReadPollTimer = New-Object Windows.Threading.DispatcherTimer
$script:TaskReadPollTimer.Interval = [TimeSpan]::FromMilliseconds(120)
$script:TaskReadPollTimer.Add_Tick({ Complete-TaskRead })
$script:Mini.Add_Loaded({
  if ($script:MiniInitialized) { return }
  $script:MiniInitialized = $true
  $area = [Windows.SystemParameters]::WorkArea
  $script:Mini.Left = $area.Right - $script:Mini.Width - 12
  $script:Mini.Top = $area.Bottom - $script:Mini.Height - 12
  if (-not $PreviewPath) {
    if ($script:LastGoodQuota) { Show-ReadError '正在更新额度' }
    [void]$script:Mini.Dispatcher.BeginInvoke([Action]{ Refresh-Data }, [Windows.Threading.DispatcherPriority]::ApplicationIdle)
  }
})
$script:Mini.Add_Closed({
  $timer.Stop()
  $script:ReadPollTimer.Stop()
  $script:TaskReadPollTimer.Stop()
  if ($script:ReadProcess) {
    try { if (-not $script:ReadProcess.HasExited) { $script:ReadProcess.Kill() } } catch { }
    $script:ReadProcess.Dispose()
    $script:ReadProcess = $null
  }
  if ($script:TaskReadProcess) {
    try { if (-not $script:TaskReadProcess.HasExited) { $script:TaskReadProcess.Kill() } } catch { }
    $script:TaskReadProcess.Dispose()
    $script:TaskReadProcess = $null
  }
  if ($script:TrayIcon) { $script:TrayIcon.Visible = $false; $script:TrayIcon.Dispose() }
  if ($script:TrayMenu) { $script:TrayMenu.Dispose() }
  if ($script:TrayImage -and $script:TrayImage -ne [Drawing.SystemIcons]::Application) { $script:TrayImage.Dispose() }
  if ($script:Detail.IsVisible) { $script:Detail.Close() }
  $script:WidgetMutex.ReleaseMutex()
  $script:WidgetMutex.Dispose()
  if (-not $PreviewPath) { $script:Mini.Dispatcher.InvokeShutdown() }
})

if ($env:CODEX_WIDGET_SELFTEST -eq '1') {
  $startWatch = [Diagnostics.Stopwatch]::StartNew()
  Refresh-Data
  $startWatch.Stop()
  while ($script:ReadProcess) {
    Start-Sleep -Milliseconds 100
    Complete-Read
  }
  if ($env:CODEX_WIDGET_SELFTEST_TASKS -eq '1') {
    Refresh-Tasks
    while ($script:TaskReadProcess) {
      Start-Sleep -Milliseconds 100
      Complete-TaskRead
    }
  }
  Write-Output ('startMs={0}; primary={1}; secondary={2}; tasks={3}; status={4}' -f
    $startWatch.ElapsedMilliseconds,
    $script:ShortQuota.remainingPercent,
    $script:WeekQuota.remainingPercent,
    $(if ($env:CODEX_WIDGET_SELFTEST_TASKS -eq '1') { @($script:CurrentTasks).Count } else { 'deferred' }),
    $script:DetailStatus.Text)
  $script:WidgetMutex.ReleaseMutex()
  $script:WidgetMutex.Dispose()
  exit
}

if ($PreviewPath) {
  $script:Mini.Show()
  try { Apply-Data (Read-Data) } catch { Show-ReadError $_.Exception.Message }
  if ($env:CODEX_WIDGET_PREVIEW_STALE -eq '1') { Show-ReadError '模拟读取失败' }
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
  $script:Mini.Show()
  [Windows.Threading.Dispatcher]::Run()
}
