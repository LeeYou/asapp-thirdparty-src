<#
.SYNOPSIS
  将 header-only 包按制品规格写入 slice 根下的 <pkg>/ 目录（无需编译器）。
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("nlohmann_json", "stb")]
    [string]$Package,
    [Parameter(Mandatory = $true)]
    [string]$SliceRoot
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$Dest = Join-Path $SliceRoot $Package
if (Test-Path $Dest) { Remove-Item -Recurse -Force $Dest }

switch ($Package) {
    "nlohmann_json" {
        $Src = Join-Path $RepoRoot "sources\nlohmann\src\single_include\nlohmann"
        if (-not (Test-Path (Join-Path $Src "json.hpp"))) {
            throw "nlohmann source missing: $Src\json.hpp"
        }
        $Inc = Join-Path $Dest "include\nlohmann"
        New-Item -ItemType Directory -Force -Path $Inc | Out-Null
        Copy-Item (Join-Path $Src "json.hpp") $Inc -Force

        $CmakeDir = Join-Path $Dest "lib\cmake\nlohmann_json"
        New-Item -ItemType Directory -Force -Path $CmakeDir | Out-Null
        Set-Content -Encoding utf8 (Join-Path $CmakeDir "nlohmann_jsonConfig.cmake") @'
if(TARGET nlohmann_json::nlohmann_json)
  return()
endif()
add_library(nlohmann_json::nlohmann_json INTERFACE IMPORTED)
get_filename_component(_NLOHMANN_PREFIX "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set_target_properties(nlohmann_json::nlohmann_json PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES "${_NLOHMANN_PREFIX}/include")
'@

        Set-Content -Encoding utf8 (Join-Path $Dest "PACKAGE_META.yaml") @'
name: nlohmann_json
version: "3.11.3"
kind: header-only
license: MIT
windows_min_os: win7
toolchain:
  generator: ninja
  preferred: clang-ninja
'@
    }
    "stb" {
        $Src = Join-Path $RepoRoot "sources\stb\src"
        foreach ($h in @("stb_image.h", "stb_image_write.h", "stb_truetype.h")) {
            if (-not (Test-Path (Join-Path $Src $h))) { throw "stb missing: $h" }
        }
        $Inc = Join-Path $Dest "include\stb"
        New-Item -ItemType Directory -Force -Path $Inc | Out-Null
        Copy-Item (Join-Path $Src "*.h") $Inc -Force

        $CmakeDir = Join-Path $Dest "lib\cmake\stb"
        New-Item -ItemType Directory -Force -Path $CmakeDir | Out-Null
        Set-Content -Encoding utf8 (Join-Path $CmakeDir "stbConfig.cmake") @'
if(TARGET AsApp::stb)
  return()
endif()
add_library(AsApp::stb INTERFACE IMPORTED)
get_filename_component(_STB_PREFIX "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set_target_properties(AsApp::stb PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES "${_STB_PREFIX}/include")
'@

        Set-Content -Encoding utf8 (Join-Path $Dest "PACKAGE_META.yaml") @'
name: stb
version: "master-pinned"
kind: header-only
license: Public Domain / MIT-like
windows_min_os: win7
toolchain:
  generator: ninja
  preferred: clang-ninja
'@
    }
}

Write-Host "Packaged $Package -> $Dest"
