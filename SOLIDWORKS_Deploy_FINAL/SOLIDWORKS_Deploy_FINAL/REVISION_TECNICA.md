# Revisión técnica de fuentes

## Guía institucional

Procedimiento descrito: comprobar hardware/software; ejecutar `SolidWorksSetup.exe` como administrador; pulsar **Unzip**; elegir instalación en este equipo; introducir serial; decidir instalación nueva o actualización; escoger Toolbox; aceptar condiciones; descargar e instalar; finalizar; abrir SOLIDWORKS 2026; activar productos con correo electrónico.

Requisitos indicados: Windows 11 oficialmente soportado; Windows 10 21H2/22H2 compatible; 16 GB de RAM mínimo; CPU de 4/6 núcleos y 3.3 GHz o superior recomendada; GPU de 4 GB y 80 GB/s o superior recomendada. La guía no fija espacio de disco ni describe SolidNetWork.

## Instalador inspeccionado

- SHA-256 del archivo original: `9D28ED0B923485340F67A4F308BB449624AFE4CD23C80CD7C9726F910363221E`.
- Firma Authenticode válida de Dassault Systèmes SE.
- Contenido: autoextraíble ZIP con `setup.exe`, `sldim\sldIM.exe`, ayuda CHM y componentes del Installation Manager.
- Versión: SOLIDWORKS 2026 SP04.1; build `34.4.1.1011`; versión interna `20260-40401-1100`.
- Carpeta de descarga: el usuario la selecciona en Installation Manager; cada versión usa su propia subcarpeta. La ayuda indica ejecutar `setup.exe` desde esa carpeta y no ejecutar directamente los MSI de una descarga parcial.
- Serial: Installation Manager lo solicita en su interfaz. En una imagen administrativa, la propiedad MSI documentada es `SOLIDWORKSSERIALNUMBER`.
- Servidor: Installation Manager solicita `puerto@equipo` al reconocer un serial SolidNetWork. En instalación MSI, la propiedad documentada es `SERVERLIST`.
- Silencio: documentado para imágenes administrativas, no para el bootstrapper. Métodos documentados: `StartSWInstall.exe /install /showui /now` o `msiexec /i ... /qb`.

## Correcciones respecto al ZIP original

- Se separaron instalación, licencia, verificación y prueba final en seis pasos con los nombres solicitados.
- Se sustituyó el serial en texto plano por DPAPI y se amplió `.gitignore`.
- Se eliminó `OFFICEOPTION=4`: la ayuda 2026 define únicamente 0 a 3.
- Se eliminó el intento de tratar cualquier `SOLIDWORKS.msi` como medio completo; ahora se exige la ruta propia de una imagen administrativa.
- Se agregó prioridad a `StartSWInstall.exe`, comprobación de códigos, reinicio 3010, resultados claros y parada cuando falta `SLDWORKS.exe`.
- Se movió la lógica compleja a PowerShell integrado para evitar errores de escape de CMD con `<`, `>`, `|`, `%`, `!`, comillas y rutas con espacios.
