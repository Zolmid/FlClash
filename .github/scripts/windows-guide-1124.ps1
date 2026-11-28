$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName UIAutomationClient,UIAutomationTypes,System.Drawing,System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class GuideWindow {
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int n);
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
$seen = [System.Collections.Generic.HashSet[int]]::new()
[void]$seen.Add($process.Id)
$root = [System.Windows.Automation.AutomationElement]::RootElement
$tree = [System.Windows.Automation.TreeScope]::Children
$all = [System.Windows.Automation.TreeScope]::Descendants
$condition = [System.Windows.Automation.Condition]::TrueCondition
$startSaved = $false
$finishSaved = $false
$lastAction = [DateTime]::MinValue
$deadline = (Get-Date).AddMinutes(7)
function Save-Window($window, [string]$name) {
  $hwnd = [IntPtr]$window.Current.NativeWindowHandle
  if ($hwnd -eq [IntPtr]::Zero) { throw 'Wizard has no window handle' }
  [void][GuideWindow]::ShowWindow($hwnd, 9)
  [void][GuideWindow]::SetForegroundWindow($hwnd)
  Start-Sleep -Milliseconds 700
  $r = $window.Current.BoundingRectangle
  if ($r.Width -lt 250 -or $r.Height -lt 150 -or $r.X -lt 0 -or $r.Y -lt 0 -or ($r.X + $r.Width) -gt [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width -or ($r.Y + $r.Height) -gt [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height) { throw 'Wizard window outside visible screen' }
  $bmp = [System.Drawing.Bitmap]::new([int]$r.Width,[int]$r.Height)
  $graphics = [System.Drawing.Graphics]::FromImage($bmp)
  try { $graphics.CopyFromScreen([int]$r.X,[int]$r.Y,0,0,$bmp.Size); $bmp.Save((Join-Path $out $name),[System.Drawing.Imaging.ImageFormat]::Png) } finally { $graphics.Dispose(); $bmp.Dispose() }
}
try {
  while ((Get-Date) -lt $deadline -and -not $finishSaved) {
    $procs = @(Get-CimInstance Win32_Process)
    foreach ($p in $procs) { if ($seen.Contains([int]$p.ParentProcessId)) { [void]$seen.Add([int]$p.ProcessId) } }
    $windows = $root.FindAll($tree,$condition)
    foreach ($w in $windows) {
      if (-not $seen.Contains($w.Current.ProcessId) -or $w.Current.IsOffscreen -or $w.Current.NativeWindowHandle -eq 0) { continue }
      $elements = $w.FindAll($all,$condition)
      $names = @($elements | ForEach-Object { $_.Current.Name } | Where-Object { $_ })
      $buttons = @($elements | Where-Object { $_.Current.ControlType -eq [System.Windows.Automation.ControlType]::Button -and $_.Current.IsEnabled -and -not $_.Current.IsOffscreen })
      $text = ($names -join ' | ')
      Write-Host ("Window pid={0} title={1} controls={2}" -f $w.Current.ProcessId,$w.Current.Name,$text)
      $finish = @($buttons | Where-Object { $_.Current.Name -match '^(Finish|完成)\s*$' })
      if ($startSaved -and $finish.Count -eq 1 -and $text -match '(complet|finished|安装完成|完成安装)' ) {
        Save-Window $w 'windows-install-finish.png'
        $finishSaved = $true
        break
      }
      $next = @($buttons | Where-Object { $_.Current.Name -match '^(&?Next\s*>?|&?Install|下一步\s*>?|安装)(\.\.\.)?$' })
      if ($next.Count -eq 1 -and ((Get-Date) - $lastAction).TotalSeconds -ge 3) {
        if (-not $startSaved) { Save-Window $w 'windows-install-start.png'; $startSaved = $true }
        $pattern = $next[0].GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
        $pattern.Invoke()
        $lastAction = Get-Date
      }
    }
    Start-Sleep -Seconds 1
  }
  if (-not $startSaved -or -not $finishSaved) { throw 'Could not verify both start and completion windows; no artifact will be uploaded.' }
  @{ installer_url=$url; sha256=$actual; bytes=(Get-Item $installer).Length; started_pid=$process.Id; observed_pids=@($seen); start_verified=$startSaved; completion_verified=$finishSaved; commit=$env:GITHUB_SHA } | ConvertTo-Json | Set-Content -Encoding UTF8 (Join-Path $out 'verification.json')
} finally {
  foreach ($id in $seen) { Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
}
