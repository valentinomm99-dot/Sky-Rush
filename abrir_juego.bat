@echo off
cd /d "%~dp0"
set "GODOT_EXE=%CD%\.tools\godot-4.7\Godot_v4.7-stable_win64.exe"

if not exist "%GODOT_EXE%" (
  echo No se encontro Godot en:
  echo %GODOT_EXE%
  pause
  exit /b 1
)

start "" "%GODOT_EXE%" --path .
