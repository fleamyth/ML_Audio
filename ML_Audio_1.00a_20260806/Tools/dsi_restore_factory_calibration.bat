@echo off
setlocal enabledelayedexpansion

call color_codes.bat

set FIRMWARE_DIR=/mnt/vendor/persist/firmware
set BACKUP_ARCHIVE=pre_robocal.tar.gz
set CALIBRATION_FILE_DIR=/mnt/vendor/persist/display

set PANEL_TYPE=RAXIUM
set NONINTERACTIVE=0
set SKIP_RESTORE=0

:: Parse arguments
:parse_args
if "%~1"=="" goto :args_done
if /i "%~1"=="/jbd" set PANEL_TYPE=JBD
if /i "%~1"=="/raxium" set PANEL_TYPE=RAXIUM
if /i "%~1"=="/noninteractive" set NONINTERACTIVE=1
if /i "%~1"=="/skip" set SKIP_RESTORE=1
if /i "%~1"=="/?" goto :usage
if /i "%~1"=="-?" goto :usage
if /i "%~1"=="-h" goto :usage
if /i "%~1"=="--help" goto :usage
shift
goto :parse_args
:args_done

if !SKIP_RESTORE! equ 1 (
    echo Skipping factory calibration restoration.
    timeout /t 3
    exit /b 0
)

echo Restoration mode: !PANEL_TYPE!

echo Preparing device connection...
adb wait-for-device
adb root
adb wait-for-device
adb remount
adb wait-for-device

if /i "!PANEL_TYPE!"=="JBD" (
    call :echo_red "Restoring JBD factory calibration baseline..."
    echo Removing Robocal calibration files from %FIRMWARE_DIR%...
    :: Remove DSI file, protos, raw binary dumps, and demura maps.
    adb shell "rm -f %FIRMWARE_DIR%/dsi_calib_data %FIRMWARE_DIR%/jbdcal_panel_*.robocal.pbin %FIRMWARE_DIR%/jbdcal_panel_*.bin %FIRMWARE_DIR%/*_demura.bin %FIRMWARE_DIR%/*_brightness_*.bin"

    echo Removing QDCM and brightness artifacts...
    adb shell "rm -f %CALIBRATION_FILE_DIR%/factory_calib_data_*.json /mnt/vendor/efs/display/v53/device_measured_nits_*.cal"

    if !errorlevel! neq 0 (
        call :echo_red "Error: Failed to remove one or more JBD calibration files or artifacts."
        exit /b !errorlevel!
    )
    call :echo_green "Successfully removed JBD robocal calibration files and artifacts. Device will reload from SPI flash on reboot."
) else (
    echo Checking for Raxium backup calibration on device...
    adb shell "ls %FIRMWARE_DIR%/%BACKUP_ARCHIVE%" >nul 2>&1
    if not !errorlevel! equ 0 (
        call :echo_green "No backup calibration file found. No action needed."
        timeout /t 3
        exit /b 0
    )

    call :echo_red "Backup calibration file (%BACKUP_ARCHIVE%) exists at %FIRMWARE_DIR%."
    echo Restoring backup calibration...

    echo Extracting files from %BACKUP_ARCHIVE%...
    adb shell "cd %FIRMWARE_DIR% && tar -xzvf %BACKUP_ARCHIVE% && rm %BACKUP_ARCHIVE%"
    if !errorlevel! neq 0 (
        call :echo_red "Error while restoring backup: Failed to extract or remove %BACKUP_ARCHIVE% on device."
        exit /b !errorlevel!
    )

    echo Removing calibration .json.gz files in %CALIBRATION_FILE_DIR%...
    adb shell "rm -f %CALIBRATION_FILE_DIR%/rj1/rj1cal_panel_*.json.gz %CALIBRATION_FILE_DIR%/v53/rj1cal_panel_*.json.gz"
    call :echo_green "Successfully restored the pre-robocal calibration files."
)

echo Rebooting the device...
adb reboot
echo Waiting for device to come back online...
adb wait-for-device
call :echo_green "Reboot completed."

if !NONINTERACTIVE! equ 0 (
    pause
)

exit /b 0

:usage
echo.
echo Usage: dsi_restore_factory_calibration.bat [switches]
echo.
echo Switches:
echo   /raxium         (Default) Restore calibration for Raxium panels using backup archive.
echo   /jbd            Restore calibration for JBD panels by removing local files.
echo   /skip           Exit immediately without performing any action.
echo   /noninteractive Do not pause at the end of execution.
echo   /?              Display this help message.
echo.
exit /b 1

:echo_red
echo %RED%%~1%RESET%
goto :EOF

:echo_green
echo %GREEN%%~1%RESET%
goto :EOF
