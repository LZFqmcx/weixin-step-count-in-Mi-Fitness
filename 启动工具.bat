@echo off
cd /d "%~dp0"

echo [Step Tool] Looking for Python...

if exist "%LocalAppData%\Python\bin\python.exe" (
    echo [Step Tool] Found: %%LocalAppData%%\Python\bin\python.exe
    "%LocalAppData%\Python\bin\python.exe" "%~dp0step_tool.py"
    if errorlevel 1 pause
    exit /b
)

where python >nul 2>&1
if %errorlevel% equ 0 (
    echo [Step Tool] Found python in PATH
    python "%~dp0step_tool.py"
    if errorlevel 1 pause
    exit /b
)

echo [Step Tool] Python not found!
echo Please install Python 3 from python.org
pause
exit /b
