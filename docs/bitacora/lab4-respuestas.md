
## Parte B. Respaldo del estado del Lab 3

Evidencia de ejecución: docs/bitacora/lab4/evidencia/script/20261115T105252Z_00-backup-lab3.script.log

Copia local: backups/20261115T105252Z_lab3-final.
Tamaño mostrado: 509 MB. Resultado del script: 0.
La comprobación SHA-256 terminó con todos los archivos en OK.
Tras el arranque, el CDB y la PDB estaban en READ WRITE.

### Hallazgo sobre la ubicación de los archivos

El inventario detectó 0 archivos fuera del volumen.
Los cinco datafiles de negocio aparecen en
/opt/oracle/product/26ai/dbhomeFree/dbs/,
pero readlink -f demuestra que sus rutas reales están en
/opt/oracle/oradata/dbconfig/FREE/dbs/.
Por tanto, están cubiertos por la copia del volumen, aunque todavía
no se encuentran en la carpeta estándar FREE/FREEPDB1.

### 1. Consistencia de la copia

La copia se tomó después de SHUTDOWN IMMEDIATE y de detener el
contenedor. La salida confirma el cierre de la base y de la instancia.
El cierre limpio deja una copia consistente que no requiere aplicar
redo para resolver un cierre inconsistente al restaurarla.
Copiar los archivos con la base abierta no garantiza que todos
correspondan a un estado consistente; no sería equivalente a este
procedimiento. Mi base ya estaba en ARCHIVELOG y no cambié ese modo.

### 2. Manifiesto y SHA-256

El manifiesto identifica la copia mediante fecha, etiqueta, contenedor,
volumen, imagen y commit, e indica que no había archivos externos.
SHA256SUMS permite comprobar si los archivos han cambiado o se han
corrompido. El script de restauración verifica esas sumas antes de
modificar el entorno.

### 3. RPO y RTO en este laboratorio

Al restaurar esta copia perdería los cambios realizados después del
punto de respaldo: esa es la ventana de pérdida de datos de esta copia.
El RTO sería el tiempo necesario para restaurar y recuperar el servicio.
Todavía no he ejecutado un simulacro de restauración, por lo que no
dispongo de un RTO medido. Los 10 segundos mostrados por la sonda
corresponden a la comprobación del arranque, no a una restauración completa.

### Pregunta tipo examen P1

Opciones A y D. Tras un cierre limpio, la copia completa es consistente
y puede restaurarse y abrirse sin recuperación con redo por un cierre
inconsistente.
