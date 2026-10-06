@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar_plantillas.ps1" -DesdeBat
if not "%ERRORLEVEL%"=="0" (
    echo.
    echo Hubo un error. No se borro nada.
    pause
    exit /b 1
)
(goto) 2>nul & del "%~f0"
