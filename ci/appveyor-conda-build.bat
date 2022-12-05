@echo on
setlocal EnableDelayedExpansion

if "%PYTHON_VERSION%" == "" (
    echo PYTHON_VERSION must be defined >&2
    exit /b 1
)

if  "%PLATTAG%" == "" (
    echo Missing PLATTAG variable >&2
    exit /b 1
)

rem activate the root conda environment (miniconda3 4.7.0 installs
rem libarchive that requires this - conda cannot be used as a executable
rem without activation first)
if exist "%CONDA%\..\activate" (
    call "%CONDA%\..\activate"
)

"%CONDA%" config --append channels conda-forge  || exit /b !ERRORLEVEL!

if not "%CONDA_USE_ONLY_TAR_BZ2%" == "" (
    "%CONDA%" config --set use_only_tar_bz2 True  || exit /b !ERRORLEVEL!
    "%CONDA%" clean --all --yes
)

if "%CONDA_BUILD_VERSION%" == "" (
    set "CONDA_BUILD_VERSION=3.17.8"
)

if "%MINICONDA_VERSION%" == "" (
    set "MINICONDA_VERSION=4.7.12"
)

if not "%BUILD_LOCAL%" == "" (
    "%CONDA%" install --yes conda-build=%CONDA_BUILD_VERSION%  || exit /b !ERRORLEVEL!
    "%CONDA%" install --yes git
    "%CONDA%" build --no-test --python %PYTHON_VERSION% conda-recipe ^
        || exit /b !ERRORLEVEL!

    rem # Copy the build conda pkg to artifacts dir
    rem # and the cache\conda-pkgs which is used later by build-conda-installer
    rem # script

    mkdir ..\conda-pkgs        || exit /b !ERRORLEVEL!
    mkdir ..\cache             || exit /b !ERRORLEVEL!
    mkdir ..\cache\conda-pkgs  || exit /b !ERRORLEVEL!

    for /f %%s in ( '"%CONDA%" build --output --python %PYTHON_VERSION% ../specs/conda-recipe' ) do (
        copy /Y "%%s" ..\conda-pkgs\  || exit /b !ERRORLEVEL!
        copy /Y "%%s" ..\cache\conda-pkgs\  || exit /b !ERRORLEVEL!
    )

    for /f %%s in ( '"%PYTHON%" setup.py --version' ) do (
        set "VERSION=%%s"
    )
) else (
    set "VERSION=%BUILD_COMMIT%"
)

echo VERSION = %VERSION%

if "%CONDA_SPEC_FILE%" == "" (
    rem # prefer conda forge
    "%CONDA%" config --add channels conda-forge  || exit /b !ERRORLEVEL!
    "%CONDA%" config --set channel_priority strict

    "%CONDA%" create -n env --yes --use-local ^
                 python=%PYTHON_VERSION% ^
                 numpy=1.23.* ^
                 scipy=1.9.* ^
                 scikit-learn=1.1.* ^
                 pandas=1.4.* ^
                 pyqtgraph=0.13.* ^
                 bottleneck=1.3.* ^
                 pyqt=5.15.* ^
                 pyqtwebengine=5.15.* ^
                 Orange3=%VERSION% ^
                 blas=*=openblas ^
        || exit /b !ERRORLEVEL!

    "%CONDA%" list -n env --export --explicit --md5 > env-spec.txt
    set CONDA_SPEC_FILE=env-spec.txt
)

type "%CONDA_SPEC_FILE%"

bash -e ../scripts/windows/build-conda-installer.sh ^
        --platform %PLATTAG% ^
        --cache-dir ../.cache ^
        --dist-dir dist ^
        --miniconda-version "%MINICONDA_VERSION%" ^
        --env-spec "%CONDA_SPEC_FILE%" ^
        --online no ^
    || exit /b !ERRORLEVEL!


for %%s in ( dist/Orange3-*Miniconda*.exe ) do (
    set "INSTALLER=%%s"
)

for /f %%s in ( 'sha256sum -b dist/%INSTALLER%' ) do (
    set "CHECKSUM=%%s"
)

echo INSTALLER = %INSTALLER%
echo SHA256    = %CHECKSUM%

@echo on
