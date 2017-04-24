$PYTAG = "$Env:PYTHON_VERSION.substring(0,1)$Env:PYTHON_VERSION.substring(2,1)"
$SPECARGS=@(
    "--python-version", "$env:PYTHON_VERSION",
    "--platform", "$env:PLATTAG",
    "--pip-arg=-r", "--pip-arg=$env:ENVSPEC"
)
echo "PYTAG    = $env:PYTAG"
echo "SPECARGS = $env:SPECARGS"

& git clone -q --depth 20 %REPO%
if ($LastExitCode -ne 0) { throw "git command exited with $LastExitCode" }
cd orange3
& git fetch origin $env:BUILD_BRANCH
if ($LastExitCode -ne 0) { throw "git command exited with $LastExitCode" }
& git checkout $env:BUILD_COMMIT
if ($LastExitCode -ne 0) { throw "git command exited with $LastExitCode" }

# Store/restore path around the build to not affect the tests later

$PATH_BEFORE_BUILD = "$Env:PATH"
$Env:PATH="$Env:PYTHON;$env:PYTHON\Scripts;$env:PATH"

# https://bugs.python.org/issue29943
& python -c "import sys; assert not sys.version_info[:3] == (3, 6, 1)"
if ($LastExitCode -ne 0) { throw "python version == 3.6.1" }

& python --version
if ($LastExitCode -ne 0) { throw "python exited with $LastExitCode" }

& python -m pip --version
if ($LastExitCode -ne 0) { throw "pip exited with $LastExitCode" }

& python -m pip install ( "$Env:BUILD_DEPS" -Split )


& python setup.py %BUILD_OPTIONS% bdist_wheel -d ../wheels
if ($LastExitCode -ne 0) { throw "python exited with $LastExitCode" }

$Env:VERSION = & python setup.py --version
if ($LastExitCode -ne 0) { throw "python exited with $LastExitCode" }

# Strip newline from the end (.TrimEnd() does not work ????)
$Env:VERSION = ( ( $Env:VERSION + " " ).trim() )
echo "VERSION  = "$Env:VERSION"
# add msys2 and NSIS to path
set PATH=C:\msys64\usr\bin;C:\Program Files (x86)\NSIS;%PATH%
bash -c "pacman -S --noconfirm unzip"
bash -c "which unzip"
bash -e scripts/windows/build-win-installer.sh --find-links=../wheels --pip-arg=orange3==%VERSION% %SPECARGS%
cd ..
set INSTALLER=Orange3-%VERSION%-Python%PYTAG%-%PLATTAG%.exe
restore original path
set PATH=%PATH_BEFORE_BUILD%