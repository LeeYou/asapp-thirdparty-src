<#
.SYNOPSIS
  将源码仓 licenses/ 目录同步到制品仓 licenses/（robocopy）。
.DESCRIPTION
  默认目标为与源码仓同级的 Demo004 asapp-thirdparty-prebuilt。
.PARAMETER PrebuiltRoot
  制品仓根目录；未指定时使用 ../asapp-thirdparty-prebuilt 或 E:\work\Demo\Demo\Demo004\asapp-thirdparty-prebuilt。
#>
param(
    [string]$PrebuiltRoot = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$LicensesSrc = Join-Path $RepoRoot "licenses"

if ([string]::IsNullOrWhiteSpace($PrebuiltRoot)) {
    $Sibling = Join-Path (Split-Path $RepoRoot -Parent) "asapp-thirdparty-prebuilt"
    if (Test-Path (Join-Path $Sibling ".git")) {
        $PrebuiltRoot = $Sibling
    }
    else {
        $PrebuiltRoot = "E:\work\Demo\Demo\Demo004\asapp-thirdparty-prebuilt"
    }
}

$PrebuiltRoot = (Resolve-Path $PrebuiltRoot).Path
$LicensesDest = Join-Path $PrebuiltRoot "licenses"

if (-not (Test-Path $LicensesSrc)) {
    throw "Source licenses directory not found: $LicensesSrc"
}

New-Item -ItemType Directory -Force -Path $LicensesDest | Out-Null
Write-Host "Robocopy $LicensesSrc -> $LicensesDest"
$Robo = robocopy $LicensesSrc $LicensesDest /E /NFL /NDL /NJH /NJS /NC /NS /NP
$ExitCode = $LASTEXITCODE
if ($ExitCode -ge 8) {
    throw "robocopy failed with exit code $ExitCode"
}
Write-Host "Licenses synced to $LicensesDest"
