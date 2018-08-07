@echo off
setlocal EnableDelayedExpansion

if "%PYTHON_VERSION%" == "" (
    echo "Missing PYTHON_VERSION variable"
    exit /b 1
)

if  "%PLATTAG%" == "" (
    echo "Missing PLATTAG variable"
    exit /b 1
)

set PYTAG=%PYTHON_VERSION:~0,1%%PYTHON_VERSION:~2,1%
set SPECARGS=--python-version %PYTHON_VERSION% --platform %PLATTAG% --pip-arg=-r --pip-arg=%ENVSPEC%

echo PYTAG    = %PYTAG%
echo SPECARGS = %SPECARGS%

rem Store/restore path around the build to not affect the tests later
set PATH_BEFORE_BUILD=%PATH%
set "PATH=%PYTHON%;%PYTHON%\Scripts;%PATH%"

python --version                     || exit /b !ERRORLEVEL!
python -m pip --version              || exit /b !ERRORLEVEL!

if not "%BUILD_DEPS%" == "" (
    python -m pip install %BUILD_DEPS%   || exit /b !ERRORLEVEL!
)
python -m pip list --format=freeze

if not "%BUILD_LOCAL%" == "" (
    rem # https://bugs.python.org/issue29943
    python -c "import sys; assert not sys.version_info[:3] == (3, 6, 1)" ^
        || exit /b !ERRORLEVEL!

    python setup.py %BUILD_GLOBAL_OPTIONS% bdist_wheel -d ../wheels  ^
        || exit /b !ERRORLEVEL!

    for /f %%s in ( 'python setup.py --version' ) do (
        set "VERSION=%%s"
    ) || exit /b !ERRORLEVEL!
) else (
    set "VERSION=%BUILD_COMMIT%"
)

echo VERSION  = "%VERSION%"

rem add msys2 and NSIS to path
set "PATH=C:\msys64\usr\bin;C:\Program Files (x86)\NSIS;%PATH%"
rem ensure unzip is present in msys2
bash -c "pacman -S --noconfirm unzip"  || exit /b %ERRORLEVEL%
bash -c "which unzip"                  || exit /b %ERRORLEVEL%
bash -e scripts/windows/build-win-installer.sh ^
     --find-links=../wheels ^
     --pip-arg=orange3==%VERSION%  ^
     %SPECARGS%        || exit /b %ERRORLEVEL%

for %%s in ( dist/Orange3-*-Python*-*.exe ) do (
    set "INSTALLER=%%s"
)
for /f %%s in ( 'sha256sum -b dist/%INSTALLER%' ) do (
    set "CHECKSUM=%%s"
)

echo INSTALLER = %INSTALLER%
echo SHA256    = %CHECKSUM%

rem restore original path
set "PATH=%PATH_BEFORE_BUILD%"

@echo on