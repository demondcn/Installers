Option Explicit
Dim shell, fso, chrome, url
Set shell = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
url = "https://apps-script-frontend.replit.app/"
' Espera 10 minutos para dar tiempo a que Limpieza.bat termine.
WScript.Sleep 600000
chrome = shell.ExpandEnvironmentStrings("%ProgramFiles%") & "\Google\Chrome\Application\chrome.exe"
If Not fso.FileExists(chrome) Then chrome = shell.ExpandEnvironmentStrings("%ProgramFiles(x86)%") & "\Google\Chrome\Application\chrome.exe"
If Not fso.FileExists(chrome) Then chrome = shell.ExpandEnvironmentStrings("%LOCALAPPDATA%") & "\Google\Chrome\Application\chrome.exe"
If fso.FileExists(chrome) Then
    shell.Run Chr(34) & chrome & Chr(34) & " " & Chr(34) & url & Chr(34), 1, False
End If
