# Parte O — Simulacros de fallo y recuperación

Fecha de ejecución: 2026-11-24.

## Alcance y preparación

Se ejecutaron cuatro simulacros sobre el entorno local del laboratorio.
Antes de provocar fallos se creó una copia en frío del estado del Lab 5
y se comprobaron sus sumas SHA-256.

- Copia inicial: `backups/20261124T201601Z_lab5-pre-simulacros`.
- Commit de preparación: `d12fe7c`.
- La comprobación de integridad de los archivos no se consideró, por sí
  sola, un ensayo de restauración.
- El simulacro C utilizó una copia posterior específica y sí completó
  una restauración real del volumen.
- El simulacro D utilizó un respaldo RMAN específico, validado antes
  de eliminar el datafile.

Los scripts del kit se adaptaron al entorno local, incluido el uso de
`CONTNAME`, las comprobaciones de estado y la conservación de evidencias.

## Resumen de tiempos observados

| Ensayo | Intervalo medido | Tiempo |
|---|---|---:|
| A | Desde antes de solicitar SHUTDOWN ABORT hasta comprobar las filas tras el arranque | 10 s |
| B | Desde la solicitud de parada limpia hasta comprobar los datos | 15 s |
| B | Desde el inicio de reparación hasta comprobar los datos | 9 s |
| C | DROP sin PURGE, flashback, recreación de FK y comprobación | 1 s |
| C | Desde el inicio del script de restauración hasta comprobar tabla y metadatos | 267 s |
| C | Desde la solicitud de DROP PURGE hasta comprobar tabla y metadatos | 268 s |
| D | Desde la reanudación previa al borrado hasta comprobar los datos | 9 s |
| D | Desde la ausencia física del datafile hasta comprobar los datos | 9 s |
| D | Desde el inicio de RESTORE/RECOVER hasta comprobar los datos | 9 s |

Los intervalos tienen límites distintos y no constituyen una comparación
homogénea de rendimiento. Las verificaciones conjuntas posteriores de
TiendaSur no están incluidas en estos tiempos.

En D, los tiempos excluyen la pausa de diagnóstico y no representan toda
la indisponibilidad desde el primer OFFLINE.

## A — Caída de instancia

Commit: `0126d23`.

Se utilizaron dos sesiones: una mantuvo la transacción abierta y otra
provocó SHUTDOWN ABORT desde la raíz.

Antes de la caída:

- La fila 102 pasó a EGRESADO y se confirmó.
- La fila 103 pasó a INACTIVO sin confirmar.
- Se comprobó la existencia de la transacción abierta.

Después del arranque:

- La fila 102 conservó EGRESADO.
- La fila 103 volvió a ACTIVO.
- Se identificaron mensajes de recuperación de instancia en el alert log.
- La fila 102 se devolvió a ACTIVO tras comprobar el resultado.

Tiempo observado: 10 s.

RPO observado: cero para el cambio confirmado de prueba. No se interpreta
como una auditoría del contenido completo de la base.

Evidencias:

- [Métricas de A](evidencia/config/20261124T203633Z_14a-metricas.txt)
- [Ejecución de A](evidencia/script/20261124T203633Z_14a-caida-instancia.script.log)
- [Alert log de A](evidencia/script/20261124T203633Z_14a-alert-recuperacion.script.log)

## B — Ausencia de una copia del control file

Commit: `fcd1851`.

Tras una parada limpia se apartó mediante renombrado:

`/opt/oracle/oradata/FREE/control03.ctl`

El arranque produjo ORA-00205 y la instancia quedó STARTED, sin completar
el montaje de la base.

Se paró de nuevo la instancia y se reparó la ubicación ausente utilizando:

`/opt/oracle/oradata/FREE/control01.ctl`

Se comprobó la igualdad de las copias antes del arranque. Después se
verificaron los tres control files, la apertura de la base y la PDB, y
los datos de prueba. El archivo apartado se eliminó tras la verificación.

No se utilizó un control file antiguo ni se ejecutó RESETLOGS.

Tiempos observados:

- 15 s desde la solicitud inicial de parada hasta los datos verificados.
- 9 s desde el inicio de reparación hasta los datos verificados.

El ensayo no introdujo una transacción posterior a una copia para medir
pérdida de datos. No se le asigna un RPO numérico por analogía con A o D.

Evidencias:

- [Métricas de B](evidencia/config/20261124T203833Z_14b-metricas.txt)
- [Ejecución de B](evidencia/script/20261124T203833Z_14b-perdida-controlfile.script.log)
- [Arranque fallido esperado](evidencia/script/20261124T203833Z_14b-arranque-fallido.script.log)

## C — Borrado lógico de tabla

Preparación: `d372d82`.
Ejecución: `08d1b67`.

Se guardaron los metadatos originales de ACA_MATRICULAS y el DDL real de
sus dos claves ajenas. Se creó y verificó esta copia específica:

`backups/20261124T204154Z_lab5-pre-simulacro-c`

### Recuperación desde la papelera

Se ejecutaron DROP TABLE sin PURGE y FLASHBACK TABLE TO BEFORE DROP.

Después se recrearon:

- FK_ACA_MAT_ASI.
- FK_ACA_MAT_EST.

Se comprobaron 60000 filas, nueve restricciones ENABLED y VALIDATED,
y cuatro índices VALID.

Tiempo del procedimiento, incluida la recreación de FK y la verificación:
1 s.

En esta etapa no se exigieron los nombres originales de todos los objetos
recuperados, que podían conservar nombres de la papelera.

### Restauración después de PURGE

Se ejecutó DROP TABLE PURGE y se comprobó:

- Ausencia de la tabla en el diccionario.
- Ausencia de la tabla en la papelera.
- Imposibilidad de consultarla, con el error esperado de tabla inexistente.

Se restauró el volumen completo desde la copia específica, no únicamente
la tabla. Tras el arranque se comprobaron las 60000 filas y se compararon
los metadatos registrados con los originales, incluidos nombres y
columnas de restricciones e índices.

Tiempos observados:

- Restauración y comprobación de tabla y metadatos: 267 s.
- Desde la solicitud de DROP PURGE hasta esa comprobación: 268 s.

El punto de recuperación fue el estado de la copia en frío. No se
introdujeron cambios de negocio posteriores para medir pérdida de datos:
la antigüedad de la copia no se presentó como una cantidad de datos
perdidos.

La comprobación del recuento y los metadatos no equivale a comparar el
contenido fila a fila.

Evidencias:

- [Métricas de C](evidencia/config/20261124T205017Z_14c-metricas.txt)
- [Metadatos originales](evidencia/config/20261124T204149Z_14c-metadatos-previos.txt)
- [Metadatos restaurados](evidencia/config/20261124T205017Z_14c-metadatos-restaurados.txt)
- [Restauración del volumen](evidencia/script/20261124T205017Z_14c-restauracion-volumen.script.log)

## D — Pérdida controlada de datafile

Preparación RMAN: `7bfabf0`.
Ejecución, corrección y reanudación: `5f31f78`.

Archivo afectado:

- Número absoluto: 16.
- Ruta: `/opt/oracle/oradata/FREE/FREEPDB1/academia01.dbf`.
- Tablespace: TBS_ACADEMIA, en FREEPDB1.
- Tamaño de datos registrado: 104857600 bytes.
- Etiqueta RMAN: `LAB5_D_20261124T211036Z`.

Se creó el respaldo y se comprobó mediante RESTORE VALIDATE. Después,
sin crear una nueva copia del datafile, se cambió la fila 104 a EGRESADO,
se confirmó la transacción y se solicitó el archivado del log actual.

### Variante controlada

El archivo se puso fuera de línea antes de eliminarlo. Por tanto, el
ensayo no reproduce la desaparición inesperada de un datafile en línea
ni el posible cierre automático de la PDB por fallo de medio.

### Incidencia conservada

El primer intento se detuvo tras ejecutar DATAFILE 16 OFFLINE, porque
una comprobación exigía el valor OFFLINE en V$DATAFILE.

El diagnóstico mostró:

- Archivo todavía presente y no vacío.
- V$DATAFILE.STATUS = RECOVER.
- Cabecera OFFLINE, RECOVER=YES, FUZZY=YES y ERROR vacío.
- Archivo fuera de línea en V$RECOVER_FILE.

El borrado todavía no se había ejecutado.

Se corrigió la comprobación para admitir OFFLINE o RECOVER y se creó
una continuación con comprobaciones adicionales de identidad, cabecera
y respaldo. No se repitió el cambio de la fila 104 ni se creó otra copia.

### Recuperación y resultado

Se eliminó el datafile, se comprobó su ausencia física, se ejecutó
RESTORE desde la etiqueta indicada y después RECOVER.

Tras poner el archivo ONLINE se comprobó:

- Fila 104 = EGRESADO antes de la limpieza.
- 20000 estudiantes.
- Datafile 16 ONLINE.

La fila 104 se devolvió después a ACTIVO y se verificaron también las
60000 matrículas, sus nueve restricciones y sus cuatro índices.

RPO observado: cero para la transacción de prueba confirmada después
del respaldo.

Los tres intervalos registrados en la continuación fueron de 9 s.
Excluyen la pausa de diagnóstico; no se dispone aquí de una medición
consolidada de toda la indisponibilidad desde el primer OFFLINE.

Evidencias:

- [Métricas de D](evidencia/config/20261124T211620Z_14d-metricas.txt)
- [Incidencia y reanudación](evidencia/config/20261124T211620Z_14d-incidencia-y-reanudacion.txt)
- [Intento interrumpido](evidencia/script/20261124T211256Z_14d-perdida-datafile.script.log)
- [Diagnóstico](evidencia/script/20261124T211427Z_14d-diagnostico-interrupcion.script.log)
- [Reanudación](evidencia/script/20261124T211620Z_14d-reanudacion.script.log)
- [RESTORE y RECOVER](evidencia/script/20261124T211620Z_14d-restore-recover.script.log)

## Comprobaciones finales y límites

Las verificaciones posteriores confirmaron:

- Academia: 20000 estudiantes y 60000 matrículas.
- Matrículas: nueve restricciones habilitadas y validadas y cuatro
  índices válidos.
- TiendaSur: 100000 clientes y 1000000 pedidos.
- TiendaSur: nueve índices totales, válidos y visibles, y las restantes
  comprobaciones automatizadas del estado V005.
- Filas de prueba devueltas al estado previsto por los scripts.

El escaneo local no encontró coincidencias de las dos contraseñas que
comprueba. Esto no equivale a una auditoría exhaustiva de secretos.

Los resultados acreditan los escenarios y comprobaciones descritos,
no una prueba de todos los modos de fallo ni una garantía de recuperación
para cualquier incidente.

Este documento cierra los cuatro simulacros de la Parte O. No implica
por sí mismo el cierre del Lab 5, de la incidencia #11 ni la publicación
de los commits en el remoto.
