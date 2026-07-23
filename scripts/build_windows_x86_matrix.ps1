#Requires -Version 5.1
<#
.SYNOPSIS
  产出 Windows x86 主交付四切片：static|shared × debug|release。

.DESCRIPTION
  顺序：
  1) header-only（nlohmann/stb/spdlog/boost）布局到四切片
  2) sqlite/gtest/libffi 经 build.ps1（VsDevCmd x86）编译四组合
  3) openssl / grpc 专用脚本四组合
  4) libcef → 仅 windows-x86-shared-release（官方 binary）
  5) 可选 SyncToPrebuilt

  权威：AsApp docs/enterprisev3.0/third_party/09-主交付编译矩阵.md
#>
param(
    [string]$Packages = "nlohmann_json,stb,spdlog,boost,sqlite,gtest,libffi,openssl,grpc,libcef",
    [string]$PrebuiltRoot = "",
    [switch]$SkipGrpc,
    [switch]$SkipOpenssl,
    [switch]$SkipLibcef,
    [switch]$SyncToPrebuilt,
    [ValidateSet("all", "static", "shared")]
    [string]$LinkageFilter = "all",
    [ValidateSet("all", "debug", "release")]
    [string]$ConfigFilter = "all",
    [int]$Jobs = 0,
    [string]$CefBundleRoot = "",
    [string]$BoostSourceRoot = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot
. (Join-Path $PSScriptRoot "AsAppDepCommon.ps1")
$Jobs = Get-AsAppDepParallelJobs -Jobs $Jobs
Write-Host "Matrix parallel jobs: $Jobs"

if ([string]::IsNullOrWhiteSpace($PrebuiltRoot))
{
    $PrebuiltRoot = Resolve-AsAppDepPrebuiltRoot
}
if ($SyncToPrebuilt -and -not $PrebuiltRoot)
{
    throw "Prebuilt root not found. Pass -PrebuiltRoot or set ASAPP_PREBUILT_ROOT / nest prebuilt submodule."
}

$Linkages = @("static", "shared")
$Configs = @("debug", "release")
if ($LinkageFilter -ne "all") { $Linkages = @($LinkageFilter) }
if ($ConfigFilter -ne "all") { $Configs = @($ConfigFilter) }

$PkgList = @($Packages -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$HeaderPkgs = @("nlohmann_json", "stb", "spdlog", "boost") | Where-Object { $PkgList -contains $_ }
$CmakePkgs = @("sqlite", "gtest", "libffi") | Where-Object { $PkgList -contains $_ }
$WantOpenssl = ($PkgList -contains "openssl") -and (-not $SkipOpenssl)
$WantGrpc = ($PkgList -contains "grpc") -and (-not $SkipGrpc)
$WantLibcef = ($PkgList -contains "libcef") -and (-not $SkipLibcef)

function Invoke-HeaderSlice([string]$SliceRoot)
{
    foreach ($pkg in $HeaderPkgs)
    {
        if ($pkg -eq "boost")
        {
            $boostSrc = Resolve-AsAppDepBoostSourceRoot -Hint $BoostSourceRoot
            if (-not $boostSrc)
            {
                throw "boost headers not found. Set ASAPP_BOOST_SRC / -BoostSourceRoot or sources/boost/src."
            }
            & (Join-Path $PSScriptRoot "sync_boost_headers.ps1") `
                -SourceRoot $boostSrc `
                -DestRoot (Join-Path $SliceRoot "boost")
            continue
        }
        if ($pkg -eq "spdlog")
        {
            & (Join-Path $PSScriptRoot "package_spdlog_headers.ps1") -SliceRoot $SliceRoot
            continue
        }
        & (Join-Path $PSScriptRoot "package_header_only.ps1") -Package $pkg -SliceRoot $SliceRoot
    }
}

Write-Host "=== Windows x86 matrix: linkages=$($Linkages -join ',') configs=$($Configs -join ',') ==="

foreach ($link in $Linkages)
{
    foreach ($cfg in $Configs)
    {
        $slice = "windows-x86-$link-$cfg"
        $dist = Join-Path $RepoRoot "dist\$slice"
        Write-Host "`n======== $slice ========"

        New-Item -ItemType Directory -Force -Path $dist | Out-Null
        Invoke-HeaderSlice -SliceRoot $dist

        if ($CmakePkgs.Count -gt 0)
        {
            $joined = ($CmakePkgs -join ",")
            & (Join-Path $PSScriptRoot "build.ps1") `
                -Os windows -Arch x86 -Linkage $link -Config $cfg `
                -Packages $joined -InstallRoot $dist -Jobs $Jobs
        }

        if ($WantOpenssl)
        {
            & (Join-Path $PSScriptRoot "build_openssl_windows.ps1") `
                -Arch x86 -Linkage $link -Config $cfg `
                -InstallRoot (Join-Path $dist "openssl") -Jobs $Jobs
        }

        if ($WantGrpc)
        {
            & (Join-Path $PSScriptRoot "build_grpc_windows.ps1") `
                -Arch x86 -Linkage $link -Config $cfg `
                -InstallRoot (Join-Path $dist "grpc") -Jobs $Jobs
        }

        if ($SyncToPrebuilt)
        {
            & (Join-Path $PSScriptRoot "sync_to_prebuilt.ps1") -Slice $slice -PrebuiltRoot $PrebuiltRoot
        }
    }
}

if ($WantLibcef)
{
    $cefSlice = "windows-x86-shared-release"
    $cefDest = Join-Path $RepoRoot "dist\$cefSlice\libcef"
    Write-Host "`n======== libcef -> $cefSlice ========"
    $cefBundle = Resolve-AsAppDepCefBundleRoot -Hint $CefBundleRoot -Suffix "windows32"
    if (-not $cefBundle)
    {
        throw "CEF windows32 bundle not found. Pass -CefBundleRoot / set ASAPP_CEF_BUNDLE or place under sources/libcef/src."
    }
    & (Join-Path $PSScriptRoot "package_libcef_windows.ps1") `
        -Arch x86 `
        -DestRoot $cefDest `
        -BundleRoot $cefBundle
    if ($SyncToPrebuilt)
    {
        $preCef = Join-Path $PrebuiltRoot "$cefSlice\libcef"
        if (Test-Path $preCef) { Remove-Item -Recurse -Force $preCef }
        New-Item -ItemType Directory -Force -Path (Split-Path $preCef -Parent) | Out-Null
        Copy-Item -Path $cefDest -Destination $preCef -Recurse -Force
        Write-Host "Synced libcef -> $preCef"
    }
}

Write-Host "`nDone. dist roots under $($RepoRoot)\dist\windows-x86-*"
