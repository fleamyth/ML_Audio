@echo off 
set "TargetDir=C:\Users\User\Robocal-v5_Audio" 
cmd /c "cd /d "C:\Users\User\Robocal-v5_Audio" && bazel-bin\robocal\v5\stations\audio\audio_station.exe" 
