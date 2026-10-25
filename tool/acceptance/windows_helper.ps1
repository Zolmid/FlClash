param(
    [string]$Go = 'go',
    [string]$Cargo = 'cargo'
)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'A Windows host is required.' }
$repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$workspace = Join-Path ([IO.Path]::GetTempPath()) ('zolnit-helper-acceptance-' + [Guid]::NewGuid().ToString('N'))
$workspaceCreated = $false
$saved = @{}
foreach ($name in @('CORE_NAME', 'CORE_SHA256', 'CARGO_TARGET_DIR', 'CGO_ENABLED', 'TMP', 'TEMP')) {
    $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
function Invoke-Checked([string]$Executable, [string[]]$Arguments) {
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Executable failed with exit code $LASTEXITCODE" }
}
try {
    $null = New-Item -ItemType Directory -Path $workspace
    $workspaceCreated = $true
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $acl = [Security.AccessControl.DirectorySecurity]::new()
    $acl.SetOwner($sid)
    $acl.SetAccessRuleProtection($true, $false)
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new($sid, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow'))
    Set-Acl -LiteralPath $workspace -AclObject $acl
    $bin = Join-Path $workspace 'bin'
    $null = New-Item -ItemType Directory -Path $bin
    $env:TMP = $workspace
    $env:TEMP = $workspace
    $env:CGO_ENABLED = '0'
    $env:CORE_NAME = 'SyntheticCore.exe'
    $env:CARGO_TARGET_DIR = Join-Path $workspace 'rust-target'
    Push-Location (Join-Path $repo 'core')
    try {
        Invoke-Checked $Go @('build', '-o', (Join-Path $bin $env:CORE_NAME), './cmd/core')
        Invoke-Checked $Go @('build', '-o', (Join-Path $bin 'observer.exe'), './cmd/zolnit-lease-observer')
        Invoke-Checked $Go @('test', './cmd/zolnit-helper-acceptance')
        Invoke-Checked $Go @('build', '-o', (Join-Path $bin 'acceptance.exe'), './cmd/zolnit-helper-acceptance')
    } finally { Pop-Location }
    $env:CORE_SHA256 = (Get-FileHash -LiteralPath (Join-Path $bin $env:CORE_NAME) -Algorithm SHA256).Hash.ToLowerInvariant()
    $manifest = Join-Path $repo 'services/helper/Cargo.toml'
    Invoke-Checked $Cargo @('fmt', '--manifest-path', $manifest, '--', '--check')
    Invoke-Checked $Cargo @('test', '--locked', '--manifest-path', $manifest)
    Invoke-Checked $Cargo @('build', '--locked', '--manifest-path', $manifest, '--features', 'isolated-acceptance', '--bin', 'helper-acceptance')
    Copy-Item -LiteralPath (Join-Path $env:CARGO_TARGET_DIR 'debug/helper-acceptance.exe') -Destination $bin
    Invoke-Checked (Join-Path $bin 'acceptance.exe') @('--helper', (Join-Path $bin 'helper-acceptance.exe'), '--observer', (Join-Path $bin 'observer.exe'))
} finally {
    foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
    if ($workspaceCreated -and (Test-Path -LiteralPath $workspace)) { Remove-Item -LiteralPath $workspace -Recurse -Force }
}
