@echo off
rem ===========================================================================
rem  Double-click to open the Godot editor for the Daishu project (F5 to play).
rem
rem  Why this launcher exists: on this machine Godot cannot create its user://
rem  directories under the real %APPDATA%, and crashes (signal 11) before the
rem  project loads. This wrapper runs tools\run-godot.ps1 -Editor, which
rem  redirects APPDATA / LOCALAPPDATA to <workspace>\.godot-userdata first.
rem ===========================================================================
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-godot.ps1" -Editor
if errorlevel 1 pause