WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 220 PAGESIZE 100 FEEDBACK ON VERIFY OFF
SET SERVEROUTPUT ON SIZE UNLIMITED
COLUMN name FORMAT A90
COLUMN destination FORMAT A90
COLUMN error FORMAT A80

PROMPT === ARCHIVADO DESPUES DE RECUPERAR EL LIMITE ===
ALTER SYSTEM ARCHIVE LOG CURRENT;

DECLARE
  n NUMBER;
  modo VARCHAR2(30);
  ruta VARCHAR2(1000);
  tam NUMBER;
BEGIN
  SELECT log_mode INTO modo FROM v$database;
  IF modo <> 'ARCHIVELOG' THEN
    RAISE_APPLICATION_ERROR(-20021, 'La base no esta en ARCHIVELOG');
  END IF;

  SELECT value INTO ruta FROM v$parameter
   WHERE name = 'db_recovery_file_dest';
  IF ruta IS NULL OR ruta <> '/opt/oracle/oradata/fra' THEN
    RAISE_APPLICATION_ERROR(-20021, 'Ruta de FRA distinta de la prevista');
  END IF;

  SELECT TO_NUMBER(value) INTO tam FROM v$parameter
   WHERE name = 'db_recovery_file_dest_size';
  IF tam <> 4294967296 THEN
    RAISE_APPLICATION_ERROR(-20021, 'FRA en memoria no esta en 4 GiB');
  END IF;

  SELECT COUNT(*) INTO n FROM v$spparameter
   WHERE name = 'db_recovery_file_dest_size'
     AND isspecified = 'TRUE' AND value = '4294967296';
  IF n <> 1 THEN
    RAISE_APPLICATION_ERROR(-20021, 'FRA en SPFILE no esta en 4 GiB');
  END IF;

  SELECT COUNT(*) INTO n FROM v$archived_log
   WHERE is_recovery_dest_file = 'YES'
     AND archived = 'YES' AND deleted = 'NO'
     AND completion_time > SYSDATE - 10/1440;
  IF n = 0 THEN
    RAISE_APPLICATION_ERROR(-20021, 'No hay archivados recientes en la FRA');
  END IF;

  SELECT COUNT(*) INTO n FROM v$archive_dest
   WHERE status = 'ERROR' AND error IS NOT NULL;
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20021, 'Persisten errores en destinos de archivado');
  END IF;

  SELECT open_mode INTO modo FROM v$database;
  IF modo <> 'READ WRITE' THEN
    RAISE_APPLICATION_ERROR(-20021, 'CDB no esta en READ WRITE');
  END IF;

  SELECT COUNT(*) INTO n FROM v$pdbs
   WHERE name = 'FREEPDB1' AND open_mode = 'READ WRITE';
  IF n <> 1 THEN
    RAISE_APPLICATION_ERROR(-20021, 'FREEPDB1 no esta en READ WRITE');
  END IF;

  DBMS_OUTPUT.PUT_LINE('OK: ARCHIVELOG y archivados recientes en la FRA');
  DBMS_OUTPUT.PUT_LINE('OK: FRA en 4 GiB en memoria y SPFILE');
  DBMS_OUTPUT.PUT_LINE('OK: sin destinos en ERROR y base disponible');
END;
/

ARCHIVE LOG LIST

SELECT name,
       ROUND(space_limit / 1048576) AS limite_mb,
       ROUND(space_used / 1048576, 2) AS usado_mb
FROM v$recovery_file_dest;

SELECT dest_id, status, destination, error
FROM v$archive_dest WHERE status <> 'INACTIVE';

SELECT sequence#, name, archived, is_recovery_dest_file
FROM v$archived_log
WHERE name IS NOT NULL
ORDER BY completion_time DESC FETCH FIRST 5 ROWS ONLY;

PROMPT PARTE_L_VERIFICADA_OK
EXIT SUCCESS
