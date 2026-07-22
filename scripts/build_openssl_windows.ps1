<#
.SYNOPSIS
  鏋勫缓 OpenSSL 鍒?dist/<slice>/openssl锛圵indows锛夈€?
  宸ュ叿閾句緥澶栵細perl + VsDevCmd + nmake锛堝畼鏂?Windows 璺緞锛夛紱鐧昏涓?clang-ninja 鐭╅樀澶栦緥澶栥€?
  榛樿 static锛欳onfigure 鍔?no-shared銆?
#>
param(
    [ValidateSet("x64", "x86")]
    [string]$Arch = "x64",
    [ValidateSet("static", "shared")]
    [string]$Linkage = "static",
    [ValidateSet("debug", "release")]
    [string]$Config = "release",
    [string]$SourceRoot = "",
    [string]$InstallRoot = "",
    [string]$BuildRoot = "",
    [string]$VsDevCmdPath = "",
    [string]$PerlPath = "",
    [string]$NMakePath = ""
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Join-Path $RepoRoot "sources\openssl\src"
}
if (-not (Test-Path (Join-Path $SourceRoot "Configure"))) {
    throw "OpenSSL Configure not found under $SourceRoot"
}

$Slice = "windows-$Arch-$Linkage-$Config"
if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $InstallRoot = Join-Path $RepoRoot "dist\$Slice\openssl"
}
if ([string]::IsNullOrWhiteSpace($BuildRoot)) {
    $BuildRoot = Join-Path $RepoRoot "build\$Slice\openssl"
}

function Resolve-Abs([string]$PathText) {
    if ([System.IO.Path]::IsPathRooted($PathText)) {
        return [System.IO.Path]::GetFullPath($PathText)
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $PathText))
}

if ([string]::IsNullOrWhiteSpace($PerlPath)) {
    $perlCmd = Get-Command perl -ErrorAction SilentlyContinue
    if ($perlCmd) {
        $PerlPath = $perlCmd.Source
    } else {
        $PerlPath = "C:\Program Files\Git\usr\bin\perl.exe"
    }
}
if ([string]::IsNullOrWhiteSpace($VsDevCmdPath)) {
    $vsCandidates = @(
        "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\VsDevCmd.bat",
        "C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\Tools\VsDevCmd.bat",
        "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat"
    )
    $VsDevCmdPath = $vsCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if ([string]::IsNullOrWhiteSpace($VsDevCmdPath) -or -not (Test-Path $VsDevCmdPath)) {
    throw "VsDevCmd.bat not found"
}
if ([string]::IsNullOrWhiteSpace($NMakePath) -or -not (Test-Path $NMakePath)) {
    $nmakeCandidates = Get-ChildItem "C:\Program Files\Microsoft Visual Studio\2022" -Recurse -Filter nmake.exe -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -match "Hostx64\\x64\\nmake.exe" } |
        Sort-Object FullName -Descending
    if (-not $nmakeCandidates) {
        throw "nmake.exe not found"
    }
    $NMakePath = $nmakeCandidates[0].FullName
}

$SourceRoot = Resolve-Abs $SourceRoot
$InstallRoot = Resolve-Abs $InstallRoot
$BuildRoot = Resolve-Abs $BuildRoot
$PerlPath = Resolve-Abs $PerlPath
$VsDevCmdPath = Resolve-Abs $VsDevCmdPath
$NMakePath = Resolve-Abs $NMakePath

# 浣跨敤骞插噣鎷疯礉鏋勫缓锛岄伩鍏嶆薄鏌?sources
$WorkSrc = Join-Path $BuildRoot "src"
if (Test-Path $BuildRoot) { Remove-Item -Recurse -Force $BuildRoot }
New-Item -ItemType Directory -Force -Path $WorkSrc, $InstallRoot | Out-Null
Write-Host "Copying OpenSSL sources to work tree (may take a while)..."
robocopy $SourceRoot $WorkSrc /E /XD .git /XF *.obj *.lib *.dll *.exp *.pdb *.map /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
# robocopy exit codes 0-7 are success-ish
if ($LASTEXITCODE -ge 8) { throw "robocopy failed: $LASTEXITCODE" }

$Target = if ($Arch -eq "x86") { "VC-WIN32" } else { "VC-WIN64A" }
$vsArch = if ($Arch -eq "x86") { "x86" } else { "x64" }
$cfgOpts = "$Target no-asm no-tests no-docs"
if ($Linkage -eq "static") { $cfgOpts += " no-shared" }
if ($Config -eq "debug") { $cfgOpts += " --debug" }

$logDir = Join-Path $BuildRoot "logs"
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$buildLog = Join-Path $logDir "build.log"
$stderrLog = Join-Path $logDir "build-stderr.log"

$cmd = @"
call "$VsDevCmdPath" -arch=$vsArch -host_arch=x64
if errorlevel 1 exit /b 1
cd /d "$WorkSrc"
"$PerlPath" Configure $cfgOpts --prefix="$InstallRoot" --openssldir="$InstallRoot\ssl"
if errorlevel 1 exit /b 1
"$NMakePath"
if errorlevel 1 exit /b 1
"$NMakePath" install_sw
if errorlevel 1 exit /b 1
"@

$runFile = Join-Path $BuildRoot "run-openssl.cmd"
Set-Content -LiteralPath $runFile -Value $cmd -Encoding ASCII
Write-Host "Building OpenSSL ($Slice) via perl+nmake..."
    # 直接 cmd /c，避免 Start-Process 破坏重定向
    cmd.exe /c "`"$runFile`" > `"$buildLog`" 2>`"$stderrLog`""
    if ($LASTEXITCODE -ne 0) {
        Get-Content $buildLog -Tail 40 -ErrorAction SilentlyContinue
        Get-Content $stderrLog -Tail 40 -ErrorAction SilentlyContinue
        throw "OpenSSL build failed: $LASTEXITCODE"
    }

$sslH = Join-Path $InstallRoot "include\openssl\ssl.h"
$libSsl = Join-Path $InstallRoot "lib\libssl.lib"
$libCrypto = Join-Path $InstallRoot "lib\libcrypto.lib"
if (-not (Test-Path $sslH)) { throw "missing $sslH" }
if (-not (Test-Path $libSsl)) { throw "missing $libSsl" }
if (-not (Test-Path $libCrypto)) { throw "missing $libCrypto" }

# OpenSSLConfig.cmake for find_package(OpenSSL)
$cmakeDir = Join-Path $InstallRoot "lib\cmake\OpenSSL"
New-Item -ItemType Directory -Force -Path $cmakeDir | Out-Null
@'
if(TARGET OpenSSL::SSL)
  return()
endif()
get_filename_component(_OPENSSL_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
add_library(OpenSSL::Crypto STATIC IMPORTED)
set_target_properties(OpenSSL::Crypto PROPERTIES
  IMPORTED_LOCATION "${_OPENSSL_ROOT}/lib/libcrypto.lib"
  INTERFACE_INCLUDE_DIRECTORIES "${_OPENSSL_ROOT}/include")
add_library(OpenSSL::SSL STATIC IMPORTED)
set_target_properties(OpenSSL::SSL PROPERTIES
  IMPORTED_LOCATION "${_OPENSSL_ROOT}/lib/libssl.lib"
  INTERFACE_INCLUDE_DIRECTORIES "${_OPENSSL_ROOT}/include"
  INTERFACE_LINK_LIBRARIES OpenSSL::Crypto)
set(OPENSSL_FOUND TRUE)
set(OPENSSL_INCLUDE_DIR "${_OPENSSL_ROOT}/include")
set(OPENSSL_CRYPTO_LIBRARY "${_OPENSSL_ROOT}/lib/libcrypto.lib")
set(OPENSSL_SSL_LIBRARY "${_OPENSSL_ROOT}/lib/libssl.lib")
set(OPENSSL_VERSION "3.5.6")
'@ | Set-Content -Encoding utf8 (Join-Path $cmakeDir "OpenSSLConfig.cmake")

@'
name: openssl
version: "3.5.6"
kind: compiled
license: Apache-2.0
windows_min_os: win7
toolchain:
  generator: nmake
  preferred: clang-ninja
  exception: "perl+VsDevCmd+nmake (OpenSSL official Windows path)"
  windows_driver: msvc
  abi: msvc
'@ | Set-Content -Encoding utf8 (Join-Path $InstallRoot "PACKAGE_META.yaml")

Write-Host "OpenSSL staged: $InstallRoot"
