
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

## Parte C. Diagnostico y correcciones

### 4. Ubicacion inicial de los datafiles

Evidencia: script/*_01-diagnostico.script.log.

Los cinco datafiles de negocio estaban registrados bajo
/opt/oracle/product/26ai/dbhomeFree/dbs/.
DB_CREATE_FILE_DEST estaba vacio y V000 utilizaba rutas relativas.

En mi imagen, dbhomeFree/dbs es un enlace simbolico hacia
/opt/oracle/oradata/dbconfig/FREE/dbs/.
Por ello los archivos estaban dentro del volumen, aunque fuera de la
carpeta estandar de FREEPDB1. No estaban expuestos a perderse simplemente
por borrar el contenedor en esta configuracion concreta.

DB_CREATE_FILE_DEST, configurado con un destino adecuado, habria permitido
usar Oracle Managed Files al crear archivos sin indicar su nombre.
Para las migraciones del laboratorio se emplean rutas absolutas dentro
del volumen.

### 5. Procedimiento de reubicacion

Evidencias:
- script/*_03-reubicar-datafiles.script.log.
- script/*_03-reubicar-idempotencia.script.log.

RENAME DATAFILE cambia la ruta registrada en Oracle; no copia el archivo.
Se ejecuto OFFLINE NORMAL, copia fisica con cp -p, RENAME DATAFILE,
ONLINE y configuracion del crecimiento. Solo despues se retiro el original.

Los cinco tablespaces quedaron ONLINE, con archivos de 100 MB bajo
/opt/oracle/oradata/FREE/FREEPDB1/, AUTOEXTEND activado y MAXSIZE de 1024 MB.

La segunda ejecucion respondio "Nada que reubicar", demostrando
idempotencia.

### 6. Migraciones y credenciales expuestas

Evidencias:
- spool/*_04-V003__cuentas_esquema_sin_password.spool.log.
- spool/*_04-verificacion-cuentas.spool.log.
- database/migrations/V003__cuentas_esquema_sin_password.sql.
- scripts/deployment/env/08-aplicar-migraciones.sh.

V000 y V001 permanecen sin modificar: describen cambios ya aplicados.
La correccion se introduce mediante V003.

Los cinco propietarios ADMIN_* muestran AUTHENTICATION_TYPE=NONE.
Conservan sus objetos, pero no pueden iniciar sesion mediante las
contrasenas antiguas. La prueba manual de conexion como ADMIN_ACADEMIA
devolvio ORA-01017.

Borrar una contrasena del archivo actual no la elimina del historial.
Invalidarla impide utilizar la credencial expuesta.

El ejecutor de migraciones utiliza autenticacion del sistema operativo
dentro del contenedor: no pasa la contrasena de SYS como argumento.

### 7. Prueba de persistencia y definicion del contenedor

Evidencia: script/*_03-prueba-persistencia.script.log.

Se paro Oracle limpiamente, se elimino solo el contenedor y se recreo
utilizando el volumen oralab-26ai-data.

Antes y despues:
- DBID: 1509902213.
- Cinco tablespaces de negocio ONLINE.
- Tablas: Academia 3, Clinica 3, Fintech 2, Logistica 3 y Retail 3.
- Estudiantes: 0, porque V002 todavia no se habia aplicado.

La prueba demuestra conservacion de la base y de su estructura.
No demuestra conservacion de filas de Academia, porque estaban vacias.

Se realiza despues de la reubicacion para que los archivos esten en el
destino previsto dentro del volumen y no dependan del enlace de la imagen.

La nueva definicion publica solo el puerto 1521, no el 8181.
Al reutilizar el volumen no se pasa ORACLE_PWD al contenedor.
PORTORDS se conserva marcado como obsoleto.
La plantilla utiliza APP_USER_PWD y existen V000 y V001 con sus nombres
correspondientes.

### Carga de demostracion V002

Evidencias: spool/*_04-V002__datos_demo_academia.spool.log.

Primera ejecucion:
- 20000 estudiantes.
- 40 asignaturas.
- 60000 matriculas.
- Estudiante 101: DNI 00000101X, estado ACTIVO.

La segunda ejecucion no inserto datos y mantuvo los mismos recuentos.
La migracion recopila estadisticas del esquema para el optimizador.

### Pregunta tipo examen P2

Opcion B: OFFLINE, copia fisica, RENAME DATAFILE y ONLINE.
El cambio de nombre registrado en Oracle no mueve fisicamente el archivo.

### Archivos de evidencia de la Parte C

- docs/bitacora/lab4/evidencia/script/20261115T105808Z_01-diagnostico.script.log
- docs/bitacora/lab4/evidencia/script/20261115T105913Z_03-reubicar-datafiles.script.log
- docs/bitacora/lab4/evidencia/script/20261115T105958Z_03-reubicar-idempotencia.script.log
- docs/bitacora/lab4/evidencia/script/20261115T110635Z_03-prueba-persistencia.script.log
- docs/bitacora/lab4/evidencia/spool/20261115T110115Z_04-V003__cuentas_esquema_sin_password.spool.log
- docs/bitacora/lab4/evidencia/spool/20261115T110401Z_04-verificacion-cuentas.spool.log
- docs/bitacora/lab4/evidencia/spool/20261115T110532Z_04-verificacion-cuentas.spool.log
- docs/bitacora/lab4/evidencia/spool/20261115T110742Z_04-V002__datos_demo_academia.spool.log
- docs/bitacora/lab4/evidencia/spool/20261115T110803Z_04-V002__datos_demo_academia.spool.log

## Parte D. Instancia, base de datos y servicios

### 8. Tres datos de instancia y tres de base de datos

Evidencias:
- script/*_02-cuenta-observabilidad.script.log.
- spool/*_05-instancia-y-base.spool.log.
- script/*_05-instancia-so.script.log.

Datos de la instancia:
1. INSTANCE_NAME: FREE.
2. HOST_NAME: d1d9aadc0fa5.
3. STARTUP_TIME: 2026-11-15 11:06:44, segun la salida de Oracle.

Datos de la base:
1. DBID: 1509902213.
2. Fecha de creacion: 2026-07-05.
3. LOG_MODE: ARCHIVELOG.

La instancia estaba OPEN y ACTIVE. La base estaba READ WRITE.
La fecha de arranque corresponde a la instancia, no a la creacion
de la base.

Al recrear el contenedor, el hostname cambio de d75ed86cf6d5 a
d1d9aadc0fa5, pero el DBID siguio siendo 1509902213.
La instancia se vuelve a iniciar; los archivos de la base permanecen
en el volumen.

### Cuenta y contexto de observacion

C##OPS_RO aparece como usuario comun (COMMON=YES), OPEN, en CDB$ROOT
y FREEPDB1. La consulta se ejecuto como C##OPS_RO, mediante el servicio
free, dentro de CDB$ROOT. El SID observado fue 57; identifica esa sesion
y puede cambiar en otra conexion.

La contrasena se conserva en config.env, excluido de Git.
El ejecutor ro.sh recibe la conexion por entrada estandar, sin pasar
la contrasena como argumento del proceso.

### Servicios y vista desde Linux

El servicio free corresponde a la raiz y freepdb1 a la PDB.
El listener mostro ambos servicios con la instancia FREE en estado READY.

Linux mostro 59 procesos de background y el proceso tnslsnr del listener.
No aparecio un servidor dedicado oracleFREE en esa captura; la consulta
SQL anterior ya habia terminado.

El consumo observado del contenedor fue 2.175 GiB sobre un limite de
5.79 GiB. Es una medida del contenedor completo, no solo de la SGA.

### Archivos observados

La consulta SQL mostro:
- 16 datafiles, con 3974 MB en total.
- 3 tempfiles, con 60 MB en total.
- 3 miembros de redo.
- 2 control files.

El listado de Linux confirma los datafiles de negocio en FREE/FREEPDB1
y los control files y redo logs bajo FREE.

### Pregunta tipo examen P3

Opciones A y C.
STARTUP_TIME cambia al arrancar la instancia.
CREATED indica cuando se creo la base, no cuando se inicio la instancia.

## Parte D. Instancia, base de datos y servicios

### 8. Tres datos de instancia y tres de base de datos

Evidencias:
- script/*_02-cuenta-observabilidad.script.log.
- spool/*_05-instancia-y-base.spool.log.
- script/*_05-instancia-so.script.log.

Datos de la instancia:
1. INSTANCE_NAME: FREE.
2. HOST_NAME: d1d9aadc0fa5.
3. STARTUP_TIME: 2026-11-15 11:06:44, segun la salida de Oracle.

Datos de la base:
1. DBID: 1509902213.
2. Fecha de creacion: 2026-07-05.
3. LOG_MODE: ARCHIVELOG.

La instancia estaba OPEN y ACTIVE. La base estaba READ WRITE.
La fecha de arranque corresponde a la instancia, no a la creacion
de la base.

Al recrear el contenedor, el hostname cambio de d75ed86cf6d5 a
d1d9aadc0fa5, pero el DBID siguio siendo 1509902213.
La instancia se vuelve a iniciar; los archivos de la base permanecen
en el volumen.

### Cuenta y contexto de observacion

C##OPS_RO aparece como usuario comun (COMMON=YES), OPEN, en CDB$ROOT
y FREEPDB1. La consulta se ejecuto como C##OPS_RO, mediante el servicio
free, dentro de CDB$ROOT. El SID observado fue 57; identifica esa sesion
y puede cambiar en otra conexion.

La contrasena se conserva en config.env, excluido de Git.
El ejecutor ro.sh recibe la conexion por entrada estandar, sin pasar
la contrasena como argumento del proceso.

### Servicios y vista desde Linux

El servicio free corresponde a la raiz y freepdb1 a la PDB.
El listener mostro ambos servicios con la instancia FREE en estado READY.

Linux mostro 59 procesos de background y el proceso tnslsnr del listener.
No aparecio un servidor dedicado oracleFREE en esa captura; la consulta
SQL anterior ya habia terminado.

El consumo observado del contenedor fue 2.175 GiB sobre un limite de
5.79 GiB. Es una medida del contenedor completo, no solo de la SGA.

### Archivos observados

La consulta SQL mostro:
- 16 datafiles, con 3974 MB en total.
- 3 tempfiles, con 60 MB en total.
- 3 miembros de redo.
- 2 control files.

El listado de Linux confirma los datafiles de negocio en FREE/FREEPDB1
y los control files y redo logs bajo FREE.

### Pregunta tipo examen P3

Opciones A y C.
STARTUP_TIME cambia al arrancar la instancia.
CREATED indica cuando se creo la base, no cuando se inicio la instancia.

### Archivos de evidencia de la Parte D

- docs/bitacora/lab4/evidencia/script/20261115T111219Z_02-cuenta-observabilidad.script.log
- docs/bitacora/lab4/evidencia/script/20261115T111329Z_05-instancia-so.script.log
- docs/bitacora/lab4/evidencia/spool/20261115T111312Z_05-instancia-y-base.spool.log
- docs/bitacora/lab4/evidencia/spool/20261115T111407Z_05-instancia-y-base.spool.log
