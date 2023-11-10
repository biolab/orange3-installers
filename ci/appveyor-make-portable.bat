setlocal

rem Install prefix
set "PREFIX=%~1"

rem Output filename
set "OUTPUT=%~2"
set "__PATH=%PATH%"

set "PATH=C:\Python37-x64;C:\msys64\usr\bin;%PATH%"
python -m pip install pywin32

set "THISHEREDIR=%~dp0"
set "TEMP=%CD%\temp\Orange"
mkdir "%TEMP%"

xcopy /q /s /i "%PREFIX%" "%TEMP%"
del "%TEMP%\Orange-Uninstall.exe"
del "%TEMP%\Orange Command Prompt.lnk"
del "%TEMP%\Scripts\conda.bat"
del "%TEMP%\Scripts\activate.bat"

set "QT_CONF=%TEMP%\qt.conf"
echo [Paths]>                         "%QT_CONF%"
echo Prefix = ./Library>>             "%QT_CONF%"
echo Binaries = ./Library/bin>>       "%QT_CONF%"
echo Libraries = ./Library/lib>>      "%QT_CONF%"
echo Headers = ./Library/include/qt>> "%QT_CONF%"

set "QT_CONF=%TEMP%\Library\bin\qt.conf"
echo [Paths]>                  "%QT_CONF%"
echo Prefix = ../>>            "%QT_CONF%"
echo Binaries = ../bin>>       "%QT_CONF%"
echo Libraries = ../lib>>      "%QT_CONF%"
echo Headers = ../include/qt>> "%QT_CONF%"

mkdir "%TEMP%\etc"
copy "%THISHEREDIR%\orangerc.conf" "%TEMP%\etc\orangerc.conf"

python "%THISHEREDIR%\create_shortcut.py" ^
   --target %%COMSPEC%% ^
   --arguments "/C start pythonw.exe -m Orange.canvas" ^
   --working-directory "" ^
   --window-style Minimized ^
   --shortcut "%TEMP%\Orange.lnk"

python "%THISHEREDIR%\create_shortcut.py" ^
   --target %%COMSPEC%% ^
   --arguments "/K python.exe -m Orange.canvas -l4" ^
   --working-directory "" ^
   --shortcut "%TEMP%\Orange Debug.lnk"

python "%THISHEREDIR%\create_shortcut.py" ^
   --target %%COMSPEC%% ^
   --arguments "/C start Orange\pythonw.exe -m Orange.canvas" ^
   --working-directory "" ^
   --window-style Minimized ^
   --shortcut "%TEMP%\..\Orange.lnk"


pushd "%TEMP%\.."
zip --quiet -9 -r temp.zip Orange Orange.lnk -x 'Orange/pkgs/*' '*.pyc' '*.pyo' '*/__pycache__/*''
popd

move /y "%TEMP%\..\temp.zip" "%OUTPUT%"
set "PATH=%__PATH%"
