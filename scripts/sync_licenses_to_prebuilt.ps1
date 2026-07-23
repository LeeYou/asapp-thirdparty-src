<#
.SYNOPSIS
  将源码仓 licenses/ 目录同步到制品仓 licenses/（robocopy）。
.PARAMETER PrebuiltRoot
  制品仓根目录；未指定时用 ASAPP_PREBUILT_ROOT / 嵌套 prebuilt / 同级 asapp-thirdparty-prebuilt。
#>
param(
    [string]$PrebuiltRoot = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
. (Join-Path $PSScriptRoot "AsAppDepCommon.ps1")
$LicensesSrc = Join-Path $RepoRoot "licenses"

if ([string]::IsNullOrWhiteSpace($PrebuiltRoot)) {
    $PrebuiltRoot = Resolve-AsAppDepPrebuiltRoot
}
if (-not $PrebuiltRoot -or -not (Test-Path $PrebuiltRoot)) {
    throw "Prebuilt root not found. Pass -PrebuiltRoot or set ASAPP_PREBUILT_ROOT."
}

$PrebuiltRoot = (Resolve-Path $PrebuiltRoot).Path
$LicensesDest = Join-Path $PrebuiltRoot "licenses"

if (-not (Test-Path $LicensesSrc)) {
    throw "Source licenses directory not found: $LicensesSrc"
}

New-Item -ItemType Directory -Force -Path $LicensesDest | Out-Null
Write-Host "Robocopy $LicensesSrc -> $LicensesDest"
$rc = Start-Process -FilePath "robocopy.exe" -ArgumentList @(
    $LicensesSrc, $LicensesDest, "/E", "/NFL", "/NDL", "/NJH", "/NJS", "/NC", "/NS"
) -Wait -PassThru
if ($rc.ExitCode -ge 8) {
    throw "robocopy failed: $($rc.ExitCode)"
}
Write-Host "Done."
