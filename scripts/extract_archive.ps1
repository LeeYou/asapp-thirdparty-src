#Requires -Version 5.1
<#
.SYNOPSIS
  从 archives/<pkg>/ 解压受控源码包到 sources/<pkg>/src（gitignore，不入库）。
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("boost", "openssl")]
    [string]$Package,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
. (Join-Path $PSScriptRoot "AsAppDepCommon.ps1")

function Assert-Sha256([string]$File, [string]$Expect)
{
    if ([string]::IsNullOrWhiteSpace($Expect)) { return }
    $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $File).Hash.ToLowerInvariant()
    if ($hash -ne $Expect.ToLowerInvariant())
    {
        throw "SHA256 mismatch for $File`n  expect=$Expect`n  actual=$hash"
    }
}

switch ($Package)
{
    "boost"
    {
        $Zip = Join-Path $RepoRoot "archives\boost\boost_1_90_0.zip"
        $Dest = Join-Path $RepoRoot "sources\boost\src"
        $Marker = Join-Path $Dest "boost\asio.hpp"
        # 用户投放/官方镜像可能校验和不同；以实际文件为准（见 archives/boost/README.md）
        $ExpectSha = "bdc79f179d1a4a60c10fe764172946d0eeafad65e576a8703c4d89d49949973c"
        if ((Test-Path $Marker) -and (-not $Force))
        {
            Write-Host "boost already extracted: $Dest"
            return
        }
        if (-not (Test-Path $Zip)) { throw "missing archive: $Zip" }
        Assert-Sha256 $Zip $ExpectSha
        $Tmp = Join-Path $RepoRoot "build\_extract\boost"
        if (Test-Path $Tmp) { Remove-Item -Recurse -Force $Tmp }
        New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
        Write-Host "Extracting $Zip (tar) ..."
        # Expand-Archive 对大 zip 极慢；Windows tar 可直接解 zip
        tar -xf $Zip -C $Tmp
        if ($LASTEXITCODE -ne 0) { throw "tar extract failed: $Zip" }
        $Inner = Join-Path $Tmp "boost_1_90_0"
        if (-not (Test-Path (Join-Path $Inner "boost\asio.hpp")))
        {
            throw "unexpected boost zip layout (need boost_1_90_0/boost/asio.hpp)"
        }
        if (Test-Path $Dest) { Remove-Item -Recurse -Force $Dest }
        New-Item -ItemType Directory -Force -Path (Split-Path $Dest -Parent) | Out-Null
        Move-Item -LiteralPath $Inner -Destination $Dest
        Write-Host "boost -> $Dest"
    }
    "openssl"
    {
        $Tar = Join-Path $RepoRoot "archives\openssl\openssl-3.5.6.tar.gz"
        $Dest = Join-Path $RepoRoot "sources\openssl\src"
        $Marker = Join-Path $Dest "Configure"
        if ((Test-Path $Marker) -and (-not $Force))
        {
            Write-Host "openssl already extracted: $Dest"
            return
        }
        if (-not (Test-Path $Tar)) { throw "missing archive: $Tar" }
        $Tmp = Join-Path $RepoRoot "build\_extract\openssl"
        if (Test-Path $Tmp) { Remove-Item -Recurse -Force $Tmp }
        New-Item -ItemType Directory -Force -Path $Tmp | Out-Null
        Write-Host "Extracting $Tar ..."
        tar -xf $Tar -C $Tmp
        $Inner = Join-Path $Tmp "openssl-3.5.6"
        if (-not (Test-Path (Join-Path $Inner "Configure")))
        {
            throw "unexpected openssl archive layout"
        }
        if (Test-Path $Dest) { Remove-Item -Recurse -Force $Dest }
        New-Item -ItemType Directory -Force -Path (Split-Path $Dest -Parent) | Out-Null
        Move-Item -LiteralPath $Inner -Destination $Dest
        Write-Host "openssl -> $Dest"
    }
}
