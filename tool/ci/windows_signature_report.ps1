<#
Inventories the Authenticode signatures of the Windows payload and the installer.

Inventory (never fails on missing signatures; the report says whether the
candidate is release ready):
  pwsh tool/ci/windows_signature_report.ps1 -Bundle <Release dir> -Installer <setup.exe> -Report <file>

Strict gate for a candidate that claims to be signed (exits 3 unless the three
root first-party binaries and the installer are present, every PE is validly
signed, and the first-party files carry the approved publisher subject and a
timestamp; any other failure is a script error with a different exit code):
  pwsh tool/ci/windows_signature_report.ps1 -Bundle <Release dir> -Installer <setup.exe> -Strict -PublisherSubject '<certificate subject>'
#>
param(
    [Parameter(Mandatory)][string]$Bundle,
    [Parameter(Mandatory)][string]$Installer,
    [string]$Report,
    [switch]$Strict,
    [string]$PublisherSubject
)

$ErrorActionPreference = 'Stop'
if ($Strict -and -not $PublisherSubject) {
    throw '-Strict needs the approved -PublisherSubject'
}

$root = (Resolve-Path -LiteralPath $Bundle).Path.TrimEnd('\')
$installerFile = Get-Item -LiteralPath $Installer
$firstParty = @('ZolNit.exe', 'FlClashCore.exe', 'ZolNitHelperService.exe')
$payload = @(Get-ChildItem -LiteralPath $root -Recurse -File |
    Where-Object { $_.Extension -in '.exe', '.dll' }) + $installerFile

$rows = foreach ($file in $payload | Sort-Object FullName) {
    $signature = Get-AuthenticodeSignature -LiteralPath $file.FullName
    $isInstaller = $file.FullName -eq $installerFile.FullName
    $isFirstParty = $isInstaller -or
        ($file.DirectoryName -eq $root -and $firstParty -contains $file.Name)
    $certificate = $signature.SignerCertificate
    [pscustomobject]@{
        Name = if ($isInstaller) { $file.Name } else { $file.FullName.Substring($root.Length + 1) }
        Role = if ($isFirstParty) { 'first-party' } else { 'bundled' }
        Status = $signature.Status.ToString()
        Subject = if ($certificate) { $certificate.Subject } else { '-' }
        Thumbprint = if ($certificate) { $certificate.Thumbprint } else { '-' }
        Timestamped = [bool]$signature.TimeStamperCertificate
        Sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
}

$failures = @()
foreach ($name in $firstParty) {
    if (-not ($rows | Where-Object { $_.Role -eq 'first-party' -and $_.Name -eq $name })) {
        $failures += "$name is missing from the bundle root"
    }
}
foreach ($row in $rows) {
    if ($row.Status -ne 'Valid') {
        $failures += "$($row.Name): signature status $($row.Status)"
    } elseif ($row.Role -eq 'first-party') {
        if (-not $PublisherSubject) {
            continue
        }
        if ($row.Subject -ne $PublisherSubject) {
            $failures += "$($row.Name): signed by '$($row.Subject)', not the approved publisher"
        }
        if (-not $row.Timestamped) {
            $failures += "$($row.Name): signature has no timestamp"
        }
    }
}

$ready = $failures.Count -eq 0 -and [bool]$PublisherSubject
$lines = @(
    "release_ready=$($ready.ToString().ToLowerInvariant())",
    "pe_files=$($rows.Count)",
    "not_validly_signed=$(@($rows | Where-Object { $_.Status -ne 'Valid' }).Count)",
    ("publisher_signing_required=" + ((@($rows | Where-Object { $_.Role -eq 'first-party' }).Name) -join ', '))
)
if (-not $PublisherSubject) {
    $lines += 'publisher_subject=not configured; the candidate cannot be release ready'
}
$lines += $failures | ForEach-Object { "failure=$_" }
$lines += ''
$lines += $rows | ForEach-Object {
    '{0} | {1} | {2} | {3} | {4} | timestamp={5} | sha256={6}' -f $_.Role, $_.Name, $_.Status, $_.Subject, $_.Thumbprint, $_.Timestamped, $_.Sha256
}
if ($Report) {
    Set-Content -LiteralPath $Report -Value $lines -Encoding utf8
}
$lines | Write-Host

if ($Strict -and -not $ready) {
    foreach ($failure in $failures) {
        Write-Host "::error::$failure"
    }
    exit 3
}
