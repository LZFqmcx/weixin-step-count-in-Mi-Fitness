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

if exist "%LocalAppData%\Python\bin\python.exe" (
    "%LocalAppData%\Python\bin\python.exe" "%~dp0step_tool.py"
    exit /b
)

echo 未找到 Python 3.x
echo 请从 https://www.python.org/downloads/ 安装
pause
