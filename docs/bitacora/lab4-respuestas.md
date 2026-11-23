
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

### Archivos de evidencia de la Parte D

- docs/bitacora/lab4/evidencia/script/20261115T111219Z_02-cuenta-observabilidad.script.log
- docs/bitacora/lab4/evidencia/script/20261115T111329Z_05-instancia-so.script.log
- docs/bitacora/lab4/evidencia/spool/20261115T111312Z_05-instancia-y-base.spool.log
- docs/bitacora/lab4/evidencia/spool/20261115T111407Z_05-instancia-y-base.spool.log

## Parte E. Arranque por etapas y alert log

### 9. NOMOUNT, MOUNT y OPEN

Evidencia:
script/20261115T111615Z_06-arranque-por-etapas.script.log.

NOMOUNT:
Oracle lee los parametros de arranque, reserva la SGA e inicia los
procesos de background. La instancia aparece como STARTED.
V$PARAMETER devuelve DB_NAME, SPFILE y CONTROL_FILES.
La consulta a V$DATABASE produce ORA-01507 porque la base aun no esta
montada: los control files todavia no se han abierto.

MOUNT:
Oracle abre los control files y conoce la estructura de la base.
La instancia aparece como MOUNTED. Se muestran dos control files
y 16 datafiles conocidos.
DBA_TABLES produce ORA-01219 porque la base todavia no esta abierta
y no se puede consultar normalmente el diccionario almacenado en
sus datafiles.

OPEN:
Oracle abre los datafiles y los redo logs para el funcionamiento normal.
La instancia termina OPEN y ACTIVE, y la base READ WRITE.
La grabacion finaliza con codigo 0.
Los errores ORA-01507 y ORA-01219 fueron provocados deliberadamente.

### 10. Apertura automatica de FREEPDB1

La evidencia muestra FREEPDB1 en READ WRITE tras ALTER DATABASE OPEN.
DBA_PDB_SAVED_STATES muestra:
FREEPDB1 | FREE | OPEN.

La PDB tiene guardado su estado de apertura.
Si no se abriera automaticamente, desde CDB$ROOT ejecutaria:

    ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;
    ALTER PLUGGABLE DATABASE FREEPDB1 SAVE STATE;

No fue necesario ejecutar estos cambios durante la prueba.

### 11. Clasificacion de mensajes del alert log

Evidencia: script/*_06-alert-log.script.log.
Archivo revisado:
 /opt/oracle/diag/rdbms/free/FREE/trace/alert_FREE.log.
Alcance de la revision: ultimas 400 lineas.

Se observa ORA-00800 con Set Priority Failed para VKTM y LGWR.
El contexto indica que no se pudo elevar la prioridad de esos procesos.
Coincide con el aviso conocido de restricciones del contenedor descrito
en el laboratorio. No impidio montar y abrir la base:
el log termina mostrando la apertura de FREEPDB1 en lectura y escritura
y Completed: ALTER DATABASE OPEN.

No se observo ORA-20013 en el fragmento revisado.
El documento describe el caso asociado a DBMS_QOPATCH y al inventario
de parches como un aviso conocido de esta imagen; no afirmo haberlo
reproducido en mi ejecucion.

Esta clasificacion depende del contexto del mensaje. No implica que
cualquier ORA-00800 u ORA-20013 deba ignorarse en cualquier entorno.

El log tambien recoge el cierre limpio, Instance shutdown complete,
Starting ORACLE instance, MOUNT y OPEN.
La mera aparicion del texto Crash Recovery no demuestra por si sola
un cierre anterior mediante ABORT: la prueba ejecutada fue
SHUTDOWN IMMEDIATE y el log indica PDB cerradas limpiamente.

### Pregunta tipo examen P4

Opciones A y C.
En NOMOUNT se pueden consultar parametros y crear o recrear el
control file. Todavia no se puede consultar normalmente el diccionario.

### Pregunta tipo examen P5

Opcion B: MOUNT.
El cambio a ARCHIVELOG requiere la base montada, pero no abierta.
Mi base ya estaba en ARCHIVELOG y no cambie su modo.

### Archivos de evidencia de la Parte E

- docs/bitacora/lab4/evidencia/script/20261115T111615Z_06-arranque-por-etapas.script.log
- docs/bitacora/lab4/evidencia/script/20261115T111802Z_06-alert-log.script.log

## Parte F. Parametros, alcances y PFILE

Evidencias:
- spool/*_07-parametros-lectura.spool.log.
- script/*_07-parametros-cambios.script.log.
- script/*_07-pfile.script.log.
- config/initFREE-lab4-antes.ora.
- config/initFREE-lab4.ora.
- config/initFREE-lab4-memoria.ora.

### 12. V$PARAMETER frente a V$SPPARAMETER

V$PARAMETER muestra el valor efectivo de los parametros en la sesion.
V$SPPARAMETER muestra lo registrado en el archivo de parametros
persistente, que puede ser distinto de lo que esta activo.

Mi evidencia de DB_FILES muestra:
- Estado inicial: memoria 200, sin entrada explicita en SPFILE.
- Tras SET con SCOPE=SPFILE: memoria 200, SPFILE 300.
- Tras RESET: memoria 200 y SPFILE ISSPECIFIED=FALSE.

No se reinicio la instancia durante este experimento.
El valor 300 de DB_FILES se retiro antes de que pudiera aplicarse
en un arranque posterior.

### 13. MEMORY, SPFILE y BOTH

OPEN_CURSORS con SCOPE=MEMORY paso a 400 en memoria y siguio en
300 en el SPFILE: el cambio no persistiria tras reiniciar.

Con SCOPE=BOTH paso a 500 tanto en memoria como en SPFILE.
El comentario "Lab4 prueba SCOPE BOTH" tambien aparece en la evidencia.

Finalmente se devolvio a 300 en ambos y se retiro el comentario.
Al arrancar con SPFILE, el SCOPE por defecto de ALTER SYSTEM SET
es BOTH, siempre que el parametro admita esa modificacion.

SCOPE=SPFILE modifica solo la configuracion persistente; permite
preparar un cambio estatico para el siguiente arranque.

### 14. PROCESSES y limites de la metadata

La consulta inicial muestra PROCESSES con ISSYS_MODIFIABLE=IMMEDIATE,
pero el intento de cambiarlo en memoria fue rechazado con
ORA-02097 y ORA-02095.

PROCESSES dimensiona estructuras al arrancar y en esta prueba no
admite el cambio en memoria. Para cambiarlo se utilizaria
SCOPE=SPFILE y un reinicio planificado.
La metadata debe contrastarse con el comportamiento observado.

MEMORY_SIZE=1600M tambien fue rechazado, con ORA-62352:
no se puede activar dinamicamente si no estaba configurado al arrancar.
Su valor final permanecio en 0.

### Alcances PDB y sesion

En FREEPDB1, OPEN_CURSORS se cambio temporalmente a 350 en memoria.
Tras RESET volvio a heredar 300.

El intento de cambiar PROCESSES desde FREEPDB1 fue rechazado con
ORA-65040: no es modificable en ese ambito.

ALTER SESSION cambio NLS_DATE_FORMAT solo para la conexion del
experimento. No se modifico el formato global de la instancia.

### 15. PFILE y deriva de configuracion

Antes de modificar parametros se creo initFREE-lab4-antes.ora desde
el SPFILE, como copia legible de seguridad.

Al finalizar se exportaron:
- initFREE-lab4.ora desde SPFILE.
- initFREE-lab4-memoria.ora desde MEMORY.

El exportado de memoria puede incluir parametros derivados o por
defecto que no estaban escritos explicitamente en el SPFILE.

Versionar estas fotografias permite comparar configuraciones con
git diff y detectar cambios no documentados: configuration drift.
Los PFILE son archivos de configuracion; no sustituyen al backup
de los archivos de la base.

### Estado final comprobado

- OPEN_CURSORS: 300 en CDB$ROOT y FREEPDB1.
- DB_FILES: 200 en memoria, sin entrada explicita pendiente en SPFILE.
- PROCESSES: 200.
- MEMORY_SIZE: 0.
- Experimento terminado con resultado 0.

### Pregunta tipo examen P6

Opcion B: con SPFILE y sin especificar SCOPE, el cambio del parametro
dinamico se aplica a memoria y SPFILE.

### Pregunta tipo examen P7

Opcion C: PROCESSES no es modificable a nivel de PDB y se obtiene
ORA-65040.

### Pregunta tipo examen P8

Opciones A y C: arrancar con un PFILE valido y reconstruir el SPFILE
desde ese archivo permite corregir una configuracion persistente
que impide el arranque.

### Archivos de evidencia de la Parte F

- docs/bitacora/lab4/evidencia/config/initFREE-lab4-antes.ora
- docs/bitacora/lab4/evidencia/config/initFREE-lab4-memoria.ora
- docs/bitacora/lab4/evidencia/config/initFREE-lab4.ora
- docs/bitacora/lab4/evidencia/script/20261115T112120Z_07-parametros-cambios.script.log
- docs/bitacora/lab4/evidencia/script/20261115T112211Z_07-pfile.script.log
- docs/bitacora/lab4/evidencia/spool/20261115T111954Z_07-parametros-lectura.spool.log

## Parte G. Memoria y Buffer Cache

### 16. Modelo de gestion de memoria

Evidencia: spool/*_08-memoria.spool.log.

La instancia utiliza ASMM, gestion automatica de memoria compartida:
- MEMORY_TARGET=0.
- MEMORY_SIZE=0.
- SGA_TARGET=1536M.

La PGA se gestiona por separado:
PGA_AGGREGATE_TARGET=512M y PGA_AGGREGATE_LIMIT=2G.
El primero es un objetivo, no un limite rigido.

DB_CACHE_SIZE=0 y SHARED_POOL_SIZE=0 no significan ausencia de esos
componentes: no se ha fijado un minimo manual mediante esos parametros.

La captura mostro:
- Database Buffers: 1024 MB en V$SGA.
- Shared Pool Size: 464 MB en V$SGAINFO.
- DEFAULT buffer cache: 944 MB en V$SGA_DYNAMIC_COMPONENTS.
- Shared IO Pool: 80 MB en esa misma vista.

Se conservan los valores de cada vista sin sumarlos indiscriminadamente
ni tratar todos sus conceptos como componentes independientes.

La PGA mostraba 298.8 MB en uso, 397.1 MB asignados y un maximo
observado de 460.6 MB. OVER ALLOCATION COUNT era 0.

El asesor mostro el mismo factor de tiempo estimado y las mismas
lecturas fisicas para todos los tamanos considerados. Esta captura,
con poca carga representativa, no basta para decidir reducir la SGA.

### 17. Experimento de cache

Evidencia: script/*_08-experimento-cache.script.log.

ACA_ESTUDIANTES tiene 20000 filas y 244 bloques segun sus estadisticas.

Resultados:
- Ronda fria: 17600 filas ACTIVO, 357 lecturas logicas y 261 fisicas.
- Ronda caliente: 17600 filas ACTIVO, 247 lecturas logicas y 0 fisicas.
- V$BH mostro 245 entradas de bloques de la tabla presentes en cache.

La segunda consulta reutilizo los bloques ya cargados y no necesito
lecturas fisicas. Esto demuestra el efecto del Buffer Cache.

La tasa estimada se calculo como:
100 * (1 - lecturas_fisicas / lecturas_logicas).

Ronda fria: 26.89 %.
Ronda caliente: 100 %.

A diferencia del ejemplo del documento, mis lecturas logicas no fueron
iguales en ambas rondas. Los contadores son de la sesion e incluyen
trabajo adicional, no exclusivamente la lectura de los bloques de datos
de esta tabla. La primera ejecucion puede incluir trabajo de preparacion
y consultas recursivas. No se ha aislado la contribucion exacta de cada
causa.

Por eso no atribuyo las 261 lecturas fisicas solo a los 244 bloques de
datos de la tabla. Las 245 entradas observadas en cache son compatibles
con los bloques de datos mas la cabecera de segmento descrita en el
laboratorio.

El 100 % del experimento se refiere al intervalo medido en la segunda
ronda, no a una garantia de acierto de toda la base.

### 18. Por que no sumar el RSS de los procesos

La SGA es memoria compartida que puede aparecer en el RSS de varios
procesos. Sumar sus RSS contaria repetidamente paginas compartidas.
Para analizar la memoria se deben distinguir SGA y PGA y contrastar
con medidas del contenedor, sin confundir ambos ambitos.

### Pregunta tipo examen P9

Opcion B.
Con ASMM, DB_CACHE_SIZE=512M establece un minimo para el buffer cache,
no obliga a que tenga exactamente ese tamano.

### Pregunta tipo examen P10

Opciones A y D.
El area de ordenacion y la memoria de sesion en servidor dedicado
pertenecen a la PGA; shared pool, log buffer y buffer cache son de la SGA.

### Archivos de evidencia de la Parte G

- docs/bitacora/lab4/evidencia/script/20261115T112730Z_08-experimento-cache.script.log
- docs/bitacora/lab4/evidencia/spool/20261115T112643Z_08-memoria.spool.log

## Parte H. Procesos Oracle y Linux

### 19. Correspondencia entre SPID y PID

Evidencias:
- spool/*_09-procesos.spool.log.
- script/*_09-procesos-so.script.log.

Oracle mostro LGWR con SPID 1254.
La consulta directa de /proc/1254 dentro del contenedor mostro:
- Pid: 1254.
- PPid: 1.
- Comando: db_lgwr_FREE.

docker top mostro ese mismo proceso db_lgwr_FREE con PID 6890.
Los numeros difieren porque se observan desde espacios de nombres
de PID distintos: interior del contenedor y anfitrion de Docker.
No son dos procesos LGWR diferentes.

La consulta SQL registro 87 entradas de background en V$PROCESS,
pero 54 SPID distintos. Por tanto, no hay correspondencia uno a uno
entre todas las entradas Oracle y los procesos Linux; algunas entradas
comparten un proceso del sistema operativo.

La captura posterior de /proc encontro 58 procesos con el patron
de nombres de background. No se tomo simultaneamente con SQL y usa
un criterio de recuento diferente: no se exige igualdad entre cifras.

Mi sesion SQLcl se identifico con SID 177, SERIAL# 12653 y SPID 2441.
En la captura posterior de Linux ya no habia servidores dedicados
oracleFREE: la conexion SQLcl habia terminado.

### 20. PMON y SMON

PMON se relaciona con la deteccion y limpieza de procesos de usuario
fallidos y la liberacion de recursos. En versiones modernas parte
del trabajo de limpieza se delega en procesos como CLMN.
Ejemplo: una conexion desaparece dejando recursos que deben liberarse.

SMON se relaciona con la recuperacion de instancia al arrancar cuando
es necesaria y con tareas de limpieza del sistema.
Ejemplo: recuperacion tras una parada no limpia de la instancia.
En esta practica no se provoco un SHUTDOWN ABORT.

Otros procesos identificados:
- DBW0, SPID 1252: escribe bloques modificados en los datafiles.
- LGWR, SPID 1254: escribe redo en los redo logs.
- CKPT, SPID 1257: coordina checkpoints y actualiza informacion asociada.
- LREG, SPID 1270: registra servicios de la instancia en el listener.
- ARC0 a ARC3: cuatro archivadores, coherentes con ARCHIVELOG.

### 21. Por que observar con C##OPS_RO

La cuenta dispone de los permisos de conexion, cambio de contenedor
y consulta de catalogo concedidos en la Parte D, sin usar una cuenta
administrativa general como SYSTEM o SYS.

No se le han concedido privilegios para modificar las tablas de negocio
ni para realizar operaciones SYSDBA como arrancar o parar la instancia.
Se aplica minimo privilegio para reducir el riesgo de una operacion
administrativa accidental.

### 22. Vias de exposicion de contrasenas corregidas

1. V000 contenia credenciales de propietarios de esquema.
   V003 las invalido convirtiendo las cuentas en NO AUTHENTICATION,
   sin modificar las migraciones historicas.

2. El ejecutor de migraciones pasaba la contrasena de SYS como argumento.
   La nueva version utiliza autenticacion del sistema operativo dentro
   del contenedor, sin contrasena en la linea de comandos.

La nueva contrasena de observabilidad se conserva en config.env,
excluido de Git, y se envia por entrada estandar.
La ausencia de secretos en archivos e historial se comprobara en J.2.

### Pregunta tipo examen P11

Opcion C: LGWR.
En un COMMIT sincrono normal, el proceso confirma la escritura del redo
necesario antes de devolver el control. DBWn no tiene que escribir en
ese momento todos los bloques modificados a los datafiles.

### Pregunta tipo examen P12

Opciones B y D: PMON y SMON.
ARC0 depende del modo de archivado; no es obligatorio en una instancia
que trabaja en NOARCHIVELOG.

### Archivos de evidencia de la Parte H

- docs/bitacora/lab4/evidencia/script/20261115T113005Z_09-procesos-so.script.log
- docs/bitacora/lab4/evidencia/spool/20261115T112929Z_09-procesos.spool.log

## Parte I. Verificacion final

Evidencia: archivo indicado en la lista siguiente.

El verificador termino con resultado 0 y todas las comprobaciones OK:
backup integro, cinco tablespaces ONLINE, rutas correctas, propietarios
sin autenticacion, datos V002 completos, CDB y PDB abiertas,
C##OPS_RO comun, parametros restaurados, puerto 8181 retirado,
evidencias presentes y PFILE versionado.

V000 y V001 permanecen sin cambios. No hay backups ni config.env
versionados. Esta verificacion tecnica no sustituye la revision del PR.

## Parte J. Control previo a la entrega

Evidencia:
script/20261115T113312Z_10-control-secretos.script.log.

El escaneo de las contrasenas actuales ORACLE_PWD y OPS_RO_PWD
mostro 0 archivos y 0 lineas de historial con coincidencias.
El alcance es el contenido versionado y el historial local disponible
examinados por verificar-secretos.sh; no constituye un escaneo
universal de cualquier secreto posible.

Se reviso el indice de respuestas y se elimino una copia duplicada
de la Parte D. La entrega en GitHub requiere completar la revision,
el merge del PR y la publicacion de lab4-final.

### Evidencias finales disponibles

- docs/bitacora/lab4/evidencia/script/20261115T113146Z_10-verificacion-final.script.log
- docs/bitacora/lab4/evidencia/script/20261115T113312Z_10-control-secretos.script.log

## Ampliacion del Lab 4 a la version v3 — Issue #9

### Punto de partida y copia previa

La ampliacion parte del cierre anterior del Lab 4, fusionado mediante
el PR #8 y etiquetado como lab4-final, en el commit aefda12.

Antes de introducir cambios se ejecuto de nuevo el verificador
scripts/lab4/10-verificacion-final.sh. Todas las comprobaciones
terminaron en OK, con codigo de salida 0.

Se creo una copia en frio del estado actual:
backups/20261123T223543Z_lab4-pre-ampliacion.

Evidencia:
docs/bitacora/lab4/evidencia/script/20261123T223543Z_00-backup-pre-ampliacion.script.log

Resultados observados:
- Base FREE en ARCHIVELOG antes de la copia.
- Cierre limpio mediante SHUTDOWN IMMEDIATE y parada del contenedor.
- Todos los archivos inventariados estan dentro del volumen al resolver sus rutas reales.
- SPFILE y password file apuntan mediante enlaces a rutas dentro del volumen.
- Archivos externos al volumen: 0.
- Comprobacion SHA-256: todos los archivos en OK.
- Tamano comprimido mostrado: 578 MB.
- Tras el arranque, CDB y FREEPDB1 en READ WRITE.
- Codigo de salida del backup: 0.
- Codigo de salida de escritura de la evidencia: 0.

Se ha comprobado la integridad de la copia, pero no se ha realizado
una restauracion de prueba. No se dispone todavia de un RTO de
restauracion medido para esta copia.

La copia permanece fuera de Git. Se conserva tambien la copia
anterior del Lab 3 y no se han modificado las etiquetas publicadas.

### Compatibilidad del ejecutor de migraciones con el Lab 5

Se adapto scripts/deployment/env/08-aplicar-migraciones.sh para
aceptar dos variables opcionales:

- MIG_EVID: carpeta de destino de las evidencias.
- MIG_PARTE: numero de parte utilizado en el nombre del log.

Si no se indican, se mantienen los valores anteriores:
docs/bitacora/lab4/evidencia/spool y parte 04.

La comprobacion bash -n termino con codigo 0.
La revision del diff confirmo que solo se modificaron las dos
lineas que construyen el destino y el nombre de la evidencia.

No se ejecutaron migraciones durante este ajuste. La comprobacion
real de estas opciones con las migraciones del Lab 5 queda pendiente.

### Ampliacion de la Parte G: analisis de sentencias y PGA

Se conservaron los experimentos anteriores de memoria y Buffer Cache.
La ampliacion se realizo mediante dos scripts separados:
08-parse.sql y 08-pga.sql.

#### G.3. Literales frente a variables de enlace

Primera ejecucion de 08-parse.sql, como SYS en FREEPDB1:

| Medida | Literales | Variable de enlace |
|---|---:|---:|
| Analisis totales | 1011 | 1 |
| Analisis duros | 1003 | 1 |
| CPU de analisis, ms | 1190 | 0 |
| Tiempo total, ms | 1290 | 20 |
| Cursores presentes al consultar V$SQL | 1000 | 1 |
| Memoria compartida, KB | 38844.6 | 38.9 |
| Ejecuciones recogidas en V$SQL | 1000 | 1000 |

La version con literales construyo textos SQL distintos al cambiar
el estudiante_id. La version con :id reutilizo un unico texto para
1000 ejecuciones.

Los contadores son de sesion y pueden incluir trabajo interno.
No se ha aislado la causa concreta de los tres analisis duros
adicionales respecto a las 1000 consultas con literales.
Los 0 ms registrados para la CPU de analisis con bind no significan
que el trabajo carezca de coste.

CURSOR_SHARING se fijo en EXACT solo para la sesion del experimento.
No se modificaron datos ni se vaciaron caches.

#### G.4. PGA automatica frente a area manual de 64 KB

Se ordenaron las 60000 matriculas en los dos escenarios:

| Medida | Automatica | Manual 64 KB |
|---|---:|---:|
| Filas ordenadas | 60000 | 60000 |
| Sorts memory, incremento de sesion | 11 | 0 |
| Sorts disk, incremento de sesion | 0 | 1 |
| Tiempo observado, ms | 80 | 430 |
| Memoria optima estimada, KB | 2604 | 1710 |
| Memoria usada, KB | 2314 | 65 |
| LAST_EXECUTION | OPTIMAL | 6 PASSES |
| Espacio en TEMP, KB | 0 | 2048 |

Con gestion automatica, el area de trabajo fue OPTIMAL y no uso TEMP.
Con el area manual reducida, la ordenacion uso TEMP y mostro
6 PASSES. En esta ejecucion tambien aumento el tiempo observado.

WORKAREA_SIZE_POLICY quedo en AUTO antes de finalizar.
Los cambios de configuracion fueron de sesion, no globales.

La consulta de PGA desde CDB$ROOT mostro:
- Objetivo agregado: 512 MB.
- PGA asignada: 360.5 MB.
- Maximo asignado desde el arranque: 461 MB.
- Over allocation count: 0.
- Cache hit percentage: 91.6 %.

El histograma de la instancia mostro 6252 ejecuciones optimas,
0 de una pasada y 2 multipasada. Son contadores acumulados:
no equivalen al numero de pasadas de la consulta concreta.

#### Reto: localizar familias con muchos literales

08-reto-literales.sql agrupa V$SQL por FORCE_MATCHING_SIGNATURE
y selecciona familias con mas de 50 SQL_ID distintos.
Tambien distingue los textos distintos de las filas de cursores hijos.

La primera consulta del reto no devolvio filas. El diagnostico
posterior tampoco encontro las etiquetas del experimento.
Ambas consultas terminaron con codigo 0; se conservan sus evidencias.
No se ha demostrado la causa exacta de esa ausencia.

Se repitio el experimento de parse y se ejecutaron inmediatamente
el reto y el diagnostico, sin reiniciar ni vaciar la shared pool.

Resultados de la repeticion:
- Literales: 1003 analisis totales, 1000 duros, 1060 ms de CPU de
  analisis y 1160 ms de tiempo total.
- Bind: 1 analisis total, 1 duro, 0 ms registrados de CPU de analisis
  y 30 ms de tiempo total.
- Al finalizar el script de parse quedaban 876 cursores con literales.
- La consulta inmediata del reto encontro 875 textos distintos,
  con firma 1863221789280198928 y 32606.7 KB de memoria compartida.
- El diagnostico encontro esa misma familia de literales y un unico
  texto bind con 1000 ejecuciones.

Los recuentos corresponden a consultas realizadas en momentos distintos.
La repeticion se utilizo para comprobar la deteccion por firma;
no se presenta como una prueba con la cache vaciada.

Todos los scripts de este bloque terminaron con codigo 0.

#### Archivos de evidencia de la ampliacion de G
- docs/bitacora/lab4/evidencia/script/20261123T224438Z_08-parse.script.log
- docs/bitacora/lab4/evidencia/script/20261123T225221Z_08-pga.script.log
- docs/bitacora/lab4/evidencia/script/20261123T225339Z_08-reto-literales.script.log
- docs/bitacora/lab4/evidencia/script/20261123T225423Z_08-diagnostico-firmas.script.log
- docs/bitacora/lab4/evidencia/script/20261123T225513Z_08-diagnostico-firmas-inmediato.script.log
- docs/bitacora/lab4/evidencia/script/20261123T225513Z_08-parse-repeticion.script.log
- docs/bitacora/lab4/evidencia/script/20261123T225513Z_08-reto-literales-inmediato.script.log

### Parte I ampliada: contenedores, usuarios y diccionario

#### I.1. Mapa de contenedores

Como SYS en CDB$ROOT se observaron:
- CDB$ROOT, CON_ID 1, READ WRITE.
- PDB$SEED, CON_ID 2, READ ONLY.
- FREEPDB1, CON_ID 3, READ WRITE.
- Datafiles por contenedor: 4 en la raiz, 3 en la semilla y 9 en FREEPDB1.
- Tres grupos de redo con CON_ID 0.
- DBA_TABLESPACES: 5 tablespaces de la raiz.
- CDB_TABLESPACES: 15, repartidos entre raiz (5) y FREEPDB1 (10).
- COMMON_USER_PREFIX: C##.

Desde FREEPDB1, V$DATAFILE mostro solo sus 9 archivos.
DBA_TABLESPACES y CDB_TABLESPACES devolvieron 10 tablespaces,
todos de CON_ID 3. El contexto de la sesion cambia el alcance observado.

El redo aparecio con CON_ID 0, no asociado a una PDB concreta.
El script del mapa termino con codigo 0.

#### I.2. Usuario local y privilegio de esquema

LAB4ANALISTA se creo en FREEPDB1 con solo CREATE SESSION.
No tenia tablas propias ni acceso a las de Academia.

Recibio ORA-00942 al consultar DBA_TABLES, V$SESSION y
ADMIN_ACADEMIA.ACA_ESTUDIANTES. Son objetos existentes, pero no
accesibles para esa cuenta. El cambio a CDB$ROOT fue rechazado
con ORA-01031.

Tras conceder READ ANY TABLE ON SCHEMA admin_academia:
- Vio las tres tablas de Academia.
- Pudo contar 20000 estudiantes.
- Clinica siguio inaccesible, con ORA-00942.
- El UPDATE fue rechazado con ORA-41900 por falta de ese privilegio.

Se ejecuto ROLLBACK por precaucion y se elimino el usuario.
Recuento final del usuario: 0. Fila 101: ACTIVO.
El experimento termino con codigo 0.

El privilegio de lectura de esquema permite acceder a las tablas
presentes y futuras de Academia, pero no concede escritura ni acceso
a otros esquemas. Un permiso global de lectura seria mas amplio.

#### I.2. Usuario comun y CONTAINER_DATA

C##LAB4AUDITOR se creo con CREATE SESSION, SET CONTAINER y
SELECT_CATALOG_ROLE concedidos con CONTAINER=ALL.

Desde CDB$ROOT vio solo los 5 tablespaces de la raiz.
En V$SESSION vio 86 sesiones de CON_ID 0 y 3 de CON_ID 1.
Los recuentos corresponden al momento de la prueba.

Pudo cambiar a FREEPDB1 y consultar desde dentro sus 10 tablespaces.
Poder cambiar de contenedor no le dio visibilidad agregada desde la raiz.

CDB_CONTAINER_DATA mostro C##OPS_RO con DEFAULT_ATTR=Y y
ALL_CONTAINERS=Y, pero ninguna entrada para C##LAB4AUDITOR.

Para configurar en el auditor la misma visibilidad agregada se usaria,
desde la raiz:
ALTER USER c##lab4auditor SET CONTAINER_DATA=ALL CONTAINER=CURRENT;

Esta sentencia se documenta como respuesta; no se ejecuto.
El auditor se elimino al finalizar. Los recuentos finales del usuario
comun y del usuario local fueron 0. Codigo del experimento: 0.

#### I.3. Diccionario con la cuenta de observabilidad

La consulta se ejecuto como C##OPS_RO en CDB$ROOT, con codigo 0.

Recuentos de vistas:
- USER: 656.
- ALL: 590.
- DBA: 1309.
- CDB: 1307.
- V$: 921.
- GV$: 880.

DBA_TABLESPACES devolvio 5 y CDB_TABLESPACES 15:
5 de CDB$ROOT y 10 de FREEPDB1.

V$FIXED_TABLE mostro 1591 estructuras TABLE y 1803 VIEW.
La definicion de GV$LOG incluyo X$KCCLE y X$KCCRT.

#### I.4. Usuarios comunes/locales y ciclo de vida de una PDB

Se comprobaron estos rechazos:
- Crear LAB4LOCAL en la raiz: ORA-65096, por faltar el prefijo C##.
- Crear C##LAB4COMUN dentro de FREEPDB1: ORA-65094.

LAB4LOCAL se creo correctamente en FREEPDB1 sin autenticacion:
COMMON=NO y AUTHENTICATION_TYPE=NONE. Despues se elimino.

PDBLAB4 se creo desde PDB$SEED, con archivos bajo:
 /opt/oracle/oradata/FREE/PDBLAB4/

Se observaron estos estados y resultados:
- Tras crearla: CON_ID 4, MOUNTED.
- Tras abrirla: READ WRITE.
- Datafiles SYSTEM, SYSAUX y UNDO en la carpeta prevista.
- Servicio pdblab4.
- C##OPS_RO presente como usuario comun en CON_ID 4.
- Intento de borrado abierta: ORA-65025, capturado como esperado.
- Cierre y DROP INCLUDING DATAFILES completados.
- PDB de prueba restante: 0.
- Usuarios de prueba restantes: 0.
- Carpeta vacia retirada.

No se capturo el codigo final del bloque de terminal por una
instruccion incompleta al terminar el pegado. No se atribuye
retrospectivamente un codigo de salida a ese bloque.

La comprobacion posterior confirmo CDB y FREEPDB1 en READ WRITE,
contenedor healthy y ausencia de la ruta PDBLAB4.
No se repitio el experimento ni se modifico FREEPDB1 para restaurarlo.

#### Evidencias de la Parte I ampliada
- docs/bitacora/lab4/evidencia/script/20261123T225715Z_10-mapa-contenedores.script.log
- docs/bitacora/lab4/evidencia/script/20261123T225822Z_10-diccionario.script.log
- docs/bitacora/lab4/evidencia/script/20261123T225922Z_10-usuario-local.script.log
- docs/bitacora/lab4/evidencia/script/20261123T230037Z_10-usuario-comun.script.log
- docs/bitacora/lab4/evidencia/script/20261123T230137Z_10-previo-ciclo-pdb.script.log
- docs/bitacora/lab4/evidencia/script/20261123T230235Z_10-ciclo-vida-pdb.script.log

### Parte J: inventario de archivos y acceso al alert log

#### J.1. Permiso puntual de observabilidad

Se concedio SELECT sobre SYS.V_$DIAG_ALERT_EXT a C##OPS_RO
con CONTAINER=ALL. DBA_TAB_PRIVS mostro SELECT y COMMON=YES.

La prueba real mediante ro.sh se identifico como C##OPS_RO
en CDB$ROOT y devolvio los ultimos ocho mensajes del alert log.
La concesion y la prueba terminaron con codigo 0.
No se concedio DBA ni ningun permiso de escritura.

El alert log mostro un aviso de escrituras de redo mas lentas de
lo esperado. Se registra como hallazgo de rendimiento pendiente
de investigar; no se ha demostrado su causa.

#### J.2. Inventario desde Oracle

El inventario se ejecuto como C##OPS_RO en CDB$ROOT.

| Tipo | Archivos | MB mostrados por Oracle |
|---|---:|---:|
| Datafiles | 16 | 3984 |
| Tempfiles | 3 | 60 |
| Control files | 2 | 35.8 |
| Miembros de redo | 3 | 600 |

Hay tres grupos de redo de 200 MB, cada uno con un solo miembro.
Los dos control files estan en la misma carpeta y en el mismo
volumen de Docker. El Lab 5 trabajara su multiplexacion y la del redo.

Configuracion observada:
- DB_BLOCK_SIZE: 8192 bytes.
- DB_CREATE_FILE_DEST: sin configurar.
- ARCHIVELOG activo y base READ WRITE.
- DB_RECOVERY_FILE_DEST: sin configurar.
- DB_RECOVERY_FILE_DEST_SIZE: 0.
- V$RECOVERY_FILE_DEST: sin filas.
- Password file con formato 12.
- SYS es la unica cuenta mostrada en V$PWFILE_USERS.
- TEMP aparece en CDB_TABLESPACES para raiz y FREEPDB1.

La primera ejecucion se detuvo con ORA-00904 porque el script
utilizaba FILENAME en V$PASSWORDFILE_INFO. Se corrigio a FILE_NAME.
Se conserva la evidencia fallida y el inventario corregido termino
con codigo 0. No fue necesario ampliar permisos para resolverlo.

#### J.3. Contraste desde Linux

Docker mostro un unico montaje de volumen en /opt/oracle/oradata.

Las rutas de SPFILE y password file se resolvieron a:
- /opt/oracle/oradata/dbconfig/FREE/dbs/spfileFREE.ora: 3584 bytes.
- /opt/oracle/oradata/dbconfig/FREE/dbs/orapwFREE: 2048 bytes.

La resolucion de las rutas demuestra que estan dentro del volumen,
aunque el listado de cada archivo no lo muestre como enlace individual.

academia01.dbf mide 104865792 bytes en Linux:
100 MiB de datos mas 8192 bytes.
Cada miembro de redo mide 209715712 bytes, equivalentes a 200 MiB.
Se conservan los tamanos reales sin forzar que todos los tipos de
archivo tengan el mismo sobrecoste de cabecera.

El ADR resuelve a /opt/oracle/diag/rdbms/free/FREE, fuera del
montaje persistente mostrado. Ocupaba 25 MB segun du y contenia
282 trazas .trc. El alert log media 138977 bytes.

Hallazgo: el ADR queda en la capa del contenedor, por lo que su
historia no queda protegida por el volumen de datos. Se propone
persistencia especifica o envio centralizado de logs. No se
cambio su ubicacion durante este apartado.

El inventario de Linux termino con codigo 0.

#### Comprobacion adicional del archivado

V$ARCHIVE_DEST mostro el destino 1 VALID, sin error, terminado
en /dbs/arch. La primera comprobacion busco una carpeta arch
y no la encontro. Eso no demostraba un fallo de archivado.

La comprobacion posterior mostro:
- LOG_ARCHIVE_DEST y LOG_ARCHIVE_DEST_1 sin valor explicito.
- LOG_ARCHIVE_FORMAT: %t_%s_%r.dbf.
- Tres archivados registrados, secuencias 1, 2 y 3 del thread 1.
- STATUS=A y DELETED=NO.
- Los tres archivos existian fisicamente.

Los nombres eran arch1_1_1237845575.dbf,
arch1_2_1237845575.dbf y arch1_3_1237845575.dbf.
arch es un prefijo de archivo, no una carpeta.

Las rutas reales de los tres estan bajo:
 /opt/oracle/oradata/dbconfig/FREE/dbs/

Por tanto, estos archivados estan dentro del volumen, aunque
no se almacenen en una FRA. No se borraron ni se forzo un cambio
de log. La comprobacion termino con codigo 0.

#### Esperas de redo observadas

La fotografia acumulada desde el arranque mostro:
- log file parallel write: 1508 esperas, media 5.45 ms.
- log file sync: 124 esperas, media 22.48 ms.

Estas medias no son una medida aislada del intervalo del aviso
del alert log ni demuestran su causa. No se aplicaron ajustes
de rendimiento basados solo en esta fotografia.

#### Evidencias de la Parte J
- docs/bitacora/lab4/evidencia/script/20261123T230604Z_11-ampliar-ops-ro.script.log
- docs/bitacora/lab4/evidencia/script/20261123T230604Z_11-probar-alert-log.script.log
- docs/bitacora/lab4/evidencia/script/20261123T230712Z_11-archivos.script.log
- docs/bitacora/lab4/evidencia/script/20261123T230759Z_11-archivos-corregido.script.log
- docs/bitacora/lab4/evidencia/script/20261123T230913Z_11-archivos-so.script.log
- docs/bitacora/lab4/evidencia/script/20261123T231007Z_11-comprobar-archivados.script.log

### Parte K: del tablespace al bloque y a la fila

#### K.1. Jerarquia de almacenamiento

ACA_ESTUDIANTES pertenece a TBS_ACADEMIA:
- BIGFILE=YES.
- Bloques de 8192 bytes.
- Gestion local de extensiones.
- ALLOCATION_TYPE=SYSTEM y SEGMENT_SPACE_MANAGEMENT=AUTO.
- PCTFREE=10 e INITRANS=1.

El segmento tenia 17 extensiones y 256 bloques asignados, 2048 KB.
Las primeras 16 extensiones eran de 8 bloques, 64 KB cada una.
La extension 16 tenia 128 bloques, 1024 KB.

El bloque 780 pertenece a la extension 0, que abarca del 776 al 783.
El bloque 1175 pertenece a la extension 16, que comienza en 1152.

#### K.2. Direccion fisica de la fila 101

Resultados obtenidos:
- ROWID: AAAR2mAAAAAAAMMAAH.
- DATA_OBJECT_ID: 73126.
- Archivo absoluto: 16.
- Bloque BIGFILE: 780.
- Ranura: 7.
- Estado: ACTIVO.

DBA_DATA_FILES relaciono el archivo 16 con:
 /opt/oracle/oradata/FREE/FREEPDB1/academia01.dbf

RELATIVE_FNO mostro 1024; no se utilizo como numero absoluto
del archivo. Este se obtuvo con ROWID_TO_ABSOLUTE_FNO.
El bloque se obtuvo indicando BIGFILE en ROWID_BLOCK_NUMBER.

DBA_OBJECTS confirmo que DATA_OBJECT_ID=73126 corresponde a
ADMIN_ACADEMIA.ACA_ESTUDIANTES.

#### K.3. Ocupacion del segmento

DBMS_SPACE.SPACE_USAGE devolvio:
- FULL: 236 bloques.
- FS1: 0.
- FS2: 0.
- FS3: 1.
- FS4: 7.
- Sin formatear: 0.

La suma de las categorias observadas es 244 bloques.
Se distingue de los 256 bloques asignados al segmento.
Estas medidas no representan exactamente el mismo concepto.

#### K.4. Volcado del bloque 780

La traza completa se guardo como texto en evidencia/config.
El volcado mostro:
- Block header dump: 0x30c = 780.
- seg/obj: 0x11da6 = 73126.
- itc=2: dos entradas ITL.
- typ=1 - DATA.
- ntab=1 y nrow=88.
- tsiz=0x1f98 = 8088 bytes.
- hsiz y fsbo: 0xc2 = 194.
- fseo: 0x41b = 1051.
- avsp y tosp: 0x359 = 857.

Comprobacion: 1051 - 194 = 857 bytes.
En este bloque el hueco entre fsbo y fseo coincide con avsp y tosp.

El directorio pri[7] apunta a 0x1d68, donde aparece la fila 101:
tl=80, fb=--H-FL--, lb=0x1 y cc=7.

Los valores de sus siete columnas ocupan:
3 + 9 + 10 + 12 + 19 + 6 + 11 = 70 bytes.

La longitud del registro se reconstruye como:
70 bytes de valores + 7 de longitudes + 3 de cabecera = 80 bytes.
La entrada de 2 bytes en el directorio queda fuera de esos 80.

AVG_ROW_LEN era 78: es una media estadistica, no la longitud
exacta de esta fila ni el total con su entrada de directorio.

La primera entrada ITL mostro --U-, Lck=88 y la fila lb=0x1.
Es coherente con la informacion de una transaccion confirmada
pendiente de limpieza completa del bloque. No se interpreta
Lck=88 como prueba de 88 bloqueos activos actuales.

#### Reto: comparar con el estudiante 19001

Se genero una traza independiente sin modificar la fila.
La direccion obtenida fue archivo 16, bloque 1175, ranura 22.

| Medida | Fila 101 | Fila 19001 |
|---|---:|---:|
| Bloque | 780 | 1175 |
| Ranura | 7 | 22 |
| nrow | 88 | 84 |
| tl de la fila | 80 | 84 |
| fsbo | 194 | 186 |
| fseo | 1051 | 993 |
| avsp | 857 | 807 |

El bloque 1175 mostro 0x497 y el mismo seg/obj=0x11da6.
Su directorio y su fila seleccionada se localizaron en la ranura 22.

Para la fila 19001, los valores ocupan:
4 + 9 + 12 + 11 + 21 + 6 + 11 = 74 bytes.
Con longitudes y cabecera: 74 + 7 + 3 = 84 bytes.

En ese bloque: 993 - 186 = 807 bytes, igual que avsp y tosp.

Ambos bloques tienen itc=2, la primera ITL con --U- y la segunda
sin transaccion registrada. La primera muestra Lck=88 en el
bloque 780 y Lck=84 en el 1175. Ambos conservan informacion
coherente con limpieza diferida.

La diferencia de tamanos de las filas demuestra que no todas
ocupan lo mismo. No se atribuye toda la diferencia de ocupacion
entre bloques solo a las dos filas seleccionadas.

La localizacion, ambos volcados y la extraccion/comparacion
terminaron con codigo 0. No se modificaron filas ni se vaciaron caches.

#### Evidencias de la Parte K
- docs/bitacora/lab4/evidencia/script/20261123T231208Z_12-localizar-fila.script.log
- docs/bitacora/lab4/evidencia/script/20261123T231323Z_12-bloque.script.log
- docs/bitacora/lab4/evidencia/script/20261123T231426Z_12-extracto-bloque.script.log
- docs/bitacora/lab4/evidencia/script/20261123T231848Z_12-reto-bloque.script.log
- docs/bitacora/lab4/evidencia/script/20261123T231953Z_12-comparacion-bloques.script.log
- docs/bitacora/lab4/evidencia/config/20261123T231323Z_12-volcado-bloque.trc.txt
- docs/bitacora/lab4/evidencia/config/20261123T231848Z_12-volcado-bloque-reto.trc.txt
