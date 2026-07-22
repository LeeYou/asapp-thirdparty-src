<#
.SYNOPSIS
  统一构建入口（Windows）：按包独立 configure/build/install 到 dist/<slice>/<pkg>。
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
    [switch]$HeaderOnlyOnly
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot

$Slice = "{0}-{1}-{2}-{3}" -f $Os, $Arch, $Linkage, $Config
if ([string]::IsNullOrWhiteSpace($InstallRoot)) {
    $InstallRoot = Join-Path $RepoRoot "dist\$Slice"
}

$CmakeBuildType = if ($Config -eq "release") { "Release" } else { "Debug" }
$Toolchain = Join-Path $RepoRoot "cmake\toolchains\windows-clang-cl.cmake"
$CmakeSource = Join-Path $RepoRoot "cmake"
$HeaderOnlyPkgs = @("nlohmann_json", "stb")

New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null
Write-Host "Slice: $Slice -> $InstallRoot"

foreach ($pkg in ($Packages -split ",")) {
    $pkg = $pkg.Trim()
    if (-not $pkg) { continue }

    if ($HeaderOnlyOnly -and ($HeaderOnlyPkgs -notcontains $pkg)) {
        Write-Host "Skip non-header-only package under -HeaderOnlyOnly: $pkg"
        continue
    }

    # header-only：无需编译器，直接布局
    if ($HeaderOnlyPkgs -contains $pkg) {
        & (Join-Path $PSScriptRoot "package_header_only.ps1") -Package $pkg -SliceRoot $InstallRoot
        continue
    }

    $PkgBuild = Join-Path $RepoRoot "build\$Slice\$pkg"
    $PkgDest = Join-Path $InstallRoot $pkg
    if (Test-Path $PkgDest) { Remove-Item -Recurse -Force $PkgDest }
    New-Item -ItemType Directory -Force -Path $PkgBuild, $PkgDest | Out-Null

    Write-Host "Building compiled package: $pkg"
    & cmake -G Ninja -S $CmakeSource -B $PkgBuild --toolchain $Toolchain `
        "-DCMAKE_BUILD_TYPE=$CmakeBuildType" `
        "-DCMAKE_INSTALL_PREFIX=$PkgDest" `
        "-DASAPP_DEP_OS=$Os" `
        "-DASAPP_DEP_ARCH=$Arch" `
        "-DASAPP_DEP_LINKAGE=$Linkage" `
        "-DASAPP_DEP_CONFIG=$Config" `
        "-DASAPP_DEP_PACKAGES=$pkg"
    if ($LASTEXITCODE -ne 0) { throw "configure failed: $pkg" }
    & cmake --build $PkgBuild
    if ($LASTEXITCODE -ne 0) { throw "build failed: $pkg" }
    & cmake --install $PkgBuild
    if ($LASTEXITCODE -ne 0) { throw "install failed: $pkg" }
}

Write-Host "Done. Slice root: $InstallRoot"
