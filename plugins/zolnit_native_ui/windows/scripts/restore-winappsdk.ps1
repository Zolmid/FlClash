param(
  [Parameter(Mandatory = $true)]
  [string]$CacheDir,
  # Optional path to Microsoft.Web.WebView2.Core.winmd, which
  # Microsoft.UI.Xaml.winmd references (WebView2 control).
  [string]$WebView2Winmd = ''
)

$ErrorActionPreference = 'Stop'
$sdkVersion = '1.7.250401001'
$sdkSha256 = '989887a1ec5d1dd99223d78af424e94f73dacd0f617f2815bd61b36d04d585d3'
$webView2Version = '1.0.2903.40'
$webView2Sha256 = 'ef128016dd1e51c59178c827ed5b8aa3322c57afa8675d930f8109505542ad74'
$cppWinrtVersion = '2.0.240405.15'
$cppWinrtSha256 = 'e889007b5d9235931e7340ddf737d2c346eebdd23c619f1f4f2426a2aae47180'
$packageName = "Microsoft.WindowsAppSDK.$sdkVersion"
$packageDir = Join-Path $CacheDir $packageName
$projectionDir = Join-Path $CacheDir 'winrt'

function Restore-Package([string]$id, [string]$version, [string]$destination, [string]$sha256) {
  $marker = Join-Path $destination '.zolnit-sha256'
  if ((Test-Path $marker) -and ((Get-Content -Raw $marker).Trim() -eq $sha256)) { return }
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $destination
  New-Item -ItemType Directory -Force -Path $destination | Out-Null
  $archive = Join-Path $CacheDir "$id.$version.zip"
  $url = "https://api.nuget.org/v3-flatcontainer/$($id.ToLowerInvariant())/$version/$($id.ToLowerInvariant()).$version.nupkg"
  Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $archive
  if ((Get-FileHash -Algorithm SHA256 $archive).Hash.ToLowerInvariant() -ne $sha256) {
    Remove-Item -Force $archive
    throw "SHA256 mismatch for $id.$version."
  }
  Expand-Archive -Force -Path $archive -DestinationPath $destination
  Set-Content -NoNewline -Path $marker -Value $sha256
  Remove-Item -Force $archive
}

New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null
Restore-Package 'Microsoft.WindowsAppSDK' $sdkVersion $packageDir $sdkSha256
$cppWinrtDir = Join-Path $CacheDir "Microsoft.Windows.CppWinRT.$cppWinrtVersion"
Restore-Package 'Microsoft.Windows.CppWinRT' $cppWinrtVersion $cppWinrtDir $cppWinrtSha256
$webView2Dir = Join-Path $CacheDir "Microsoft.Web.WebView2.$webView2Version"
Restore-Package 'Microsoft.Web.WebView2' $webView2Version $webView2Dir $webView2Sha256
if (-not $WebView2Winmd) { $WebView2Winmd = Join-Path $webView2Dir 'lib\Microsoft.Web.WebView2.Core.winmd' }
if (-not (Test-Path $WebView2Winmd)) { throw 'Pinned WebView2 metadata is missing.' }

$cppwinrt = Join-Path $cppWinrtDir 'bin\cppwinrt.exe'
if (-not (Test-Path $cppwinrt)) {
  throw 'Pinned Microsoft.Windows.CppWinRT package did not contain cppwinrt.exe.'
}

# Microsoft.UI.Xaml/Text live in lib\uap10.0; Microsoft.UI (Content, Dispatching,
# WindowId), Microsoft.Foundation and Microsoft.Graphics live in lib\uap10.0.18362.
$winmd = Join-Path $packageDir 'lib\uap10.0'
$winmd18362 = Join-Path $packageDir 'lib\uap10.0.18362'
$inputs = @(
  (Join-Path $winmd 'Microsoft.UI.Xaml.winmd'),
  (Join-Path $winmd 'Microsoft.UI.Text.winmd'),
  (Join-Path $winmd18362 'Microsoft.UI.winmd'),
  (Join-Path $winmd18362 'Microsoft.Foundation.winmd'),
  (Join-Path $winmd18362 'Microsoft.Graphics.winmd')
)
foreach ($file in $inputs) {
  if (-not (Test-Path $file)) { throw "Missing metadata in pinned Windows App SDK package: $file" }
}
$marker = Join-Path $projectionDir '.zolnit-projection-v2'
$expectedMarker = "$sdkSha256|$cppWinrtSha256|$webView2Sha256|$WebView2Winmd"
$header = Join-Path $projectionDir 'winrt\Microsoft.UI.Xaml.h'
if (-not (Test-Path $header) -or -not (Test-Path $marker) -or (Get-Content -Raw $marker).Trim() -ne $expectedMarker) {
  Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $projectionDir
  # 'sdk' as input generates the Windows.* projection with the same pinned
  # cppwinrt, so base.h and every Windows.* header come from one version.
  $arguments = @('-input', 'sdk') + @($inputs | ForEach-Object { @('-input', $_) })
  if ($WebView2Winmd) {
    if (-not (Test-Path $WebView2Winmd)) { throw "WebView2 metadata not found: $WebView2Winmd" }
    $arguments += @('-input', $WebView2Winmd)
  }
  $arguments += @('-output', $projectionDir)
  & $cppwinrt @arguments
  if ($LASTEXITCODE -ne 0) { throw "cppwinrt failed with exit code $LASTEXITCODE." }
  Set-Content -NoNewline -Path $marker -Value $expectedMarker
}

Write-Output "ZOLNIT_WINDOWS_APP_SDK_DIR=$packageDir"
Write-Output "ZOLNIT_WINAPPSDK_CPPWINRT_INCLUDE=$projectionDir"
