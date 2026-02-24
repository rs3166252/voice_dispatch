@echo off
REM Voice Dispatch Launcher - Auto-Update on Startup
REM Users run this instead of VoiceDispatchSpeech.exe directly

setlocal enabledelayedexpansion

echo.
echo ================================
echo Voice Dispatch - Launcher
echo ================================
echo.

REM Always run from the script directory
set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%"
REM Check if in correct directory
if not exist "app_manifest.json" (
    echo [Launcher] ERROR: app_manifest.json not found
    echo [Launcher] Run this script from: SpeechRecognition folder
    pause
    exit /b 1
)

REM Check for updates silently (if update.ps1 exists)
if exist "update.ps1" (
    echo [Launcher] Checking for updates...
    powershell -NoProfile -ExecutionPolicy Bypass -File "update.ps1" > nul 2>&1

    if errorlevel 1 (
        echo [Launcher] Update check failed, running local version
    )
) else (
    echo [Launcher] update.ps1 not found, skipping update check
)

REM Start the app
echo [Launcher] Starting VoiceDispatchSpeech...
if exist "VoiceDispatchSpeech.exe" (
    start "" "VoiceDispatchSpeech.exe"
) else (
    echo [Launcher] ERROR: VoiceDispatchSpeech.exe not found
    pause
    exit /b 1
)

exit /b 0
