#Requires -Version 5.1
<#
.SYNOPSIS
  为已有 openssl 的 windows-x86 四切片补编 gRPC（高并发）。
#>
param(
    [string]$PrebuiltRoot = "",
    [switch]$SyncToPrebuilt,
    [int]$Jobs = 0,
    [ValidateSet("all", "static", "shared")]
    [string]$LinkageFilter = "all",
    [ValidateSet("all", "debug", "release")]
    [string]$ConfigFilter = "all"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
Set-Location $RepoRoot
. (Join-Path $PSScriptRoot "AsAppDepCommon.ps1")
$Jobs = Get-AsAppDepParallelJobs -Jobs $Jobs
if ([string]::IsNullOrWhiteSpace($PrebuiltRoot)) {
    $PrebuiltRoot = Resolve-AsAppDepPrebuiltRoot
}
if ($SyncToPrebuilt -and -not $PrebuiltRoot) {
    throw "Prebuilt root not found. Pass -PrebuiltRoot or set ASAPP_PREBUILT_ROOT."
}
$Linkages = @("static", "shared")
$Configs = @("debug", "release")
if ($LinkageFilter -ne "all") { $Linkages = @($LinkageFilter) }
if ($ConfigFilter -ne "all") { $Configs = @($ConfigFilter) }

Write-Host "gRPC Win32 matrix jobs=$Jobs linkages=$($Linkages -join ',') configs=$($Configs -join ',')"

foreach ($link in $Linkages)
{
    foreach ($cfg in $Configs)
    {
        $slice = "windows-x86-$link-$cfg"
        $dist = Join-Path $RepoRoot "dist\$slice"
        $ssl = Join-Path $dist "openssl"
        if (-not (Test-Path (Join-Path $ssl "include\openssl\ssl.h")))
        {
            $ssl = Join-Path $PrebuiltRoot "$slice\openssl"
        }
        if (-not (Test-Path (Join-Path $ssl "include\openssl\ssl.h")))
        {
            throw "OpenSSL missing for $slice (need dist or prebuilt)"
        }
        Write-Host "`n======== gRPC $slice ========"
        & (Join-Path $PSScriptRoot "build_grpc_windows.ps1") `
            -Arch x86 -Linkage $link -Config $cfg `
            -OpenSslRoot $ssl `
            -InstallRoot (Join-Path $dist "grpc") `
            -Jobs $Jobs
        if ($SyncToPrebuilt)
        {
            $dst = Join-Path $PrebuiltRoot "$slice\grpc"
            if (Test-Path $dst) { Remove-Item -Recurse -Force $dst }
            New-Item -ItemType Directory -Force -Path (Split-Path $dst -Parent) | Out-Null
            robocopy (Join-Path $dist "grpc") $dst /E /NFL /NDL /NJH /NJS /NC /NS | Out-Null
            # robocopy: 0-7 均为成功类退出码
            if ($LASTEXITCODE -ge 8)
            {
                throw "robocopy failed for $slice grpc (exit=$LASTEXITCODE)"
            }
            $global:LASTEXITCODE = 0
            Write-Host "Synced grpc -> $dst"
        }
    }
}

Write-Host "gRPC Win32 matrix done."
