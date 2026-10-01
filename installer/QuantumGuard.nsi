Unicode True
RequestExecutionLevel admin
ManifestDPIAware true
SetCompressor /SOLID lzma
SetRegView 64

!include "LogicLib.nsh"
!include "x64.nsh"

!ifndef APP_VERSION
  !error "APP_VERSION is required, e.g. /DAPP_VERSION=1.11.0-preview.4"
!endif
!ifndef SOURCE_DIR
  !error "SOURCE_DIR is required and must contain the published Quantum Guard payload"
!endif

!define APP_NAME "Quantum Guard"
!define REGKEY "Software\QuantumGuard"
!define UNINSTKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\QuantumGuard"

Name "${APP_NAME} ${APP_VERSION}"
OutFile "QuantumGuard-${APP_VERSION}-x64-Setup.exe"
InstallDir "$PROGRAMFILES64\Quantum Guard"
InstallDirRegKey HKLM "${REGKEY}" "InstallRoot"
ShowInstDetails show
ShowUninstDetails show

Page directory
Page instfiles
UninstPage uninstConfirm
UninstPage instfiles

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "Quantum Guard requires 64-bit Windows."
    Abort
  ${EndIf}
FunctionEnd

Section "Quantum Guard" SEC_MAIN
  SectionIn RO

  nsExec::ExecToStack '"$SYSDIR\taskkill.exe" /F /T /IM QuantumGuard.UI.exe'
  Pop $0
  Pop $1
  nsExec::ExecToStack '"$SYSDIR\taskkill.exe" /F /T /IM QuantumGuard.Engine.exe'
  Pop $0
  Pop $1

  ReadRegStr $R0 HKLM "${REGKEY}" "CurrentVersion"
  ${If} $R0 != ""
    WriteRegStr HKLM "${REGKEY}" "PreviousVersion" "$R0"
  ${EndIf}

  CreateDirectory "$INSTDIR\versions\${APP_VERSION}"
  SetOutPath "$INSTDIR\versions\${APP_VERSION}"
  File /r "${SOURCE_DIR}\*.*"

  WriteRegStr HKLM "${REGKEY}" "InstallRoot" "$INSTDIR"
  WriteRegStr HKLM "${REGKEY}" "CurrentVersion" "${APP_VERSION}"

  SetOutPath "$INSTDIR"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  File "rollback.ps1"

  CreateDirectory "$SMPROGRAMS\Quantum Guard"
  CreateShortcut "$SMPROGRAMS\Quantum Guard\Quantum Guard.lnk" "$INSTDIR\versions\${APP_VERSION}\QuantumGuard.UI.exe"
  CreateShortcut "$SMPROGRAMS\Quantum Guard\Rollback to previous version.lnk" "$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" '-NoProfile -ExecutionPolicy Bypass -File "$INSTDIR\rollback.ps1"' "$INSTDIR\versions\${APP_VERSION}\QuantumGuard.UI.exe" 0
  CreateShortcut "$DESKTOP\Quantum Guard.lnk" "$INSTDIR\versions\${APP_VERSION}\QuantumGuard.UI.exe"

  WriteRegStr HKLM "${UNINSTKEY}" "DisplayName" "Quantum Guard"
  WriteRegStr HKLM "${UNINSTKEY}" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKLM "${UNINSTKEY}" "Publisher" "Quantum Guard"
  WriteRegStr HKLM "${UNINSTKEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${UNINSTKEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegDWORD HKLM "${UNINSTKEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINSTKEY}" "NoRepair" 1

  ; Startup/service integration is intentionally not rewritten here. The engine must migrate
  ; its managed startup/service path in application source before production release.
SectionEnd

Section "Uninstall"
  nsExec::ExecToStack '"$SYSDIR\taskkill.exe" /F /T /IM QuantumGuard.UI.exe'
  Pop $0
  Pop $1
  nsExec::ExecToStack '"$SYSDIR\taskkill.exe" /F /T /IM QuantumGuard.Engine.exe'
  Pop $0
  Pop $1

  Delete "$DESKTOP\Quantum Guard.lnk"
  RMDir /r "$SMPROGRAMS\Quantum Guard"
  DeleteRegKey HKLM "${UNINSTKEY}"
  DeleteRegKey HKLM "${REGKEY}"
  RMDir /r "$INSTDIR"
SectionEnd
