# Lab 5 — Respuestas, simulacro de examen y retrospectivas

Fecha de las ejecuciones: 2026-11-24. Documento preparado a partir de evidencias locales y del PDF v3 del laboratorio.

## Alcance y revisión

Las cifras de las respuestas proceden de los archivos enlazados. Las referencias de línea corresponden a los originales, no a la numeración global del dossier. Los resultados históricos no describen necesariamente el estado actual después de todos los simulacros.

Se distingue entre comprobación ejecutada, interpretación de una prueba y aplicación teórica a un escenario no provocado. Esta es una propuesta de redacción para revisión personal; no acredita que se haya realizado un examen cronometrado ni asigna una nota al alumno.

Limitaciones que no se ocultan: K omitió el intento de dejar un único grupo; L ya partía de ARCHIVELOG; D perdió el archivo después de ponerlo OFFLINE y tuvo una pausa de diagnóstico. P.2 superado acredita sus controles, no la ejecución de todos los casos teóricos del examen.

## Preguntas de comprobación (1–22)

### 1. Comparación de las copias lab3-final y lab4-final

En ambas copias el paso 6 terminó con **Archivos externos: 0**. Por tanto, en este entorno no hubo una reducción de cinco archivos externos a cero.

La diferencia está en las rutas: en Lab 3 los cinco datafiles de negocio figuraban bajo `/opt/oracle/product/26ai/dbhomeFree/dbs/`, pero `readlink -f` los resolvía bajo `/opt/oracle/oradata/dbconfig/FREE/dbs/`, dentro del volumen. En Lab 4 ya figuraban bajo `/opt/oracle/oradata/FREE/FREEPDB1/`.

Esto demuestra que hay que comprobar rutas reales, no deducir la cobertura a partir del nombre aparente. La reubicación del Lab 4 dejó las rutas de negocio explícitas en FREEPDB1; la copia anterior ya cubría sus destinos reales. El SPFILE y el archivo de contraseñas también resolvían dentro del volumen.

Evidencias: [copia Lab 3](lab4/evidencia/script/20261115T105252Z_00-backup-lab3.script.log), líneas 25–29, 60–66 y 72–73; [20261124T191902Z_00-backup-lab4.script.log](lab5/evidencia/script/20261124T191902Z_00-backup-lab4.script.log), línea 69, inventario y resolución de rutas. Los archivos comprimidos ocuparon 509M y 670M respectivamente; ese cambio no mide archivos fuera del volumen.

### 2. Factor de bloqueo de CLIENTE y PEDIDO

Con la media empírica `bfr = filas / bloques`:

- CLIENTE: `100000 / 1517 = 65,92`, aproximadamente 66 filas/bloque; longitud media 102 bytes.
- PEDIDO: `1000000 / 5320 = 187,97`, aproximadamente 188 filas/bloque; longitud media 32 bytes.

PEDIDO contiene unas `188 / 66 = 2,85` veces más filas por bloque porque sus filas son mucho más cortas. No calculo `8192 / longitud_media` como si todo el bloque estuviera disponible para filas: también hay cabeceras, directorios y espacio libre.

Evidencia: [20261124T193426Z_01-perfil-tiendasur.script.log](lab5/evidencia/script/20261124T193426Z_01-perfil-tiendasur.script.log), línea 6.

### 3. Por qué se mide la segunda ejecución

La primera ejecución puede incluir análisis y trabajo inicial, además de accesos todavía no calentados. La segunda permite comparar las alternativas en condiciones de caché caliente y con el mismo método. No es una medida del rendimiento en frío.

En la búsqueda de PEDIDO 4711, la ejecución medida consumió 4 buffers al recuperar también IMPORTE; al pedir solo ID_PEDIDO fueron 3, porque no hizo falta acceder a la tabla.

Evidencia: [20261124T193743Z_02-anatomia-indice.script.log](lab5/evidencia/script/20261124T193743Z_02-anatomia-indice.script.log), línea 35, sección 3 y planes con Buffers 4 y 3.

### 4. Altura, hojas y fan-out de IX_PED_CLIENTE

Se midieron altura 3, 2216 hojas y 6 bloques de rama. El fan-out medio es `(2216 + 6 - 1) / 6 = 370,17`, redondeado a 370. El límite estimado a partir del tamaño de las entradas de rama fue 543.

La proyección del script para mil millones de filas, con su hipótesis de capacidad de hoja y llenado inicial, dio 2208969 hojas y altura 4: unas 5 lecturas para una búsqueda puntual que además necesita la tabla. Es una proyección, no un índice construido con mil millones de filas.

Evidencia: [20261124T193743Z_02-anatomia-indice.script.log](lab5/evidencia/script/20261124T193743Z_02-anatomia-indice.script.log), línea 19, sección 2.

### 5. Descomposición del ROWID de una entrada de PK_CLIENTE

La primera entrada de hoja contiene `data:(6): 00 00 03 1b 00 00` y la clave `c1 02`, que representa el cliente 1.

- Los cuatro bytes `00 00 03 1b` identifican el bloque `0x31B = 795`.
- Los dos bytes finales `00 00` identifican la ranura 0.

Es el localizador físico corto almacenado en la entrada del índice para este tablespace bigfile; el archivo se determina por el contexto del tablespace y no aparece como un campo adicional en esos seis bytes. No debe confundirse con la representación completa de un ROWID extendido.

Evidencia: [20261124T193743Z_02-anatomia-indice.script.log](lab5/evidencia/script/20261124T193743Z_02-anatomia-indice.script.log), línea 136, y comprobación final ID_CLIENTE=1, BLOQUE=795, RANURA=0.

### 6. Tres comparaciones de tipos de índice

| Prueba | Lecturas medidas | Explicación |
|---|---:|---|
| Q13, DNI sin índice / UNIQUE | 1486 / 3 | La igualdad pasa de recorrer CLIENTE a una búsqueda única. Además, el INSERT duplicado falla con ORA-00001 |
| Q7, índice simple / compuesto / cubriente | 15 / 7 / 3 | El compuesto entrega el rango ordenado; el cubriente evita el acceso a PEDIDO |
| Q15, heap con PK / IOT / clúster hash | 4 / 3 / 1 | La IOT evita el salto a un segmento de tabla independiente; el hash localiza por igualdad. Su limpieza por fecha necesitó 2770 lecturas |

La última cifra limita la conclusión: que el hash gane por token no lo hace mejor para consultas de rango.

Evidencia: [20261124T193859Z_03-tipos-indice.script.log](lab5/evidencia/script/20261124T193859Z_03-tipos-indice.script.log), secciones 1, 3 y 7.

### 7. Clustering factor y efecto de REBUILD

IX_PED_FECHA tiene CF=5220 frente a 5320 bloques de tabla: el orden temporal del índice se aproxima al orden físico de inserción. IX_PED_CLIENTE tiene CF=999041 frente a 1000000 filas: recorrer sus claves salta repetidamente entre bloques de PEDIDO.

REBUILD reorganiza el índice, no reordena físicamente las filas de la tabla. Por ello no corrige por sí solo este CF malo. Tampoco confundo CF con el número de bloques únicos: cuenta cambios de bloque durante el recorrido ordenado, pudiendo volver a un bloque ya visitado.

Evidencia: [20261124T193743Z_02-anatomia-indice.script.log](lab5/evidencia/script/20261124T193743Z_02-anatomia-indice.script.log), línea 9, tabla inicial.

### 8. Punto de equilibrio medido y elección del optimizador

El recorrido completo de referencia consumió 5232 lecturas lógicas.

- CF bueno: 3938 lecturas al 50 % y 7875 al 100 %; el cruce queda acotado entre esas muestras.
- CF malo: 4875 lecturas al 0,5 % y 9920 al 1 %; el cruce está entre 0,5 % y 1 %.
- El plan estimado del optimizador pasó de índice al 0,1 % a completo al 0,2 %. No coincide con el cruce de lecturas lógicas forzadas.

La fórmula orientativa `k/r < (1/bfr) × (c_secuencial/c_aleatoria)` da, si se igualan ambos costes, `100 × 5320/1000000 = 0,532 %`. Su orden de magnitud concuerda con el cruce del CF malo, pero el optimizador incorpora otros costes. Los porcentajes y las filas del CSV son nominales del muestreo; no afirmo un umbral exacto entre puntos.

Evidencia: [20261124T194200Z_04-curva-equilibrio.csv](lab5/evidencia/config/20261124T194200Z_04-curva-equilibrio.csv); [20261124T194200Z_04-curva-equilibrio.txt](lab5/evidencia/config/20261124T194200Z_04-curva-equilibrio.txt).

### 9. Por qué Q4b usa índice y aun así lee muchos bloques

`LIKE 'Gonz%'` define un rango de claves y puede usar IX_CLI_APELLIDOS. Sin embargo, las 2056 filas están dispersas y recuperarlas por ROWID acumuló 2024 lecturas. El acceso completo de la prueba Q4a consumió 1523 lecturas.

La sargabilidad permite un acceso por índice; no garantiza que minimice las lecturas. Aquí Q4a y Q4b tampoco son consultas equivalentes: Q4a devuelve 18902 filas por otro patrón. Uso la comparación para explicar el coste de recorrer tabla frente a hacer accesos dispersos, no como un benchmark de dos respuestas idénticas. Para medir causalmente ambos planes de Gonz% habría que forzar alternativas de ese mismo predicado, algo que no se hizo en este ensayo.

Evidencia: [20261124T194440Z_05-sargabilidad.script.log](lab5/evidencia/script/20261124T194440Z_05-sargabilidad.script.log), línea 38, regla 4.

### 10. Coste de escritura y decisiones de V005

| Escenario | Índices en PEDIDO | Bloques modificados por INSERT | Bytes de redo por fila |
|---|---:|---:|---:|
| Heredado | 4 | 10,1 | 1313 |
| Propuesta del compañero | 9 | 20,2 | 2578 |
| V005 | 5 | 12,1 | 1611 |

Son 2000 operaciones por medida; los valores por fila están redondeados. La propuesta casi duplica el trabajo de INSERT. Se rechazó mantener IX_PED_CANAL y IX_PED_FEC_CLI sin uso en la carga observada; IX_PED_CANAL tiene tres valores, un 33,333 % por valor medio. Se sustituyó el índice general de ESTADO por la solución parcial para pendientes; el promedio de cuatro estados no representa el sesgo de P=2 %.

IX_PED_CLIENTE era prefijo de IX_PED_CLI_FEC y después del cubriente de V005. Se retiró solo al disponer del cubriente que empieza por ID_CLIENTE y conserva el soporte de la FK. IX_PED_IMPORTE tampoco tuvo uso; al hacerlo invisible Q2 mantuvo 335 lecturas y finalmente se retiró. IX_PED_CP sí se conservó porque Q3 devolvió 102 filas con 106 lecturas.

El precio aceptado no es solo INSERT: UPDATE de ESTADO pasó de 2 a 8,1 bloques/fila en V005 por el mantenimiento del cubriente y del índice parcial. La ventana de uso es la del ensayo, no una observación de producción de semanas.

Evidencias: [20261124T194843Z_06-coste-dml.csv](lab5/evidencia/config/20261124T194843Z_06-coste-dml.csv); [20261124T194641Z_06-indices.script.log](lab5/evidencia/script/20261124T194641Z_06-indices.script.log); [migración V005](../../database/migrations/V005__indices_tiendasur.sql).

### 11. Divisiones 50/50, 90/10 y patrón cola

- IX_AZAR: 595 divisiones, ninguna 90/10; 596 hojas y ocupación viva aproximada del 75,40 %. Su mapa distribuye huecos por el árbol: no es una cola ni una justificación automática de rebuild.
- IX_CRECIENTE: 398 divisiones, todas 90/10; 399 hojas, ocupación viva aproximada del 99,92 %. El mapa está lleno porque se van completando hojas por la derecha.
- IX_COLA: 487 hojas, 90403 entradas borradas y 286 hojas sin entradas vivas. El mapa tiene un tramo vacío a la izquierda y hojas llenas a la derecha. Obtener el mensaje más antiguo costó 288 lecturas frente a 2 en el índice sano.

Las ocupaciones proceden del modelo de 7996 bytes útiles del generador del gráfico, no de una medición exacta de cada estructura interna.

Evidencias: [20261124T195042Z_07a-crecimiento.script.log](lab5/evidencia/script/20261124T195042Z_07a-crecimiento.script.log); [20261124T195042Z_07a-grafico-IX_AZAR.script.log](lab5/evidencia/script/20261124T195042Z_07a-grafico-IX_AZAR.script.log); [20261124T195042Z_07a-grafico-IX_CRECIENTE.script.log](lab5/evidencia/script/20261124T195042Z_07a-grafico-IX_CRECIENTE.script.log); [20261124T195042Z_07b-grafico-IX_COLA-antes.script.log](lab5/evidencia/script/20261124T195042Z_07b-grafico-IX_COLA-antes.script.log).

### 12. Remedio del patrón cola en horario de servicio

Elegiría COALESCE como primera intervención medida para este síntoma, no un REBUILD rutinario. En el ensayo redujo las lecturas de 288 a 2, las hojas de 487 a 201 y las entradas borradas a 0; el segmento siguió ocupando 4 MB.

Si además hiciera falta devolver espacio al tablespace, evaluaría SHRINK SPACE: en la prueba dejó 1,69 MB y mantuvo las 2 lecturas. REBUILD ONLINE dejó 2 MB y no mejoró esas 2 lecturas. Estas cifras favorecen el remedio menos costoso que ya corrige el síntoma. En producción se comprobarían elegibilidad, concurrencia y bloqueos breves de DDL; no prometo ausencia absoluta de bloqueos. A largo plazo revisaría el diseño de retención, por ejemplo particionado cuando proceda y esté disponible.

Evidencia: [20261124T195042Z_07-remedios.csv](lab5/evidencia/config/20261124T195042Z_07-remedios.csv).

### 13. SCN de checkpoint del control file y de la cabecera

Oracle contrasta el checkpoint registrado para el archivo en V$DATAFILE con su cabecera en V$DATAFILE_HEADER, dentro del procedimiento de apertura y recuperación.

En academia01.dbf ambos valían 4397443 antes del checkpoint y 4401053 después. PDB$SEED mantuvo 2098101 porque estaba en solo lectura. CURRENT_SCN llegó a 4401108: no debe sustituirse el checkpoint por ese reloj actual.

La coincidencia aislada de SCN con la base abierta no demuestra un cierre limpio ni elimina toda necesidad de recuperación: también importan el estado de los archivos y la información de recuperación. El reto posterior mostró RECOVER=NO y FUZZY=YES en archivos abiertos con checkpoints coincidentes.

Evidencias: [20261124T195704Z_08-scn-checkpoint.script.log](lab5/evidencia/script/20261124T195704Z_08-scn-checkpoint.script.log); [20261124T195704Z_08-reto-mttr-verificacion.script.log](lab5/evidencia/script/20261124T195704Z_08-reto-mttr-verificacion.script.log).

### 14. Qué protege la multiplexación en un mismo volumen

El ensayo B mostró recuperación de una copia ausente: control03.ctl se reparó desde control01.ctl y volvieron a estar operativas las tres copias. Se tardaron 15 s desde la solicitud de parada y 9 s desde el inicio de reparación.

Como las tres rutas están en el mismo volumen, esto no protege frente a perder ese volumen o su soporte común. Tampoco sustituye a una copia histórica. En producción se separarían los dominios de fallo y se mantendrían respaldos recuperables del control file, junto con una estrategia de RMAN y redo adecuada.

Evidencia: [20261124T203833Z_14b-metricas.txt](lab5/evidencia/config/20261124T203833Z_14b-metricas.txt); [20261124T203833Z_14b-controlfiles-previos.txt](lab5/evidencia/config/20261124T203833Z_14b-controlfiles-previos.txt).

### 15. Estados del redo y límites de lo que se ejecutó

CURRENT es el grupo donde LGWR escribe; ACTIVE sigue siendo necesario para recuperación de instancia; INACTIVE ya no se necesita para esa recuperación. El archivado es otra propiedad: no convierte por sí solo un grupo ACTIVE en prescindible.

Al terminar K: grupo 1 INACTIVE/archivado, grupo 2 ACTIVE/archivado y grupo 3 CURRENT/no archivado; cada grupo tenía dos miembros y 200 MB.

Se observaron dos rechazos: borrar el CURRENT produjo ORA-01623 y borrar un miembro suyo ORA-01609. El tercer intento del enunciado, dejar un único grupo, se omitió deliberadamente; el log lo dice. La regla teórica de conservar al menos dos grupos por thread y el error ORA-01567 no se presentan como una tercera prueba ejecutada. Este es un alcance no ensayado, no un resultado fabricado.

Evidencia: [20261124T200207Z_10-redo.script.log](lab5/evidencia/script/20261124T200207Z_10-redo.script.log), línea 56, y estado final del mismo archivo.

### 16. Cadena de causas de la FRA llena

El límite se redujo de 4096 MB a 2097152 bytes (2 MiB), por debajo del uso necesario. La base registró ORA-19815 con 100 % de ocupación y 0 bytes restantes. El archivado falló con ORA-19809 y ORA-16038 sobre la secuencia 20; ORA-00312 identificó sus miembros.

Sin espacio para archivar, un grupo pendiente no puede reutilizarse cuando corresponda. Si se agotan los grupos reutilizables, los cambios que necesitan seguir generando redo pueden esperar en `log file switch (archiving needed)`. En esta ejecución se acreditan el fallo de archivado y los grupos sin archivar; no afirmo haber medido un bloqueo prolongado de todas las escrituras.

Se recuperó el límite de 4 GiB, también en SPFILE; los grupos pendientes se archivaron y la verificación terminó sin destinos en ERROR. No se borraron todos los archivados para resolver este ensayo. La base ya estaba en ARCHIVELOG al empezar L: no se ensayó allí una nueva transición desde NOARCHIVELOG.

Evidencias: [20261124T200617Z_11-fra-llena.script.log](lab5/evidencia/script/20261124T200617Z_11-fra-llena.script.log); [20261124T200617Z_11-verificacion-final.script.log](lab5/evidencia/script/20261124T200617Z_11-verificacion-final.script.log); [20261124T200617Z_11-configurar-fra.script.log](lab5/evidencia/script/20261124T200617Z_11-configurar-fra.script.log), línea 19.

### 17. Lectura consistente y bloqueo de escritores

Mientras A tenía sin confirmar EGRESADO para la fila 101, B pudo leer ACTIVO, el último valor confirmado reconstruido mediante undo. Se registraron 1 bloque y 1 registro de undo en la transacción de A, SID 60.

A tenía un bloqueo TM modo 3 y TX modo 6. B pudo hacer SELECT, pero al solicitar FOR UPDATE WAIT 3 sobre esa misma fila obtuvo ORA-00054 y ORA-40097, identificando la transacción 1.24.709. Por tanto, la lectura normal no esperó a A; el segundo escritor sí tuvo conflicto. La frase no significa que ningún tipo de bloqueo pueda afectar nunca a una consulta o DDL.

Evidencia: [20261124T200841Z_12-lectura-consistente.script.log](lab5/evidencia/script/20261124T200841Z_12-lectura-consistente.script.log), pasos B1–B4. La fila quedó finalmente en ACTIVO.

### 18. Coste de undo y redo de la reversión

En la primera ejecución de 10000 operaciones:

| Operación | Bloques de undo | Undo KB | Redo KB | Redo que describe undo KB | Redo del ROLLBACK KB |
|---|---:|---:|---:|---:|---:|
| INSERT | 142 | 1136 | 4834 | 2032 | 357 |
| UPDATE | 71 | 568 | 1258 | 540 | 751 |
| DELETE | 428 | 3424 | 6627 | 3262 | 4701 |

Deshacer INSERT necesita información para eliminar la fila insertada; deshacer DELETE necesita reconstruir la fila eliminada y revertir el trabajo de índices. Por eso el DELETE dejó unas tres veces el undo del INSERT en esta prueba. El undo se almacena en bloques que también deben poder recuperarse; sus cambios generan redo. ROLLBACK aplica cambios inversos, y esos cambios también se protegen con redo.

No mezclo estas cifras con la segunda ejecución del reto FRA, que dio valores distintos. En ese reto la FRA creció 18623488 bytes (17,76 MiB): incluye el archivado de la carga, sus reversiones y posible actividad de fondo, no solo el DELETE.

Evidencias: [20261124T200841Z_12-undo-redo.script.log](lab5/evidencia/script/20261124T200841Z_12-undo-redo.script.log); [20261124T200841Z_12-crecimiento-fra.txt](lab5/evidencia/config/20261124T200841Z_12-crecimiento-fra.txt).

### 19. Garantía después del COMMIT y después del checkpoint

Tras UPDATE de 20000 filas y COMMIT se midieron 1786 KB de redo, 3 escrituras de LGWR, 1 commit, 0 bloques escritos desde caché por DBWn y 237 bloques sucios de la tabla. La durabilidad observada se apoya en el redo persistido, no en que los datafiles ya contengan todos los cambios.

El checkpoint siguiente produjo 355 bloques escritos por DBWn y dejó 0 bloques sucios de la tabla; también se midieron 8 KB de redo y 1 escritura LGWR. Las estadísticas son de toda la instancia: los 355 bloques no deben atribuirse exclusivamente a los 237 bloques de esa tabla; incluyen otros bloques, como undo, y actividad de fondo.

Evidencia: [20261124T201320Z_13-lgwr-dbwn.csv](lab5/evidencia/config/20261124T201320Z_13-lgwr-dbwn.csv); [20261124T201320Z_13-lgwr-dbwn.script.log](lab5/evidencia/script/20261124T201320Z_13-lgwr-dbwn.script.log).

### 20. Roll forward y roll back en el simulacro A

La fila 102 conservó EGRESADO porque su cambio se había confirmado. La 103 volvió a ACTIVO porque INACTIVO no se había confirmado. El arranque y la comprobación tardaron 10 s.

El alert log registró Beginning crash recovery, lectura de 50 KB de redo, 44 bloques que necesitaban recuperación, redo scan, redo application y Completed crash recovery. El roll forward rehace los cambios necesarios, incluidos los de bloques de undo; el undo permite deshacer las transacciones no confirmadas. La reversión puede continuar después de la apertura; no la atribuyo toda a una única línea del alert log. La comprobación de las filas acredita el resultado de este ensayo.

Evidencias: [20261124T203633Z_14a-alert-recuperacion.script.log](lab5/evidencia/script/20261124T203633Z_14a-alert-recuperacion.script.log); [20261124T203633Z_14a-metricas.txt](lab5/evidencia/config/20261124T203633Z_14a-metricas.txt).

### 21. Comparación de recuperación completa y de un datafile

C tardó 267 s desde iniciar la restauración hasta comprobar tabla y metadatos, y 268 s desde solicitar DROP PURGE. Restauró el volumen completo: su punto de recuperación es el de la copia en frío, por lo que cualquier cambio posterior de otras tablas también retrocedería. No se introdujeron transacciones de negocio para cuantificar esa pérdida; no asigno un RPO medido de cero ni calculo una antigüedad de copia inexistente en las métricas.

D recuperó solo el datafile de 100 MiB y aplicó redo: los intervalos de la continuación fueron de 9 s. La fila 104 apareció EGRESADO, confirmada después del backup: RPO observado cero para esa transacción. Los 9 s excluyen la pausa de diagnóstico desde el primer OFFLINE. D fue una pérdida controlada con archivo fuera de línea antes del borrado, no una caída espontánea de un disco en línea.

La diferencia de volumen restaurado y el procedimiento explican buena parte del contraste; no son mediciones homogéneas para concluir una aceleración universal. RESTORE recupera el contenido respaldado y RECOVER lo actualiza con redo.

Evidencias: [20261124T205017Z_14c-metricas.txt](lab5/evidencia/config/20261124T205017Z_14c-metricas.txt); [20261124T211620Z_14d-metricas.txt](lab5/evidencia/config/20261124T211620Z_14d-metricas.txt).

### 22. Clasificación de los errores del runbook de salud

| Mensajes del bloque 5 | Clasificación |
|---|---|
| ORA-00202 sobre control03.ctl, ORA-205 durante MOUNT y ORA-00210, 20:38 | Efecto de B: pérdida provocada de una copia del control file; reparación comprobada después |
| ORA-01110 sobre el datafile 16, 21:16 | Contexto de D: identifica el archivo de la recuperación; por sí solo no prueba una avería pendiente |
| ORA-00800 con Set Priority Failed para LGWR y VKTM | Aviso del entorno asociado a prioridades, no fatal en ese momento. No se declara resuelto ni universalmente inocuo; corresponde revisar trazas y configuración |

El runbook muestra como máximo diez entradas del filtro en 24 h, no todos los errores del periodo. P.2 terminó TODO OK y las consultas finales comprobaron disponibilidad y datos; eso no diagnostica la causa de los avisos de prioridad.

Los avisos de índices sin estadísticas se aclararon con recuentos reales: once tablas vacías en los otros cuatro esquemas. En undo, los 644 s del runbook raíz y los 0 s consultados en FREEPDB1 tienen distinto ámbito y no se atribuyen a la misma carga.

Evidencias: [20261124T212313Z_15-healthcheck.script.log](lab5/evidencia/script/20261124T212313Z_15-healthcheck.script.log); [20261124T212446Z_16-recuentos-complementarios.script.log](lab5/evidencia/script/20261124T212446Z_16-recuentos-complementarios.script.log); [20261124T212446Z_16-verificacion-final.script.log](lab5/evidencia/script/20261124T212446Z_16-verificacion-final.script.log).

## Simulacro de examen S1–S26

Letras según el PDF v3, páginas 140–146. Las menciones «teórica» o «parcial» evitan presentar como ejecutados los supuestos que no se provocaron.

| Pregunta | Respuesta | Justificación | Parte y evidencia / alcance |
|---|---|---|---|
| S1 | B | CF próximo a las filas implica saltos frecuentes entre bloques de tabla; CF de IX_PED_CLIENTE=999041. | E. [20261124T193743Z_02-anatomia-indice.script.log](lab5/evidencia/script/20261124T193743Z_02-anatomia-indice.script.log) |
| S2 | A y C | El índice funcional permite buscar por UPPER; con emails normalizados, aplicar LOWER al dato permite reutilizar el índice normal. Q1 pasó de 1486 a 4 lecturas. | D/F. [20261124T194440Z_05-sargabilidad.script.log](lab5/evidencia/script/20261124T194440Z_05-sargabilidad.script.log) |
| S3 | B | El predicado mostró TO_NUMBER(CODIGO_POSTAL)=30001; comparar como texto permitió 106 lecturas frente a 5232. | F. [20261124T194440Z_05-sargabilidad.script.log](lab5/evidencia/script/20261124T194440Z_05-sargabilidad.script.log) |
| S4 | B | Los bitmaps favorecen combinaciones analíticas sobre baja cardinalidad, no DML concurrente intenso. Q14: 4073 a 528 lecturas. | D. [20261124T193859Z_03-tipos-indice.script.log](lab5/evidencia/script/20261124T193859Z_03-tipos-indice.script.log) |
| S5 | B | SKIP SCAN puede recorrer subíndices por valores de la columna inicial. En el ensayo PAIS tenía 40 valores, no los cinco del supuesto: 144 lecturas solo por ciudad. | D. [20261124T193859Z_03-tipos-indice.script.log](lab5/evidencia/script/20261124T193859Z_03-tipos-indice.script.log) |
| S6 | B | INVISIBLE permite observar el efecto sin dejar de mantener el índice y con vuelta a VISIBLE; Q2 conservó 335 lecturas. | G. [20261124T194641Z_06-indices.script.log](lab5/evidencia/script/20261124T194641Z_06-indices.script.log) |
| S7 | A y C | COALESCE corrige la cola; SHRINK puede además devolver espacio. En el ensayo ambos dejaron 2 lecturas; SHRINK redujo el segmento a 1,69 MB. | H. [20261124T195042Z_07-remedios.csv](lab5/evidencia/config/20261124T195042Z_07-remedios.csv) |
| S8 | B | REVERSE dispersa claves consecutivas pero no permite el rango ordenado por la clave original: el rango pasó de 4 a 878 lecturas. | H. [20261124T195042Z_07a-crecimiento.script.log](lab5/evidencia/script/20261124T195042Z_07a-crecimiento.script.log) |
| S9 | C | Cambiar una columna ajena a todos los índices no requiere mantener sus claves por ese cambio. Es una regla de coste de mantenimiento, no una promesa de coste total idéntico. M midió UPDATE de CANAL, no nueve configuraciones de índices. | G/M, fundamento e ilustración. [20261124T200841Z_12-undo-redo.script.log](lab5/evidencia/script/20261124T200841Z_12-undo-redo.script.log) |
| S10 | B | La capacidad de ramificación determina el crecimiento logarítmico: fan-out máximo estimado 543 y altura observada 3. | C. [20261124T193743Z_02-anatomia-indice.script.log](lab5/evidencia/script/20261124T193743Z_02-anatomia-indice.script.log) |
| S11 | A y C | Las filas residen en las hojas de la PK de la IOT; se evita un segmento de tabla separado. Q15: 3 lecturas IOT frente a 4 heap+PK. | D. [20261124T193859Z_03-tipos-indice.script.log](lab5/evidencia/script/20261124T193859Z_03-tipos-indice.script.log) |
| S12 | B | Se contrasta el checkpoint registrado en el control file con el de la cabecera; academia01 mostró 4401053 en ambos tras el checkpoint. | I. [20261124T195704Z_08-scn-checkpoint.script.log](lab5/evidencia/script/20261124T195704Z_08-scn-checkpoint.script.log) |
| S13 | C | CKPT registra el checkpoint; DBWn escribe bloques y LGWR redo. La identificación del proceso es interpretación arquitectónica, no un experimento que aislara sus llamadas al sistema. | I/N, interpretación. [20261124T201320Z_13-lgwr-dbwn.csv](lab5/evidencia/config/20261124T201320Z_13-lgwr-dbwn.csv) |
| S14 | B y E | La instancia y sus parámetros son accesibles antes del montaje; las vistas que necesitan el control file o diccionario abierto no lo son. B acredita STARTED tras el fallo de MOUNT, pero no se ejecutaron allí las cinco consultas del supuesto. | O.B; aplicación teórica parcial. [20261124T203833Z_14b-arranque-fallido.script.log](lab5/evidencia/script/20261124T203833Z_14b-arranque-fallido.script.log) |
| S15 | B | La transición exige parada limpia, STARTUP MOUNT, ALTER DATABASE ARCHIVELOG y OPEN. En L la base ya estaba ARCHIVELOG y no se volvió a cambiar su modo. | L; respuesta teórica no reensayada. [20261124T200617Z_11-configurar-fra.script.log](lab5/evidencia/script/20261124T200617Z_11-configurar-fra.script.log) |
| S16 | B | Para ese supuesto de redo INACTIVE ya archivado, CLEAR LOGFILE recrea el grupo. No se provocó pérdida de su único miembro ni se ejecutó CLEAR en K. | K; respuesta teórica. [20261124T200207Z_10-redo.script.log](lab5/evidencia/script/20261124T200207Z_10-redo.script.log) |
| S17 | A y C | Undo permite lectura consistente y flashback AS OF: B leyó ACTIVO antes del commit y también mediante flashback después. | M. [20261124T200841Z_12-lectura-consistente.script.log](lab5/evidencia/script/20261124T200841Z_12-lectura-consistente.script.log) |
| S18 | B | Hay que poder reconstruir bloques de undo antes de deshacer lo no confirmado. DELETE generó 3262 KB de redo que describían undo. | M. [20261124T200841Z_12-undo-redo.script.log](lab5/evidencia/script/20261124T200841Z_12-undo-redo.script.log) |
| S19 | A | En el COMMIT normal del ensayo quedó protegido el redo, no necesariamente todos los bloques de datos: 237 bloques de tabla seguían sucios. | N. [20261124T201320Z_13-lgwr-dbwn.csv](lab5/evidencia/config/20261124T201320Z_13-lgwr-dbwn.csv) |
| S20 | A | Un objetivo menor tiende a exigir checkpoints incrementales más frecuentes y menos trabajo de recuperación, con coste de escritura. No se cambió el parámetro de 300 a 30: en I valía 0 y el reto dejó MTTR=11 s aunque creció el redo pendiente. | I; respuesta teórica. [20261124T195704Z_08-reto-mttr-verificacion.script.log](lab5/evidencia/script/20261124T195704Z_08-reto-mttr-verificacion.script.log) |
| S21 | B | Si ARCn no puede archivar, pueden agotarse los grupos reutilizables. L mostró ORA-19809 y ORA-16038 con FRA limitada a 2 MiB. | L. [20261124T200617Z_11-fra-llena.script.log](lab5/evidencia/script/20261124T200617Z_11-fra-llena.script.log) |
| S22 | B | Se aísla el archivo de aplicación antes de RESTORE/RECOVER para preservar el servicio restante. D probó la secuencia en variante controlada, con OFFLINE anterior a la pérdida; no produjo el fallo espontáneo exacto del supuesto. | O.D, variante controlada. [20261124T211620Z_14d-metricas.txt](lab5/evidencia/config/20261124T211620Z_14d-metricas.txt) |
| S23 | B | SYSTEM de la raíz requiere recuperación con CDB montada y posterior apertura. No se dañó SYSTEM en este laboratorio. | O, fundamento del PDF; no ensayado. PDF v3, p. 119 y p. 145; sin evidencia de fallo de SYSTEM propia |
| S24 | B | Es la opción esperada en el supuesto del laboratorio sin redo archivado suficiente: restaurar una copia consistente completa y perder lo posterior. No se ensayó un fallo en NOARCHIVELOG; C restauró copia en frío con la base configurada en ARCHIVELOG. | O.C, ilustración; caso NOARCHIVELOG teórico. [20261124T205017Z_14c-metricas.txt](lab5/evidencia/config/20261124T205017Z_14c-metricas.txt) |
| S25 | B y D | Más retención y capacidad de undo; GUARANTEE si procede, aceptando riesgo de fallo de escrituras por falta de espacio. No se provocó ORA-01555 ni se activó GUARANTEE; el runbook mostró cero errores. | M/P; medidas teóricas. [20261124T212313Z_15-healthcheck.script.log](lab5/evidencia/script/20261124T212313Z_15-healthcheck.script.log) |
| S26 | A | V$RECOVERY_AREA_USAGE desglosa el uso por tipo: L mostró ARCHIVED LOG y dos archivos en la comprobación inicial. | L. [20261124T200617Z_11-configurar-fra.script.log](lab5/evidencia/script/20261124T200617Z_11-configurar-fra.script.log) |

## Tabla consolidada de recuperación observada

Los nombres de RTO/RPO del guion se documentan aquí como tiempos observados y puntos de recuperación. No se ha definido un SLO contractual ni un objetivo de recuperación garantizado.

| Simulacro | Tiempo observado y límites | Pérdida de datos / punto de recuperación | Alcance |
|---|---|---|---|
| A — Instancia | 10 s desde antes de solicitar ABORT hasta comprobar filas tras STARTUP | Cero pérdida del cambio confirmado de prueba; lo no confirmado se deshizo | Recuperación de instancia, sin restaurar copia |
| B — Control file | 15 s desde solicitar parada limpia; 9 s desde empezar reparación, ambos hasta datos verificados | Copia multiplexada actual tras parada limpia; no se midió un RPO independiente con transacciones de negocio | Tres copias operativas, sin RESETLOGS |
| C — Tabla / volumen | 1 s para flashback+FK+verificación; 267 s desde iniciar restauración; 268 s desde DROP PURGE | Vuelta al punto de la copia en frío. Sin cambios de negocio posteriores introducidos para cuantificar pérdida | Volumen completo; 60000 filas y metadatos, no comparación fila a fila |
| D — Datafile | 9 s en la continuación desde antes del borrado hasta datos verificados; pausa de diagnóstico excluida | Cero pérdida para la transacción confirmada después del backup | Archivo de 100 MiB puesto OFFLINE antes de borrarlo; no se probó cierre automático de PDB |

Los 267/268 s de C y los 9 s de D tienen límites distintos. No calculo un factor universal de rendimiento ni presento los 9 s como toda la indisponibilidad de D.

Ver [informe de O](lab5/parte-o-simulacros.md) y [salud y verificación de P](lab5/parte-p-salud-verificacion.md).

## Retrospectiva técnica de los simulacros

Estas observaciones son una propuesta técnica de reflexión basada en las pruebas; deben revisarse para expresar también la valoración personal del alumno.

| Caso | Observación más significativa | Qué funcionó | Qué mejoraría |
|---|---|---|---|
| A | El COMMIT sobrevivió sin exigir que todos los datos estuvieran escritos antes de ABORT | Dos sesiones y comprobación de transacción abierta evitaron perder el experimento antes del fallo | Medición de mayor resolución y comprobación automatizada de disponibilidad de aplicación |
| B | Una sola ruta ausente impidió montar, aunque había copias sanas | Se identificó la copia sana antes de parar y se copió con la instancia detenida | Separar dominios de fallo; las tres rutas actuales comparten volumen |
| C | Recuperar una sola tabla mediante copia fría obligó a restaurar todo el volumen | Copia específica, DDL de FK y comparación de metadatos evitaron una recuperación incompleta | Evaluar recuperación de tabla con RMAN en otro ejercicio, sin afirmar que se haya probado aquí |
| D | V$DATAFILE mostró RECOVER mientras la cabecera y V$RECOVER_FILE confirmaban OFFLINE | La condición conservadora detuvo el bloque antes de borrar; se diagnosticó, revalidó el respaldo y reanudó | Comprobar conjuntamente identidad, estado y cabecera; guardar tiempos persistentes desde el primer OFFLINE para incluir pausas |

### Incidencia D: retrospectiva sin culpables

- Impacto: el datafile 16 quedó fuera de línea durante la pausa; la CDB y FREEPDB1 seguían abiertas. No se perdió la transacción de prueba.
- Detección: ORA-20027 del comprobador después de DATAFILE OFFLINE y antes de rm.
- Causa: condición demasiado estrecha que solo aceptaba OFFLINE en V$DATAFILE, ignorando RECOVER.
- Mitigación: comprobar archivo presente, cabecera OFFLINE/RECOVER=YES/ERROR vacío, revalidar la pieza RMAN y continuar desde el borrado sin repetir el UPDATE ni crear otra copia.
- Resultado: fila 104=EGRESADO tras RESTORE/RECOVER; limpieza posterior a ACTIVO; P.2 TODO OK.
- Acción: conservar el intento fallido y la corrección; no limpiar la evidencia para simular una primera ejecución perfecta.

## Retrospectiva del escenario de FRA llena

- Contexto: ensayo controlado de L, no incidente espontáneo por repetir cargas de un millón de filas.
- Impacto observado: archivado de la secuencia 20 fallido; grupos ACTIVE/CURRENT pendientes de archivar. No se documenta una indisponibilidad prolongada medida de toda la base.
- Detección: ORA-19815 avisó del 100 % de la cuota de 2097152 bytes; se registraron ORA-19809, ORA-16038 y ORA-00312.
- Causa raíz: reducción deliberada del límite de FRA a 2 MiB por debajo del uso necesario.
- Mitigación aplicada: devolver 4 GiB, incluido SPFILE; un rescate auxiliar también registró LIMITE_FRA_RECUPERADO_4G. No se afirma una limpieza masiva de archivados que no se realizó.
- Verificación: archivado posterior correcto, destino VALID sin ERROR y FRA de 4096 MB; comprobación L y P.2 superadas.
- Prevención: revisar FRA antes de cargas, mantener aviso temprano al 80 % y una escalada más alta, además de una política de copias y gestión de archivados. No usar rm ni borrar todo el redo archivado como reacción rutinaria.
- Lección: hay que distinguir cuota FRA de espacio físico libre y registrar la vuelta del límite tanto en memoria como en SPFILE.

Evidencia: [FRA llena](lab5/evidencia/script/20261124T200617Z_11-fra-llena.script.log), [rescate](lab5/evidencia/script/20261124T200619Z_11-rescate-limite.script.log) y [verificación](lab5/evidencia/script/20261124T200617Z_11-verificacion-final.script.log).

## Pendientes de entrega fuera de esta redacción

- Revisión personal de las respuestas y de los supuestos no ensayados; no se declara cumplimiento práctico total de esos casos.
- Control Q.2 antes del push, revisión del diff y preparación del PR de Q.3.
- Revisión por otra persona, resolución de comentarios y merge conforme al flujo del curso.
- Etiqueta lab5-final y copia final únicamente en el punto de cierre previsto por Q.5.

La documentación no sustituye las pruebas omitidas ni afirma que la rama esté publicada, fusionada o que la incidencia #11 esté cerrada. El reto independiente V006 no se ha realizado con esta redacción y no se añade ficticiamente a V005.
