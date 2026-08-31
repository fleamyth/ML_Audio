@echo off
set "TargetDir=C:\Users\User\Barney_exp"
cmd /c "cd /d "C:\Users\User\Barney_exp" && bazel-bin\robocal\v5\stations\audio\audio_station.exe --smoke_test"
pause
