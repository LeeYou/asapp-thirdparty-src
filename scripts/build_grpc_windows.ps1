<#
.SYNOPSIS
  构建 gRPC(+捆绑 protobuf) 并安装到 dist/<slice>/grpc。
  Windows 工具链例外：VsDevCmd + Ninja + MSVC cl（MSVC ABI）；与 OpenSSL 制品联动。

.EXAMPLE
  .\scripts\build_grpc_windows.ps1 -Arch x64 -Linkage static -Config release
#>
param(
    [ValidateSet("x64", "x86")]
    [string]$Arch = "x64",
    [ValidateSet("static", "shared")]
    [string]$Linkage = "static",
    [ValidateSet("debug", "release")]
    [string]$Config = "release",
    [string]$SourceRoot = "",
    [string]$OpenSslRoot = "",
    [string]$InstallRoot = "",
    [string]$BuildRoot = "",
    [string]$VsDevCmdPath = "",
    [int]$Jobs = 0
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot
. (Join-Path $PSScriptRoot "AsAppDepCommon.ps1")
$Jobs = Get-AsAppDepParallelJobs -Jobs $Jobs
if ([string]::IsNullOrWhiteSpace($VsDevCmdPath)) {
    $VsDevCmdPath = Resolve-AsAppDepVsDevCmd
}

$Os = "windows"
$Slice = "{0}-{1}-{2}-{3}" -f $Os, $Arch, $Linkage, $Config

if ([string]::IsNullOrWhiteSpace($SourceRoot)) {
    $SourceRoot = Join-Path $RepoRoot "sources\grpc\src"
}
if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $InstallRoot = Join-Path $RepoRoot "dist\$Slice\grpc"
}
if ([string]::IsNullOrWhiteSpace($BuildRoot)) {
    $BuildRoot = Join-Path $RepoRoot "build\$Slice\grpc"
}
if ([string]::IsNullOrWhiteSpace($OpenSslRoot)) {
    $Candidate = Join-Path $RepoRoot "dist\$Slice\openssl"
    if (Test-Path (Join-Path $Candidate "include\openssl\ssl.h")) {
        $OpenSslRoot = $Candidate
    } else {
        $Candidate = Join-Path $RepoRoot "prebuilt\$Slice\openssl"
        if (Test-Path (Join-Path $Candidate "include\openssl\ssl.h")) {
            $OpenSslRoot = $Candidate
        }
    }
}

function Resolve-Abs([string]$PathText) {
    if ([System.IO.Path]::IsPathRooted($PathText)) {
        return [System.IO.Path]::GetFullPath($PathText)
    }
    return [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $PathText))
}

$SourceRoot = Resolve-Abs $SourceRoot
$InstallRoot = Resolve-Abs $InstallRoot
$BuildRoot = Resolve-Abs $BuildRoot
if (-not [string]::IsNullOrWhiteSpace($OpenSslRoot)) {
    $OpenSslRoot = Resolve-Abs $OpenSslRoot
}

if (-not (Test-Path (Join-Path $SourceRoot "CMakeLists.txt"))) {
    throw "gRPC source CMakeLists.txt not found: $SourceRoot"
}
if (-not (Test-Path -LiteralPath $VsDevCmdPath)) {
    throw "VsDevCmd not found: $VsDevCmdPath"
}
if ([string]::IsNullOrWhiteSpace($OpenSslRoot) -or -not (Test-Path (Join-Path $OpenSslRoot "include\openssl\ssl.h"))) {
    throw "OpenSSL root with include/openssl/ssl.h required. Pass -OpenSslRoot or build openssl into dist/$Slice/openssl first."
}

$CmakeBuildType = if ($Config -eq "release") { "Release" } else { "Debug" }
$VsArch = if ($Arch -eq "x86") { "x86" } else { "x64" }
$SharedFlag = if ($Linkage -eq "shared") { "ON" } else { "OFF" }

Write-Host "gRPC build"
Write-Host "  Source : $SourceRoot"
Write-Host "  OpenSSL: $OpenSslRoot"
Write-Host "  Build  : $BuildRoot"
Write-Host "  Install: $InstallRoot"
Write-Host "  Slice  : $Slice"

# Win32/x64 shared：补齐 upb STATIC（见 patches/grpc/README.md）
if ($Linkage -eq "shared")
{
    & (Join-Path $PSScriptRoot "apply_grpc_win32_shared_upb_static.ps1") -SourceRoot $SourceRoot
}

New-Item -ItemType Directory -Force -Path $BuildRoot, $InstallRoot | Out-Null
$LogDir = Join-Path $BuildRoot "logs"
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

$ConfigureScript = Join-Path $LogDir "configure.cmd"
$BuildScript = Join-Path $LogDir "build.cmd"
$InstallScript = Join-Path $LogDir "install.cmd"

$CmakeArgList = @(
    "-G", "Ninja",
    "-S", "`"$SourceRoot`"",
    "-B", "`"$BuildRoot`"",
    "-DCMAKE_BUILD_TYPE=$CmakeBuildType",
    "-DCMAKE_INSTALL_PREFIX=`"$InstallRoot`"",
    "-DBUILD_SHARED_LIBS=$SharedFlag",
    "-DgRPC_BUILD_TESTS=OFF",
    "-DgRPC_BUILD_GRPC_CSHARP_PLUGIN=OFF",
    "-DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF",
    "-DgRPC_BUILD_GRPC_OBJECTIVE_C_PLUGIN=OFF",
    "-DgRPC_BUILD_GRPC_PHP_PLUGIN=OFF",
    "-DgRPC_BUILD_GRPC_PYTHON_PLUGIN=OFF",
    "-DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF",
    "-DgRPC_INSTALL=ON",
    "-DgRPC_SSL_PROVIDER=package",
    "-DOPENSSL_ROOT_DIR=`"$OpenSslRoot`"",
    "-DgRPC_ZLIB_PROVIDER=module",
    "-DgRPC_CARES_PROVIDER=module",
    "-DgRPC_RE2_PROVIDER=module",
    "-DgRPC_ABSL_PROVIDER=module",
    "-DgRPC_PROTOBUF_PROVIDER=module",
    "-Dprotobuf_BUILD_TESTS=OFF",
    "-Dprotobuf_INSTALL=ON",
    "-DCMAKE_CXX_STANDARD=17",
    # Win7 SP1 API 面（与 08 / 制品 windows_min_os: win7 对齐）
    "`"-DCMAKE_C_FLAGS=/D_WIN32_WINNT=0x0601 /DWINVER=0x0601`"",
    "`"-DCMAKE_CXX_FLAGS=/D_WIN32_WINNT=0x0601 /DWINVER=0x0601`""
)
# shared：关闭 protobuf 自带 libupb，避免与 vendored upb 符号冲突（grpc#35794）
if ($Linkage -eq "shared")
{
    $CmakeArgList += "-Dprotobuf_BUILD_LIBUPB=OFF"
}
$CmakeArgs = $CmakeArgList -join " "

@"
@echo off
call "$VsDevCmdPath" -arch=$VsArch -host_arch=x64 || exit /b 1
cmake $CmakeArgs
exit /b %ERRORLEVEL%
"@ | Set-Content -Encoding ASCII $ConfigureScript

@"
@echo off
call "$VsDevCmdPath" -arch=$VsArch -host_arch=x64 || exit /b 1
REM shared：protoc 插件依赖构建目录中的 DLL（0xC0000135 = STATUS_DLL_NOT_FOUND）
set "PATH=$BuildRoot;$BuildRoot\bin;%PATH%"
cmake --build "$BuildRoot" --parallel $Jobs
exit /b %ERRORLEVEL%
"@ | Set-Content -Encoding ASCII $BuildScript

@"
@echo off
call "$VsDevCmdPath" -arch=$VsArch -host_arch=x64 || exit /b 1
set "PATH=$BuildRoot;$BuildRoot\bin;%PATH%"
cmake --install "$BuildRoot"
exit /b %ERRORLEVEL%
"@ | Set-Content -Encoding ASCII $InstallScript

function Invoke-LoggedCmd {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [Parameter(Mandatory = $true)][string]$LogPath,
        [Parameter(Mandatory = $true)][string]$FailMessage
    )
    # 用 cmd 重定向，避免 PowerShell 把 cmake stderr Warning 当成终止错误
    $fullCmd = "cmd.exe /c `"`"$ScriptPath`" > `"$LogPath`" 2>&1`""
    Write-Host "  Running: $ScriptPath"
    cmd.exe /c "`"$ScriptPath`" > `"$LogPath`" 2>&1"
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        if (Test-Path $LogPath) {
            Write-Host "---- log tail: $LogPath ----"
            Get-Content -LiteralPath $LogPath -Tail 40
        }
        throw "$FailMessage (exit=$code, see $LogPath)"
    }
}

Write-Host "Configuring..."
Invoke-LoggedCmd -ScriptPath $ConfigureScript `
    -LogPath (Join-Path $LogDir "configure.log") `
    -FailMessage "gRPC cmake configure failed"

Write-Host "Building (this can take a long time)..."
Invoke-LoggedCmd -ScriptPath $BuildScript `
    -LogPath (Join-Path $LogDir "build.log") `
    -FailMessage "gRPC build failed"

Write-Host "Installing..."
if (Test-Path $InstallRoot) {
    Get-ChildItem -LiteralPath $InstallRoot -Force | Remove-Item -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
Invoke-LoggedCmd -ScriptPath $InstallScript `
    -LogPath (Join-Path $LogDir "install.log") `
    -FailMessage "gRPC install failed"

# PACKAGE_META
@"
name: grpc
version: "1.67.1"
kind: compiled
license: Apache-2.0
windows_min_os: win7
components:
  - protobuf (bundled 27.2)
  - protoc
  - grpc_cpp_plugin
toolchain:
  generator: ninja
  preferred: clang-ninja
  exception: "VsDevCmd + Ninja + MSVC cl (gRPC Windows reliability); SSL via prebuilt OpenSSL package"
  windows_driver: msvc
  abi: msvc
"@ | Set-Content -Encoding utf8 (Join-Path $InstallRoot "PACKAGE_META.yaml")

$Protoc = Join-Path $InstallRoot "bin\protoc.exe"
$Plugin = Join-Path $InstallRoot "bin\grpc_cpp_plugin.exe"
$Cfg = Join-Path $InstallRoot "lib\cmake\grpc\gRPCConfig.cmake"
foreach ($p in @($Protoc, $Plugin, $Cfg)) {
    if (-not (Test-Path $p)) { throw "Missing expected install artifact: $p" }
}

Write-Host "Done. gRPC installed to $InstallRoot"
