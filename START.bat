REM Program Description
REM Copyright by Pegatron, Build Date:2016-11-02 Rev1.01f, Diagnostics
REM ============================================================
@echo on
IF /I "%~1"=="__UPLOAD_GRR_WORKER" GOTO UPLOAD_GRR_WORKER
IF EXIST op.dat DEL op.dat
REM ===== Version Setting =====
SET Ver=1.00a
SET DateVer=20260806
REM ===========================
SET TYPE=%1
SET MODE=%2
SET TEST_MODE=Online
IF "%MODE%" EQU "D" SET TEST_MODE=Offline
SET PROJECT=ML
SET SUITE_NAME=ML_Audio
SET BUILD=MP
SET CSV_NAME=%PROJECT%_%TYPE%.csv
SET CFG_NAME=config.xml
IF "%DebugXML%" equ "True" SET CFG_NAME=config_Deb.xml
SET SN_LEN=12
SET FOLDER=%SUITE_NAME%_%Ver%_%DateVer%
SET on_Drive=N:
SET SFIS_IP=172.24.248.128
SET Connect=FALSE
SET "GOOGLE_DRIVE_URL=https://drive.google.com/drive/folders/1VuN9N7JXBBuHByXVgUjm1jEw18wSW_N6"
SET "GOOGLE_DRIVE_UPLOAD_BAT=%~dp0%FOLDER%\Tools\upload_Folder_to_google_drive.bat"
SET "DESKTOP_DIR="
FOR /F "usebackq delims=" %%D IN (`powershell.exe -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) DO SET "DESKTOP_DIR=%%D"
IF NOT DEFINED DESKTOP_DIR SET "DESKTOP_DIR=%USERPROFILE%\Desktop"
SET "LOG_ROOT=%DESKTOP_DIR%\logs"
SET /a SCAN=0

:START_OP
IF NOT EXIST C:\MFGlog\%TYPE%log\event mkdir C:\MFGlog\%TYPE%log\event
IF EXIST MISClog.dat DEL MISClog.dat
IF "%MODE%" NEQ "D" ECHO C:\MISClog>MISClog.dat

SET Result=
cd %~dp0
IF EXIST %CSV_NAME% DEL %CSV_NAME%
IF EXIST *KoreVer.log DEL *KoreVer.log
IF EXIST PN.log DEL PN.log
IF EXIST PN.txt DEL PN.txt
IF EXIST op.dat GOTO START

DiagPGM\Chopper-diag.exe /SB "^[Ss][0-9]{2}[0-9,AaBbCc][0-9]{5}$" -SIF op.jpg -EMF sb_msg_OP.msgdat -SFN ..\OP.dat -FS 30 -st "Please scan operator number\nPlease Enter Operator Number" -sbsize 800 300
IF %ERRORLEVEL% NEQ 0 GOTO START_OP

:START
adb kill-server
DiagPGM\Screen-diag.exe -nl -enter /SS 55 "<br>Please connect the device.<br> <br>Press [Enter] to start the test." 0xFFFFFF -bg 0x223366
adb get-state 2>nul | findstr /X /C:"device" >nul
adb root
adb shell aflags disable com.android.microxr.flags.enable_wifi_connection_access_point
adb shell setprop persist.microxr.internetaccess.disable_wifi_control true
adb reboot
IF %ERRORLEVEL% NEQ 0 GOTO START

SET ScanTime=0

:GetDutSN
REM Get SN from DUT
IF EXIST SN.dat DEL SN.dat

REM Make sure the DUT is connected over adb, then read its serial number.
adb wait-for-device
TIMEOUT 1

SET "DUT_SN="
FOR /F "usebackq delims=" %%S IN (`adb get-serialno 2^>nul`) DO SET "DUT_SN=%%S"

REM Retry if no valid serial was returned.
IF NOT DEFINED DUT_SN GOTO GetDutSN
IF /I "%DUT_SN%"=="unknown" GOTO GetDutSN

REM Ensure the serial number is exactly 12 characters.
IF NOT "%DUT_SN:~12%"=="" GOTO GetDutSN
IF "%DUT_SN:~11,1%"=="" GOTO GetDutSN

ECHO %DUT_SN%>SN.dat

IF %ERRORLEVEL% EQU 0 GOTO SetVar
GOTO GetDutSN

:setvar
IF EXIST OP.dat SET /p OP=<OP.dat
IF EXIST SN.dat SET /p SN=<SN.dat
SET "LOG_IDENTIFIER="
FOR /F "usebackq delims=" %%H IN (`adb shell getprop ro.serialno 2^>nul`) DO SET "LOG_IDENTIFIER=%%H"
IF NOT DEFINED LOG_IDENTIFIER SET "LOG_IDENTIFIER=%SN%"
COPY OP.dat DiagPGM\OP.dat
COPY SN.dat DiagPGM\SN.dat

IF NOT EXIST %on_Drive% net use /delete %on_Drive%

:chkroute
if "%MODE%" EQU "D" GOTO Non_TID
python RESTSFIS-diag\RESTSFIS-diag.py /C -sn %SN%
IF %ERRORLEVEL% EQU 0 GOTO Non_TID
GOTO CRfail

:CRfail
REM Check Route Fail
DiagPGM\Screen-diag.exe -nl -enter /SS 55 "SFIS Error - Check Route Failure !!<br>Please check DUT route status !! <br>See SFISLOG\YYYYMMDD.log for details.<br>OP: %op% <br> SN: %SN%" 0xFFFFFF -bg 0x882222
GOTO InteruptErr

:Non_TID
SET tid=NOTID
echo NOTID>tid.dat

:getconfig
IF "%SFISCONN%" EQU "True" Call config.bat 1 online %FOLDER%
IF "%SFISCONN%" NEQ "True" Call config.bat 1 offline %FOLDER%
IF "%SFISCONN%" NEQ "True" GOTO NoSFISTid
GOTO clean
:NoSFISTid
echo Debug>tid.dat

:clean
IF EXIST %FOLDER% GOTO enterTS
DiagPGM\Screen-diag.exe -enter /ss 50 "Please check folder "%FOLDER%" exist <br> <br>Press [Enter] to Jig Up" 0xFFFFFF -bg 0xFF0000
GOTO InteruptErr

:enterTS
rd /s /q %FOLDER%\TypeCTester\log_csv\
rd /s /q %FOLDER%\TypeCTester\log\
cd %~dp0
cd %FOLDER%
rd /s /q Tools\DeviceBridge\MISClog

rmdir /s /q Tools\Temp
rd /s /q Tools\MISClog

if not exist Tools\Temp mkdir Tools\Temp

del online.flg
IF "%DebugXML%" neq "True" echo flg > online.flg
IF "%DebugXML%" equ "True" echo debug>debug.flg
IF EXIST %CSV_NAME% DEL %CSV_NAME%
IF EXIST .chopper RMDIR /S /Q .chopper
IF EXIST *.log DEL *.log
IF EXIST *.wav DEL *.wav
IF EXIST *.dat DEL *.dat
IF EXIST deviceID.ini DEL deviceID.ini
IF EXIST err_string.* DEL err_string.*
move ..\*.dat .
copy op.dat ..
copy ..\Config.ini .
copy ..\deviceID.ini .

:test
set /p SN=<SN.dat

echo %SN%>SN.DAT
cd %~dp0%FOLDER%
IF DEFINED TEST_RUN_MARKER DEL /Q "%TEST_RUN_MARKER%" 2>nul
SET "TEST_RUN_MARKER=%TEMP%\ML_Audio_run_%RANDOM%_%RANDOM%.tmp"
TYPE NUL >"%TEST_RUN_MARKER%"

set connectRetry=0
adb wait-for-device
adb devices
:wifi_connect_to_Dut
call Tools\wifi_connect_fast.bat
set "wifiResult=%ERRORLEVEL%"
set /a connectRetry=connectRetry+1
if %connectRetry% geq 5 goto start
if %wifiResult% neq 0 goto wifi_connect_to_Dut

Screen-diag.exe -nl -enter /SS 55 "<br>Please remove cable and put the device to the fixture.<br> <br>Press [Enter] to start the test." 0xFFFFFF -bg 0x224466

Chopper-diag.exe -NoHotKey -LD TcsTestSuiteDuration %PROJECT% -c -si -CGV -opf op.dat -SNF SN.dat -sip -TSRID -lock -RL -f %CFG_NAME% -as -ae -SNP "^[0-9,A-Z]{%SN_LEN%}$" -tidf tid.dat -lf ..\DiagPGM\tidlog.xml /r
IF %ERRORLEVEL% EQU 0 GOTO TestPass
IF %ERRORLEVEL% EQU 255 GOTO TestFail
IF %ERRORLEVEL% NEQ 0 pause
IF %ERRORLEVEL% EQU 250 GOTO InteruptErr
IF %ERRORLEVEL% EQU 251 GOTO InteruptErr
IF %ERRORLEVEL% EQU 252 GOTO InteruptErr
IF %ERRORLEVEL% EQU 253 GOTO InteruptErr
IF %ERRORLEVEL% EQU 254 GOTO InteruptErr

:InteruptErr
ECHO Interupt Error
GOTO START

:TestFail
find /i "%PROJECT%,80" %CSV_NAME%
IF %ERRORLEVEL% equ 0 goto ShowFail
find /i "%PROJECT%,8F" %CSV_NAME%
IF %ERRORLEVEL% equ 0 goto ShowFail
find /i "%PROJECT%,C" %CSV_NAME%
IF %ERRORLEVEL% equ 0 goto ShowFail
find /i "%PROJECT%,N" %CSV_NAME%
IF %ERRORLEVEL% equ 0 goto ShowFail
find /i "%PROJECT%,M" %CSV_NAME%
IF %ERRORLEVEL% equ 0 goto ShowFail
find /i "%PROJECT%,0x" %CSV_NAME%
IF %ERRORLEVEL% equ 0 goto ShowFail
find /i "%PROJECT%,FF" %CSV_NAME%
IF %ERRORLEVEL% equ 0 goto ShowFail
cls
call Screen-diag.exe -enter /ss 70 "unexpected exit or unknow error code happens." 0xFFFFFF -bg 0xBB2222
goto ShowFail

:ShowFail
SET Result=FAIL

cd %~dp0%FOLDER%
Tools\UILogResult-auto.exe -log %CSV_NAME% /F
goto DateCHK

:TestPass
cd %~dp0
cd %FOLDER%
SET Result=PASS

:DateCHK
Tools\DateChk-auto.exe /FILE %CSV_NAME%
IF %ERRORLEVEL% NEQ 0 GOTO CHKFAIL
goto Backup

:Backup
LogTransfer-auto.exe -nl /de
call setdate.bat
SET Dest=C:\MFGlog\%TYPE%log\Online
SET MISC=C:\MISClog\%PROJECT%\%BUILD%\Online\%datepath%\%Result%
SET /p TSRID=<TSRID.dat
IF "%MODE%" EQU "D" SET Dest=C:\MFGlog\%TYPE%log\Debug
IF "%MODE%" EQU "D" SET MISC=C:\MISClog\%PROJECT%\%BUILD%\Debug\%datepath%\%Result%

COPY /y /v %CSV_NAME% .\tools\Temp\

cd tools
del .\MISCLog.zip

rename temp MISCLog
7z\7za.exe a -tzip .\MISCLog.zip .\MISCLog
IF NOT EXIST %MISC% MKDIR %MISC%
copy /y .\MISCLog.zip %MISC%\%SN%_%TSRID%.zip

cd..
Tools\LogTransfer-auto.exe -nl /L %CSV_NAME%
IF "%MODE%" EQU "D" GOTO END
cd %~dp0%FOLDER%

IF %Result% EQU FAIL goto DUT1_UP_fail
Tools\LogTransfer-auto.exe -nl  -tester -F PASS /L %CSV_NAME%
goto SFIS_UP
:DUT1_UP_fail
Tools\LogTransfer-auto.exe -nl  -tester -F FAIL /L %CSV_NAME%

:SFIS_UP
SET SFISerror=0

:SFIS
if "%MODE%" equ DGOTO END
python RESTSFIS-diag.py /UP -log %CSV_NAME%
IF %ERRORLEVEL% NEQ 0 GOTO SFIS_fail
GOTO END

:SFIS_FAIL
SET /a SFISerror=%SFISerror% + 1
echo SFIS Upload Fail
Tools\Screen-diag.exe -nl -enter /ss 70 "SFIS Upload FAIL(%SFISerror%)! <br> <br>Please Check SFIS!<br> <br>Press [Enter] to Retry"  0xFFFFFF -bg 0xBB2222
GOTO SFIS

:END
adb kill-server
IF "%Result%" NEQ "PASS" GOTO Record
IF EXIST TSRID.dat DEL TSRID.dat
Tools\Screen-diag.exe -nl -enter /ss 200 "PASS"  0xFFFFFF -bg 0x008800
Chopper-diag.exe /delay 500 2>nul
taskkill /IM Screen-diag.exe

GOTO Record

:UPLOAD_GRR_AND_WAIT_DUT_DISCONNECT
SET "GOOGLE_DRIVE_UPLOAD_STATUS=%TEMP%\ML_Audio_gdrive_status_%RANDOM%_%RANDOM%.tmp"
DEL /Q "%GOOGLE_DRIVE_UPLOAD_STATUS%" "%GOOGLE_DRIVE_UPLOAD_STATUS%.new" 2>nul
START "" /B CMD.EXE /D /C CALL "%~f0" __UPLOAD_GRR_WORKER
IF %ERRORLEVEL% NEQ 0 >"%GOOGLE_DRIVE_UPLOAD_STATUS%" ECHO 1
CALL :WAIT_DUT_DISCONNECT

:WAIT_GOOGLE_DRIVE_UPLOAD
IF NOT EXIST "%GOOGLE_DRIVE_UPLOAD_STATUS%" (
	TIMEOUT /T 1 /NOBREAK >nul
	GOTO WAIT_GOOGLE_DRIVE_UPLOAD
)
SET "GOOGLE_DRIVE_UPLOAD_EXITCODE=1"
SET /P GOOGLE_DRIVE_UPLOAD_EXITCODE=<"%GOOGLE_DRIVE_UPLOAD_STATUS%"
DEL /Q "%GOOGLE_DRIVE_UPLOAD_STATUS%" 2>nul
SET "GOOGLE_DRIVE_UPLOAD_STATUS="
DEL /Q "%TEST_RUN_MARKER%" 2>nul
SET "TEST_RUN_MARKER="
IF "%GOOGLE_DRIVE_UPLOAD_EXITCODE%" EQU "0" EXIT /B 0

Tools\Screen-diag.exe -nl -enter /SS 40 "Google Drive upload FAIL!!<br><br>Log ID: %LOG_IDENTIFIER%<br>Please check rclone and network settings.<br><br>Press [Enter] to continue." 0xFFFFFF -bg 0x882222
EXIT /B 1

:WAIT_DUT_DISCONNECT
START "" Tools\Screen-diag.exe -nl /SS 55 "Please disconnect the device from the computer.<br><br>Waiting for ADB device disconnection..." 0xFFFFFF -bg 0xFF7F25
TIMEOUT /T 1 /NOBREAK >nul

:WAIT_DUT_DISCONNECT_CHECK
SET "ADB_DEVICE_CONNECTED="
adb devices >"%TEMP%\ML_Audio_adb_devices.tmp" 2>nul
IF %ERRORLEVEL% NEQ 0 GOTO WAIT_DUT_DISCONNECT_RETRY
FOR /F "usebackq skip=1 tokens=1" %%A IN ("%TEMP%\ML_Audio_adb_devices.tmp") DO SET "ADB_DEVICE_CONNECTED=TRUE"
DEL /Q "%TEMP%\ML_Audio_adb_devices.tmp" 2>nul
IF DEFINED ADB_DEVICE_CONNECTED GOTO WAIT_DUT_DISCONNECT_RETRY
taskkill /IM Screen-diag.exe
EXIT /B 0

:WAIT_DUT_DISCONNECT_RETRY
DEL /Q "%TEMP%\ML_Audio_adb_devices.tmp" 2>nul
TIMEOUT /T 1 /NOBREAK >nul
GOTO WAIT_DUT_DISCONNECT_CHECK

:UPLOAD_GRR_TO_GOOGLE_DRIVE
SET "GOOGLE_DRIVE_UPLOAD_FAILED=0"
IF NOT EXIST "%LOG_ROOT%\%LOG_IDENTIFIER%\" ECHO Google Drive folder upload skipped: "%LOG_ROOT%\%LOG_IDENTIFIER%" does not exist.
IF NOT EXIST "%LOG_ROOT%\%LOG_IDENTIFIER%\" GOTO FIND_CURRENT_ROBOCAL_LOG
CALL "%GOOGLE_DRIVE_UPLOAD_BAT%" "%LOG_ROOT%\%LOG_IDENTIFIER%" "%GOOGLE_DRIVE_URL%"
IF %ERRORLEVEL% NEQ 0 SET "GOOGLE_DRIVE_UPLOAD_FAILED=1"

:FIND_CURRENT_ROBOCAL_LOG
SET "CURRENT_ROBOCAL_LOG="
IF EXIST "%TEST_RUN_MARKER%" FOR /F "usebackq delims=" %%L IN (`powershell.exe -NoProfile -Command "$marker=(Get-Item -LiteralPath $env:TEST_RUN_MARKER).LastWriteTimeUtc; $dir=Join-Path $env:LOG_ROOT 'robocal_output'; $latest=$null; if(Test-Path -LiteralPath $dir){foreach($file in Get-ChildItem -LiteralPath $dir -File){if(($file.Name -like 'log_file_*.log' -or $file.Name -like 'log_file_*.txt') -and $file.LastWriteTimeUtc -ge $marker -and ($null -eq $latest -or $file.LastWriteTimeUtc -gt $latest.LastWriteTimeUtc)){$latest=$file}}}; if($null -ne $latest){$latest.FullName}"`) DO SET "CURRENT_ROBOCAL_LOG=%%L"
IF NOT DEFINED CURRENT_ROBOCAL_LOG ECHO Google Drive log upload skipped: no new robocal_output log was found.
IF NOT DEFINED CURRENT_ROBOCAL_LOG GOTO GOOGLE_DRIVE_UPLOAD_FINISH

SET "GOOGLE_DRIVE_STAGE_ROOT=%TEMP%\ML_Audio_gdrive_%RANDOM%_%RANDOM%"
SET "GOOGLE_DRIVE_STAGE=%GOOGLE_DRIVE_STAGE_ROOT%\%LOG_IDENTIFIER%"
SET "GOOGLE_DRIVE_PRE_STAGE=%GOOGLE_DRIVE_STAGE%\Pre"
MKDIR "%GOOGLE_DRIVE_PRE_STAGE%" 2>nul
COPY /Y "%CURRENT_ROBOCAL_LOG%" "%GOOGLE_DRIVE_PRE_STAGE%\" >nul
IF %ERRORLEVEL% NEQ 0 GOTO GOOGLE_DRIVE_STAGE_COPY_FAIL
CALL "%GOOGLE_DRIVE_UPLOAD_BAT%" "%GOOGLE_DRIVE_STAGE%" "%GOOGLE_DRIVE_URL%"
IF %ERRORLEVEL% NEQ 0 SET "GOOGLE_DRIVE_UPLOAD_FAILED=1"
GOTO GOOGLE_DRIVE_STAGE_CLEANUP

:GOOGLE_DRIVE_STAGE_COPY_FAIL
SET "GOOGLE_DRIVE_UPLOAD_FAILED=1"

:GOOGLE_DRIVE_STAGE_CLEANUP
RMDIR /S /Q "%GOOGLE_DRIVE_STAGE_ROOT%" 2>nul

:GOOGLE_DRIVE_UPLOAD_FINISH
DEL /Q "%TEST_RUN_MARKER%" 2>nul
SET "TEST_RUN_MARKER="
IF "%GOOGLE_DRIVE_UPLOAD_FAILED%" EQU "0" EXIT /B 0
IF DEFINED GOOGLE_DRIVE_UPLOAD_BACKGROUND EXIT /B 1

Tools\Screen-diag.exe -nl -enter /SS 40 "Google Drive upload FAIL!!<br><br>Log ID: %LOG_IDENTIFIER%<br>Please check rclone and network settings.<br><br>Press [Enter] to continue." 0xFFFFFF -bg 0x882222
EXIT /B 1

:UPLOAD_GRR_WORKER
SET "GOOGLE_DRIVE_UPLOAD_BACKGROUND=1"
CALL :UPLOAD_GRR_TO_GOOGLE_DRIVE
>"%GOOGLE_DRIVE_UPLOAD_STATUS%.new" ECHO %ERRORLEVEL%
MOVE /Y "%GOOGLE_DRIVE_UPLOAD_STATUS%.new" "%GOOGLE_DRIVE_UPLOAD_STATUS%" >nul
EXIT /B 0

:Record
IF "%MODE%" EQU "D" GOTO Record1
cd %~dp0
if exist %CSV_NAME% del %CSV_NAME%
copy %FOLDER%\%CSV_NAME% %CSV_NAME%

:Record1
cd %~dp0
IF "%MODE%" EQU "D" GOTO START

:chk2Aroute
GOTO START
IF "%Result%" EQU "PASS" GOTO START
Start DiagPGM\Screen-diag.exe -enter /SS 55 "Checking SN %SN% SFIS 2A status<br>Please wait... <br> <br>Checking 2A Status from SFIS<br>Please wait a moment..." 0xFFFFFF -bg 0x223366
python RESTSFIS-diag\RESTSFIS-diag.py /C -sn %SN%
IF %ERRORLEVEL% EQU 0 DiagPGM\Screen-diag.exe -enter /SS 40 "SN (2A) not allowed!!<br> <br>Please change another tester to do SN (2A) test!!<br><br>Press [ENTER] to continue..." 0xFFFFFF -bg 0x773399
taskkill /IM Screen-diag.exe

