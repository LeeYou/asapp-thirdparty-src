#Requires -Version 5.1
<#
.SYNOPSIS
  将业务仓历史 staged/windows_x86/{debug|release}/<pkg> 导入为新规格
  windows-x86-static-{debug|release}/<pkg>（加速 Win32 矩阵；随后应以源码仓正式构建覆盖）。
#>
param(
    [string]$LegacyRoot = "E:\work\Demo\AsApp\third_party\staged\windows_x86",
    [string]$DestRoot = "",
    [string]$PrebuiltRoot = "E:\work\Demo\Demo\Demo004\asapp-thirdparty-prebuilt",
    [switch]$ToPrebuilt
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if ([string]::IsNullOrWhiteSpace($DestRoot)) {
    $DestRoot = Join-Path $RepoRoot "dist"
}

function Copy-Pkg([string]$Src, [string]$Dst)
{
    if (-not (Test-Path $Src)) { Write-Host "skip missing $Src"; return $false }
    if (Test-Path $Dst) { Remove-Item -Recurse -Force $Dst }
    New-Item -ItemType Directory -Force -Path (Split-Path $Dst -Parent) | Out-Null
    robocopy $Src $Dst /E /NFL /NDL /NJH /NJS /NC /NS | Out-Null
    if (-not (Test-Path (Join-Path $Dst "PACKAGE_META.yaml"))) {
        Set-Content -Encoding utf8 (Join-Path $Dst "PACKAGE_META.yaml") @"
name: $(Split-Path $Dst -Leaf)
kind: imported-legacy
windows_min_os: win7
notes: "Imported from legacy staged/windows_x86; replace with formal source-repo build when ready."
"@
    }
    Write-Host "imported $Src -> $Dst"
    return $true
}

foreach ($cfg in @("debug", "release"))
{
    $slice = "windows-x86-static-$cfg"
    $legacyCfg = Join-Path $LegacyRoot $cfg
    foreach ($pkg in @("openssl", "gtest", "grpc", "spdlog"))
    {
        $src = Join-Path $legacyCfg $pkg
        $dst = Join-Path $DestRoot "$slice\$pkg"
        [void](Copy-Pkg $src $dst)
        if ($ToPrebuilt)
        {
            [void](Copy-Pkg $src (Join-Path $PrebuiltRoot "$slice\$pkg"))
        }
    }
    # libcef 仅 shared-release（官方 runtime）
    if ($cfg -eq "release" -or $cfg -eq "debug")
    {
        $cefSrc = Join-Path $legacyCfg "libcef"
        if (Test-Path $cefSrc)
        {
            $cefSlice = "windows-x86-shared-$cfg"
            [void](Copy-Pkg $cefSrc (Join-Path $DestRoot "$cefSlice\libcef"))
            if ($ToPrebuilt)
            {
                [void](Copy-Pkg $cefSrc (Join-Path $PrebuiltRoot "$cefSlice\libcef"))
            }
        }
    }
}

Write-Host "Legacy import done."
