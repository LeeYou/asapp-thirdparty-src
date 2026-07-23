#Requires -Version 5.1
<#
.SYNOPSIS
  扫描制品仓切片目录，重写 MANIFEST.yaml（保留 schema/defaults，刷新 packages 切片列表）。
#>
param(
    [string]$PrebuiltRoot = "E:\work\Demo\Demo\Demo004\asapp-thirdparty-prebuilt",
    [string]$Tag = "",
    [string]$SourceCommit = ""
)

$ErrorActionPreference = "Stop"
if (-not (Test-Path (Join-Path $PrebuiltRoot "MANIFEST.yaml")))
{
    throw "MANIFEST.yaml not found under $PrebuiltRoot"
}

# 收集 slice/pkg
$pkgMap = @{}  # name -> list of slice info
Get-ChildItem -LiteralPath $PrebuiltRoot -Directory | Where-Object {
    $_.Name -match '^(windows|linux|macos)-'
} | ForEach-Object {
    $slice = $_.Name
    $parts = $slice -split '-'
    if ($parts.Count -lt 4) { return }
    $os = $parts[0]
    $arch = $parts[1]
    $linkage = $parts[2]
    $config = $parts[3]
    Get-ChildItem $_.FullName -Directory | ForEach-Object {
        $name = $_.Name
        $meta = Join-Path $_.FullName "PACKAGE_META.yaml"
        $ver = ""
        $kind = ""
        if (Test-Path $meta)
        {
            foreach ($line in Get-Content $meta)
            {
                if ($line -match '^\s*version:\s*"?([^"]+)"?\s*$') { $ver = $Matches[1].Trim() }
                if ($line -match '^\s*kind:\s*"?([^"]+)"?\s*$') { $kind = $Matches[1].Trim() }
            }
        }
        if (-not $pkgMap.ContainsKey($name))
        {
            $pkgMap[$name] = @{
                version = $ver
                kind = $kind
                slices = New-Object System.Collections.Generic.List[object]
            }
        }
        if ($ver -and -not $pkgMap[$name].version) { $pkgMap[$name].version = $ver }
        if ($kind -and -not $pkgMap[$name].kind) { $pkgMap[$name].kind = $kind }
        $pkgMap[$name].slices.Add([ordered]@{
            os = $os; arch = $arch; linkage = $linkage; config = $config
            path = "$slice/$name"
        }) | Out-Null
    }
}

if (-not $Tag)
{
    $Tag = "deps-" + (Get-Date -Format "yyyy.MM.dd") + "-win32"
}
if (-not $SourceCommit)
{
    $srcRepo = "E:\work\Demo\Demo\Demo003\asapp-thirdparty-src"
    if (Test-Path (Join-Path $srcRepo ".git"))
    {
        $SourceCommit = (git -C $srcRepo rev-parse HEAD).Trim()
    }
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine("schema_version: 1")
[void]$sb.AppendLine("prebuilt_tag: `"$Tag`"")
[void]$sb.AppendLine("source_repo: `"https://github.com/LeeYou/asapp-thirdparty-src`"")
[void]$sb.AppendLine("source_repo_commit: `"$SourceCommit`"")
[void]$sb.AppendLine("created_at: `"$(Get-Date -Format 'yyyy-MM-dd')T00:00:00Z`"")
[void]$sb.AppendLine("defaults:")
[void]$sb.AppendLine("  linkage: static")
[void]$sb.AppendLine("  windows_min_os: win7")
[void]$sb.AppendLine("  toolchain:")
[void]$sb.AppendLine("    generator: ninja")
[void]$sb.AppendLine("    preferred: clang-ninja")
[void]$sb.AppendLine("    windows_driver: clang-cl")
[void]$sb.AppendLine("    abi: msvc")
[void]$sb.AppendLine("packages:")

foreach ($name in ($pkgMap.Keys | Sort-Object))
{
    $p = $pkgMap[$name]
    $ver = if ($p.version) { $p.version } else { "unknown" }
    $kind = if ($p.kind) { $p.kind } else { "compiled" }
    [void]$sb.AppendLine("  - name: $name")
    [void]$sb.AppendLine("    version: `"$ver`"")
    [void]$sb.AppendLine("    kind: $kind")
    [void]$sb.AppendLine("    slices:")
    foreach ($s in ($p.slices | Sort-Object { $_.path }))
    {
        [void]$sb.AppendLine("      - os: $($s.os)")
        [void]$sb.AppendLine("        arch: $($s.arch)")
        [void]$sb.AppendLine("        linkage: $($s.linkage)")
        [void]$sb.AppendLine("        config: $($s.config)")
        [void]$sb.AppendLine("        path: $($s.path)")
    }
}

$out = Join-Path $PrebuiltRoot "MANIFEST.yaml"
Set-Content -LiteralPath $out -Value $sb.ToString() -Encoding utf8
Write-Host "Wrote $out (tag=$Tag, packages=$($pkgMap.Count))"
