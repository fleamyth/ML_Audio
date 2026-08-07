@echo off
setlocal

REM Retrieve the hostname
for /f "tokens=*" %%i in ('hostname') do set HOSTNAME=%%i

REM Remove the "DESKTOP-" prefix
set WIFI_NAME="ITU8ATO_5G"

REM -- Configuration --
SET WIFI_SSID=%WIFI_NAME%
SET WIFI_PROTOCOL=wpa2
SET WIFI_PASSWORD=google123
SET ADB_PORT=5555
SET "USB_SERIAL_NUMBER="
SET "DEVICE_IP="
SET "STATUS="

echo.
echo ########## Android Wi-Fi ADB Setup (Optimized) ##########
echo.

echo [+] Resetting ADB server for a clean start...
adb kill-server >nul
REM The 'timeout /t 1' was removed as it's not needed. The next adb command will start the server if required.
echo.

echo [+] Step 1: Capturing device Serial Number (SN)...
adb wait-for-device
REM This loop finds the first attached device with "device" status and grabs its SN.
FOR /F "skip=1 tokens=1,2" %%A IN ('adb devices') DO (
    IF "%%B"=="device" (
        IF not defined USB_SERIAL_NUMBER (
            SET "USB_SERIAL_NUMBER=%%A"
        )
    )
)

if not defined USB_SERIAL_NUMBER (
    echo [!] ERROR: No USB device found. Please connect a device and ensure it is authorized.
    goto end
)
echo [+] Found device with SN: %USB_SERIAL_NUMBER%
echo.


echo [+] Step 2: Restarting adb as root and waiting for reconnection...
adb root
adb wait-for-device
echo [+] Device reconnected with root privileges.
echo.

echo [+] Step 3: Enabling Wi-Fi and connecting to network...
adb shell "svc wifi enable"
timeout /t 2 >nul  
adb shell cmd wifi start-scan
timeout /t 3 >nul  

echo [+] Connecting to SSID: %WIFI_SSID%
adb shell "cmd wifi connect-network %WIFI_SSID% %WIFI_PROTOCOL% %WIFI_PASSWORD%"

echo [+] Waiting for the device to receive an IP address...
SET "IP_POLL_ATTEMPTS=0"
:poll_for_ip
    IF %IP_POLL_ATTEMPTS% GEQ 15 (
        echo [!] ERROR: Timed out waiting for an IP address. Check Wi-Fi credentials and network.
        goto end
    )
    SET /A IP_POLL_ATTEMPTS+=1
    
    FOR /F "tokens=1,2 delims= " %%G IN ('adb shell "ip addr show wlan0"') DO (
        IF "%%G"=="inet" (
            SET "IP_WITH_MASK=%%H"
        )
    )
    
    IF defined IP_WITH_MASK (
        goto ip_found
    )
    timeout /t 1 /nobreak >nul
goto poll_for_ip

:ip_found
echo [+] Step 4: Parsing the device's IP address...
FOR /F "tokens=1 delims=/" %%I IN ("%IP_WITH_MASK%") DO (
    SET "DEVICE_IP=%%I"
)

echo [+] Successfully Parsed IP: %DEVICE_IP%
echo.

echo [+] Step 5: Restarting adb in TCP/IP mode...
adb tcpip %ADB_PORT%
timeout /t 1 >nul 
echo.

echo [+] Step 6: Connecting to device wirelessly...
adb connect %DEVICE_IP%:%ADB_PORT%
timeout /t 2 >nul
echo.

echo [+] Step 7: Verifying final connection status...
FOR /F "tokens=1,2" %%J IN ('adb devices') DO (
    if "%%J"=="%DEVICE_IP%:%ADB_PORT%" (
        set "STATUS=%%K"
    )
)

if "%STATUS%"=="device" (
    echo.
    echo +--------------------------------------------------+
    echo ^| SUCCESS:
    echo ^| Original SN: %USB_SERIAL_NUMBER%
    echo ^| Connected as IP: %DEVICE_IP%:%ADB_PORT%
    echo +--------------------------------------------------+
) else (
    echo.
    echo +--------------------------------------------------+
    echo ^| FAIL:
    echo ^| Could not verify a stable wireless connection.
    echo ^| Try running the script again.
    echo +--------------------------------------------------+
)
echo.

:end

echo ########## Script Finished ##########
endlocal