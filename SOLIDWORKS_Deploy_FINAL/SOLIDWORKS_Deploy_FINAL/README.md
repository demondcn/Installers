# Despliegue de SOLIDWORKS 2026 - Universidad de Cundinamarca

Paquete de prueba controlada para un equipo Windows 10/11. Los BAT se pueden ejecutar desde USB o desde una carpeta local; todos resuelven sus rutas desde la ubicación del paquete y aceptan espacios en el nombre de la ruta.

## Hallazgos verificados

- El instalador adjunto está firmado por Dassault Systèmes y contiene **SOLIDWORKS Installation Manager 2026 SP04.1**, build `34.4.1.1011`.
- La guía institucional adjunta describe **Student Access con activación individual**: ejecutar el autoextractor como administrador, instalar en este equipo, introducir serial, descargar e instalar y activar con correo. No describe SolidNetWork ni despliegue silencioso.
- La ayuda oficial incluida en Installation Manager sí documenta SolidNetWork e imágenes administrativas. El método preferido para laboratorio es una imagen administrativa configurada con Option Editor y `StartSWInstall.exe /install /showui /now`.
- También está documentado instalar desde `64bit\SOLIDWORKS\SOLIDWORKS.msi` mediante `msiexec /i ... /qb`. Este paquete usa solamente las propiedades documentadas `INSTALLDIR`, `SOLIDWORKSSERIALNUMBER`, `ENABLEPERFORMANCE`, `ADDLOCAL`, `TOOLBOXFOLDER` y `SERVERLIST`.
- El bootstrapper no documenta switches para descarga o instalación silenciosa. En ese caso el paso 02 abre Installation Manager y exige completar la interfaz.

## Antes de la primera prueba

1. Confirme con el administrador de licencias que el serial entregado es realmente **SolidNetWork 2026**. Un serial Student Access individual no convierte el cliente en flotante.
2. Confirme que SolidNetWork License Manager 2026 o compatible ya está instalado, activado y accesible desde el laboratorio.
3. Copie el paquete a disco local si el USB es lento. No use una carpeta sincronizada públicamente.
4. Mantenga el contenido de `MEDIA` fuera de Git. Este paquete local incluye el Installation Manager extraído para la prueba; todavía deberá descargar el medio completo desde la interfaz si no aporta una imagen administrativa.

## Orden exacto de uso

Ejecute los BAT con la misma cuenta de Windows. El serial se solicita oculto y queda cifrado mediante DPAPI en `Configuracion.local.json`; ese archivo está excluido por `.gitignore`.

1. `00_Preparar_Configuracion.bat`
   - Introduzca el serial y el servidor como `25734@SERVIDOR`.
   - Para varios servidores use el formato que corresponda a su licencia: punto y coma para servidores independientes o coma para una tríada.
2. Clic derecho en `01_Verificar_Requisitos.bat` y seleccione **Ejecutar como administrador**.
   - Verifica administrador, Windows, 16 GB de RAM, CPU recomendada, 25 GB libres como política local, Ethernet físico y TCP al puerto SolidNetWork.
   - La guía no fija espacio mínimo; 25 GB es un umbral preventivo del paquete, no un requisito oficial.
3. Ejecute `02_Instalar_SOLIDWORKS.bat`.
   - Se autoeleva por UAC.
   - Prioriza `StartSWInstall.exe`, luego el MSI de imagen administrativa y, por último, Installation Manager interactivo.
   - No continúa si el instalador devuelve error o si no aparece `SLDWORKS.exe`.
4. Ejecute `03_Configurar_Licencia.bat`.
   - Establece `SW_D_LICENSE_FILE` a nivel de equipo sin mostrar el valor en logs y prueba TCP.
   - En la ruta MSI, `SERVERLIST` también se entrega durante la instalación.
5. Ejecute `04_Verificar_SOLIDWORKS.bat`.
   - Comprueba ejecutable, versión, servidor, puerto, `SW_D_LICENSE_FILE` y servicios relacionados.
   - Produce `OK` o `ERROR` y guarda `C:\Software_Logs\SOLIDWORKS\Resultado_<EQUIPO>.txt`.
6. Ejecute `05_Prueba_Final.bat`.
   - Abre SOLIDWORKS y verifica que el proceso siga vivo durante 30 segundos.
   - La validación final obligatoria es confirmar visualmente que abre sin error de licencia.

## Logs y reinicios

- Log del orquestador: `C:\Software_Logs\SOLIDWORKS\Despliegue_<EQUIPO>.log`.
- Resultado: `C:\Software_Logs\SOLIDWORKS\Resultado_<EQUIPO>.txt`.
- Logs nativos de Installation Manager: `%APPDATA%\SOLIDWORKS\Installation Logs\<versión>`.
- Los códigos `0` y `3010` se consideran éxito; `3010` significa que se requiere reinicio. Cualquier otro código detiene el flujo.
- No se activa registro MSI detallado porque puede registrar propiedades sensibles, incluido el serial.
- En la ruta MSI, Windows Installer recibe el serial como propiedad de proceso; por diseño puede ser visible transitoriamente para un administrador local que inspeccione procesos, aunque el paquete no lo imprime ni lo escribe en sus logs.

## Límites deliberados

- No se automatiza la activación individual por correo mostrada en la guía: corresponde a Student Access, no a un cliente SolidNetWork.
- No se automatiza la descarga completa desde el bootstrapper: la ayuda incluida solo documenta el flujo interactivo **Download and share all files**.
- La instalación MSI directa requiere una imagen administrativa completa y sus prerrequisitos; una carpeta de descarga parcial no sirve para ejecutar MSI directamente.
- No se desactiva el antivirus automáticamente. La guía solo lo recomienda y cambiar esa protección requiere la política institucional.
- La configuración DPAPI solo se descifra con la misma cuenta de Windows en el mismo equipo. Si cambia de cuenta, vuelva a ejecutar el paso 00.

## Despliegue masivo

No despliegue masivamente hasta que un equipo piloto complete los seis pasos y abra SOLIDWORKS sin error. Para muchos equipos, cree una imagen administrativa desde Installation Manager, configure productos/serial/servidor con Administrative Image Option Editor y coloque la imagen completa en `MEDIA`; así el paso 02 utilizará la ruta oficial `StartSWInstall.exe` sin interacción.
