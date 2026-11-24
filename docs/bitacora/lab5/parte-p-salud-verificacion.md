# Parte P — Runbook de salud y verificación final

Fecha de ejecución: 2026-11-24.

## P.1 — Ejecución con cuenta de solo lectura

Se ejecutó `scripts/lab5/15-healthcheck.sql` mediante
`scripts/ops/ro.sh`.

La sesión confirmó:

- Usuario: C##OPS_RO.
- Contenedor: CDB$ROOT.
- Nueve secciones ejecutadas.
- Marca final: HEALTHCHECK_P1_EJECUTADO_OK.
- Salida conservada tanto en log de terminal como en spool SQLcl.

Adaptaciones respecto al kit:

- Comprobación explícita de usuario y contenedor.
- Interrupción ante errores SQL o del sistema operativo.
- Identificación de FREEPDB1 por nombre en lugar de fijar CON_ID=3.
- Marca de finalización para detectar ejecuciones incompletas.

La finalización del script acredita la ejecución de sus consultas, no
que todos los indicadores estén libres de advertencias.

## Interpretación de las nueve secciones

| Sección | Resultado observado | Interpretación |
|---|---|---|
| 1. Disponibilidad | Instancia OPEN; CDB y FREEPDB1 READ WRITE; ARCHIVELOG | Disponibilidad correcta en la consulta |
| 2. Tablespaces | Ninguna fila por encima del 80 % | Sin superaciones del umbral consultado |
| 3. Recuperabilidad | FRA 128 de 4096 MB, 3,1 %; último archivado 21:13; tres control files; cero grupos de redo con menos de dos miembros | Configuración y margen de FRA acordes con el laboratorio |
| 4. Capacidad | Procesos 95/200, máximo 105; sesiones 121/322, máximo 135; cero transacciones actuales | Sin agotamiento de los límites mostrados |
| 5. Alert log | Mensajes históricos de los simulacros y avisos de prioridad del entorno | Clasificación detallada más abajo |
| 6. Cambios de log | 1 en cada franja mostrada de 11-23 22h, 11-24 05h y 11h; 9 a las 19h y 11 a las 20h | Actividad histórica durante el trabajo; no se usa aisladamente como prueba de mal dimensionamiento |
| 7. RMAN | DATAFILE FULL, COMPLETED, 39 MB, 4 s, inicio 21:10 | Existe un respaldo concreto completado; no demuestra cobertura completa de la base |
| 8. Índices | Sin estadísticas: Clínica 8, Fintech 6, Logística 6 y Retail 7 | Las once tablas de esos esquemas se comprobaron vacías |
| 9. Undo | Cero ORA-01555, cero errores de espacio y consulta máxima registrada de 644 s desde la raíz | Sin esos errores en los registros visibles consultados |

Las horas de esta tabla se transcriben de la salida de Oracle; no se
convierten implícitamente a la zona horaria de la terminal del usuario.

## Clasificación de los mensajes del alert log

El runbook muestra como máximo las diez entradas más recientes que
coinciden con su filtro dentro de las últimas 24 horas. No es un
inventario exhaustivo de todos los errores de ese intervalo.

| Mensaje y momento | Clasificación y evidencia |
|---|---|
| ORA-00202 sobre control03.ctl, ORA-205 durante MOUNT y ORA-00210, a las 20:38 | Efecto del simulacro B. Coinciden con la ausencia provocada del control file; la reparación y el arranque se verificaron después |
| ORA-01110 sobre el datafile 16, a las 21:16 | Contexto del simulacro D. Identifica el archivo y coincide con la recuperación registrada; por sí solo no expresa la causa ni demuestra un fallo pendiente |
| ORA-00800 con Set Priority Failed para LGWR y VKTM, en varios arranques | Aviso del entorno relacionado con prioridades. No fatal en ese momento, pero no se declara inofensivo ni corregido. Queda pendiente revisar trazas y configuración del entorno si se requiere resolver su causa |

La verificación final superada permite distinguir el estado operativo
comprobado de las huellas históricas de B y D. No resuelve por sí misma
la causa de los avisos de prioridad.

## Comprobaciones complementarias

Se realizaron consultas administrativas separadas del runbook de solo
lectura. No se modificaron datos ni se recopilaron estadísticas.

Se comprobaron vacías:

- ADMIN_CLINICA: CLI_CITAS, CLI_MEDICOS y CLI_PACIENTES.
- ADMIN_FINTECH: FIN_CUENTAS y FIN_TRANSACCIONES.
- ADMIN_LOGISTICA: LOG_ALMACENES, LOG_ENVIOS y LOG_EVENTOS_TRACKING.
- ADMIN_RETAIL: RET_PRODUCTOS, RET_VENTAS_CABECERA y RET_VENTAS_DETALLE.

No se ejecutó DBMS_STATS únicamente para hacer desaparecer los avisos
de falta de estadísticas.

En FREEPDB1 se registró:

- undo_management: AUTO.
- undo_tablespace: UNDOTBS1.
- undo_retention: 900 s.
- Retención ajustada mínima y máxima consultada: 900 s.
- Consulta máxima en esa consulta de V$UNDOSTAT: 0 s.

Los 644 s del runbook se obtuvieron desde CDB$ROOT y los 0 s de la
consulta complementaria desde FREEPDB1. No se comparan como si fueran
la misma población ni se atribuye la consulta de 644 s a FREEPDB1.

## Reto — Consulta de alerta de FRA

Consulta propuesta para devolver una fila cuando la ocupación de la FRA
supera el 85 %, usando la misma vista del runbook:

```sql
SELECT 'FRA_SUPERA_85_PCT' AS alerta,
       name AS destino,
       ROUND(100 * space_used / NULLIF(space_limit, 0), 1) AS usado_pct
FROM v$recovery_file_dest
WHERE space_limit > 0
  AND space_used > 0.85 * space_limit;
```

Con el 3,1 % observado, la condición no se cumple. La consulta queda
documentada como propuesta: no se ha probado provocando otra FRA llena
ni se ha integrado en un sistema de notificaciones.

Esta condición detecta ocupación alta, no la ausencia de configuración
de FRA; esa comprobación debe mantenerse por separado.

## P.2 — Verificación automática final

Se ejecutó `scripts/lab5/16-verificacion-final.sh`.

Resultado:

`RESULTADO: TODO OK. Verificacion tecnica P.2 superada.`

Se conservaron las comprobaciones del kit y se adaptaron:

- CONT_NAME a CONTNAME.
- Tratamiento de errores SQL y del código de salida de SQL*Plus.
- Comprobación adicional de config.env y archivos prohibidos versionados.
- Mensaje final limitado a la verificación técnica de P.2, sin declarar
  completadas las respuestas ni el proceso de revisión de Q.

Entre las comprobaciones superadas:

- Copia lab4-final con SHA-256 correcto.
- TiendaSur: 100000 clientes y 1000000 pedidos.
- Lista exacta de los cinco índices de PEDIDO tras V005.
- Índice único de DNI y ausencia de índices invisibles en TiendaSur.
- LAB_TOOLS.MEDIR válido y LAB5_PRUEBAS ausente.
- Tres control files y cero grupos de redo con un solo miembro.
- ARCHIVELOG, FRA configurada y tamaño persistente de 4294967296 bytes.
- Existencia de redo archivado y de trabajos RMAN completados.
- Filas 101, 102 y 104 en ACTIVO y 60000 matrículas.
- Una PDB de usuario, CDB abierta y permiso consultado sobre el alert log.
- Presencia de evidencias numeradas 00 a 15.
- Ausencia de los archivos sensibles o de base de datos que comprueba
  el verificador entre los archivos versionados.

La prueba de presencia de evidencias no valida por sí sola la calidad
de todas sus interpretaciones. El escaneo de secretos comprueba las
dos contraseñas configuradas; no es una auditoría exhaustiva de secretos.

## Evidencias

- [Healthcheck: terminal](evidencia/script/20261124T212313Z_15-healthcheck.script.log)
- [Healthcheck: spool SQLcl](evidencia/spool/20261124T212319Z_15-healthcheck.spool.log)
- [Verificación final](evidencia/script/20261124T212446Z_16-verificacion-final.script.log)
- [Recuentos y undo de FREEPDB1](evidencia/script/20261124T212446Z_16-recuentos-complementarios.script.log)

## Estado de cierre

P.1 ejecutado e interpretado y P.2 superado.

Queda por continuar con Q: respuestas y retrospectivas, control de
seguridad previo a publicación y flujo de revisión y entrega.

Este cierre no hace push, no cierra la incidencia #11 y no crea la
etiqueta lab5-final ni la copia final del laboratorio.
