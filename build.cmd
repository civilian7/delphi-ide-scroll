@echo off
REM ============================================================
REM IDEScroll standalone EXE build script (Win64)
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

REM cd into the project folder so the "in '..\common\...'" path inside the .dpr resolves correctly.
pushd "%~dp0src\exe"

"%STUDIO%\bin\brcc32.exe" IDEScroll.rc

"%STUDIO%\bin\dcc64.exe" --no-config -B ^
  -U"%STUDIO%\lib\Win64\release" ^
  -NS"System;Winapi;Vcl;Vcl.Samples;Data;Xml" ^
  -E"%~dp0bin" ^
  -N0"%~dp0dcu" ^
  IDEScroll.dpr

popd

endlocal
