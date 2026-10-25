param(
    [string]$Go = 'go',
    [string]$Cargo = 'cargo',
    [ValidateSet('NativeX64', 'NativeArm64', 'X64OnArm64')]
    [string]$ExecutionType = 'NativeX64',
    [switch]$BuildOnly,
    [string]$OutputDirectory,
    [string]$PrebuiltDirectory
)
$ErrorActionPreference = 'Stop'
function Get-HostArchitecture {
    $result = @{ OSArchitecture = 'unknown'; ProcessArchitecture = 'unknown'; OSVersion = [Environment]::OSVersion.Version.ToString(); Detection = 'IsWow64Process2' }
    try {
        if (-not ('ZolNitAcceptance.NativeArchitecture' -as [type])) {
            Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace ZolNitAcceptance {
    public static class NativeArchitecture {
        [DllImport("kernel32.dll", SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        public static extern bool IsWow64Process2(IntPtr process, out ushort processMachine, out ushort nativeMachine);
    }
}
'@
        }
        [ushort]$processMachine = 0
        [ushort]$nativeMachine = 0
        if (-not [ZolNitAcceptance.NativeArchitecture]::IsWow64Process2([IntPtr](-1), [ref]$processMachine, [ref]$nativeMachine)) {
            throw 'IsWow64Process2 failed.'
        }
        $machines = @{ 0x8664 = 'x64'; 0xaa64 = 'arm64'; 0x014c = 'x86' }
        if ($machines.ContainsKey([int]$nativeMachine)) { $result.OSArchitecture = $machines[[int]$nativeMachine] }
        if ($processMachine -eq 0) {
            $result.ProcessArchitecture = [Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString().ToLowerInvariant()
        } elseif ($machines.ContainsKey([int]$processMachine)) {
            $result.ProcessArchitecture = $machines[[int]$processMachine]
        }
    } catch {
        $result.Detection = 'unknown: ' + $_.Exception.Message
    }
    return [pscustomobject]$result
}
function Get-BuildTarget([string]$Type) {
    switch ($Type) {
        'NativeX64' { $requiredOS = 'x64'; $goarch = 'amd64'; $rustTarget = 'x86_64-pc-windows-msvc'; $machine = 0x8664 }
        'NativeArm64' { $requiredOS = 'arm64'; $goarch = 'arm64'; $rustTarget = 'aarch64-pc-windows-msvc'; $machine = 0xaa64 }
        'X64OnArm64' { $requiredOS = 'arm64'; $goarch = 'amd64'; $rustTarget = 'x86_64-pc-windows-msvc'; $machine = 0x8664 }
        default { throw "Unsupported execution type: $Type" }
    }
    return [pscustomobject]@{ GoArch = $goarch; RustTarget = $rustTarget; Machine = $machine; RequiredOS = $requiredOS }
}
function Resolve-ExecutionTarget([string]$Type, [string]$OSArchitecture, [string]$ProcessArchitecture, [int]$WindowsBuild) {
    if ($ProcessArchitecture -notin @('x64', 'arm64', 'x86')) { throw 'Process architecture unknown; refusing launch.' }
    $target = Get-BuildTarget $Type
    $requiredOS = $target.RequiredOS
    if ($OSArchitecture -ne $requiredOS) { throw "$Type requires OS architecture $requiredOS; detected $OSArchitecture. Refusing launch." }
    if ($Type -eq 'X64OnArm64' -and $WindowsBuild -lt 22000) { throw 'x64-on-ARM64 emulation requires Windows 11 or later; refusing launch.' }
    return $target
}
function Assert-ExecutableArchitecture([string]$Path, [int]$ExpectedMachine) {
    $stream = [IO.File]::OpenRead($Path)
    $reader = [IO.BinaryReader]::new($stream)
    try {
        if ($stream.Length -lt 64 -or $reader.ReadUInt16() -ne 0x5a4d) { throw "Invalid DOS header: $Path" }
        $stream.Position = 0x3c
        $offset = $reader.ReadInt32()
        if ($offset -lt 64 -or $offset -gt ($stream.Length - 6)) { throw "Invalid PE offset: $Path" }
        $stream.Position = $offset
        if ($reader.ReadUInt32() -ne 0x00004550) { throw "Invalid PE signature: $Path" }
        if ($reader.ReadUInt16() -ne $ExpectedMachine) { throw "Incompatible executable architecture: $Path" }
    } finally { $reader.Dispose() }
}
function Get-ExecutionPlan([string]$Type, [bool]$OnlyBuild, $Architecture, [int]$WindowsBuild) {
    if ($OnlyBuild) { return Get-BuildTarget $Type }
    return Resolve-ExecutionTarget $Type $Architecture.OSArchitecture $Architecture.ProcessArchitecture $WindowsBuild
}
function Invoke-Checked([string]$Executable, [string[]]$Arguments) {
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Executable failed with exit code $LASTEXITCODE" }
}
function Get-PackageNames { return @('SyntheticCore.exe', 'observer.exe', 'acceptance.exe', 'helper-acceptance.exe', 'windows_helper.ps1') }
function Assert-Package([string]$Directory, $Target) {
    $names = @(Get-PackageNames)
    $items = @(Get-ChildItem -LiteralPath $Directory -Force)
    if ($items.Count -ne 6) { throw 'Package must contain exactly four executables, runner and manifest.' }
    foreach ($item in $items) {
        if ($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $item.Name -notin ($names + 'manifest.json')) {
            throw 'Unsupported package entry.'
        }
    }
    $metadata = Get-Content -LiteralPath (Join-Path $Directory 'manifest.json') -Raw | ConvertFrom-Json
    if ($metadata.schemaVersion -ne 1 -or $metadata.kind -ne 'isolated-helper-acceptance' -or
        $metadata.goos -ne 'windows' -or $metadata.goarch -ne $Target.GoArch -or
        $metadata.rustTarget -ne $Target.RustTarget -or $metadata.peMachine -ne $Target.Machine -or
        $metadata.classification -ne 'build-only' -or $metadata.executed -ne $false -or
        $metadata.rustCrt -ne 'static' -or $metadata.hardwareType -ne 'unknown' -or
        $metadata.tunTested -ne $false -or $metadata.kernelDriverTested -ne $false -or
        $metadata.scmTested -ne $false -or $metadata.realFlutterTested -ne $false -or
        $metadata.source.commit -notmatch '^[0-9a-f]{40}$' -or
        $metadata.source.coreSubmoduleCommit -notmatch '^[0-9a-f]{40}$') { throw 'Unsupported or incompatible package metadata.' }
    $files = @($metadata.files)
    if ($files.Count -ne $names.Count) { throw 'Invalid package hash inventory.' }
    foreach ($name in $names) {
        $entry = @($files | Where-Object { $_.name -ceq $name })
        if ($entry.Count -ne 1 -or $entry[0].sha256 -cnotmatch '^[0-9a-f]{64}$') { throw "Invalid hash entry: $name" }
        $path = Join-Path $Directory $name
        if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -cne $entry[0].sha256) { throw "SHA256 mismatch: $name" }
        if ($name.EndsWith('.exe')) { Assert-ExecutableArchitecture $path $Target.Machine }
        if ($name -eq 'SyntheticCore.exe' -and $metadata.coreSha256 -cne $entry[0].sha256) { throw 'Core hash binding mismatch.' }
    }
    return $metadata
}
function Write-Package([string]$Directory, [string]$Bin, [string]$Runner, $Target, $Source) {
    if (Test-Path -LiteralPath $Directory) { throw 'OutputDirectory must be new.' }
    $created = $false
    try {
        $null = New-Item -ItemType Directory -Path $Directory
        $created = $true
        foreach ($name in @('SyntheticCore.exe', 'observer.exe', 'acceptance.exe', 'helper-acceptance.exe')) {
            Assert-ExecutableArchitecture (Join-Path $Bin $name) $Target.Machine
            Copy-Item -LiteralPath (Join-Path $Bin $name) -Destination $Directory
        }
        Copy-Item -LiteralPath $Runner -Destination (Join-Path $Directory 'windows_helper.ps1')
        $files = @(foreach ($name in (Get-PackageNames)) {
            @{ name = $name; sha256 = (Get-FileHash -LiteralPath (Join-Path $Directory $name) -Algorithm SHA256).Hash.ToLowerInvariant() }
        })
        @{
            schemaVersion = 1; kind = 'isolated-helper-acceptance'; classification = 'build-only'; executed = $false; rustCrt = 'static'
            goos = 'windows'; goarch = $Target.GoArch; rustTarget = $Target.RustTarget; peMachine = $Target.Machine
            coreSha256 = ($files | Where-Object { $_.name -eq 'SyntheticCore.exe' }).sha256
            source = $Source; files = $files; hardwareType = 'unknown'
            tunTested = $false; kernelDriverTested = $false; scmTested = $false; realFlutterTested = $false
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $Directory 'manifest.json') -Encoding UTF8
        $null = Assert-Package $Directory $Target
    } catch {
        if ($created) { Remove-Item -LiteralPath $Directory -Recurse -Force }
        throw
    }
}
function Invoke-PackageHarness([string]$Bin, $Target) {
    $null = Assert-Package $Bin $Target
    Invoke-Checked (Join-Path $Bin 'acceptance.exe') @('--helper', (Join-Path $Bin 'helper-acceptance.exe'), '--observer', (Join-Path $Bin 'observer.exe'))
}
if ($BuildOnly -and $PrebuiltDirectory) { throw 'BuildOnly and PrebuiltDirectory are mutually exclusive.' }
if (($BuildOnly -and -not $OutputDirectory) -or (-not $BuildOnly -and $OutputDirectory)) { throw 'OutputDirectory is required only with BuildOnly.' }
if ($OutputDirectory -and (Test-Path -LiteralPath $OutputDirectory)) { throw 'OutputDirectory must be new.' }
if ($env:OS -ne 'Windows_NT') { throw 'A Windows host is required.' }
$architecture = Get-HostArchitecture
Write-Output ('ARCHITECTURE ' + ($architecture | ConvertTo-Json -Compress))
$target = Get-ExecutionPlan $ExecutionType ([bool]$BuildOnly) $architecture ([Environment]::OSVersion.Version.Build)
$classification = if ($BuildOnly) { 'build-only' } else { $ExecutionType }
Write-Output ('ACCEPTANCE ' + (@{
    executionType = $classification; goarch = $target.GoArch; rustTarget = $target.RustTarget
    hardwareType = 'unknown'; tunTested = $false; kernelDriverTested = $false
    scmTested = $false; realFlutterTested = $false; productArm64Support = 'unverified'
} | ConvertTo-Json -Compress))
if ($PrebuiltDirectory) { $null = Assert-Package $PrebuiltDirectory $target }
$workspace = Join-Path ([IO.Path]::GetTempPath()) ('zolnit-helper-acceptance-' + [Guid]::NewGuid().ToString('N'))
$workspaceCreated = $false
$saved = @{}
foreach ($name in @('CORE_NAME', 'CORE_SHA256', 'CARGO_TARGET_DIR', 'CGO_ENABLED', 'GOOS', 'GOARCH', 'GOAMD64', 'GOARM64', 'CARGO_ENCODED_RUSTFLAGS', 'TMP', 'TEMP')) {
    $saved[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
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
    if ($PrebuiltDirectory) {
        foreach ($name in ((Get-PackageNames) + 'manifest.json')) { Copy-Item -LiteralPath (Join-Path $PrebuiltDirectory $name) -Destination $bin }
        Invoke-PackageHarness $bin $target
    } else {
        $repo = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
        $env:CGO_ENABLED = '0'
        $env:GOOS = 'windows'
        $env:GOARCH = $target.GoArch
        $env:GOAMD64 = 'v1'
        $env:GOARM64 = 'v8.0'
        if ($BuildOnly) { $env:CARGO_ENCODED_RUSTFLAGS = '-C' + [char]0x1f + 'target-feature=+crt-static' }
        $env:CORE_NAME = 'SyntheticCore.exe'
        $env:CARGO_TARGET_DIR = Join-Path $workspace 'rust-target'
        Push-Location (Join-Path $repo 'core')
        try {
            Invoke-Checked $Go @('build', '-o', (Join-Path $bin $env:CORE_NAME), './cmd/core')
            Invoke-Checked $Go @('build', '-o', (Join-Path $bin 'observer.exe'), './cmd/zolnit-lease-observer')
            if (-not $BuildOnly) { Invoke-Checked $Go @('test', './cmd/zolnit-helper-acceptance') }
            Invoke-Checked $Go @('build', '-o', (Join-Path $bin 'acceptance.exe'), './cmd/zolnit-helper-acceptance')
        } finally { Pop-Location }
        $env:CORE_SHA256 = (Get-FileHash -LiteralPath (Join-Path $bin $env:CORE_NAME) -Algorithm SHA256).Hash.ToLowerInvariant()
        $manifest = Join-Path $repo 'services/helper/Cargo.toml'
        Invoke-Checked $Cargo @('fmt', '--manifest-path', $manifest, '--', '--check')
        if (-not $BuildOnly) { Invoke-Checked $Cargo @('test', '--locked', '--target', $target.RustTarget, '--manifest-path', $manifest) }
        Invoke-Checked $Cargo @('build', '--locked', '--target', $target.RustTarget, '--manifest-path', $manifest, '--features', 'isolated-acceptance', '--bin', 'helper-acceptance')
        Copy-Item -LiteralPath (Join-Path $env:CARGO_TARGET_DIR ($target.RustTarget + '/debug/helper-acceptance.exe')) -Destination $bin
        foreach ($name in @($env:CORE_NAME, 'observer.exe', 'acceptance.exe', 'helper-acceptance.exe')) {
            Assert-ExecutableArchitecture (Join-Path $bin $name) $target.Machine
        }
        if ($BuildOnly) {
            $commit = & git -C $repo rev-parse HEAD
            if ($LASTEXITCODE -ne 0) { throw 'Cannot identify source commit.' }
            $status = @(& git -C $repo status --porcelain --untracked-files=normal)
            if ($LASTEXITCODE -ne 0) { throw 'Cannot identify source status.' }
            $submoduleCommit = & git -C (Join-Path $repo 'core/Clash.Meta') rev-parse HEAD
            if ($LASTEXITCODE -ne 0) { throw 'Cannot identify Core source commit.' }
            $source = @{ commit = $commit; coreSubmoduleCommit = $submoduleCommit; dirty = ($status.Count -gt 0); status = $status }
            Write-Package $OutputDirectory $bin $PSCommandPath $target $source
            Write-Output ('BUILD-ONLY package: ' + $OutputDirectory + '; no target binaries or target tests executed.')
        } else {
            Invoke-Checked (Join-Path $bin 'acceptance.exe') @('--helper', (Join-Path $bin 'helper-acceptance.exe'), '--observer', (Join-Path $bin 'observer.exe'))
        }
    }
} finally {
    foreach ($name in $saved.Keys) { [Environment]::SetEnvironmentVariable($name, $saved[$name], 'Process') }
    if ($workspaceCreated -and (Test-Path -LiteralPath $workspace)) { Remove-Item -LiteralPath $workspace -Recurse -Force }
}
