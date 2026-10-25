$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'windows_helper.ps1'
$tokens = $null
$parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$tokens, [ref]$parseErrors)
if ($parseErrors.Count) { throw ($parseErrors | Out-String) }
foreach ($name in @('Get-HostArchitecture', 'Get-BuildTarget', 'Get-ExecutionPlan', 'Resolve-ExecutionTarget', 'Assert-ExecutableArchitecture', 'Invoke-Checked', 'Get-PackageNames', 'Assert-Package', 'Write-Package', 'Invoke-PackageHarness')) {
    $function = $ast.Find({ param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name }.GetNewClosure(), $true)
    if (-not $function) { throw "Missing function $name" }
    . ([scriptblock]::Create($function.Extent.Text))
}
function Assert-Equal($Actual, $Expected) {
    if ($Actual -ne $Expected) { throw "Expected '$Expected', got '$Actual'" }
}
function Assert-Throws([scriptblock]$Action, [string]$Message) {
    try { & $Action } catch {
        if ($_.Exception.Message -notlike "*$Message*") { throw }
        return
    }
    throw "Expected failure containing '$Message'"
}
if ($env:OS -ne 'Windows_NT') {
    $unknown = Get-HostArchitecture
    Assert-Equal $unknown.OSArchitecture 'unknown'
    Assert-Equal $unknown.ProcessArchitecture 'unknown'
    if ($unknown.Detection -notlike 'unknown:*') { throw 'Detection failure must remain explicit.' }
}
foreach ($type in @('NativeX64', 'NativeArm64', 'X64OnArm64')) {
    foreach ($os in @('x64', 'arm64', 'x86', 'unknown')) {
        foreach ($process in @('x64', 'arm64', 'x86', 'unknown')) {
            $expectedOS = if ($type -eq 'NativeX64') { 'x64' } else { 'arm64' }
            if ($process -eq 'unknown') {
                Assert-Throws { Resolve-ExecutionTarget $type $os $process 22621 } 'unknown'
            } elseif ($os -ne $expectedOS) {
                Assert-Throws { Resolve-ExecutionTarget $type $os $process 22621 } 'Refusing launch'
            } else {
                $target = Resolve-ExecutionTarget $type $os $process 22621
                if ($type -eq 'NativeArm64') {
                    Assert-Equal $target.GoArch 'arm64'
                    Assert-Equal $target.RustTarget 'aarch64-pc-windows-msvc'
                    Assert-Equal $target.Machine 0xaa64
                } else {
                    Assert-Equal $target.GoArch 'amd64'
                    Assert-Equal $target.RustTarget 'x86_64-pc-windows-msvc'
                    Assert-Equal $target.Machine 0x8664
                }
            }
        }
    }
}
Assert-Throws { Resolve-ExecutionTarget 'X64OnArm64' 'arm64' 'x64' 19045 } 'Windows 11'
Assert-Throws { Resolve-ExecutionTarget 'X64OnArm64' 'arm64' 'x64' 0 } 'Windows 11'
Assert-Throws { Resolve-ExecutionTarget 'CrossBuild' 'arm64' 'arm64' } 'Unsupported'
$workspace = Join-Path ([IO.Path]::GetTempPath()) ('zolnit-arch-test-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $workspace
try {
    $exe = Join-Path $workspace 'fixture.exe'
    foreach ($machine in @(0x8664, 0xaa64)) {
        $bytes = [byte[]]::new(128)
        $bytes[0] = 0x4d; $bytes[1] = 0x5a
        [BitConverter]::GetBytes([int]64).CopyTo($bytes, 60)
        [BitConverter]::GetBytes([uint32]0x00004550).CopyTo($bytes, 64)
        [BitConverter]::GetBytes([uint16]$machine).CopyTo($bytes, 68)
        [IO.File]::WriteAllBytes($exe, $bytes)
        Assert-ExecutableArchitecture $exe $machine
        $other = if ($machine -eq 0x8664) { 0xaa64 } else { 0x8664 }
        Assert-Throws { Assert-ExecutableArchitecture $exe $other } 'Incompatible'
        $bytes[64] = 0
        [IO.File]::WriteAllBytes($exe, $bytes)
        Assert-Throws { Assert-ExecutableArchitecture $exe $machine } 'signature'
        [BitConverter]::GetBytes([int]0x7fffffff).CopyTo($bytes, 60)
        [IO.File]::WriteAllBytes($exe, $bytes)
        Assert-Throws { Assert-ExecutableArchitecture $exe $machine } 'offset'
    }
    [IO.File]::WriteAllBytes($exe, [byte[]]@(1, 2))
    Assert-Throws { Assert-ExecutableArchitecture $exe 0x8664 } 'DOS header'
    $failingCommand = Join-Path $workspace 'fail.ps1'
    [IO.File]::WriteAllText($failingCommand, 'exit 7')
    Assert-Throws { Invoke-Checked $failingCommand @() } 'exit code 7'
} finally {
    Remove-Item -LiteralPath $workspace -Recurse -Force
}
$parameter = $ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'ExecutionType' }
Assert-Equal $parameter.DefaultValue.Value 'NativeX64'
Write-Output 'PASS Windows acceptance architecture matrix (48 cases), PE rejection, nonzero command failure and default x64; no Windows binaries executed.'

$hostX64 = [pscustomobject]@{ OSArchitecture = 'x64'; ProcessArchitecture = 'x64' }
$armBuild = Get-ExecutionPlan 'NativeArm64' $true $hostX64 20348
Assert-Equal $armBuild.GoArch 'arm64'
Assert-Equal $armBuild.RustTarget 'aarch64-pc-windows-msvc'
Assert-Throws { Get-ExecutionPlan 'NativeArm64' $false $hostX64 20348 } 'Refusing launch'
$workspace = Join-Path ([IO.Path]::GetTempPath()) ('zolnit-package-test-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $workspace
$script:launches = 0
function Invoke-Checked([string]$Executable, [string[]]$Arguments) { $script:launches++ }
function Save-Manifest($Metadata, [string]$Directory) {
    $Metadata | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $Directory 'manifest.json') -Encoding UTF8
}
try {
    $bin = Join-Path $workspace 'bin'
    $null = New-Item -ItemType Directory -Path $bin
    $sourceMetadata = @{ commit = ('a' * 40); coreSubmoduleCommit = ('b' * 40); dirty = $true; status = @(' M tool/acceptance/windows_helper.ps1') }
    foreach ($type in @('NativeX64', 'NativeArm64')) {
        $target = Get-BuildTarget $type
        $bytes = [byte[]]::new(128)
        $bytes[0] = 0x4d; $bytes[1] = 0x5a
        [BitConverter]::GetBytes([int]64).CopyTo($bytes, 60)
        [BitConverter]::GetBytes([uint32]0x00004550).CopyTo($bytes, 64)
        [BitConverter]::GetBytes([uint16]$target.Machine).CopyTo($bytes, 68)
        foreach ($name in ((Get-PackageNames) | Where-Object { $_.EndsWith('.exe') })) {
            [IO.File]::WriteAllBytes((Join-Path $bin $name), $bytes)
        }
        $package = Join-Path $workspace $type
        Write-Package $package $bin $scriptPath $target $sourceMetadata
        Assert-Equal @(Get-ChildItem -LiteralPath $package).Count 6
        $metadata = Assert-Package $package $target
        Assert-Equal $metadata.classification 'build-only'
        Assert-Equal $metadata.executed $false
        Assert-Equal $metadata.rustCrt 'static'
        Assert-Equal $metadata.source.commit ('a' * 40)
        Assert-Equal $script:launches 0
        Assert-Throws { Write-Package $package $bin $scriptPath $target $sourceMetadata } 'must be new'
        $null = Assert-Package $package $target
        $otherTarget = if ($type -eq 'NativeX64') { Get-BuildTarget 'NativeArm64' } else { Get-BuildTarget 'NativeX64' }
        Assert-Throws { Invoke-PackageHarness $package $otherTarget } 'incompatible package metadata'
        $metadata.schemaVersion = 99
        Save-Manifest $metadata $package
        Assert-Throws { Invoke-PackageHarness $package $target } 'Unsupported'
        $metadata.schemaVersion = 1
        $metadata.coreSha256 = '0' * 64
        Save-Manifest $metadata $package
        Assert-Throws { Invoke-PackageHarness $package $target } 'Core hash binding'
        $metadata.coreSha256 = ($metadata.files | Where-Object { $_.name -eq 'SyntheticCore.exe' }).sha256
        Save-Manifest $metadata $package
        [IO.File]::AppendAllText((Join-Path $package 'observer.exe'), 'changed')
        Assert-Throws { Invoke-PackageHarness $package $target } 'SHA256 mismatch'
        [IO.File]::WriteAllBytes((Join-Path $package 'observer.exe'), $bytes)
        [BitConverter]::GetBytes([uint16]$otherTarget.Machine).CopyTo($bytes, 68)
        [IO.File]::WriteAllBytes((Join-Path $package 'observer.exe'), $bytes)
        ($metadata.files | Where-Object { $_.name -eq 'observer.exe' }).sha256 = (Get-FileHash -LiteralPath (Join-Path $package 'observer.exe')).Hash.ToLowerInvariant()
        Save-Manifest $metadata $package
        Assert-Throws { Invoke-PackageHarness $package $target } 'Incompatible executable'
        Assert-Equal $script:launches 0
        [BitConverter]::GetBytes([uint16]$target.Machine).CopyTo($bytes, 68)
        [IO.File]::WriteAllBytes((Join-Path $package 'observer.exe'), $bytes)
        ($metadata.files | Where-Object { $_.name -eq 'observer.exe' }).sha256 = (Get-FileHash -LiteralPath (Join-Path $package 'observer.exe')).Hash.ToLowerInvariant()
        Save-Manifest $metadata $package
        [IO.File]::WriteAllText((Join-Path $package 'extra.txt'), 'extra')
        Assert-Throws { Invoke-PackageHarness $package $target } 'exactly four'
        Remove-Item -LiteralPath (Join-Path $package 'extra.txt')
        [IO.File]::AppendAllText((Join-Path $package 'windows_helper.ps1'), 'changed')
        Assert-Throws { Invoke-PackageHarness $package $target } 'SHA256 mismatch'
        Copy-Item -LiteralPath $scriptPath -Destination (Join-Path $package 'windows_helper.ps1') -Force
        Assert-Equal $script:launches 0
        Invoke-PackageHarness $package $target
        Assert-Equal $script:launches 1
        $script:launches = 0
        Remove-Item -LiteralPath (Join-Path $bin 'observer.exe')
        $partial = Join-Path $workspace ($type + '-partial')
        Assert-Throws { Write-Package $partial $bin $scriptPath $target $sourceMetadata } 'observer.exe'
        Assert-Equal (Test-Path -LiteralPath $partial) $false
    }
    $native = Resolve-ExecutionTarget 'NativeX64' 'x64' 'x64' 22621
    $emulated = Resolve-ExecutionTarget 'X64OnArm64' 'arm64' 'arm64' 22621
    Assert-Equal $native.GoArch $emulated.GoArch
    Assert-Equal $native.RustTarget $emulated.RustTarget
    Assert-Equal $native.Machine $emulated.Machine
} finally { Remove-Item -LiteralPath $workspace -Recurse -Force }
Write-Output 'PASS cross-build-only planning, six-file x64/ARM64 packages, source metadata, existing-output refusal, hash/PE/metadata rejection, partial-output cleanup and zero prebuilt launches on validation failure; valid launch mocked.'
