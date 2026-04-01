@echo off
setlocal enabledelayedexpansion

set "INSTALL_DIR=%SystemRoot%\System32\WechoAPO"
set "SOURCE_DIR=%~dp0"
set "APO_DLL=apo.dll"
set "SHARED_MEMORY_EXE=sharedMemory.exe"
set "FFTWF_DLL=fftw3f.dll"
set "FFTWF_LIB=fftw3f.lib"
set "CLSID={F1955965-CD9C-4D97-9B02-3FB0FDCF0936}"
set "TASK_NAME=WechoAPO_Connector"
set "FXKEY={d04e05a6-594b-4fb6-a80d-01af5eed7d1d},6"
set "DEVICE_TYPE={a45c254e-df1c-4efd-8020-67d146a850e0},2"
set "DEVICE_NAME={b3f8fa53-0004-438e-9003-51a46e139bfc},6"

net session >nul 2>&1
if %errorlevel% neq 0 (
    echo This script must be run as an administrator.
    pause
    exit /b 1
)

echo ====================================
echo Wecho Start Installing...
echo ====================================

echo [1/7] checking system configuration
reg query "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Audio" /v DisableProtectedAudioDG >nul 2>&1

if !errorlevel! equ 0 (
    echo Protected Audio DG is enabled.
) else (
    reg add HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Audio /t REG_DWORD /v DisableProtectedAudioDG /d 1 >nul
    echo Protected Audio DG has been enabled.
)

echo [2/7] creating installing directory
if not exist "%INSTALL_DIR%" mkdir "%INSTALL_DIR%"

echo [3/7] copying files
if exist "%SOURCE_DIR%%APO_DLL%" (
    copy /Y "%SOURCE_DIR%%APO_DLL%" "%INSTALL_DIR%"
    echo %APO_DLL% copied successfully.
) else (
    echo %APO_DLL% does not exist.
)

if exist "%SOURCE_DIR%%SHARED_MEMORY_EXE%" (
    copy /Y "%SOURCE_DIR%%SHARED_MEMORY_EXE%" "%INSTALL_DIR%"
    echo %SHARED_MEMORY_EXE% copied successfully.
) else (
    echo %SHARED_MEMORY_EXE% does not exist.
)

if exist "%SOURCE_DIR%%FFTWF_DLL%" (
    copy /Y "%SOURCE_DIR%%FFTWF_DLL%" "%INSTALL_DIR%"
    echo %FFTWF_DLL% copied successfully.
) else (
    echo %FFTWF_DLL% does not exist.
)

if exist "%SOURCE_DIR%%FFTWF_LIB%" (
    copy /Y "%SOURCE_DIR%%FFTWF_LIB%" "%INSTALL_DIR%"
    echo %FFTWF_LIB% copied successfully.
) else (
    echo %FFTWF_LIB% does not exist.
)

echo [4/7] registering DLL
regsvr32 /s "%INSTALL_DIR%\%APO_DLL%" >nul
if !errorlevel! equ 0 (
    echo %APO_DLL% registered successfully.
) else (
    echo Failed to register %APO_DLL%.
)

echo [5/7] creating scheduled task
if exist "%INSTALL_DIR%\%SHARED_MEMORY_EXE%" (
    schtasks /query /tn "%TASK_NAME%" >nul 2>&1
    if !errorlevel! equ 0 (
        schtasks /delete /tn "%TASK_NAME%" /f >nul
    )

    schtasks /create /tn "%TASK_NAME%" /tr "%INSTALL_DIR%\%SHARED_MEMORY_EXE%" /sc onstart /ru System /rl highest /f >nul
    if !errorlevel! equ 0 (
        echo Scheduled task %TASK_NAME% created successfully.

        schtasks /run /tn "%TASK_NAME%" >nul 2>&1
        echo Task started.

    ) else (
        echo Failed to create scheduled task %TASK_NAME%.
    )
    
) else (
    echo %SHARED_MEMORY_EXE% does not exist.
)

echo [6/7] choose audio device
set n=0
for /f "tokens=*" %%a in ('reg query HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render') do (
    set "guid=%%a"
    if not "!guid!"=="HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\MMDevices\Audio\Render" (
        set /a n+=1

        for /f "tokens=2,*" %%b in ('reg query "!guid!\Properties" /v "{a45c254e-df1c-4efd-8020-67d146a850e0},2" 2^>nul') do set "type=%%c"
        set "type=!type:REG_SZ=!"

        for /f "tokens=2,*" %%b in ('reg query "!guid!\Properties" /v "{b3f8fa53-0004-438e-9003-51a46e139bfc},6" 2^>nul') do set "name=%%c"
        set "name=!name:REG_SZ=!"

        echo !n!    !type!    !name!
        echo !n!^|!guid!>>%temp%\dev.txt
    )
)

if %n%==0 echo No audio device found. & goto end

echo.
set /p id=Enter the number of the audio device you want to use: (1-%n% / -1 skip):
if "%id%"=="-1" goto end

for /f "tokens=1,2 delims=|" %%a in (%temp%\dev.txt) do (
    if "%%a"=="%id%" reg add "%%b\FxProperties" /v "%FXKEY%" /t REG_SZ /d "%CLSID%" /f >nul
)

:end
del %temp%\dev.txt 2>nul

echo [7/7] restart Audiosrv
net stop audiosrv
net start audiosrv

pause