@echo off
chcp 65001 >nul
rem ============================================================
rem  anotherme rule sync -- launcher
rem
rem  All logic lives in sync-rules.ps1: two of the four targets need
rem  text surgery (preserve CodeBuddy's IDE-managed .mdc frontmatter,
rem  regenerate CLAUDE.md behind an auto-generated marker) which batch
rem  cannot do without corrupting content. This wrapper keeps the entry
rem  point identical to the other scripts (install.bat calls it, and a
rem  plain double-click works).
rem
rem  Usage:
rem    sync-rules.bat                Sync to all detected IDEs
rem    sync-rules.bat --only=qoder   Sync one IDE only
rem                                  (codebuddy / qoder / qodercn / claude)
rem    sync-rules.bat --check        Report drift only, write nothing
rem    sync-rules.bat --force        Overwrite CLAUDE.md even if it holds
rem                                  content this repo did not generate
rem ============================================================

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync-rules.ps1" %*
exit /b %ERRORLEVEL%
