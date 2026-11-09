@echo off
setlocal
if not exist "%~dp0runtime\node\node.exe" (
  echo Missing bundled Node. Extract the complete release ZIP first.
  exit /b 1
)
if not exist "%~dp0runtime\rea\scripts\rea.mjs" (
  echo Missing bundled REA. Extract the complete release ZIP first.
  exit /b 1
)
pushd "%~dp0" || exit /b 1
"%~dp0runtime\node\node.exe" "%~dp0runtime\rea\scripts\rea.mjs" %*
set "REA_EXIT=%ERRORLEVEL%"
popd
exit /b %REA_EXIT%
