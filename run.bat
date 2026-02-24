@echo off
title Voice Dispatch - Speech Recognition
echo ================================================
echo Voice Dispatch - Speech Recognition
echo ================================================
echo.
echo Make sure to keep this window open while playing!
echo Press Ctrl+C to stop.
echo.
if not exist VoiceDispatchSpeech.exe (
    echo ERROR: VoiceDispatchSpeech.exe not found!
    echo Please make sure all files are in the same folder.
    pause
    exit /b 1
)
VoiceDispatchSpeech.exe
