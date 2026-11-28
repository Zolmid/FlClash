$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes,System.Drawing,System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class GuideWindow {
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
}
'@
$url = 'https://github.com/chen08209/FlClash/releases/download/v0.9.3/FlClash-0.9.3-windows-amd64-setup.exe'
$expected = '5754a11b5177fdddf9eee06b5059ed2bcbc467c7058d4ca25541d64b778bdc86'
$installer = Join-Path $env:RUNNER_TEMP 'FlClash-0.9.3-windows-amd64-setup.exe'
$out = Join-Path $env:RUNNER_TEMP 'windows-guide-output'
New-Item -ItemType Directory -Path $out -Force | Out-Null
Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
$actual = (Get-FileHash -Algorithm SHA256 -LiteralPath $installer).Hash.ToLowerInvariant()
if ($actual -ne $expected -or (Get-Item $installer).Length -ne 43277284) { throw 'Installer hash or size mismatch; refusing to execute.' }
$process = Start-Process -FilePath $installer -PassThru
# Pair each PID with its creation time, so a recycled PID cannot acquire ownership.
$seen = @{}
$seen[[int]$process.Id] = $process.StartTime.ToUniversalTime().ToString('yyyyMMddHHmmss.ffffff')
$root = [System.Windows.Automation.AutomationElement]::RootElement
$tree = [System.Windows.Automation.TreeScope]::Children
$all = [System.Windows.Automation.TreeScope]::Descendants
$condition = [System.Windows.Automation.Condition]::TrueCondition
$startSaved = $false
$finishSaved = $false
$lastSignature = ''
$deadline = (Get-Date).AddMinutes(7)
$events = [System.Collections.Generic.List[object]]::new()
function Invoke-Control($element) {
  $pattern = $null
  if ($element.TryGetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern, [ref]$pattern)) { $pattern.Invoke(); return }
  if ($element.TryGetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern, [ref]$pattern)) { $pattern.Select(); return }
  throw ('Cannot invoke expected control: ' + $element.Current.Name)
}
function Save-Window($window, [string]$name) {
  $hwnd = [IntPtr]$window.Current.NativeWindowHandle
  if ($hwnd -eq [IntPtr]::Zero) { throw 'Wizard has no window handle' }
  [uint32]$ownerPid = 0
  [void][GuideWindow]::GetWindowThreadProcessId($hwnd, [ref]$ownerPid)
  if ($ownerPid -ne $window.Current.ProcessId -or -not $seen.ContainsKey([int]$ownerPid)) { throw 'Wizard window owner mismatch' }
  [void][GuideWindow]::ShowWindow($hwnd, 9)
  [void][GuideWindow]::SetForegroundWindow($hwnd)
  Start-Sleep -Milliseconds 800
  if ([GuideWindow]::GetForegroundWindow() -ne $hwnd) { throw 'Wizard is not foreground; refusing obscured screenshot' }
  $r = $window.Current.BoundingRectangle
  $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
  if ($r.Width -lt 250 -or $r.Height -lt 150 -or $r.X -lt $screen.Left -or $r.Y -lt $screen.Top -or ($r.X + $r.Width) -gt $screen.Right -or ($r.Y + $r.Height) -gt $screen.Bottom) { throw 'Wizard window outside visible screen' }
  $bmp = [System.Drawing.Bitmap]::new([int]$r.Width,[int]$r.Height)
  $graphics = [System.Drawing.Graphics]::FromImage($bmp)
  try {
    $graphics.CopyFromScreen([int]$r.X,[int]$r.Y,0,0,$bmp.Size)
    $colors = [System.Collections.Generic.HashSet[int]]::new()
    for ($y = 0; $y -lt $bmp.Height; $y += 8) { for ($x = 0; $x -lt $bmp.Width; $x += 8) { [void]$colors.Add($bmp.GetPixel($x,$y).ToArgb()) } }
    if ($colors.Count -lt 12) { throw "Screenshot has insufficient pixel variation: $($colors.Count) colors" }
    $bmp.Save((Join-Path $out $name),[System.Drawing.Imaging.ImageFormat]::Png)
    return @{ file=$name; width=$bmp.Width; height=$bmp.Height; sampled_colors=$colors.Count; pid=[int]$ownerPid; title=$window.Current.Name }
  } finally { $graphics.Dispose(); $bmp.Dispose() }
}
try {
  while ((Get-Date) -lt $deadline -and -not $finishSaved) {
    $procs = @(Get-CimInstance Win32_Process)
    $live = @{}
    foreach ($p in $procs) { if ($p.CreationDate) { $live[[int]$p.ProcessId] = $p.CreationDate.ToUniversalTime().ToString('yyyyMMddHHmmss.ffffff') } }
    # Repeat to resolve descendants independent of process enumeration order.
    for ($i=0; $i -lt 4; $i++) {
      foreach ($p in $procs) {
        $parent=[int]$p.ParentProcessId; $id=[int]$p.ProcessId
        if ($seen.ContainsKey($parent) -and $live.ContainsKey($parent) -and $seen[$parent] -eq $live[$parent] -and $live.ContainsKey($id) -and -not $seen.ContainsKey($id)) { $seen[$id]=$live[$id] }
      }
    }
    foreach ($w in $root.FindAll($tree,$condition)) {
      $pidOfWindow = [int]$w.Current.ProcessId
      if (-not $seen.ContainsKey($pidOfWindow) -or -not $live.ContainsKey($pidOfWindow) -or $seen[$pidOfWindow] -ne $live[$pidOfWindow] -or $w.Current.IsOffscreen -or $w.Current.NativeWindowHandle -eq 0) { continue }
      $elements = $w.FindAll($all,$condition)
      $names = @($elements | ForEach-Object { $_.Current.Name } | Where-Object { $_ })
      $buttons = @($elements | Where-Object { $_.Current.ControlType -eq [System.Windows.Automation.ControlType]::Button -and $_.Current.IsEnabled -and -not $_.Current.IsOffscreen })
      $text = $names -join ' | '
      $title = $w.Current.Name
      $signature = "$pidOfWindow|$title|$text"
      if ($signature -eq $lastSignature) { continue }
      Write-Host ("Window pid={0} title={1} controls={2}" -f $pidOfWindow,$title,$text)
      $button = $null
      if ($title -eq 'Select Setup Language') {
        if ($names -notcontains 'English') { throw 'English was not selected in the language dialog' }
        $ok = @($buttons | Where-Object { $_.Current.Name -match '^&?OK$' })
        if ($ok.Count -ne 1) { throw 'Expected a single language confirmation button' }
        $button = $ok[0]
      } elseif (($title -match '(?i)(setup|flclash)' -or $text -match 'FlClash') -and $text -match '(?i)install for (all users|me only|current user)') {
        $scope = @($buttons | Where-Object { $_.Current.Name -match '(?i)install for (me only|current user)' })
        if ($scope.Count -ne 1) { throw 'Cannot identify the current-user install scope' }
        $button = $scope[0]
      } elseif ($title -match 'FlClash') {
        $finish = @($buttons | Where-Object { $_.Current.Name -match '^&?Finish\s*$' })
        if ($startSaved -and $finish.Count -eq 1 -and $text -match '(?i)(completing|completed|finished)' ) {
          $events.Add((Save-Window $w 'windows-install-finish.png'))
          $finishSaved = $true
          break
        }
        $accept = @($elements | Where-Object { $_.Current.ControlType -eq [System.Windows.Automation.ControlType]::RadioButton -and $_.Current.IsEnabled -and $_.Current.Name -match '(?i)^I &?accept' })
        if ($accept.Count -eq 1) { Invoke-Control $accept[0] }
        $next = @($buttons | Where-Object { $_.Current.Name -match '^(?:&?Next\s*>?|&?Install)(?:\.\.\.)?$' })
        if ($next.Count -eq 1) {
          if (-not $startSaved) { $events.Add((Save-Window $w 'windows-install-start.png')); $startSaved = $true }
          $button = $next[0]
        }
      }
      if ($null -ne $button) { $lastSignature = $signature; Write-Host ('Invoking: ' + $button.Current.Name); Invoke-Control $button; Start-Sleep -Milliseconds 500 }
    }
    Start-Sleep -Milliseconds 400
  }
  if (-not $startSaved -or -not $finishSaved) { throw 'Could not verify both start and completion windows; no artifact will be uploaded.' }
  @{ installer_url=$url; sha256=$actual; bytes=(Get-Item $installer).Length; started_pid=$process.Id; observed_pids=@($seen.Keys); screenshots=$events.ToArray(); start_verified=$startSaved; completion_verified=$finishSaved; commit=$env:GITHUB_SHA } | ConvertTo-Json -Depth 5 | Set-Content -Encoding UTF8 (Join-Path $out 'verification.json')
} finally {
  foreach ($id in @($seen.Keys)) {
    $p = Get-Process -Id $id -ErrorAction SilentlyContinue
    if ($p -and $p.StartTime.ToUniversalTime().ToString('yyyyMMddHHmmss.ffffff') -eq $seen[$id]) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
  }
}
