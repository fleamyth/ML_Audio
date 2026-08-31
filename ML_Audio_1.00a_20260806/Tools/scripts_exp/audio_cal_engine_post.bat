@echo off
set "TargetDir=C:\Users\User\Barney_exp"
if "%~1"=="" (
  cmd /c "cd /d "C:\Users\User\Barney_exp" && bazel-bin\robocal\v5\stations\audio\audio_station.exe --post_analysis"
) else (
  cmd /c "cd /d "C:\Users\User\Barney_exp" && bazel-bin\robocal\v5\stations\audio\audio_station.exe --post_analysis --post_analysis_path="%~1""
)
pause
