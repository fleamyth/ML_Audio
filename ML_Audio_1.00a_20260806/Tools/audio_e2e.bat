@echo off
setlocal

set "TargetDir=C:\Users\User\Robocal-v5_Audio"
set /a attemptCount=1

cd /d "%TargetDir%" || exit /b 255

:retry
bazel-bin\robocal\v5\stations\audio\audio_station.exe
set "result=%errorlevel%"

echo Exit code: %result%

if not "%result%"=="204" exit /b %result%
if %attemptCount% geq 3 exit /b 205

set /a attemptCount+=1
echo Retrying... (%attemptCount%/3)
goto retry