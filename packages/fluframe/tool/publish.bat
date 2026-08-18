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
echo Published to pub.dev.
echo.
echo Next: do NOT push a fluframe-vX.Y.Z tag. Such a tag fires the
echo workflow in .github\workflows\publish.yml, which re-runs every
echo gate and then calls dart pub publish --force on a version that
echo pub.dev already holds.
echo The run goes red - and red in that workflow means nothing was
echo published, which is exactly the wrong record for a release that
echo succeeded.
echo.
echo You are normally here because a tag run already failed at its
echo upload step, in which case the tag is on the release commit
echo already and there is nothing left to push. Otherwise leave it
echo untagged: pub.dev and CHANGELOG.md already record the version.
exit /b 0

:fail
echo.
echo Release gate FAILED - nothing was published.
exit /b 1
