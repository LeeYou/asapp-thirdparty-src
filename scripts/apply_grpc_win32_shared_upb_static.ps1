# gRPC 1.67.x Windows shared 构建补丁（幂等）
# 1) upb_*/utf8/grpc*_unsecure → ${_gRPC_STATIC_WIN32}
# 2) TraceFlag 全局符号加 GRPC_DLL（修 grpc++.dll 对 grpc.dll 的数据符号 LNK1120）
#Requires -Version 5.1
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceRoot
)

$ErrorActionPreference = "Stop"
$Cmake = Join-Path $SourceRoot "CMakeLists.txt"
$TraceH = Join-Path $SourceRoot "src\core\lib\debug\trace_flags.h"
$TraceCc = Join-Path $SourceRoot "src\core\lib\debug\trace_flags.cc"
if (-not (Test-Path -LiteralPath $Cmake)) { throw "CMakeLists.txt not found: $Cmake" }
if (-not (Test-Path -LiteralPath $TraceH)) { throw "trace_flags.h not found: $TraceH" }
if (-not (Test-Path -LiteralPath $TraceCc)) { throw "trace_flags.cc not found: $TraceCc" }

$marker = "ASAPP_WIN32_SHARED_STATIC_V3"
$cmakeText = Get-Content -LiteralPath $Cmake -Raw

# --- CMakeLists: force STATIC on fragile targets ---
$targets = @(
    "upb_base_lib", "upb_mem_lib", "upb_message_lib", "upb_mini_descriptor_lib",
    "upb_wire_lib", "utf8_range_lib", "grpc_unsecure", "grpc++_unsecure"
)
foreach ($t in $targets)
{
    if ($cmakeText -match ("add_library\(" + [regex]::Escape($t) + "\s+(\`$\{_gRPC_STATIC_WIN32\}|STATIC)"))
    {
        continue
    }
    $pattern = "add_library\(" + [regex]::Escape($t) + "(\r?\n)"
    $replacement = "add_library($t `${_gRPC_STATIC_WIN32}`$1"
    $newText = [regex]::Replace($cmakeText, $pattern, $replacement, 1)
    if ($newText -eq $cmakeText) { throw "Failed to patch add_library($t)" }
    $cmakeText = $newText
}

$anchor = "set(_gRPC_STATIC_WIN32 STATIC)"
if ($cmakeText -notmatch [regex]::Escape($anchor)) { throw "Anchor not found: $anchor" }
# 去掉旧标记，写入 V3
$cmakeText = [regex]::Replace($cmakeText, "(?m)^\s*# ASAPP_WIN32_SHARED_STATIC_V\d+\r?\n", "")
$cmakeText = [regex]::Replace($cmakeText, "(?m)^\s*# ASAPP_UPB_STATIC_WIN32_APPLIED\r?\n", "")
if ($cmakeText -notmatch $marker)
{
    $cmakeText = $cmakeText.Replace($anchor, "$anchor`r`n  # $marker")
}
Set-Content -LiteralPath $Cmake -Value $cmakeText -Encoding UTF8

# --- trace_flags.h: GRPC_DLL on extern TraceFlag* ---
$h = Get-Content -LiteralPath $TraceH -Raw
if ($h -notmatch "ASAPP_TRACE_FLAGS_GRPC_DLL")
{
    if ($h -notmatch "port_platform\.h")
    {
        $h = $h.Replace(
            '#include "src/core/lib/debug/trace_impl.h"',
            "#include <grpc/support/port_platform.h>`r`n`r`n#include `"src/core/lib/debug/trace_impl.h`"  // ASAPP_TRACE_FLAGS_GRPC_DLL")
    }
    $h = $h -replace "(?m)^extern DebugOnlyTraceFlag ", "GRPC_DLL extern DebugOnlyTraceFlag "
    $h = $h -replace "(?m)^extern TraceFlag ", "GRPC_DLL extern TraceFlag "
    Set-Content -LiteralPath $TraceH -Value $h -Encoding UTF8
    Write-Host "Patched trace_flags.h with GRPC_DLL"
}
else
{
    Write-Host "trace_flags.h already patched"
}

# --- trace_flags.cc: GRPC_DLL on definitions ---
$cc = Get-Content -LiteralPath $TraceCc -Raw
if ($cc -notmatch "ASAPP_TRACE_FLAGS_GRPC_DLL")
{
    if ($cc -notmatch "port_platform\.h")
    {
        $cc = $cc.Replace(
            '#include "src/core/lib/debug/trace.h"',
            "#include <grpc/support/port_platform.h>  // ASAPP_TRACE_FLAGS_GRPC_DLL`r`n#include `"src/core/lib/debug/trace.h`"")
    }
    $cc = $cc -replace "(?m)^DebugOnlyTraceFlag ", "GRPC_DLL DebugOnlyTraceFlag "
    $cc = $cc -replace "(?m)^TraceFlag ", "GRPC_DLL TraceFlag "
    Set-Content -LiteralPath $TraceCc -Value $cc -Encoding UTF8
    Write-Host "Patched trace_flags.cc with GRPC_DLL"
}
else
{
    Write-Host "trace_flags.cc already patched"
}

Write-Host "Applied gRPC Win32 shared patch V3"
