#
# A Conda flavored NSIS installer script for Orange3 Windows application
#

# Required definitions need to be passed to the makensis call
#  - BASEDIR base location of all required files, ... (see below)
#  - PYARCH python architecture identifier (win32 or amd64)
#  - PY{MAJOR,MINOR,MICRO} Python version to be installed in the new env
#  - APPNAME Application (short) name
#  - VER{MAJOR,MINOR,MICRO} Application version
#  - INSTALL_REGISTRY_KEY reg subkey name to use for storing install information
#       (details will be stored under Software/${INSTALL_REGISTRY_KEY})


# Required data layout at compile time
# (by default BASEDIR is the directory where this .nsi script is located;
# use -NOCD parameter when invoking makensis to preserve invoker cwd)

# ${BASEDIR}/
#   conda-pkgs/
#   install.bat
#   conda-spec.txt

Unicode True

# Short name, used in paths
!ifndef APPNAME
    !error "APPNAME must be defined"
!endif

# Long name, used for shortcuts
!ifndef APPLICATIONNAME
    !define APPLICATIONNAME ${APPNAME}
!endif

# Name used in registry keys
!ifndef INSTALL_REGISTRY_KEY
    !define INSTALL_REGISTRY_KEY ${APPNAME}
!endif

!ifdef VERMAJOR & VERMINOR
    !ifdef VERMICRO
        !define APPVERSION ${VERMAJOR}.${VERMINOR}.${VERMICRO}
    !else
        !define APPVERSION ${VERMAJOR}.${VERMINOR}
    !endif
!else
    !error "VERMAJOR and VERMINOR are no defiend"
!endif

!define PYTHON_VERSION ${PYMAJOR}.${PYMINOR}.${PYMICRO}
!define PYTAG ${PYMAJOR}${PYMINOR}

!if ${PYARCH} == win32
    !define BITS 32
!else if ${PYARCH} == win_amd64
    !define BITS 64
!else
    !error "Invalid PYARCH ${PYARCH}"
!endif

!ifndef LAUNCHERMODULE
    !error "LAUNCHERMODULE must be defined"
!endif


!ifndef OUTFILENAME
    !define OUTFILENAME ${APPNAME}-${APPVERSION}-setup.exe
!endif


OutFile "${OUTFILENAME}"
Name ${APPNAME}-${VERSION}

# Default install folder name
!ifndef DEFAULT_INSTALL_FOLDER
    !define DEFAULT_INSTALL_FOLDER ${APPNAME}
!endif

# Conda packages which are already compressed.
SetCompress "off"

!ifdef INSTALLERICON
    Icon "${INSTALLERICON}"
    UninstallIcon "${INSTALLERICON}"

    !define MUI_ICON ${INSTALLERICON}
    !define MUI_UNICON ${INSTALLERICON}
!endif

!ifndef APPICON
    !define APPICON "${APPNAME}.ico"
!endif

!ifndef ICONDIR
    !define ICONDIR "${APPNAME}\icons"
!endif

!ifndef BASEDIR
    !define BASEDIR .
!endif

# Application launcher shortcut name (in start menu or on the desktop)
!ifndef LAUNCHER_SHORTCUT_NAME
    !define LAUNCHER_SHORTCUT_NAME "${APPLICATIONNAME}"
!endif

# Registry key/values where the installation layout is saved
!define INSTALL_SETTINGS_KEY Software\${INSTALL_REGISTRY_KEY}
!define INSTALL_SETTINGS_INSTDIR InstallDir
!define INSTALL_SETTINGS_INSTMODE InstallMode

# Support for both current or all users installation layout
# (see MultiUser/Readme.html)
!define MULTIUSER_EXECUTIONLEVEL Highest

# By default select current user mode
!define MULTIUSER_INSTALLMODE_DEFAULT_CURRENTUSER

!if ${BITS} == 64
    # Use correct program files folder.
    # NSIS >= 3.02 (currently still unreleased)
    !define MULTIUSER_USE_PROGRAMFILES64
!endif

# Enable the Current/All Users selection page.
!define MULTIUSER_MUI

# Enable /AllUsers or /CurrentUser command line switch
# (see MultiUser/Readme.html)
!define MULTIUSER_INSTALLMODE_COMMANDLINE

# the default folder name where the application will be installed
!define MULTIUSER_INSTALLMODE_INSTDIR ${DEFAULT_INSTALL_FOLDER}

!define MULTIUSER_INSTALLMODE_INSTDIR_REGISTRY_KEY ${INSTALL_SETTINGS_KEY}
!define MULTIUSER_INSTALLMODE_INSTDIR_REGISTRY_VALUENAME ${INSTALL_SETTINGS_INSTDIR}

!define MULTIUSER_INSTALLMODE_DEFAULT_REGISTRY_KEY ${INSTALL_SETTINGS_KEY}
!define MULTIUSER_INSTALLMODE_DEFAULT_REGISTRY_VALUENAME ${INSTALL_SETTINGS_INSTMODE}

# A function which will restore the install dir passed on the command
# line (/D=DIR) if running in silent mode (MultiUser.nsh will not respect
# the default $InstDir).
!define MULTIUSER_INSTALLMODE_FUNCTION RestoreSilentInstallDir

!include Sections.nsh
!include MultiUser.nsh
!include MUI2.nsh
!include LogicLib.nsh
!include FileFunc.nsh

# Installer Pages Definitions
# ---------------------------

!insertmacro MUI_PAGE_WELCOME

!ifdef LICENSE_FILE
    !insertmacro MUI_PAGE_LICENSE "${LICENSE_FILE}"
!endif

!define MUI_STARTMENUPAGE_DEFAULTFOLDER ${APPNAME}
# Stay on InstFiles page to allow log view inspection
!define MUI_FINISHPAGE_NOAUTOCLOSE

Var StartMenuFolder

# All/Current user install selection selection page:
!insertmacro MULTIUSER_PAGE_INSTALLMODE

# Components Selection Page:
# - put the component description box at the bottom of the list (more
#   compact GUI)
!define MUI_COMPONENTSPAGE_SMALLDESC
!insertmacro MUI_PAGE_COMPONENTS

# Install Directory selection page:
# Custom function to call on leaving the Directory Page (validation)
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE "DirectoryLeave"
!insertmacro MUI_PAGE_DIRECTORY

# Start Menu Directory selection page:
# - custom start menu page pre callback function to skip the page if
#   Start Menu section is unselected
!define MUI_PAGE_CUSTOMFUNCTION_PRE "StartMenuPre"
# - no check box to enable/disable start menu creation
#   (is controled by the Components Page)
!define MUI_STARTMENUPAGE_NODISABLE
# Registry key path where the selected start folder name is stored
!define MUI_STARTMENUPAGE_REGISTRY_ROOT SHELL_CONTEXT
!define MUI_STARTMENUPAGE_REGISTRY_KEY ${INSTALL_SETTINGS_KEY}
!define MUI_STARTMENUPAGE_REGISTRY_VALUENAME StartMenuFolder
!insertmacro MUI_PAGE_STARTMENU StartMenuPageID $StartMenuFolder

# Install Files page:
!insertmacro MUI_PAGE_INSTFILES

# Finish Page:
# - run the application from the finish page
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_FUNCTION "LaunchApplication"
!define MUI_FINISHPAGE_RUN_TEXT "Start ${APPLICATIONNAME}"
# - add link at the bottom
!define MUI_FINISHPAGE_LINK "orange.biolab.si"
!define MUI_FINISHPAGE_LINK_LOCATION "http://orange.biolab.si"

!insertmacro MUI_PAGE_FINISH

# Uninstaller Page Definitions
# ----------------------------
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH

!insertmacro MUI_LANGUAGE English


# Temporary folder where temp data will be extracted
# ($PLUGINSDIR is the (supposedly) recommend place for this; deleted on exit)
!define TEMPDIR "$PLUGINSDIR\${APPNAME}-installer-data"

!include "PythonHelpers.nsh"

#
# ${ExtractTemp} Resource TargetLocation
#
#   Extract a Resource (available at compile time) to TargetLocation
#   (available at install time)
#
!macro _EXTRACT_TEMP_MACRO RESOURCE LOCATION
    SetOutPath ${LOCATION}
    File ${RESOURCE}
!macroend
!define ExtractTemp "!insertmacro _EXTRACT_TEMP_MACRO"

#
# ${ExtractTempRec} Resource TargetLocation
#
#   Extract a Resource (available at compile time) recursively to
#   TargetLocation (available at install time)
#
!macro _EXTRACT_TEMP_MACRO_REC RESOURCE LOCATION
    SetOutPath ${LOCATION}
    File /r ${RESOURCE}
!macroend
!define ExtractTempRec "!insertmacro _EXTRACT_TEMP_MACRO_REC"


# Key prefix where "Add/Remove Programs" entries are registerd
!define WINDOWS_UNINSTALL_REGKEY \
    "Software\Microsoft\Windows\CurrentVersion\Uninstall"

# Full key path for the application uninstall entry in Add/Remove Programs
!define APPLICATION_UNINSTALL_REGKEY "${WINDOWS_UNINSTALL_REGKEY}\${INSTALL_REGISTRY_KEY}"

# Uninstaller base name
!ifndef UNINSTALL_EXEFILE
    !define UNINSTALL_EXEFILE "${APPLICATIONNAME}-Uninstall.exe"
!endif

# Preserved $InstDir as present in .onInit (i.e from /D=... command line
# switch)
Var SilentInstallDir

# The created env Python installation layout
Var PythonPrefix
Var PythonExecPrefix
Var PythonScriptsPrefix

Var LogFile
!macro __LOG_INIT
    !ifdef __UNINSTALL__
        FileOpen $LogFile "$TEMP\${UNINSTALL_EXEFILE}-uninstall-log.txt" "w"
    !else
        FileOpen $LogFile "$TEMP\$EXEFILE-install-log.txt" "w"
    !endif
    FileWrite $LogFile "------------------------$\r$\n"
    !ifdef __UNINSTALL__
        FileWrite $LogFile "${APPLICATIONNAME} ${VERSION} Uninstall Log$\r$\n"
    !else
        FileWrite $LogFile "${APPLICATIONNAME} ${VERSION} Install Log$\r$\n"
    !endif
    FileWrite $LogFile "------------------------$\r$\n"
!macroend

!define LogInit "!insertmacro __LOG_INIT"

# ${LogWrite}  STR
# ----------------
# Write a STR to $LogFile. The $LogFile file must already be open
# (by ${LogInit})
!macro __LOG_WRITE TEXT
    FileWrite $LogFile '${TEXT}$\r$\n'
!macroend
!define LogWrite "!insertmacro __LOG_WRITE"


# ${ExecToLog} COMMAND
# --------------------
# Log the COMMAND using ${LogWrite} and execute it using nsExec::ExecToLog
!macro __EXEC_TO_LOG COMMAND
    ${LogWrite} 'nsExec::ExecToLog: ${COMMAND}'
    SetDetailsPrint listonly
    DetailPrint 'Executing: ${COMMAND}'
    SetDetailsPrint both
    nsExec::ExecToLog '${COMMAND}'
!macroend
!define ExecToLog "!insertmacro __EXEC_TO_LOG"


# Validate the selected installation directory. Show a message and Abort
# if it is not suitable for installation.
Function DirectoryLeave
    ${LogWrite} "DirectoryLeave"
    ${LogWrite} "InstDir: $InstDir"
    Push $R0
    Push $R1
    Push $R2
    Push $R3
    ${DirState} "$InstDir" $R0
    ${LogWrite} "InstDir state: $R0"
    # Check if this looks like a location of an existing install
    ${If} $R0 == 1
        # Directory exists and is not empty
        ${If} ${FileExists} "$InstDir\${UNINSTALL_EXEFILE}"
        ${AndIf} ${FileExists} "$InstDir\python.exe"
        ${AndIf} ${FileExists} "$InstDir\${LAUNCHER_SHORTCUT_NAME}.lnk"
        ${AndIfNot} ${FileExists} "$InstDir\pyvenv.cfg"
            # Check that the existing env is binary compatible
            ${GetPythonVersion} "$InstDir\python.exe" $R1 $R2
            ${GetPythonArch} "$InstDir\python.exe" $R1 $R3

            ${If} $R1 != 0
            ${OrIf} "$R2/$R3" != "${PYMAJOR}.${PYMINOR}/${PYARCH}"
                ${LogWrite} 'Python version/architecture mismatch \
                             ($R2/$R3 != ${PYMAJOR}.${PYMINOR}/${PYARCH})'
                MessageBox MB_OK '\
                    "$InstDir" contains a pre-existing environment \
                    that is not binary compatible with this installer.$\r$\n\
                    Uninstall the existing version of ${APPLICATIONNAME} or \
                    choose another destination folder.'
                Abort '$R1 $R2 != "${PYMAJOR}.${PYMINOR} ${PYARCH}"'
            ${EndIf}
            ${LogWrite} 'Found existing python in $InstDir: $R2 - $R3'

            MessageBox MB_YESNO|MB_ICONQUESTION \
                '"$InstDir" looks like an existing ${APPLICATIONNAME} \
                 installation. Do you want to overwrite it?' \
                /SD IDYES IDYES continue_ IDNO abort_
            abort_:
                ${LogWrite} "Overwrite of an existing installation cancelled \
                             by user (InstDir: $InstDir)"
                Abort "Aborting"
            continue_:
                ${LogWrite} "Reusing an existing installation directory: \
                            $InstDir"
        ${Else}
            ${LogWrite} "$InstDir is not empty, aborting"
            MessageBox MB_OK '"$InstDir" exists and is not empty.$\r$\n \
                              Please choose another destination folder.'
            Abort '"$InstDir" exists an is not empty'
        ${EndIf}
    ${EndIf}
    Pop $R2
    Pop $R1
    Pop $R0
FunctionEnd


Function RestoreSilentInstallDir
    ${If} $SilentInstallDir != ""
    ${AndIf} ${Silent}
        StrCpy $InstDir $SilentInstallDir
        ${LogWrite} "Restored InstDir to: $SilentInstallDir"
    ${EndIf}
FunctionEnd


# Section Micromamba
# ------------------
# A Micromamba executable
Section "-Micromamba" SectionMicromamba
    DetailPrint "Installing micromamba.exe"
    ${ExtractTemp} "${BASEDIR}\micromamba.exe" "$InstDir"
SectionEnd

Function un.Micromamba
    Delete "$InstDir\micromamba.exe"
FunctionEnd


Section "-Micromamba env setup" SectionEnvSetup
    # Setup the PythonPrefix/PythonExecPrefix... variables
    # but does not actualy create any env (this is done in single step
    # in InstallPackages section
    ${LogWrite} "Using root conda env $InstDir"
    ${LogWrite} "Configuring to use/create conda env in $InstDir"

    StrCpy $PythonPrefix "$InstDir"
    StrCpy $PythonExecPrefix "$PythonPrefix"
    StrCpy $PythonScriptsPrefix "$PythonPrefix\Scripts"

    ${LogWrite} "Setting up:"
    ${LogWrite} "   PythonPrefix: $PythonPrefix"
    ${LogWrite} "   PythonExecPrefix: $PythonExecPrefix"
    ${LogWrite} "   PythonScriptsPrefix: $PythonScriptsPrefix"
SectionEnd

Function un.Environment
FunctionEnd


Section "Install required packages" InstallPackages
    SectionIn RO
    ${If} $PythonPrefix == ""
        Abort "No target python prefix configured. Cannot proceed."
    ${EndIf}
    ${If} ${FileExists} "$PythonPrefix\python.exe"
        DetailPrint 'Updating a conda env in "$PythonPrefix"'
        StrCpy $0 "install"
    ${Else}
        DetailPrint 'Creating an new conda env in "$PythonPrefix"'
        StrCpy $0 "create"
    ${EndIf}

!ifdef ONLINE
        ${ExtractTemp} "${BASEDIR}\conda-spec.txt" "${TEMPDIR}"
!else
        ${ExtractTemp} "${BASEDIR}\conda-spec.txt" "${TEMPDIR}"
        ${ExtractTemp} "${BASEDIR}\install.bat" "${TEMPDIR}"
        ${ExtractTemp} "${BASEDIR}\sitecustomize.py" "${TEMPDIR}"
        ${ExtractTempRec} "${BASEDIR}\conda-pkgs\*.*" "$InstDir\pkgs"
!endif  # ONLINE

    Push $OUTDIR
    SetDetailsPrint none
    SetOutPath "${TEMPDIR}"
    SetDetailsPrint both
 !ifdef ONLINE
    # Create an empty env first
    ${If} $0 == "create"
        # Create an empty initial skeleton to layout the conda, activate.bat
        # and other things needed to manage the environment. Installing from
        # an explicit package specification file does not do that.
        ${ExecToLog} '\
            "$InstDir\micromamba.exe" create \
                --yes --quiet --prefix "$PythonPrefix" \
            '
        Pop $0
        ${If} $0 != 0
            Abort '"micromamba create" exited with $0. Cannot continue.'
        ${EndIf}
    ${EndIf}
    DetailPrint "Fetching and installing packages (this might take a while)"
    ${ExecToLog} '\
        "$InstDir\micromamba.exe" install \
            --yes --quiet \
            --file "${TEMPDIR}\conda-spec.txt" \
            --prefix "$PythonPrefix" \
        '
!else
    # Run the install via from a helper script (informative output).
    DetailPrint "Installing packages (this might take a while)"
    ${ExecToLog} 'cmd.exe /c install.bat "$PythonPrefix" "$InstDir\micromamba.exe"'
!endif # ONLINE
    Pop $0
    SetDetailsPrint none
    Pop $OUTDIR
    SetDetailsPrint both
    ${If} $0 != 0
        Abort '"conda" command exited with $0. Cannot continue.'
    ${EndIf}
SectionEnd


# Remove all packages from the created environment
Function un.InstallPackages
    ${LogWrite} "Removing all installed packages:"
    ${LogWrite} "    installprefix: $InstDir"
    ${LogWrite} "    root conda prefix: $InstDir"
    ${If} $InstDir != ""
    ${AndIf} ${FileExists} "$InstDir\${UNINSTALL_EXEFILE}"
        DetailPrint "Removing all packages"
        ${ExecToLog} '\
            "$InstDir\micromamba.exe" remove \
                --root-prefix "$InstDir" \
                --all --yes --prefix "$InstDir" \
            '
        Pop $0
        ${LogWrite} '"micromamba remove" command exited with $0'
        ${If} $0 != 0
            MessageBox MB_OK '"micromamba remove" command exited with an error ($0)'
        ${EndIf}
        RMDir /r "$InstDir\pkgs"
        RMDir /r "$InstDir\condabin"
        RMDir /r "$InstDir\conda-meta"
        RMDir /r "$InstDir\Scripts"
        RMDir /r "$InstDir\Lib"
        RMDir /r "$InstDir\share"
        Delete "$InstDir\.condarc"
    ${Else}
        ${LogWrite} '"$InstDir" does not look like an ${APPNAME} installation. \
                     Not removing.'
    ${EndIf}
FunctionEnd


Section -Icons
    # Layout icons if necessary (are not present)
    ${IfNot} ${FileExists} $PythonPrefix\share\${ICONDIR}\*.ico"
        ${ExtractTempRec} "${BASEDIR}\icons\*.ico" "${TEMPDIR}\icons"
        CreateDirectory "$PythonPrefix\share\${ICONDIR}"
        CopyFiles /SILENT "${TEMPDIR}\icons\*.ico" \
                          "$PythonPrefix\share\${ICONDIR}"
    ${EndIf}
SectionEnd


# Create utility shortcut launchers in the $InstDir
Section -Launchers
    SetOutPath "%HOMEDRIVE%\%HOMEPATH%"
    DetailPrint "Creating launcher shortcuts"
    # Startup shortcut
    CreateShortCut \
        "$InstDir\${LAUNCHER_SHORTCUT_NAME}.lnk" \
        "$PythonExecPrefix\pythonw.exe" "-Psm ${LAUNCHERMODULE}" \
        "$PythonPrefix\share\${ICONDIR}\${APPICON}" 0
    # Utility shortcut to launch the application with max log level attached
    # to the console that remains visible after exit
    CreateShortCut \
        "$InstDir\${LAUNCHER_SHORTCUT_NAME} Debug.lnk" \
        "%COMSPEC%" '/K "$PythonExecPrefix\python.exe" -Psm ${LAUNCHERMODULE} -l4' \
        "$PythonPrefix\share\${ICONDIR}\${APPICON}" 0
    # A utility shortcut for activating the environment
    CreateShortCut \
        "$InstDir\${APPNAME} Command Prompt.lnk" \
        "%COMSPEC%" '/S /K ""$PythonScriptsPrefix\activate.bat" "$InstDir""'
SectionEnd


Function un.Launchers
    Delete "$InstDir\${LAUNCHER_SHORTCUT_NAME}.lnk"
    Delete "$InstDir\${LAUNCHER_SHORTCUT_NAME} Debug.lnk"
    Delete "$InstDir\${APPNAME} Command Prompt.lnk"
FunctionEnd


SectionGroup "Shortcuts" SectionShortcuts
Section "Start Menu Shortcuts" SectionStartMenu
    !insertmacro MUI_STARTMENU_WRITE_BEGIN StartMenuPageID
    DetailPrint "Creating Start Menu Shortcuts"
    ${If} $StartMenuFolder != ""
        ${LogWrite} "Creating shortcuts in $SMPROGRAMS\$StartMenuFolder"
        # Output path is used as the default CWD for the created shortcuts
        SetDetailsPrint none
        SetOutPath "%HOMEDRIVE%\%HOMEPATH%"
        SetDetailsPrint both
        CreateDirectory "$SMPROGRAMS\$StartMenuFolder"
        CreateShortCut \
            "$SMPROGRAMS\$StartMenuFolder\${LAUNCHER_SHORTCUT_NAME}.lnk" \
            "$PythonExecPrefix\pythonw.exe" "-Psm ${LAUNCHERMODULE}" \
            "$PythonPrefix\share\${ICONDIR}\${APPICON}" 0

        # A utility shortcut for activating the environment
        CreateShortCut \
            "$SMPROGRAMS\$StartMenuFolder\${APPNAME} Command Prompt.lnk" \
            "%COMSPEC%" '/S /K ""$PythonScriptsPrefix\activate.bat" "$InstDir""'
    ${EndIf}
    !insertmacro MUI_STARTMENU_WRITE_END
SectionEnd

# StartMenuPage 'pre' callback. Skip Start Menu directory selection if
# the SectionStarMenu is not selected on the Components page
Function StartMenuPre
    ${IfNot} ${SectionIsSelected} ${SectionStartMenu}
        ${LogWrite} "Skiping start menu page because it is not selected"
        Abort
    ${EndIf}
FunctionEnd

Section "Desktop Shortcuts" SectionDesktop
    DetailPrint "Installing Desktop shortcut"
    SetOutPath "%HOMEDRIVE%\%HOMEPATH%"
    CreateShortCut \
        "$DESKTOP\${LAUNCHER_SHORTCUT_NAME}.lnk" \
        "$PythonExecPrefix\pythonw.exe" "-Psm ${LAUNCHERMODULE}" \
        "$PythonPrefix\share\${ICONDIR}\${APPICON}" 0
SectionEnd
SectionGroupEnd


Function un.Shortcuts
    !insertmacro MUI_STARTMENU_GETFOLDER StartMenuPageID $0
    ${If} $0 != ""
    ${AndIf} ${FileExists} "$SMPROGRAMS\$0"
        ${LogWrite} "Removing Start Menu Shortcuts (from $SMPROGRAMS\$0)"
        DetailPrint "Removing Start Menu shortcuts"
        Delete "$SMPROGRAMS\$0\${LAUNCHER_SHORTCUT_NAME}.lnk"
        Delete "$SMPROGRAMS\$0\${APPNAME} Command Prompt.lnk"
        RMDir "$SMPROGRAMS\$0"
    ${EndIf}
    ${LogWrite} "Removing Desktop shortcurt"
    DetailPrint "Removing Desktop shortcurt"
    Delete "$DESKTOP\${LAUNCHER_SHORTCUT_NAME}.lnk"
FunctionEnd


# Should this section be made selectable by the user. Would allow multiple
# installations.
Section -Register SectionRegister
    DetailPrint "Writing to registry"
    ${LogWrite} 'Register installation layout (${INSTALL_SETTINGS_KEY})'
    ${LogWrite} '    BasePythonPrefix "$InstDir"'
    WriteRegStr SHELL_CONTEXT \
                ${INSTALL_SETTINGS_KEY} BasePythonPrefix "$InstDir"
    ${LogWrite} '    PythonPrefix "$PythonPrefix"'
    WriteRegStr SHELL_CONTEXT \
                ${INSTALL_SETTINGS_KEY} PythonPrefix "$PythonPrefix"
    ${LogWrite} '    ${INSTALL_SETTINGS_INSTDIR} "$InstDir"'
    WriteRegStr SHELL_CONTEXT \
                ${INSTALL_SETTINGS_KEY} ${INSTALL_SETTINGS_INSTDIR} \
                "$InstDir"

    WriteRegStr SHELL_CONTEXT \
                ${INSTALL_SETTINGS_KEY} ${INSTALL_SETTINGS_INSTMODE} \
                $MultiUser.InstallMode

    ${LogWrite} "Register .ows filetype"
    WriteRegStr SHELL_CONTEXT \
        "Software\Classes\.ows" "" ${INSTALL_REGISTRY_KEY}
    WriteRegStr SHELL_CONTEXT \
        "Software\Classes\${INSTALL_REGISTRY_KEY}" "" "Orange Workflow"
    WriteRegStr SHELL_CONTEXT \
        "Software\Classes\${INSTALL_REGISTRY_KEY}\DefaultIcon" "" \
        "$PythonPrefix\share\${ICONDIR}\OrangeOWS.ico"
    WriteRegStr SHELL_CONTEXT \
        "Software\Classes\${INSTALL_REGISTRY_KEY}\Shell\Open\Command\" "" \
        '"$PythonExecPrefix\pythonw.exe" -Psm ${LAUNCHERMODULE} "%1"'

    WriteUninstaller "$InstDir\${UNINSTALL_EXEFILE}"

    # Register uninstaller in Add/Remove Programs

    ${LogWrite} "Register uninstaller (${APPLICATION_UNINSTALL_REGKEY})"

    WriteRegStr SHELL_CONTEXT \
                "${APPLICATION_UNINSTALL_REGKEY}" \
                DisplayName "${APPLICATIONNAME} ${APPVERSION} (${BITS} bit)"
    WriteRegStr SHELL_CONTEXT \
                "${APPLICATION_UNINSTALL_REGKEY}" \
                DisplayVersion "${APPVERSION}"
    WriteRegStr SHELL_CONTEXT \
                "${APPLICATION_UNINSTALL_REGKEY}" \
                DisplayIcon "$InstDir\${UNINSTALL_EXEFILE}"
    WriteRegStr SHELL_CONTEXT \
                "${APPLICATION_UNINSTALL_REGKEY}" \
                "UninstallString" \
                '"$InstDir\${UNINSTALL_EXEFILE}" /$MultiUser.InstallMode'
    WriteRegStr SHELL_CONTEXT \
                "${APPLICATION_UNINSTALL_REGKEY}" \
                "QuietUninstallString" \
                '"$InstDir\${UNINSTALL_EXEFILE}" /$MultiUser.InstallMode /S'
    WriteRegStr SHELL_CONTEXT \
                "${APPLICATION_UNINSTALL_REGKEY}" \
                InstallLocation "$InstDir"
    WriteRegStr SHELL_CONTEXT \
                "${APPLICATION_UNINSTALL_REGKEY}" \
                URLInfoAbout http://orange.biolab.si

    WriteRegDWORD SHELL_CONTEXT \
                  "${APPLICATION_UNINSTALL_REGKEY}" \
                   NoModify 1
    WriteRegDWORD SHELL_CONTEXT \
                  "${APPLICATION_UNINSTALL_REGKEY}" \
                  NoRepair 1
SectionEnd


Var un.InstallDir

Function un.Register
    DetailPrint "Unregister"
    ReadRegStr $un.InstallDir SHCTX ${INSTALL_SETTINGS_KEY} InstallDir
    ${If} $un.InstallDir != ""
    ${AndIf} $un.InstallDir == $InstDir
        ${LogWrite} "Deleting reg key: ${INSTALL_SETTINGS_KEY}"
        DeleteRegKey SHCTX "${INSTALL_SETTINGS_KEY}"
        ${LogWrite} "Deleting reg key: Software\Classes\${INSTALL_REGISTRY_KEY}"
        DeleteRegKey SHCTX Software\Classes\${INSTALL_REGISTRY_KEY}
    ${Else}
        ${LogWrite} "InstallDir from ${INSTALL_SETTINGS_KEY} does not match \
                    InstDir ($un.InstallDir != $InstDir). Leaving it."
    ${EndIf}

    ReadRegStr $un.InstallDir SHCTX \
               "${APPLICATION_UNINSTALL_REGKEY}" InstallLocation
    ${If} $un.InstallDir != ""
    ${AndIf} $un.InstallDir == $InstDir
        ${LogWrite} "Deleting reg key: ${APPLICATION_UNINSTALL_REGKEY}"
        DeleteRegKey SHCTX "${APPLICATION_UNINSTALL_REGKEY}"
    ${Else}
        ${LogWrite} "InstallLocation from \
                     ${APPLICATION_UNINSTALL_REGKEY} does not match \
                     InstDir ($0 != $InstDir). Leaving it."
    ${EndIf}
FunctionEnd

Function LaunchApplication
    ExecShell "open" "$PythonExecPrefix\pythonw.exe" "-Psm ${LAUNCHERMODULE}"
FunctionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN

!insertmacro MUI_DESCRIPTION_TEXT ${InstallPackages} \
    "Install required packages into the destination environment"

!insertmacro MUI_DESCRIPTION_TEXT ${SectionStartMenu} \
    "Install Start Menu shortcuts"
!insertmacro MUI_DESCRIPTION_TEXT ${SectionDesktop} \
    "Install Desktop shortcuts"

!insertmacro MUI_FUNCTION_DESCRIPTION_END


Section Uninstall
    ReadRegStr $PythonPrefix SHCTX ${INSTALL_SETTINGS_KEY} PythonPrefix
    ReadRegStr $un.InstallDir SHCTX ${INSTALL_SETTINGS_KEY} InstallDir

    ${LogWrite} "InstDir: $InstDir"
    ${LogWrite} "Layout from registry:"
    ${LogWrite} "    InstallDir: $un.InstallDir"
    ${LogWrite} "    PythonPrefix: $PythonPrefix"

    Call un.Shortcuts
    Call un.Register
    Call un.Launchers
    Call un.InstallPackages
    Call un.Environment
    Call un.Micromamba

    ${If} ${FileExists} "$InstDir\${UNINSTALL_EXEFILE}"
        Delete "$InstDir\${UNINSTALL_EXEFILE}"
    ${EndIf}
SectionEnd


Function .onInit
    ${LogInit}
    InitPluginsDir
    # $InstDir is not empty if specified by the /D command line switch.
    # Store it because MultiUser.nsh will override it with its own either
    # in MULTIUSER_INIT or MULTIUSER_PAGE_INSTALLMODE.
    ${If} $InstDir != ""
    ${AndIf} ${Silent}
        StrCpy $SilentInstallDir $InstDir
        ${LogWrite} "SilentInstallDir: $SilentInstallDir"
    ${EndIf}

    ${LogWrite} "Setting ${BITS} bit registry view."
    SetRegView ${BITS}

    # Initialize MultiUser.nsh
    !insertmacro MULTIUSER_INIT
FunctionEnd


Function un.onInit
    ${LogInit}
    ${LogWrite} "Setting ${BITS} bit registry view."
    SetRegView ${BITS}
    !insertmacro MULTIUSER_UNINIT
FunctionEnd
