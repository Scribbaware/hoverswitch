@echo off
rem Starts HoverSwitch in the system tray without a console window.
rem conhost --headless runs PowerShell with no window at all (Windows 11).
start "" conhost.exe --headless powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File "%~dp0HoverSwitch.ps1"
