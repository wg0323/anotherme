@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

rem ============================================================
rem  anotherme skill uninstaller
rem  Removes ONLY junctions that point into this repo.
rem  Real directories and junctions pointing elsewhere are
rem  never touched.
rem
rem  Usage:
rem    uninstall.bat                 Uninstall from all detected IDEs
rem    uninstall.bat --only=qoder    Uninstall from one IDE only
rem                                  (codebuddy / qoder / qodercn)
rem    uninstall.bat --only=qodercn  Uninstall from a non-standard skills
rem      --dir="D:\...\skills"       dir; --dir must pair with --only.
rem ============================================================

for %%i in ("%~dp0..") do set "REPO=%%~fi"
set "SKILLS=%REPO%\skills"

set "ONLY="
set "CUSTOM_DIR="

:parse
if "%~1"=="" goto parse_done
if /i "%~1"=="--help" goto usage
if /i "%~1"=="-h" goto usage
set "arg=%~1"
if "!arg:~0,7!"=="--only=" set "ONLY=!arg:~7!"
if "!arg:~0,6!"=="--dir=" set "CUSTOM_DIR=!arg:~6!"
rem tolerate "--only xxx" / "--dir xxx" (some shells split at the '=')
if /i "%~1"=="--only" (
    set "ONLY=%~2"
    shift
)
if /i "%~1"=="--dir" (
    set "CUSTOM_DIR=%~2"
    shift
)
shift
goto parse
:parse_done

if defined CUSTOM_DIR if not defined ONLY (
    echo [ERROR] --dir must be combined with --only=codebuddy^|qoder^|qodercn
    exit /b 1
)

echo Repo: %REPO%
echo.

set "REMOVED=0"
set "SKIPPED=0"

call :uninstall_ide codebuddy "%USERPROFILE%\.codebuddy\skills"
call :uninstall_ide qoder     "%USERPROFILE%\.qoder\skills"
call :uninstall_ide qodercn   "%USERPROFILE%\.qoder-cn\skills"

echo.
echo ==================== Summary ====================
echo Removed: %REMOVED%    Skipped: %SKIPPED%
exit /b 0

rem ---------- subroutines ----------

:uninstall_ide
set "IDE=%~1"
set "TARGET_DIR=%~2"
if defined ONLY if /i not "%ONLY%"=="%IDE%" exit /b 0
rem --dir overrides the default skills dir for the selected IDE
if defined CUSTOM_DIR set "TARGET_DIR=%CUSTOM_DIR%"
if not exist "%TARGET_DIR%" exit /b 0
echo [%IDE%] target: %TARGET_DIR%
for /d %%s in ("%SKILLS%\*") do call :remove_skill "%IDE%" "%TARGET_DIR%" "%%~ns"
exit /b 0

:remove_skill
set "IDE=%~1"
set "TARGET_DIR=%~2"
set "NAME=%~3"
if "%NAME:~0,1%"=="_" exit /b 0
set "DEST=%TARGET_DIR%\%NAME%"
if not exist "%DEST%" exit /b 0

fsutil reparsepoint query "%DEST%" >nul 2>&1
if !errorlevel! neq 0 (
    echo   %NAME%: real directory, not touched
    set /a SKIPPED+=1
    exit /b 0
)
fsutil reparsepoint query "%DEST%" | find /i "%REPO%" >nul
if !errorlevel! neq 0 (
    echo   %NAME%: junction points elsewhere, not touched
    set /a SKIPPED+=1
    exit /b 0
)

rmdir "%DEST%" 2>nul
if !errorlevel! equ 0 (
    echo   %NAME%: removed
    set /a REMOVED+=1
) else (
    echo   %NAME%: FAILED to remove
    set /a SKIPPED+=1
)
exit /b 0

:usage
echo anotherme skill uninstaller
echo Usage: uninstall.bat [--only=codebuddy^|qoder^|qodercn] [--dir=SKILLS_PATH]
echo.
echo   --only=IDE  target a single IDE
echo   --dir=PATH  override that IDE's skills dir ^(portable / relocated
echo               data dir^); must be combined with --only
exit /b 0
