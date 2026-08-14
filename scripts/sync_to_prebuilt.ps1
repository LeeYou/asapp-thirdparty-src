<#
.SYNOPSIS
  将 dist/<slice> 同步到制品仓工作树，并刷新 MANIFEST 骨架字段（手工可再改）。

  opencv：正式切片仅为 *-shared-release；库形态恒为 STATIC（见 cmake/packages/opencv.cmake）。
  非 ship 切片若含 opencv，默认剔除后再同步，避免实验产物误入 deps-*；
  确需入库时传 -AllowOpencvNonShip。
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$Slice,
    [string]$DistRoot = "",
    [string]$PrebuiltRoot = "",
    [switch]$AllowOpencvNonShip
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
. (Join-Path $PSScriptRoot "AsAppDepCommon.ps1")
if ([string]::IsNullOrWhiteSpace($DistRoot)) {
    $DistRoot = Join-Path $RepoRoot "dist\$Slice"
}
if ([string]::IsNullOrWhiteSpace($PrebuiltRoot)) {
    $PrebuiltRoot = Resolve-AsAppDepPrebuiltRoot
}

if (-not (Test-Path $DistRoot)) { throw "Dist slice not found: $DistRoot" }
if (-not $PrebuiltRoot -or -not (Test-Path $PrebuiltRoot)) {
    throw "Prebuilt root not found. Pass -PrebuiltRoot or set ASAPP_PREBUILT_ROOT."
}

$IsOpencvShipSlice = $Slice -match '-shared-release$'
$OpencvDist = Join-Path $DistRoot "opencv"
if ((Test-Path $OpencvDist) -and (-not $IsOpencvShipSlice) -and (-not $AllowOpencvNonShip)) {
    Write-Warning ((
        "opencv ship slice is shared-release only; excluding dist/{0}/opencv from SyncToPrebuilt. " +
        "Pass -AllowOpencvNonShip if this non-ship slice is intentional."
    ) -f $Slice)
}

$DestSlice = Join-Path $PrebuiltRoot $Slice
Write-Host "Sync $DistRoot -> $DestSlice"
if (Test-Path $DestSlice) { Remove-Item -Recurse -Force $DestSlice }
New-Item -ItemType Directory -Force -Path $DestSlice | Out-Null
Get-ChildItem -LiteralPath $DistRoot -Force | ForEach-Object {
    if ($_.Name -eq "opencv" -and (-not $IsOpencvShipSlice) -and (-not $AllowOpencvNonShip)) {
        return
    }
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $DestSlice $_.Name) -Recurse -Force
}
Write-Host "Synced. Update MANIFEST.yaml / SHA256SUMS before commit."
