@echo off
cd /d "%~dp0"

if exist "%LocalAppData%\Python\bin\pythonw.exe" (
    "%LocalAppData%\Python\bin\pythonw.exe" "%~dp0step_tool.py"
    exit /b
)

where pythonw >nul 2>&1
if %errorlevel% equ 0 (
    pythonw "%~dp0step_tool.py"
    exit /b
)

where python >nul 2>&1
if %errorlevel% equ 0 (
    python "%~dp0step_tool.py"
    exit /b
)

echo Python 3.x not found
echo Install from https://www.python.org/downloads/
pause
