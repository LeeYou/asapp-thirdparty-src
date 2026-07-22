<#
.SYNOPSIS
  将 dist/<slice> 同步到制品仓工作树，并刷新 MANIFEST 骨架字段（手工可再改）。
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Slice,
    [string]$DistRoot = "",
    [string]$PrebuiltRoot = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if ([string]::IsNullOrWhiteSpace($DistRoot)) {
    $DistRoot = Join-Path $RepoRoot "dist\$Slice"
}
if ([string]::IsNullOrWhiteSpace($PrebuiltRoot)) {
    $Candidate = Join-Path $RepoRoot "prebuilt"
    if (Test-Path (Join-Path $Candidate ".git")) {
        $PrebuiltRoot = $Candidate
    } else {
        $PrebuiltRoot = "E:\work\Demo\Demo\Demo004\asapp-thirdparty-prebuilt"
    }
}

if (-not (Test-Path $DistRoot)) { throw "Dist slice not found: $DistRoot" }
if (-not (Test-Path $PrebuiltRoot)) { throw "Prebuilt root not found: $PrebuiltRoot" }

$DestSlice = Join-Path $PrebuiltRoot $Slice
Write-Host "Sync $DistRoot -> $DestSlice"
if (Test-Path $DestSlice) { Remove-Item -Recurse -Force $DestSlice }
New-Item -ItemType Directory -Force -Path $DestSlice | Out-Null
Copy-Item -Path (Join-Path $DistRoot "*") -Destination $DestSlice -Recurse -Force
Write-Host "Synced. Update MANIFEST.yaml / SHA256SUMS before commit."
