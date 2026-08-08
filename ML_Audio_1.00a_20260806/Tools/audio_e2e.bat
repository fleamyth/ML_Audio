@echo off 
set "TargetDir=C:\Users\User\Robocal-v5_Audio" 
cd /d "C:\Users\User\Robocal-v5_Audio"
bazel-bin\robocal\v5\stations\audio\audio_station.exe > "%~dp0AudioE2E.log" 2>&1
find /i "FAILED!" AudioE2E.log
echo %errorlevel%
if %errorlevel% equ 0 exit /b 255
exit /b 0