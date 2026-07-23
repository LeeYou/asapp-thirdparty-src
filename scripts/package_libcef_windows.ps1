#Requires -Version 5.1
<#
.SYNOPSIS
  将官方 CEF binary bundle 打包为制品规格切片 windows-{x64|x86}-shared-release/libcef。

.DESCRIPTION
  CEF 以官方预编译包为主（非 Ninja 重编）。输出适配器布局（include/Release/Resources/locales
  + sdk 用 cmake/libcef_dll），并生成 AsApp::libcef 的 Config。
  默认排除 cef_sandbox.lib（体积大且 app-gui 当前 USE_SANDBOX=OFF）。
  官方包通常仅提供 Release runtime → 对应 shared-release 切片。
#>
param(
    [ValidateSet("x64", "x86")]
    [string]$Arch = "x64",
    [string]$BundleRoot = "",
    [Parameter(Mandatory = $true)]
    [string]$DestRoot,
    [string]$Version = "102.0.10+gf249b2e+chromium-102.0.5005.115",
    [switch]$IncludeSandbox
)

$ErrorActionPreference = "Stop"
$BundleSuffix = if ($Arch -eq "x86") { "windows32" } else { "windows64" }
. (Join-Path $PSScriptRoot "AsAppDepCommon.ps1")

function Resolve-BundleRoot([string]$Hint, [string]$Suffix)
{
    $resolved = Resolve-AsAppDepCefBundleRoot -Hint $Hint -Suffix $Suffix
    if ($resolved) { return $resolved }
    throw "CEF $Suffix bundle not found. Pass -BundleRoot / set ASAPP_CEF_BUNDLE or place under sources/libcef/src."
}

function Copy-Tree([string]$Source, [string]$Dest)
{
    if (-not (Test-Path $Source))
    {
        throw "Missing source: $Source"
    }
    New-Item -ItemType Directory -Force -Path $Dest | Out-Null
    $rc = Start-Process -FilePath "robocopy.exe" -ArgumentList @(
        $Source, $Dest, "/E", "/NFL", "/NDL", "/NJH", "/NJS", "/NC", "/NS", "/XD", ".git"
    ) -Wait -PassThru
    if ($rc.ExitCode -ge 8)
    {
        throw "robocopy failed ($($rc.ExitCode)): $Source -> $Dest"
    }
}

$Bundle = Resolve-BundleRoot $BundleRoot $BundleSuffix
Write-Host "Arch:   $Arch ($BundleSuffix)"
Write-Host "Bundle: $Bundle"
Write-Host "Dest:   $DestRoot"

if (Test-Path $DestRoot)
{
    Remove-Item -Recurse -Force $DestRoot
}
New-Item -ItemType Directory -Force -Path $DestRoot | Out-Null

Copy-Tree (Join-Path $Bundle "include") (Join-Path $DestRoot "include")
Copy-Tree (Join-Path $Bundle "cmake") (Join-Path $DestRoot "cmake")
Copy-Tree (Join-Path $Bundle "libcef_dll") (Join-Path $DestRoot "libcef_dll")

$ReleaseSrc = Join-Path $Bundle "Release"
$ReleaseDst = Join-Path $DestRoot "Release"
New-Item -ItemType Directory -Force -Path $ReleaseDst | Out-Null
Get-ChildItem -LiteralPath $ReleaseSrc -Force | ForEach-Object {
    if ((-not $IncludeSandbox) -and ($_.Name -eq "cef_sandbox.lib"))
    {
        Write-Host "Skip $($_.Name)"
        return
    }
    Copy-Item -LiteralPath $_.FullName -Destination $ReleaseDst -Force
}

# Resources（不含 locales）+ 顶层 locales（与历史 stage-libcef 一致）
$ResSrc = Join-Path $Bundle "Resources"
$ResDst = Join-Path $DestRoot "Resources"
$LocDst = Join-Path $DestRoot "locales"
New-Item -ItemType Directory -Force -Path $ResDst, $LocDst | Out-Null

Get-ChildItem -LiteralPath $ResSrc -Force | Where-Object { $_.Name -ne "locales" } | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $ResDst -Recurse -Force
}
$LocSrc = Join-Path $ResSrc "locales"
if (Test-Path $LocSrc)
{
    Copy-Tree $LocSrc $LocDst
}

# lib/：import lib（与 Release 硬链接）；运行时 DLL 仅保留在 Release/，避免制品体积翻倍
$LibDst = Join-Path $DestRoot "lib"
New-Item -ItemType Directory -Force -Path $LibDst | Out-Null
Get-ChildItem -LiteralPath $ReleaseDst -Filter "*.lib" -Force | ForEach-Object {
    $Link = Join-Path $LibDst $_.Name
    if (Test-Path $Link) { Remove-Item $Link -Force }
    New-Item -ItemType HardLink -Path $Link -Target $_.FullName | Out-Null
}

$CmakeDir = Join-Path $DestRoot "lib\cmake\libcef"
New-Item -ItemType Directory -Force -Path $CmakeDir | Out-Null
$Config = @'
if(TARGET AsApp::libcef)
  return()
endif()
get_filename_component(_LIBCEF_PREFIX "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
add_library(AsApp::libcef UNKNOWN IMPORTED)
if(WIN32)
  set_target_properties(AsApp::libcef PROPERTIES
    IMPORTED_LOCATION "${_LIBCEF_PREFIX}/lib/libcef.lib"
    INTERFACE_INCLUDE_DIRECTORIES "${_LIBCEF_PREFIX}/include")
else()
  set_target_properties(AsApp::libcef PROPERTIES
    IMPORTED_LOCATION "${_LIBCEF_PREFIX}/lib/libcef.so"
    INTERFACE_INCLUDE_DIRECTORIES "${_LIBCEF_PREFIX}/include")
endif()
set(AsApp_libcef_PREFIX "${_LIBCEF_PREFIX}" CACHE PATH "AsApp libcef package root")
set(AsApp_libcef_BIN_DIR "${_LIBCEF_PREFIX}/Release" CACHE PATH "AsApp libcef runtime bin (Release/)")
set(AsApp_libcef_RELEASE_DIR "${_LIBCEF_PREFIX}/Release" CACHE PATH "AsApp libcef Release")
set(AsApp_libcef_RESOURCES_DIR "${_LIBCEF_PREFIX}/Resources" CACHE PATH "AsApp libcef Resources")
set(AsApp_libcef_LOCALES_DIR "${_LIBCEF_PREFIX}/locales" CACHE PATH "AsApp libcef locales")
set(AsApp_libcef_SDK_ROOT "${_LIBCEF_PREFIX}" CACHE PATH "AsApp libcef SDK root (FindCEF/libcef_dll)")
'@
Set-Content -Path (Join-Path $CmakeDir "libcefConfig.cmake") -Value $Config -Encoding utf8

$Meta = @"
name: libcef
version: "$Version"
kind: shared-runtime
license: BSD-like
windows_min_os: win7
notes: "Official CEF binary stage (no rebuild). Sandbox lib excluded by default. Wrapper sources under libcef_dll/. Runtime DLLs live in Release/ (CEF upstream layout)."
linkage: shared
toolchain:
  generator: n/a-official-binary
  preferred: msvc-abi-prebuilt
runtime_files:
  - Release/*.dll
  - Release/*.bin
  - Release/*.json
plugin_dirs:
  - locales
  - Resources
paths:
  include: include
  lib: lib
  bin: Release
  resources: Resources
  locales: locales
  sdk_cmake: cmake
  sdk_wrapper: libcef_dll
"@
Set-Content -Path (Join-Path $DestRoot "PACKAGE_META.yaml") -Value $Meta -Encoding utf8

# 许可证副本
foreach ($Name in @("LICENSE.txt", "README.txt"))
{
    $Src = Join-Path $Bundle $Name
    if (Test-Path $Src)
    {
        Copy-Item $Src $DestRoot -Force
    }
}

Write-Host "libcef package ready at $DestRoot"
Get-ChildItem $DestRoot | ForEach-Object { Write-Host ("  " + $_.Name) }
