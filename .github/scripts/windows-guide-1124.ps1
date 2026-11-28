$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes,System.Drawing,System.Windows.Forms
Add-Type @'
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class GuideControl {
 public IntPtr Handle; public int Id; public string ClassName; public string Name;
 public bool Visible; public bool Enabled;
}
public static class GuideWindow {
 private delegate bool EnumProc(IntPtr h, IntPtr data);
 [DllImport("user32.dll")] private static extern bool EnumChildWindows(IntPtr h, EnumProc f, IntPtr data);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetWindowText(IntPtr h, StringBuilder text, int max);
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] private static extern int GetClassName(IntPtr h, StringBuilder text, int max);
 [DllImport("user32.dll")] private static extern int GetDlgCtrlID(IntPtr h);
 [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] private static extern bool IsWindowEnabled(IntPtr h);
 [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
 [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
 public static GuideControl[] Controls(IntPtr parent) {
  var items = new List<GuideControl>();
  EnumChildWindows(parent, delegate(IntPtr h, IntPtr ignored) {
   var text = new StringBuilder(2048); var cls = new StringBuilder(256);
   GetWindowText(h, text, text.Capacity); GetClassName(h, cls, cls.Capacity);
   items.Add(new GuideControl {Handle=h, Id=GetDlgCtrlID(h), ClassName=cls.ToString(), Name=text.ToString(), Visible=IsWindowVisible(h), Enabled=IsWindowEnabled(h)});
   return true;
  }, IntPtr.Zero);
  return items.ToArray();
 }
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
function Click-Native($control) {
  if (-not $control.Visible -or -not $control.Enabled -or $control.Handle -eq [IntPtr]::Zero) { throw 'Refusing to click an unavailable control' }
  Write-Host ("Native click hwnd={0} id={1} class={2} name={3}" -f $control.Handle,$control.Id,$control.ClassName,$control.Name)
  if (-not [GuideWindow]::PostMessage($control.Handle, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero)) { throw 'BM_CLICK failed to post' }
}
function Pixel-Count($bmp) {
  $colors = [System.Collections.Generic.HashSet[int]]::new()
  for ($y=0; $y -lt $bmp.Height; $y+=8) { for ($x=0; $x -lt $bmp.Width; $x+=8) { [void]$colors.Add($bmp.GetPixel($x,$y).ToArgb()) } }
  return $colors.Count
}
function Save-Window($window, [string]$name) {
  $hwnd = [IntPtr]$window.Current.NativeWindowHandle
  [uint32]$ownerPid = 0
  [void][GuideWindow]::GetWindowThreadProcessId($hwnd, [ref]$ownerPid)
  if ($hwnd -eq [IntPtr]::Zero -or $ownerPid -ne $window.Current.ProcessId -or -not $seen.ContainsKey([int]$ownerPid)) { throw 'Wizard window owner mismatch' }
  [void][GuideWindow]::ShowWindow($hwnd, 9)
  [void][GuideWindow]::SetForegroundWindow($hwnd)
  Start-Sleep -Milliseconds 800
  $r = $window.Current.BoundingRectangle
  if ($r.Width -lt 250 -or $r.Height -lt 150 -or $r.Width -gt 4096 -or $r.Height -gt 4096) { throw 'Invalid wizard window dimensions' }
  $bmp = [System.Drawing.Bitmap]::new([int]$r.Width,[int]$r.Height)
  $graphics = [System.Drawing.Graphics]::FromImage($bmp)
  try {
    $method = 'none'; $colors = 0
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    if ([GuideWindow]::GetForegroundWindow() -eq $hwnd -and $r.X -ge $screen.Left -and $r.Y -ge $screen.Top -and ($r.X+$r.Width) -le $screen.Right -and ($r.Y+$r.Height) -le $screen.Bottom) {
      $graphics.CopyFromScreen([int]$r.X,[int]$r.Y,0,0,$bmp.Size)
      $colors = Pixel-Count $bmp
      if ($colors -ge 12) { $method = 'foreground-screen' }
    }
    if ($method -eq 'none') {
      $graphics.Clear([System.Drawing.Color]::Black)
      $dc = $graphics.GetHdc()
      try { $printed = [GuideWindow]::PrintWindow($hwnd, $dc, 0) } finally { $graphics.ReleaseHdc($dc) }
      if (-not $printed) { throw 'PrintWindow failed for installer window' }
      $colors = Pixel-Count $bmp
      if ($colors -lt 12) { throw "Installer window capture has insufficient pixel variation: $colors" }
      $method = 'PrintWindow'
    }
    $bmp.Save((Join-Path $out $name),[System.Drawing.Imaging.ImageFormat]::Png)
    return @{ file=$name; width=$bmp.Width; height=$bmp.Height; sampled_colors=$colors; pid=[int]$ownerPid; title=$window.Current.Name; method=$method; hwnd=$hwnd.ToInt64() }
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
      $text = $names -join ' | '
      $title = $w.Current.Name
      $hwnd = [IntPtr]$w.Current.NativeWindowHandle
      $controls = @([GuideWindow]::Controls($hwnd))
      $nativeText = ($controls | ForEach-Object { $_.Name }) -join ' | '
      $signature = "$pidOfWindow|$title|$text|$nativeText"
      if ($signature -eq $lastSignature) { continue }
      Write-Host ("Window pid={0} hwnd={1} title={2} UIA={3}" -f $pidOfWindow,$hwnd,$title,$text)
      foreach ($c in $controls) { Write-Host ("  control hwnd={0} id={1} class={2} visible={3} enabled={4} name=[{5}]" -f $c.Handle,$c.Id,$c.ClassName,$c.Visible,$c.Enabled,$c.Name) }
      $clickable = @($controls | Where-Object { $_.Visible -and $_.Enabled -and $_.ClassName -match '(?i)button' })
      $button = $null
      if ($title -eq 'Select Setup Language') {
        if (($text + ' | ' + $nativeText) -notmatch '(?i)English') { throw 'English was not observed in the language dialog' }
        $idok = [GuideWindow]::GetDlgItem($hwnd, 1)
        $ok = @($controls | Where-Object { $_.Visible -and $_.Enabled -and (($_.Handle -eq $idok -and $idok -ne [IntPtr]::Zero) -or ($_.ClassName -match '(?i)button' -and $_.Name -match '^&?OK$')) })
        if ($ok.Count -eq 1) { $button = $ok[0] }
        elseif ($ok.Count -eq 0 -and $idok -eq [IntPtr]::Zero) {
          # Language dialog was identified and owned above; send only IDOK to it.
          Write-Host 'Language confirmation via WM_COMMAND IDOK'
          if (-not [GuideWindow]::PostMessage($hwnd, 0x0111, [IntPtr]1, [IntPtr]::Zero)) { throw 'IDOK post failed' }
          $lastSignature = $signature
        } else { throw 'Ambiguous language confirmation controls' }
      } elseif (($title -match '(?i)(setup|flclash)' -or ($text + $nativeText) -match 'FlClash') -and ($text + $nativeText) -match '(?i)install for (all users|me only|current user)') {
        $scope = @($clickable | Where-Object { ($_.Name -replace '&','') -match '(?i)install for (me only|current user)' })
        if ($scope.Count -ne 1) { throw 'Cannot identify the current-user install scope' }
        $button = $scope[0]
      } elseif ($title -match '(?i)FlClash') {
        $finish = @($clickable | Where-Object { ($_.Name -replace '&','') -match '^Finish\s*$' })
        if ($startSaved -and $finish.Count -eq 1 -and ($text + $nativeText) -match '(?i)(completing|completed|finished)' ) {
          $events.Add((Save-Window $w 'windows-install-finish.png'))
          $finishSaved = $true
          break
        }
        $accept = @($clickable | Where-Object { ($_.Name -replace '&','') -match '(?i)^I accept' })
        if ($accept.Count -eq 1) { Click-Native $accept[0] }
        $next = @($clickable | Where-Object { ($_.Name -replace '&','') -match '^(?:Next\s*>?|Install)(?:\.\.\.)?$' })
        if ($next.Count -eq 1) {
          if (-not $startSaved) { $events.Add((Save-Window $w 'windows-install-start.png')); $startSaved = $true }
          $button = $next[0]
        } elseif ($next.Count -gt 1) { throw 'Ambiguous next/install controls' }
      }
      if ($null -ne $button) { $lastSignature = $signature; Click-Native $button; Start-Sleep -Milliseconds 500 }
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
