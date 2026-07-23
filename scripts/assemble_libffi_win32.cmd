@echo off
REM 预处理 sysv_intel.S（含 #include）后用 MASM 汇编为 obj
REM 用法: assemble_libffi_win32.cmd <src.S> <out.obj> <gen_inc> <ffi_inc> <x86_dir> <src_dir> [static|shared]
setlocal EnableExtensions
set "SRC=%~1"
set "OUT=%~2"
set "GEN=%~3"
set "INC=%~4"
set "X86=%~5"
set "SRCDIR=%~6"
set "LINKAGE=%~7"
if "%SRC%"=="" goto usage
if "%OUT%"=="" goto usage
if "%LINKAGE%"=="" set "LINKAGE=static"

set "IASM=%~dp2sysv_intel.i.asm"
if exist "%IASM%" del /f /q "%IASM%"

set "DEFS=/DFFI_BUILDING /DX86_WIN32"
if /I "%LINKAGE%"=="static" (
  set "DEFS=%DEFS% /DFFI_STATIC_BUILD"
) else (
  set "DEFS=%DEFS% /DFFI_BUILDING_DLL"
)

cl /nologo /EP /I"%GEN%" /I"%INC%" /I"%X86%" /I"%SRCDIR%" %DEFS% "%SRC%" > "%IASM%"
if errorlevel 1 exit /b 1

ml /nologo /c /Fo"%OUT%" "%IASM%"
if errorlevel 1 exit /b 1
exit /b 0

:usage
echo usage: %~nx0 src.S out.obj gen_inc ffi_inc x86_dir src_dir [static^|shared]
exit /b 2
