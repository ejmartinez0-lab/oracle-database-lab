# Lab 4 - Informe de autopsia de la instancia

## Alcance y metodo

Consultas realizadas el 23 de noviembre de 2026, aproximadamente
a las 23:50-23:52 GMT, como C##OPS_RO desde CDB$ROOT.

Se ejecutaron 15-autopsia-instancia.sql y
15-ampliar-autopsia.sql, ambos con resultado 0.
Se consultaron tambien los montajes del contenedor.
No se aplicaron cambios de configuracion durante la autopsia.

Las conclusiones describen el estado observado. Las prioridades
son propuestas para el seguimiento, no correcciones ya ejecutadas.

## Estado general

- Base: FREE; DBID: 1509902213.
- Instancia: FREE; version: 23.26.3.0.0.
- Estado: OPEN / ACTIVE; base PRIMARY en READ WRITE.
- FREEPDB1 abierta READ WRITE; PDB$SEED en READ ONLY.
- ARCHIVELOG activo y FORCE_LOGGING=YES.
- Flashback Database: NO.
- MEMORY_TARGET=0.
- SGA_TARGET=1610612736; PGA_AGGREGATE_TARGET=536870912.
- Buffer cache observada: 1024 MiB.
- OPEN_CURSORS=300; DB_FILES=200; COMMON_USER_PREFIX=C##.

## Hallazgos y seguimiento

### H1. Archivado persistente; respaldo y retencion por verificar

Prioridad: media para revisar respaldo y retencion.
Persistencia de las rutas comprobadas: confirmada.

Evidencia:
- Destino 1 de archivado VALID, sin error informado.
- Ruta logica: /opt/oracle/product/26ai/dbhomeFree/dbs/arch.
- arch es un prefijo de archivo, no una carpeta.
- El directorio dbs resuelve a:
  /opt/oracle/oradata/dbconfig/FREE/dbs.
- Los archived logs de las secuencias 1, 2 y 3 existen y sus
  rutas reales estan dentro de ese directorio persistente.
- El SPFILE tambien existe bajo esa ruta real.
- La comprobacion mediante readlink -e termino con resultado 0.

Correccion de la interpretacion inicial:
La ruta logica bajo ORACLE_HOME no demostraba que los archivos
estuvieran en la capa modificable del contenedor.
La Parte J ya documentaba la resolucion de estos enlaces.
La comprobacion final confirma esa evidencia y retira la
sospecha inicial de falta de persistencia del archivado.

Riesgo pendiente de evaluar:
Persistencia no equivale a respaldo independiente. Esta revision
no demuestra la cobertura de copias de archived logs, su retencion
ni la capacidad de recuperar hasta un momento determinado.

Accion:
Revisar la politica de respaldo y retencion y probar recuperacion.
No se propone mover el destino por una falta de persistencia
que las comprobaciones han descartado para estas rutas.

### H2. Un solo miembro por grupo de redo

Prioridad: alta para un entorno de produccion.

Evidencia:
- Seccion 4: tres grupos de 200 MiB cada uno, MEMBERS=1.
- Miembros redo01.log, redo02.log y redo03.log bajo
  /opt/oracle/oradata/FREE.

Riesgo:
No hay una segunda copia de cada grupo como miembro multiplexado.
La consecuencia de perder un archivo depende del estado del
grupo y de las opciones de recuperacion disponibles.

Accion:
Planificar multiplexacion en dominios de fallo independientes.
No confundir tres grupos con tres copias del mismo redo.

### H3. Control files concentrados en el mismo volumen

Prioridad: alta para resiliencia de produccion.

Evidencia:
- /opt/oracle/oradata/FREE/control01.ctl.
- /opt/oracle/oradata/FREE/control02.ctl.
- Ambas rutas bajo el mismo montaje persistente.

Riesgo:
Existen dos copias, pero no se ha demostrado independencia
frente a la perdida del almacenamiento que las contiene.

Accion:
Revisar la arquitectura de almacenamiento y planificar copias
en dominios de fallo independientes, junto con sus respaldos.

### H4. Diagnosticos fuera del montaje persistente mostrado

Prioridad: media.

Evidencia:
- ADR Home: /opt/oracle/diag/rdbms/free/FREE.
- Diag Trace y Diag Alert bajo ese mismo directorio.
- El unico montaje mostrado corresponde a /opt/oracle/oradata.
- readlink -e confirma que Diag Trace y Diag Alert resuelven
  a las mismas rutas bajo /opt/oracle/diag, fuera del montaje.

Riesgo:
Los diagnosticos escritos en la capa modificable del contenedor
pueden perderse al eliminarlo, dificultando investigar incidentes.

Accion:
Planificar persistencia o recoleccion externa de diagnosticos.

### H5. Indices sin fecha de estadisticas en cuatro esquemas

Prioridad: media.

Evidencia, seccion 6:
- ADMIN_CLINICA: 8 indices sin fecha.
- ADMIN_FINTECH: 6 indices sin fecha.
- ADMIN_LOGISTICA: 6 indices sin fecha.
- ADMIN_RETAIL: 7 indices sin fecha.
- ADMIN_ACADEMIA: 0 sin fecha; altura maxima observada 2.
- No se detectaron estados no validos con el criterio del script.

Riesgo:
La informacion estadistica observada es incompleta para evaluar
los indices de esos cuatro esquemas. No se ha demostrado una
regresion de rendimiento por esta causa.

Accion:
Comprobar poblacion y estadisticas de tablas e indices.
Planificar su recogida cuando corresponda y revisar planes
con datos representativos, sin modificar esquemas en la autopsia.

### H6. Fallos al establecer prioridad de procesos

Prioridad: media, pendiente de diagnostico.

Evidencia:
Cuatro registros ORA-00800 con argumentos Set Priority Failed,
relativos a VKTM y LGWR, a las 22:31 y 22:38 GMT.
Los mensajes indican revisar trazas y configuracion del SO.
La instancia estaba OPEN / ACTIVE durante la autopsia.

Riesgo:
La configuracion del entorno impidio establecer las prioridades
solicitadas. No se ha cuantificado su impacto.

Accion:
Revisar las trazas citadas, limites y permisos del entorno.
No ampliar privilegios del contenedor ni silenciar la alerta
sin diagnosticar y justificar el cambio.

### H7. Dos indices con factor de agrupamiento elevado en Academia

Prioridad: baja, para analisis posterior.

Evidencia:
Dos indices de ADMIN_ACADEMIA cumplen el criterio del script:
CLUSTERING_FACTOR > 0.5 * NUM_ROWS de su tabla.

Riesgo:
Es un indicador para revisar accesos por rangos, no una
demostracion de que esos indices sean inutiles.

Accion:
Identificar los indices, consultas, selectividades y planes
antes de proponer cambios.

## Observaciones que no se clasifican como fallo por si solas

- FRA sin configurar: DB_RECOVERY_FILE_DEST vacio y tamano 0.
  Hay un destino de archivado independiente configurado.
- ORA-65025 a las 23:02:50 durante DROP PLUGGABLE DATABASE
  pdblab4 INCLUDING DATAFILES: asociado al experimento previo.
- La consulta de concesiones directas de DBA a usuarios no
  mantenidos por Oracle devolvio cero filas. No constituye una
  auditoria completa de privilegios efectivos o heredados.
- La capacidad de las metricas de tablespace y MAXBYTES no
  representan almacenamiento fisico libre garantizado.
- La ampliacion muestra 1782 MiB asignados en CON_ID=1 y
  1422 MiB en CON_ID=3. No se equipara esa suma con los
  3994 MiB de V$DATAFILE: los conjuntos visibles no son identicos.

## Resumen ejecutivo

La base esta operativa y la autopsia se completo con la cuenta de observacion.
El archivado y el SPFILE comprobados son persistentes; la prioridad es revisar la redundancia de archivos criticos y la cobertura de recuperacion.
Quedan propuestas mejoras de diagnosticos, estadisticas y configuracion del entorno; no se aplicaron cambios durante esta revision.

## Evidencias
- docs/bitacora/lab4/evidencia/script/20261123T235015Z_15-autopsia-instancia.script.log
- docs/bitacora/lab4/evidencia/script/20261123T235131Z_15-ampliar-autopsia.script.log
- docs/bitacora/lab4/evidencia/script/20261123T235131Z_15-montajes.script.log
- docs/bitacora/lab4/evidencia/spool/20261123T235015Z_15-autopsia-instancia.spool.log
- docs/bitacora/lab4/evidencia/script/20261124T000039Z_17-rutas-reales-autopsia.script.log
