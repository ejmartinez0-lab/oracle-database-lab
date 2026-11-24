# Runbook — Pérdida de un datafile de aplicación

Ámbito: FREEPDB1, ARCHIVELOG; ejemplo del laboratorio: archivo 16, `academia01.dbf`. No aplicar a SYSTEM o undo de la raíz. Registrar hora inicial, impacto, comandos y salida; avisar al responsable DBA/docente (en producción, responsable de guardia y del servicio).

## 1. Diagnóstico y condiciones para actuar

Síntomas posibles: ORA-01116 (apertura fallida), ORA-01110 (identifica archivo), ORA-27041 (fallo de apertura del SO); ORA-63999 puede acompañar el cierre protector de la PDB. Conservar el mensaje completo y el alert log; no deducir la causa solo de ORA-01110. Como SYS desde la raíz:
```sql
SELECT log_mode FROM v$database;
SELECT name, open_mode FROM v$pdbs WHERE name='FREEPDB1';
SELECT file#, con_id, name, status FROM v$datafile WHERE file#=16;
SELECT file#, status, recover, error FROM v$datafile_header WHERE file#=16;
```
Confirmar número, ruta, contenedor, acceso al almacenamiento y respaldo utilizable. En RMAN conectado a la raíz:
```rman
LIST BACKUP OF DATAFILE 16;
RESTORE DATAFILE 16 FROM TAG 'LAB5_D_20261124T211036Z' VALIDATE;
```
La etiqueta es exclusiva de este ensayo: en otro incidente seleccionar una copia vigente y confirmar disponibilidad del redo necesario. VALIDATE no garantiza por sí solo toda la cadena de recuperación. Si falta copia/redo, hay errores de E/S persistentes o la identidad no coincide, detener el procedimiento y escalar; no borrar nada ni improvisar RESETLOGS.

## 2. Aislar según el estado de la PDB

Si FREEPDB1 está READ WRITE, aislar el archivo desde esa PDB:
```sql
ALTER SESSION SET CONTAINER=FREEPDB1;
ALTER DATABASE DATAFILE 16 OFFLINE;
```
Verificar desde la raíz: V$DATAFILE puede indicar OFFLINE o RECOVER; contrastar con la cabecera y V$RECOVER_FILE. Si Oracle está cerrando la PDB, no lanzar RESTORE durante el cierre: consultar V$PDBS desde la raíz hasta que termine. Si ya está MOUNTED, mantenerla así y recuperar desde la raíz; no repetir operaciones de una fase completada ni forzar su apertura antes de recuperar.

## 3. Restaurar, recuperar y devolver al servicio

En RMAN desde la raíz, con el archivo aislado o la PDB montada:
```rman
RESTORE DATAFILE 16 FROM TAG 'LAB5_D_20261124T211036Z';
RECOVER DATAFILE 16;
```
Revisar la salida completa y detenerse ante errores. No poner ONLINE después de RESTORE sin completar RECOVER. Después, como SYS:
```sql
ALTER SESSION SET CONTAINER=FREEPDB1;
ALTER DATABASE DATAFILE 16 ONLINE;
ALTER SESSION SET CONTAINER=CDB$ROOT;
```
Solo si FREEPDB1 sigue MOUNTED: `ALTER PLUGGABLE DATABASE FREEPDB1 OPEN;`. Si el estado es otro o hay cierre en curso, diagnosticar y escalar antes de continuar.

## 4. Verificación y cierre

Comprobar FREEPDB1 READ WRITE, archivo ONLINE, cabecera sin ERROR y RECOVER=NO, y ausencia del archivo en V$RECOVER_FILE. Consultar la fila de control y el servicio: en este ensayo 104 debía ser EGRESADO antes de su limpieza; hubo 20000 estudiantes y 60000 matrículas. No modificar filas para ocultar una recuperación incorrecta. Anotar tiempo total, pausas y pérdida real observada; comunicar recuperación y acciones pendientes.

Ensayo ejecutado: pérdida con archivo previamente OFFLINE, sin cierre automático de PDB; continuación de 9 s, pausa excluida y transacción posterior al backup recuperada. [Evidencia](../bitacora/lab5/evidencia/script/20261124T211620Z_14d-reanudacion.script.log). El camino de PDB cerrada es procedimiento documentado, no resultado ensayado aquí. Conservar logs y no ejecutar este texto como un script de fallo.
