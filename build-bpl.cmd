@echo off
REM ============================================================
REM IDEScroll IDE package build script (Win32)
REM The RAD Studio IDE is a 32-bit process, so the design-time
REM package MUST be built for Win32.
REM Default: Delphi 13 / RAD Studio 37.0 (LIBSUFFIX AUTO -> IDEScrollPkg370.bpl)
REM For other versions, change the STUDIO path below and build inside that IDE.
REM ============================================================
setlocal

set "STUDIO=C:\Program Files (x86)\Embarcadero\Studio\37.0"

if not exist "%STUDIO%\bin\dcc32.exe" (
  echo [ERROR] dcc32.exe not found under "%STUDIO%".
  echo         Edit the STUDIO path in build-bpl.cmd.
  exit /b 1
)

if not exist "%~dp0bin" mkdir "%~dp0bin"
if not exist "%~dp0dcu" mkdir "%~dp0dcu"

REM cd into the package folder so the "in '..\exe\...'" paths inside the .dpk resolve correctly.
pushd "%~dp0src\bpl"

"%STUDIO%\bin\dcc32.exe" --no-config -B ^
  -U"%STUDIO%\lib\Win32\release" ^
  -NS"System;Winapi;Vcl;Data;Xml" ^
  -LE"%~dp0bin" ^
  -LN"%~dp0dcu" ^
  -N0"%~dp0dcu" ^
  IDEScrollPkg.dpk

popd

endlocal
