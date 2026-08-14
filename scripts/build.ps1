#Requires -Version 5.1
<#
.SYNOPSIS
  统一构建入口（Windows）：按包独立 configure/build/install 到 dist/<slice>/<pkg>。
  -Arch x86 时通过 VsDevCmd -arch=x86 + clang-cl target triple 保证真正 32 位 ABI。
  支持 -Jobs 并发（cmake --build --parallel）。
#>
param(
    [ValidateSet("windows", "linux", "macos")]
    [string]$Os = "windows",
    [ValidateSet("x64", "x86", "arm64", "loongarch64")]
    [string]$Arch = "x64",
    [ValidateSet("static", "shared")]
    [string]$Linkage = "static",
    [ValidateSet("debug", "release")]
    [string]$Config = "release",
    [string]$Packages = "nlohmann_json,stb",
    [string]$InstallRoot = "",
    [switch]$HeaderOnlyOnly,
    [string]$VsDevCmdPath = "",
    [int]$Jobs = 0
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot
. (Join-Path $PSScriptRoot "AsAppDepCommon.ps1")

$Jobs = Get-AsAppDepParallelJobs -Jobs $Jobs
$Slice = Get-AsAppDepSliceName -Os $Os -Arch $Arch -Linkage $Linkage -Config $Config
if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $InstallRoot = Join-Path $RepoRoot "dist\$Slice"
}

$CmakeBuildType = if ($Config -eq "release") { "Release" } else { "Debug" }
$Toolchain = Join-Path $RepoRoot "cmake\toolchains\windows-clang-cl.cmake"
$CmakeSource = Join-Path $RepoRoot "cmake"
$HeaderOnlyPkgs = @("nlohmann_json", "stb", "spdlog", "boost")

if ([string]::IsNullOrWhiteSpace($VsDevCmdPath)) {
    $VsDevCmdPath = Resolve-AsAppDepVsDevCmd
}
if ($Os -eq "windows" -and ([string]::IsNullOrWhiteSpace($VsDevCmdPath) -or -not (Test-Path $VsDevCmdPath))) {
    throw "VsDevCmd.bat not found (required for Windows ABI-correct builds). See tool/README.md"
}

$VsArch = if ($Arch -eq "x86") { "x86" } else { "amd64" }
$ClangTarget = if ($Arch -eq "x86") { "i686-pc-windows-msvc" } else { "x86_64-pc-windows-msvc" }

New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
Write-Host "Slice: $Slice -> $InstallRoot (VsDevCmd -arch=$VsArch, clang=$ClangTarget, jobs=$Jobs)"

foreach ($pkg in ($Packages -split ",")) {
    $pkg = $pkg.Trim()
    if (-not $pkg) { continue }

    if ($HeaderOnlyOnly -and ($HeaderOnlyPkgs -notcontains $pkg)) {
        Write-Host "Skip non-header-only package under -HeaderOnlyOnly: $pkg"
        continue
    }

    if ($pkg -eq "spdlog") {
        & (Join-Path $PSScriptRoot "package_spdlog_headers.ps1") -SliceRoot $InstallRoot
        continue
    }
    if ($pkg -eq "opencv") {
        $opencvMarker = Join-Path $RepoRoot "sources\opencv\src\CMakeLists.txt"
        if (-not (Test-Path $opencvMarker)) {
            & (Join-Path $PSScriptRoot "extract_archive.ps1") -Package opencv
        }
        if (-not (Test-Path $opencvMarker)) {
            throw "opencv source missing. Place archives/opencv/opencv-4.5.5.zip and run extract_archive.ps1 -Package opencv"
        }
        # 切片正式交付 = shared-release；库在配方内强制 STATIC（与切片 linkage 解耦）
        Write-Host "opencv: ship_slice=shared-release; library_linkage=STATIC (forced in recipe)"
        if ($Linkage -ne "shared" -or $Config -ne "release") {
            Write-Warning ((
                "opencv ship slice is shared-release (library is always static); building {0}-{1}-{2}-{3}. " +
                "Do not SyncToPrebuilt as delivery unless this non-ship slice is intentional."
            ) -f $Os, $Arch, $Linkage, $Config)
        }
    }
    if ($pkg -eq "boost") {
        $boostSrc = Resolve-AsAppDepBoostSourceRoot
        if (-not $boostSrc) {
            & (Join-Path $PSScriptRoot "extract_archive.ps1") -Package boost -ErrorAction SilentlyContinue
            $boostSrc = Resolve-AsAppDepBoostSourceRoot
        }
        if (-not $boostSrc) {
            throw "boost headers not found. Set ASAPP_BOOST_SRC or place tree under sources/boost/src (see sources/boost/README.md)."
        }
        & (Join-Path $PSScriptRoot "sync_boost_headers.ps1") `
            -SourceRoot $boostSrc `
            -DestRoot (Join-Path $InstallRoot "boost")
        continue
    }
    if ($HeaderOnlyPkgs -contains $pkg) {
        & (Join-Path $PSScriptRoot "package_header_only.ps1") -Package $pkg -SliceRoot $InstallRoot
        continue
    }

    $PkgBuild = Join-Path $RepoRoot "build\$Slice\$pkg"
    $PkgDest = Join-Path $InstallRoot $pkg
    if (Test-Path $PkgDest) { Remove-Item -Recurse -Force $PkgDest }
    if (Test-Path $PkgBuild) { Remove-Item -Recurse -Force $PkgBuild }
    New-Item -ItemType Directory -Force -Path $PkgBuild, $PkgDest | Out-Null

    Write-Host "Building compiled package: $pkg (parallel=$Jobs)"
    $env:ASAPP_DEP_ARCH = $Arch
    $env:ASAPP_DEP_CLANG_TARGET = $ClangTarget
    $cfgCmd = @(
        "cmake -G Ninja -S `"$CmakeSource`" -B `"$PkgBuild`" --toolchain `"$Toolchain`"",
        "-DCMAKE_BUILD_TYPE=$CmakeBuildType",
        "-DCMAKE_INSTALL_PREFIX=`"$PkgDest`"",
        "-DCMAKE_C_COMPILER_TARGET=$ClangTarget",
        "-DCMAKE_CXX_COMPILER_TARGET=$ClangTarget",
        "-DASAPP_DEP_OS=$Os",
        "-DASAPP_DEP_ARCH=$Arch",
        "-DASAPP_DEP_LINKAGE=$Linkage",
        "-DASAPP_DEP_CONFIG=$Config",
        "-DASAPP_DEP_PACKAGES=$pkg"
    ) -join " "
    Invoke-AsAppDepVsDevCommand -Arch $VsArch -VsDevCmdPath $VsDevCmdPath -CommandLine $cfgCmd
    Invoke-AsAppDepVsDevCommand -Arch $VsArch -VsDevCmdPath $VsDevCmdPath `
        -CommandLine "cmake --build `"$PkgBuild`" --parallel $Jobs"
    Invoke-AsAppDepVsDevCommand -Arch $VsArch -VsDevCmdPath $VsDevCmdPath `
        -CommandLine "cmake --install `"$PkgBuild`""

    # opencv：切片 shared-release ≠ 动态库；安装树禁止 dll/so
    if ($pkg -eq "opencv") {
        $dyn = @(Get-ChildItem -LiteralPath $PkgDest -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -match '^\.(dll|so|dylib)$' -or $_.Name -match '\.so\.' })
        if ($dyn.Count -gt 0) {
            $list = ($dyn | ForEach-Object { $_.FullName }) -join "`n  "
            throw "opencv must be STATIC-only after install; found dynamic libs:`n  $list"
        }
        $libs = @(Get-ChildItem -LiteralPath (Join-Path $PkgDest "lib") -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in @(".lib", ".a") -or $_.Name -like "libopencv*" })
        if ($libs.Count -lt 1) {
            throw "opencv static install missing: expected .lib/.a under $PkgDest\lib"
        }
        Write-Host "opencv install OK: static libs only under $PkgDest (no dll/so)"
    }
}

Write-Host "Done. Slice root: $InstallRoot"
