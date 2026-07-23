#Requires -Version 5.1
<#
.SYNOPSIS
  第三方源码仓构建公共库（工业级入口共用）。
  约定：优先使用仓库 tool/ 下的工具，再回退 PATH / VS 安装。
#>

$script:AsAppDepRepoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$script:AsAppDepToolRoot = Join-Path $script:AsAppDepRepoRoot "tool"

function Get-AsAppDepParallelJobs
{
    param([int]$Jobs = 0)
    if ($Jobs -gt 0) { return $Jobs }
    $n = [int]$env:NUMBER_OF_PROCESSORS
    if ($n -le 0) { $n = 8 }
    # 预留 2 核给系统，避免满载卡顿
    return [Math]::Max(1, $n - 2)
}

function Resolve-AsAppDepTool
{
    <#
    .SYNOPSIS
      按名称解析工具可执行文件：tool/<name>/** → PATH → 额外候选。
    #>
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string[]]$ExtraCandidates = @()
    )

    $patterns = @(
        (Join-Path $script:AsAppDepToolRoot "$Name\$Name.exe"),
        (Join-Path $script:AsAppDepToolRoot "$Name\bin\$Name.exe"),
        (Join-Path $script:AsAppDepToolRoot "$Name.exe")
    )
    foreach ($p in $patterns)
    {
        if (Test-Path -LiteralPath $p) { return (Resolve-Path $p).Path }
    }

    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd -and $cmd.Source) { return $cmd.Source }

    foreach ($p in $ExtraCandidates)
    {
        if ($p -and (Test-Path -LiteralPath $p)) { return (Resolve-Path $p).Path }
    }
    return $null
}

function Resolve-AsAppDepVsDevCmd
{
    $tool = Resolve-AsAppDepTool -Name "VsDevCmd" -ExtraCandidates @(
        (Join-Path $script:AsAppDepToolRoot "vs\VsDevCmd.bat")
    )
    if ($tool) { return $tool }
    $candidates = @(
        "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\VsDevCmd.bat",
        "C:\Program Files\Microsoft Visual Studio\2022\Professional\Common7\Tools\VsDevCmd.bat",
        "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat"
    )
    return ($candidates | Where-Object { Test-Path $_ } | Select-Object -First 1)
}

function Invoke-AsAppDepVsDevCommand
{
    param(
        [Parameter(Mandatory = $true)][ValidateSet("x86", "x64", "amd64")][string]$Arch,
        [Parameter(Mandatory = $true)][string]$CommandLine,
        [string]$VsDevCmdPath = ""
    )
    if ([string]::IsNullOrWhiteSpace($VsDevCmdPath))
    {
        $VsDevCmdPath = Resolve-AsAppDepVsDevCmd
    }
    if (-not $VsDevCmdPath -or -not (Test-Path $VsDevCmdPath))
    {
        throw "VsDevCmd.bat not found. Place a copy under tool/vs/ or install VS2022."
    }
    $vsArch = if ($Arch -eq "x86") { "x86" } else { "amd64" }
    $bat = Join-Path $env:TEMP ("asapp_dep_{0}.cmd" -f [guid]::NewGuid().ToString("N"))
    @(
        "@echo off",
        "call `"$VsDevCmdPath`" -arch=$vsArch -host_arch=amd64 >nul",
        "if errorlevel 1 exit /b 1",
        $CommandLine,
        "exit /b %ERRORLEVEL%"
    ) -join "`r`n" | Set-Content -Path $bat -Encoding ASCII
    try
    {
        & cmd.exe /c "`"$bat`""
        if ($LASTEXITCODE -ne 0)
        {
            throw "VsDevCmd command failed ($LASTEXITCODE): $CommandLine"
        }
    }
    finally
    {
        Remove-Item -Force $bat -ErrorAction SilentlyContinue
    }
}

function Get-AsAppDepSliceName
{
    param(
        [string]$Os = "windows",
        [Parameter(Mandatory = $true)][string]$Arch,
        [Parameter(Mandatory = $true)][string]$Linkage,
        [Parameter(Mandatory = $true)][string]$Config
    )
    return "{0}-{1}-{2}-{3}" -f $Os, $Arch, $Linkage, $Config
}
