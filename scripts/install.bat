@echo off
setlocal enabledelayedexpansion
chcp 65001 >nul

rem ============================================================
rem  anotherme skill installer
rem  Mounts every skill under skills\ into each IDE's skills
rem  directory via NTFS directory junction, then syncs the
rem  always_on rule copy (docs\common_rule.md) into each IDE's
rem  rule directory.
rem
rem  Usage:
rem    install.bat                 Install to all detected IDEs
rem    install.bat --only=qoder    Install to one IDE only
rem                                (codebuddy / qoder / qodercn / claude)
rem    install.bat --only=qodercn  Install into a non-standard skills
rem      --dir="D:\...\skills"     dir (portable IDE / relocated data
rem                                dir). --dir must pair with --only.
rem    install.bat --force         Rebuild junctions that point
rem                                elsewhere (never deletes real dirs)
rem ============================================================

for %%i in ("%~dp0..") do set "REPO=%%~fi"
set "SKILLS=%REPO%\skills"

set "FORCE=0"
set "ONLY="
set "CUSTOM_DIR="

:parse
if "%~1"=="" goto parse_done
if /i "%~1"=="--force" set "FORCE=1"
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
    echo [ERROR] --dir must be combined with --only=codebuddy^|qoder^|qodercn^|claude
    exit /b 1
)

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
call :install_ide claude    "%USERPROFILE%\.claude\skills"

echo.
echo ==================== Summary ====================
echo Installed: %INSTALLED%    Skipped: %SKIPPED%    Failed: %FAILED%

echo.
rem rules are copy-installed (not junctioned), so sync them here instead of
rem leaving a stale copy behind after every docs\common_rule.md edit
if defined CUSTOM_DIR (
    echo [rules] skipped: custom --dir in use, run scripts\sync-rules.bat manually
    exit /b 0
)
if defined ONLY (
    call "%~dp0sync-rules.bat" --only=!ONLY!
) else (
    call "%~dp0sync-rules.bat"
)
exit /b 0

rem ---------- subroutines ----------

:install_ide
set "IDE=%~1"
set "TARGET_DIR=%~2"
if defined ONLY if /i not "%ONLY%"=="%IDE%" exit /b 0
rem --dir overrides the default skills dir for the selected IDE
if defined CUSTOM_DIR set "TARGET_DIR=%CUSTOM_DIR%"
if not exist "%TARGET_DIR%" (
    rem IDE installed but skills dir missing: create it
    for %%i in ("%TARGET_DIR%\..") do set "PARENT=%%~fi"
    if exist "!PARENT!" mkdir "%TARGET_DIR%" 2>nul
)
if not exist "%TARGET_DIR%" (
    echo [%IDE%] skills dir not found, skipped: %TARGET_DIR%
    if not defined CUSTOM_DIR echo        hint: data dir elsewhere? use --only=%IDE% --dir="...\skills"
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
echo Usage: install.bat [--only=codebuddy^|qoder^|qodercn^|claude] [--dir=SKILLS_PATH] [--force]
echo.
echo   --only=IDE  target a single IDE
echo   --dir=PATH  override that IDE's skills dir ^(portable / relocated
echo               data dir^); must be combined with --only
echo   --force     rebuild junctions that point elsewhere
exit /b 0
