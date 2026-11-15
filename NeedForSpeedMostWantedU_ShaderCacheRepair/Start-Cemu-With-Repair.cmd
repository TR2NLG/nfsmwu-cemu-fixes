@echo off
rem Put this file and Repair-ShaderCache.ps1 next to Cemu.exe and start Cemu with it.
rem It removes the shader cache entry that makes Cemu 2.6 crash on start and then starts Cemu.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Repair-ShaderCache.ps1"
start "" "%~dp0Cemu.exe" %*
