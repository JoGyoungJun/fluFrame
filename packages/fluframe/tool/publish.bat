@echo off
REM fluFrame release publisher (Windows) - runs every release gate, then
REM publishes to pub.dev. Run from anywhere; it locates the package root.
REM
REM   packages\fluframe\tool\publish.bat            interactive confirm
REM   packages\fluframe\tool\publish.bat --yes      skip confirm (no TTY)
REM
REM Publishing is forever. A failed gate aborts BEFORE publishing.

cd /d "%~dp0.."

echo === Gate 1/4: unit tests (includes the version-sync guard) ===
call dart test -x e2e || goto :fail

echo === Gate 2/4: sync template bundle ===
call dart run tool/sync_template.dart || goto :fail

echo === Gate 3/4: e2e (generate from bundle, analyze + test) ===
call dart test -t e2e || goto :fail

echo === Gate 4/4: publish dry-run ===
call dart pub publish --dry-run || goto :fail

if /i "%~1"=="--yes" goto :publish
echo.
set /p CONFIRM="All gates green. Publish to pub.dev now? (y/N) "
if /i not "%CONFIRM%"=="y" (
  echo Aborted - nothing was published.
  exit /b 1
)

:publish
call dart pub publish --force || goto :fail
echo.
echo Published. Next: git tag fluframe-vX.Y.Z ^&^& git push origin fluframe-vX.Y.Z
exit /b 0

:fail
echo.
echo Release gate FAILED - nothing was published.
exit /b 1
