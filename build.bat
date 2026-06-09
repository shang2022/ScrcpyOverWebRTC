@echo off
SETLOCAL EnableDelayedExpansion

:: ==============================================================================
:: Windows Web App 构建与打包脚本
:: ==============================================================================

SET "SCRIPT_DIR=%~dp0"
:: 去掉末尾的斜杠
IF "%SCRIPT_DIR:~-1%"=="\" SET "SCRIPT_DIR=%SCRIPT_DIR:~0,-1%"
SET "WEB_APP_DIR=%SCRIPT_DIR%\web-app"

echo === Building Web App on Windows ===

IF EXIST "%SCRIPT_DIR%\assets" (
    echo -> Cleaning old assets...
    rmdir /s /q "%SCRIPT_DIR%\assets"
)

cd /d "%WEB_APP_DIR%"

:: 检查 node_modules
IF NOT EXIST "node_modules" (
    echo -> Installing dependencies...
    call npm install --registry=https://registry.npmmirror.com
)

:: 构建
echo -> Building...
call npm run build

echo ------------------------------------------------
IF NOT EXIST "%SCRIPT_DIR%\assets\v1\agent" (
    mkdir "%SCRIPT_DIR%\assets\v1\agent"
)

:: 拷贝 agentd 的二进制文件 (Windows 下不用 ln, 直接 copy)
echo -> Copying agent files...
copy /y "%SCRIPT_DIR%\agentd\cloudphone-agent-amd64" "%SCRIPT_DIR%\assets\v1\agent\cloudphone-agent-amd64" >nul 2>&1
copy /y "%SCRIPT_DIR%\agentd\cloudphone-agent-arm64" "%SCRIPT_DIR%\assets\v1\agent\cloudphone-agent-arm64" >nul 2>&1
copy /y "%SCRIPT_DIR%\agentd\scrcpy-server.jar" "%SCRIPT_DIR%\assets\v1\agent\scrcpy-server.jar" >nul 2>&1

echo Build Complete!
echo Output: %SCRIPT_DIR%\assets\v1
echo ------------------------------------------------

:: 打包 Windows 压缩包
echo === Packaging Windows Release ===
SET "WINDOWS_RELEASE_DIR=%SCRIPT_DIR%\release_windows"

IF EXIST "%WINDOWS_RELEASE_DIR%" rmdir /s /q "%WINDOWS_RELEASE_DIR%"
mkdir "%WINDOWS_RELEASE_DIR%"
mkdir "%WINDOWS_RELEASE_DIR%\bin\windows_amd64"
mkdir "%WINDOWS_RELEASE_DIR%\bin\windows_arm64"
mkdir "%WINDOWS_RELEASE_DIR%\agentd"
mkdir "%WINDOWS_RELEASE_DIR%\assets\v1\agent"

:: 复制 Windows 二进制
IF EXIST "%SCRIPT_DIR%\bin\windows_amd64" (
    copy /y "%SCRIPT_DIR%\bin\windows_amd64\*.*" "%WINDOWS_RELEASE_DIR%\bin\windows_amd64\" >nul
)
IF EXIST "%SCRIPT_DIR%\bin\windows_arm64" (
    copy /y "%SCRIPT_DIR%\bin\windows_arm64\*.*" "%WINDOWS_RELEASE_DIR%\bin\windows_arm64\" >nul
)

:: 复制 Agent
copy /y "%SCRIPT_DIR%\agentd\cloudphone-agent-*" "%WINDOWS_RELEASE_DIR%\agentd\" >nul 2>&1
copy /y "%SCRIPT_DIR%\agentd\scrcpy-server.jar" "%WINDOWS_RELEASE_DIR%\agentd\" >nul 2>&1
IF EXIST "%SCRIPT_DIR%\agentd\run.sh" (
    copy /y "%SCRIPT_DIR%\agentd\run.sh" "%WINDOWS_RELEASE_DIR%\agentd\" >nul
)

:: 复制 Assets
xcopy /e /i /y "%SCRIPT_DIR%\assets\v1" "%WINDOWS_RELEASE_DIR%\assets\v1" >nul

:: 复制启动脚本到根目录
(
echo @echo off
echo Starting CloudPhone Server for Windows...
echo cd bin\windows_amd64
echo call run.bat
) > "%WINDOWS_RELEASE_DIR%\start_server.bat"

:: 压缩 Windows 包 (使用 PowerShell 压缩，Windows 默认支持)
echo -> Creating ZIP archive...
IF EXIST "%SCRIPT_DIR%\cloudphone-windows.zip" del /f /q "%SCRIPT_DIR%\cloudphone-windows.zip"
powershell -Command "Add-Type -AssemblyName System.IO.Compression.FileSystem; [System.IO.Compression.ZipFile]::CreateFromDirectory('%WINDOWS_RELEASE_DIR%', '%SCRIPT_DIR%\cloudphone-windows.zip')"

rmdir /s /q "%WINDOWS_RELEASE_DIR%"
echo Windows Release Packaged: %SCRIPT_DIR%\cloudphone-windows.zip
echo ------------------------------------------------
pause
