-- Lab 4 v3: elimina exclusivamente el banco LAB4PRUEBAS/TBS_LAB4.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 180 PAGESIZE 100 FEEDBACK ON VERIFY OFF
ALTER SESSION SET CONTAINER = FREEPDB1;

PROMPT === 1. Comprobaciones antes del borrado ===
DECLARE
  n NUMBER;
BEGIN
  IF SYS_CONTEXT('USERENV', 'CON_NAME') <> 'FREEPDB1' THEN
    RAISE_APPLICATION_ERROR(-20060, 'Contenedor incorrecto.');
  END IF;

  SELECT COUNT(*) INTO n FROM dba_users
  WHERE username = 'LAB4PRUEBAS'
    AND authentication_type = 'NONE'
    AND default_tablespace = 'TBS_LAB4';
  IF n <> 1 THEN
    RAISE_APPLICATION_ERROR(-20061, 'El usuario no coincide con el banco esperado.');
  END IF;

  SELECT COUNT(*) INTO n FROM dba_segments
  WHERE (tablespace_name = 'TBS_LAB4' AND owner <> 'LAB4PRUEBAS')
     OR (owner = 'LAB4PRUEBAS' AND tablespace_name <> 'TBS_LAB4');
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20062, 'Hay segmentos fuera del alcance previsto.');
  END IF;

  SELECT COUNT(*) INTO n FROM dba_users
  WHERE username <> 'LAB4PRUEBAS'
    AND (default_tablespace = 'TBS_LAB4'
         OR temporary_tablespace = 'TBS_LAB4');
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20063, 'Otro usuario utiliza TBS_LAB4.');
  END IF;

  SELECT COUNT(*) INTO n FROM dba_data_files
  WHERE tablespace_name = 'TBS_LAB4';
  IF n <> 1 THEN
    RAISE_APPLICATION_ERROR(-20064, 'Numero inesperado de datafiles.');
  END IF;

  SELECT COUNT(*) INTO n FROM dba_data_files
  WHERE tablespace_name = 'TBS_LAB4'
    AND file_name = '/opt/oracle/oradata/FREE/FREEPDB1/lab4pruebas01.dbf';
  IF n <> 1 THEN
    RAISE_APPLICATION_ERROR(-20065, 'Ruta de datafile inesperada.');
  END IF;
END;
/

PROMPT === 2. Eliminar el esquema de pruebas ===
DROP USER lab4pruebas CASCADE;

PROMPT === 3. Confirmar que el tablespace ha quedado sin segmentos ===
DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM dba_segments
  WHERE tablespace_name = 'TBS_LAB4';
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20066, 'Quedan segmentos; no se elimina el tablespace.');
  END IF;
END;
/

PROMPT === 4. Eliminar el tablespace y su archivo fisico ===
DROP TABLESPACE tbs_lab4 INCLUDING CONTENTS AND DATAFILES;

PROMPT === 5. Verificar ausencia en el diccionario ===
SELECT
  (SELECT COUNT(*) FROM dba_users
   WHERE username = 'LAB4PRUEBAS') AS usuarios_restantes,
  (SELECT COUNT(*) FROM dba_tablespaces
   WHERE tablespace_name = 'TBS_LAB4') AS tablespaces_restantes,
  (SELECT COUNT(*) FROM dba_data_files
   WHERE file_name =
     '/opt/oracle/oradata/FREE/FREEPDB1/lab4pruebas01.dbf') AS datafiles_restantes
FROM dual;

EXIT
