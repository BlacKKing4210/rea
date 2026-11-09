@echo off
setlocal
pushd "%~dp0" || exit /b 1
rem RemoteSigned applies only to this process; policy and download marks stay intact.
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0Install-BlacKKing-REA.ps1" %*
set "REA_EXIT=%ERRORLEVEL%"
popd
exit /b %REA_EXIT%
