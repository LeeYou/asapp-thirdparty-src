#Requires -Version 5.1
<#
.SYNOPSIS
  将 Boost 头树同步到制品仓切片（header-only，无 b2）。
#>
param(
    [string]$SourceRoot = "",
    [Parameter(Mandatory = $true)]
    [string]$DestRoot,
    [string]$Version = "1.90.0"
)

$ErrorActionPreference = "Stop"

if (-not $SourceRoot) {
    $RepoRoot = Split-Path $PSScriptRoot -Parent
    $SourceRoot = Join-Path $RepoRoot "sources\boost\src"
}

$BoostHeaders = Join-Path $SourceRoot "boost"
$Asio = Join-Path $BoostHeaders "asio.hpp"
$Beast = Join-Path $BoostHeaders "beast\core.hpp"
if (-not (Test-Path $Asio)) {
    throw "Missing $Asio — place Boost $Version under $SourceRoot"
}
if (-not (Test-Path $Beast)) {
    throw "Missing $Beast"
}

$IncludeBoost = Join-Path $DestRoot "include\boost"
$CmakeDir = Join-Path $DestRoot "lib\cmake\boost"
New-Item -ItemType Directory -Force -Path $IncludeBoost | Out-Null
New-Item -ItemType Directory -Force -Path $CmakeDir | Out-Null

Write-Host "Robocopy $BoostHeaders -> $IncludeBoost"
$rc = Start-Process -FilePath "robocopy.exe" -ArgumentList @(
    $BoostHeaders, $IncludeBoost, "/E", "/NFL", "/NDL", "/NJH", "/NJS", "/NC", "/NS"
) -Wait -PassThru
# robocopy: 0-7 success
if ($rc.ExitCode -ge 8) {
    throw "robocopy failed with exit $($rc.ExitCode)"
}

$Meta = @"
name: boost
version: "$Version"
kind: header-only
license: BSL-1.0
windows_min_os: win7
notes: "Full boost/ header tree for Asio + Beast (no b2 libs)"
toolchain:
  generator: ninja
  preferred: clang-ninja
"@
Set-Content -Path (Join-Path $DestRoot "PACKAGE_META.yaml") -Value $Meta -Encoding utf8

$Config = @'
if(TARGET Boost::headers)
  return()
endif()
get_filename_component(_BOOST_PREFIX "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
add_library(Boost::headers INTERFACE IMPORTED)
set_target_properties(Boost::headers PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES "${_BOOST_PREFIX}/include")
if(NOT TARGET AsApp::boost)
  add_library(AsApp::boost INTERFACE IMPORTED)
  set_target_properties(AsApp::boost PROPERTIES INTERFACE_LINK_LIBRARIES Boost::headers)
endif()
'@
Set-Content -Path (Join-Path $CmakeDir "boostConfig.cmake") -Value $Config -Encoding utf8

Write-Host "Boost header-only package ready at $DestRoot"
