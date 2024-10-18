@echo off
:: get full directory path where this file is located
for /F "delims=" %%i in ( "%~dp0" ) do ( set "ENV_PATH=%%~fi" )
:: strip trailing \
if "%ENV_PATH:~-1%" == "\" set "ENV_PATH=%ENV_PATH:~0,-1%"
:: get directory name
for /F "delims=" %%i in ( "%ENV_PATH%" ) do ( set "ENV=%%~nxi" )

if not defined PROMPT set PROMPT=$P$G
set "PROMPT=(%ENV%) %PROMPT%"
set "PATH=%ENV_PATH%;%ENV_PATH%\Scripts;%PATH%"
