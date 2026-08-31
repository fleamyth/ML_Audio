@echo off
call scripts_exp\audio_e2e.bat
call audio_e2e.bat
adb disconnect
exit /b 0