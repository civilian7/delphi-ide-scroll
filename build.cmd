@echo off
REM ============================================================
REM IDEScroll Win64 build script
REM Default: Delphi 13 / RAD Studio 37.0
REM For other versions, change the STUDIO path below.
REM ============================================================
setlocal

set "STUDIO=C:\Program Files (x86)\Embarcadero\Studio\37.0"

if not exist "%STUDIO%\bin\dcc64.exe" (
  echo [ERROR] dcc64.exe not found under "%STUDIO%".
  echo         Edit the STUDIO path in build.cmd.
  exit /b 1
)

if not exist "%~dp0bin" mkdir "%~dp0bin"
if not exist "%~dp0dcu" mkdir "%~dp0dcu"

"%STUDIO%\bin\brcc32.exe" "%~dp0src\IDEScroll.rc"

"%STUDIO%\bin\dcc64.exe" --no-config -B ^
  -U"%STUDIO%\lib\Win64\release" ^
  -NS"System;Winapi;Vcl;Vcl.Samples;Data;Xml" ^
  -E"%~dp0bin" ^
  -N0"%~dp0dcu" ^
  "%~dp0src\IDEScroll.dpr"

endlocal
