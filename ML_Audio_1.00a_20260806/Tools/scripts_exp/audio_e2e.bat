@echo off
setlocal

set "TargetDir=C:\Users\User\Barney_exp"
set /a retryTimes=0

cd /d "%TargetDir%" || exit /b 255

:retry
bazel-bin\robocal\v5\stations\audio\audio_station.exe
set "result=%errorlevel%"

echo Exit code: %result%

if not "%result%"=="204" exit /b %result%
if %retryTimes% geq 3 exit /b 255

set /a retryTimes+=1
echo Retrying... (%retryTimes%/3)
goto retry