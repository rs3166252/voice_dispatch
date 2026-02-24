@echo off
title Voice Dispatch - Speech Recognition
echo ================================================
echo Starting Voice Dispatch Speech Recognition...
echo ================================================
echo.

REM Always run from the script directory
set "SCRIPT_DIR=%~dp0"
pushd "%SCRIPT_DIR%"

echo Make sure to keep this window open while playing!
echo Press Ctrl+C to stop.
echo.

if exist VoiceDispatchSpeech.exe (
    VoiceDispatchSpeech.exe
) else (
    echo.
    echo ERROR: VoiceDispatchSpeech.exe not found!
    echo.
    echo Please place VoiceDispatchSpeech.exe in this folder.
    echo.
    pause
)
