Option Explicit
' Espera 10 minutos desde que se inicia la sesion de Windows.
WScript.Sleep 600000

Dim sh, fso, urls, ruta, chrome, i
Set sh = CreateObject("WScript.Shell")
Set fso = CreateObject("Scripting.FileSystemObject")
urls = "https://apps-script-frontend.replit.app/"
chrome = ""
ruta = Array( _
  sh.ExpandEnvironmentStrings("%ProgramFiles%") & "\Google\Chrome\Application\chrome.exe", _
  sh.ExpandEnvironmentStrings("%ProgramFiles(x86)%") & "\Google\Chrome\Application\chrome.exe", _
  sh.ExpandEnvironmentStrings("%LocalAppData%") & "\Google\Chrome\Application\chrome.exe" _
)
For i = 0 To UBound(ruta)
  If fso.FileExists(ruta(i)) Then
    chrome = ruta(i)
    Exit For
  End If
Next
If chrome <> "" Then
  sh.Run Chr(34) & chrome & Chr(34) & " " & Chr(34) & urls & Chr(34), 1, False
Else
  ' Usa el navegador predeterminado si Chrome no se encuentra.
  sh.Run "explorer.exe " & Chr(34) & urls & Chr(34), 1, False
End If
