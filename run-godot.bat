@echo off
set "LOCAL_GODOT=%~dp0work\godot\Godot_v4.5-stable_win64.exe"
if exist "%LOCAL_GODOT%" (
  "%LOCAL_GODOT%" %*
  exit /b %ERRORLEVEL%
)
where godot >nul 2>nul
if %ERRORLEVEL% EQU 0 (
  godot %*
  exit /b %ERRORLEVEL%
)
echo Godot was not found. Install Godot 4.5+ or place the portable executable at:
echo %LOCAL_GODOT%
exit /b 1
