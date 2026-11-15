SET LINESIZE 200 PAGESIZE 100 FEEDBACK ON VERIFY OFF
COLUMN name FORMAT A20
COLUMN en_memoria FORMAT A16
COLUMN en_spfile FORMAT A20
COLUMN update_comment FORMAT A45
COLUMN contenedor FORMAT A16

WHENEVER SQLERROR EXIT FAILURE
PROMPT === 0. Copia de seguridad ANTES de cambiar parametros ===
CREATE PFILE='/tmp/initFREE-lab4-antes.ora' FROM SPFILE;

PROMPT === 1. MEMORY: cambia memoria, no SPFILE ===
ALTER SYSTEM SET open_cursors=400 SCOPE=MEMORY;

SELECT p.name, p.value AS en_memoria,
       NVL(s.value, '(no especificado)') AS en_spfile
FROM v$parameter p
JOIN v$spparameter s ON s.name=p.name
WHERE p.name='open_cursors' AND s.sid='*';

PROMPT === 2. BOTH: cambia memoria y SPFILE ===
ALTER SYSTEM SET open_cursors=500
  COMMENT='Lab4 prueba SCOPE BOTH' SCOPE=BOTH;

SELECT p.name, p.value AS en_memoria, s.value AS en_spfile,
       p.update_comment
FROM v$parameter p
JOIN v$spparameter s ON s.name=p.name
WHERE p.name='open_cursors' AND s.sid='*';

PROMPT === Deshacer: volver a 300 ===
ALTER SYSTEM SET open_cursors=300 COMMENT='' SCOPE=BOTH;

PROMPT === 3. Parametro estatico: error esperado en MEMORY ===
WHENEVER SQLERROR CONTINUE
ALTER SYSTEM SET db_files=300 SCOPE=MEMORY;

WHENEVER SQLERROR EXIT FAILURE
PROMPT === SPFILE: dejar 300 pendiente, sin cambiar memoria ===
ALTER SYSTEM SET db_files=300 SCOPE=SPFILE;

SELECT p.name, p.value AS en_memoria, s.value AS en_spfile
FROM v$parameter p
JOIN v$spparameter s ON s.name=p.name
WHERE p.name='db_files' AND s.sid='*';

PROMPT === Deshacer: eliminar la entrada pendiente ===
ALTER SYSTEM RESET db_files SCOPE=SPFILE SID='*';

SELECT p.name, p.value AS en_memoria,
       NVL(s.value, '(no especificado)') AS en_spfile,
       s.isspecified
FROM v$parameter p
JOIN v$spparameter s ON s.name=p.name
WHERE p.name='db_files' AND s.sid='*';

PROMPT === 4. Pruebas con errores esperados ===
WHENEVER SQLERROR CONTINUE
PROMPT -- PROCESSES: se espera rechazo del cambio en memoria
ALTER SYSTEM SET processes=250 SCOPE=MEMORY;

PROMPT -- MEMORY_SIZE: se espera rechazo si no se activo al arrancar
ALTER SYSTEM SET memory_size=1600M SCOPE=MEMORY;

WHENEVER SQLERROR EXIT FAILURE
PROMPT === 5. Parametro de PDB ===
ALTER SESSION SET CONTAINER=FREEPDB1;
ALTER SYSTEM SET open_cursors=350 SCOPE=MEMORY;

SELECT SYS_CONTEXT('USERENV','CON_NAME') AS contenedor,
       name, value AS en_memoria
FROM v$parameter WHERE name='open_cursors';

PROMPT -- PROCESSES desde PDB: se espera ORA-65040
WHENEVER SQLERROR CONTINUE
ALTER SYSTEM SET processes=300 SCOPE=SPFILE;

WHENEVER SQLERROR EXIT FAILURE
PROMPT === Deshacer: volver a heredar OPEN_CURSORS ===
ALTER SYSTEM RESET open_cursors SCOPE=MEMORY;

SELECT SYS_CONTEXT('USERENV','CON_NAME') AS contenedor,
       name, value AS en_memoria
FROM v$parameter WHERE name='open_cursors';

ALTER SESSION SET CONTAINER=CDB$ROOT;

PROMPT === 6. Alcance de sesion ===
ALTER SESSION SET nls_date_format='YYYY-MM-DD HH24:MI:SS';
SELECT SYSDATE AS fecha_formato_sesion FROM dual;

PROMPT === 7. Exportar configuracion final ===
CREATE PFILE='/tmp/initFREE-lab4.ora' FROM SPFILE;
CREATE PFILE='/tmp/initFREE-lab4-memoria.ora' FROM MEMORY;

PROMPT === 8. Valores finales de control ===
SELECT name, value
FROM v$parameter
WHERE name IN ('open_cursors','db_files','processes','memory_size')
ORDER BY name;

SELECT sid, name, value, isspecified
FROM v$spparameter
WHERE name IN ('open_cursors','db_files','processes','memory_size')
ORDER BY name, sid;

EXIT
