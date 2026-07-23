#Requires -Version 5.1
<#
.SYNOPSIS
  将 spdlog 头文件按制品规格写入 slice/<spdlog>/（header-only，无需编译）。
#>
param(
    [Parameter(Mandatory = $true)]
    [string]$SliceRoot,
    [string]$Version = "1.14.1"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$Dest = Join-Path $SliceRoot "spdlog"
if (Test-Path $Dest) { Remove-Item -Recurse -Force $Dest }

$Candidates = @(
    (Join-Path $RepoRoot "sources\spdlog\src\include"),
    (Join-Path $RepoRoot "sources\spdlog\include"),
    (Join-Path $RepoRoot "sources\spdlog\src")
)
$Inc = $null
foreach ($c in $Candidates)
{
    if (Test-Path (Join-Path $c "spdlog\spdlog.h"))
    {
        $Inc = $c
        break
    }
}
if (-not $Inc) { throw "spdlog headers not found under sources/spdlog" }

$DstInc = Join-Path $Dest "include"
New-Item -ItemType Directory -Force -Path $DstInc | Out-Null
$rc = Start-Process -FilePath "robocopy.exe" -ArgumentList @(
    (Join-Path $Inc "spdlog"), (Join-Path $DstInc "spdlog"),
    "/E", "/NFL", "/NDL", "/NJH", "/NJS", "/NC", "/NS"
) -Wait -PassThru
if ($rc.ExitCode -ge 8) { throw "robocopy spdlog failed: $($rc.ExitCode)" }

$CmakeDir = Join-Path $Dest "lib\cmake\spdlog"
New-Item -ItemType Directory -Force -Path $CmakeDir | Out-Null
Set-Content -Encoding utf8 (Join-Path $CmakeDir "spdlogConfig.cmake") @'
if(TARGET spdlog::spdlog)
  return()
endif()
add_library(spdlog INTERFACE)
add_library(spdlog::spdlog ALIAS spdlog)
get_filename_component(_SPDLOG_PREFIX "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
target_include_directories(spdlog INTERFACE "${_SPDLOG_PREFIX}/include")
# 勿定义 SPDLOG_HEADER_ONLY（见 cmake/packages/spdlog.cmake 注释）
'@

Set-Content -Encoding utf8 (Join-Path $Dest "PACKAGE_META.yaml") @"
name: spdlog
version: "$Version"
kind: header-only
license: MIT
windows_min_os: win7
toolchain:
  generator: ninja
  preferred: clang-ninja
"@

Write-Host "spdlog headers packaged -> $Dest"
