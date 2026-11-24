WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 200 PAGESIZE 100 FEEDBACK ON
SET SERVEROUTPUT ON SIZE UNLIMITED
COLUMN name FORMAT A90

DECLARE
  n NUMBER;
  modo VARCHAR2(30);
BEGIN
  SELECT COUNT(*) INTO n FROM v$controlfile;
  IF n <> 3 THEN
    RAISE_APPLICATION_ERROR(-20019, 'No hay exactamente tres control files');
  END IF;

  SELECT COUNT(*) INTO n FROM v$controlfile WHERE status IS NOT NULL;
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20019, 'Hay control files con estado anomalo');
  END IF;

  SELECT COUNT(*) INTO n FROM v$controlfile
   WHERE name = '/opt/oracle/oradata/FREE/control03.ctl';
  IF n <> 1 THEN
    RAISE_APPLICATION_ERROR(-20019, 'Falta la tercera ruta prevista');
  END IF;

  SELECT COUNT(*) INTO n FROM v$spparameter
   WHERE name = 'control_files' AND isspecified = 'TRUE'
     AND value = '/opt/oracle/oradata/FREE/control03.ctl';
  IF n <> 1 THEN
    RAISE_APPLICATION_ERROR(-20019, 'Tercera copia no confirmada en SPFILE');
  END IF;

  SELECT open_mode INTO modo FROM v$database;
  IF modo <> 'READ WRITE' THEN
    RAISE_APPLICATION_ERROR(-20019, 'CDB no esta en READ WRITE');
  END IF;

  SELECT COUNT(*) INTO n FROM v$pdbs
   WHERE name = 'FREEPDB1' AND open_mode = 'READ WRITE';
  IF n <> 1 THEN
    RAISE_APPLICATION_ERROR(-20019, 'FREEPDB1 no esta en READ WRITE');
  END IF;

  DBMS_OUTPUT.PUT_LINE('OK: tres copias registradas y sin estado anomalo');
  DBMS_OUTPUT.PUT_LINE('OK: tercera copia persistida en SPFILE');
  DBMS_OUTPUT.PUT_LINE('OK: CDB y FREEPDB1 en READ WRITE');
END;
/

SELECT name, status, block_size, file_size_blks FROM v$controlfile ORDER BY name;
PROMPT PARTE_J_VERIFICADA_OK
EXIT SUCCESS
