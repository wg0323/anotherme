@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

rem ============================================================
rem  anotherme skill installer
rem  Mounts every skill under skills\ into each IDE's skills
rem  directory via NTFS directory junction.
rem
rem  Usage:
rem    install.bat                 Install to all detected IDEs
rem    install.bat --only=qoder    Install to one IDE only
rem                                (codebuddy / qoder / qodercn)
rem    install.bat --force         Rebuild junctions that point
rem                                elsewhere (never deletes real dirs)
rem ============================================================

for %%i in ("%~dp0..") do set "REPO=%%~fi"
set "SKILLS=%REPO%\skills"

set "FORCE=0"
set "ONLY="

:parse
if "%~1"=="" goto parse_done
if /i "%~1"=="--force" set "FORCE=1"
if /i "%~1"=="--help" goto usage
if /i "%~1"=="-h" goto usage
set "arg=%~1"
if "!arg:~0,7!"=="--only=" set "ONLY=!arg:~7!"
rem tolerate "--only xxx" (some shells split "--only=xxx" at the '=')
if /i "%~1"=="--only" (
    set "ONLY=%~2"
    shift
)
shift
goto parse
:parse_done

if not exist "%SKILLS%" (
    echo [ERROR] skills directory not found: %SKILLS%
    exit /b 1
)

echo Repo: %REPO%
echo.

set "INSTALLED=0"
set "SKIPPED=0"
set "FAILED=0"

call :install_ide codebuddy "%USERPROFILE%\.codebuddy\skills"
call :install_ide qoder     "%USERPROFILE%\.qoder\skills"
call :install_ide qodercn   "%USERPROFILE%\.qoder-cn\skills"

echo.
echo ==================== Summary ====================
echo Installed: %INSTALLED%    Skipped: %SKIPPED%    Failed: %FAILED%
exit /b 0

rem ---------- subroutines ----------

:install_ide
set "IDE=%~1"
set "TARGET_DIR=%~2"
if defined ONLY if /i not "%ONLY%"=="%IDE%" exit /b 0
if not exist "%TARGET_DIR%" (
    rem IDE installed but skills dir missing: create it
    for %%i in ("%TARGET_DIR%\..") do set "PARENT=%%~fi"
    if exist "!PARENT!" mkdir "%TARGET_DIR%" 2>nul
)
if not exist "%TARGET_DIR%" (
    echo [%IDE%] skills dir not found, skipped: %TARGET_DIR%
    exit /b 0
)
echo [%IDE%] target: %TARGET_DIR%
for /d %%s in ("%SKILLS%\*") do call :install_skill "%IDE%" "%TARGET_DIR%" "%%~fs" "%%~ns"
exit /b 0

:install_skill
set "IDE=%~1"
set "TARGET_DIR=%~2"
set "SRC=%~3"
set "NAME=%~4"
rem skip template dirs (leading underscore) and dirs without SKILL.md
if "%NAME:~0,1%"=="_" exit /b 0
if not exist "%SRC%\SKILL.md" exit /b 0
set "DEST=%TARGET_DIR%\%NAME%"

if exist "%DEST%" (
    fsutil reparsepoint query "%DEST%" >nul 2>&1
    if !errorlevel! neq 0 (
        echo   %NAME%: target is a real directory, skipped to avoid data loss
        set /a SKIPPED+=1
        exit /b 0
    )
    fsutil reparsepoint query "%DEST%" | find /i "%REPO%" >nul
    if !errorlevel! equ 0 (
        echo   %NAME%: already installed, skipped
        set /a SKIPPED+=1
        exit /b 0
    )
    if "%FORCE%"=="0" (
        echo   %NAME%: junction points elsewhere, skipped, use --force to rebuild
        set /a SKIPPED+=1
        exit /b 0
    )
    rmdir "%DEST%" 2>nul
)

rem retry up to 3 times: IDEs may briefly lock the skills dir while scanning
set "TRY=0"
:retry
mklink /J "%DEST%" "%SRC%" >nul 2>&1
if !errorlevel! equ 0 goto link_ok
set /a TRY+=1
if %TRY% lss 3 (
    timeout /t 1 /nobreak >nul
    rmdir "%DEST%" 2>nul
    goto retry
)
goto link_fail

:link_ok
echo   %NAME%: installed
set /a INSTALLED+=1
exit /b 0

:link_fail
echo   %NAME%: FAILED to create junction
set /a FAILED+=1
exit /b 0

:usage
echo anotherme skill installer
echo Usage: install.bat [--only=codebuddy^|qoder^|qodercn] [--force]
exit /b 0
