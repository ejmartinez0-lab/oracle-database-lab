-- Lab 4 v3, Parte L: banco separado para medir lecturas.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 180 PAGESIZE 100 FEEDBACK ON VERIFY OFF TAB OFF
ALTER SESSION SET CONTAINER = FREEPDB1;

PROMPT === 1. No reutilizar objetos existentes ===
DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM dba_users
  WHERE username = 'LAB4PRUEBAS';
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20040, 'LAB4PRUEBAS ya existe. No se ha modificado.');
  END IF;
  SELECT COUNT(*) INTO n FROM dba_tablespaces
  WHERE tablespace_name = 'TBS_LAB4';
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20041, 'TBS_LAB4 ya existe. No se ha modificado.');
  END IF;
END;
/

PROMPT === 2. Tablespace de pruebas dentro del volumen ===
CREATE BIGFILE TABLESPACE tbs_lab4
DATAFILE '/opt/oracle/oradata/FREE/FREEPDB1/lab4pruebas01.dbf'
SIZE 64M AUTOEXTEND ON NEXT 32M MAXSIZE 512M;

CREATE USER lab4pruebas NO AUTHENTICATION
DEFAULT TABLESPACE tbs_lab4
QUOTA UNLIMITED ON tbs_lab4;

PROMPT === 3. Crear 400000 filas de prueba y su clave primaria ===
CREATE TABLE lab4pruebas.lecturas
TABLESPACE tbs_lab4 PCTFREE 10
AS
SELECT ROWNUM AS id,
       MOD(ROWNUM, 1000) AS grupo,
       RPAD('x', 60, 'x') AS relleno,
       SYSDATE - MOD(ROWNUM, 3650) AS fecha
FROM dual
CONNECT BY LEVEL <= 400000;

ALTER TABLE lab4pruebas.lecturas
ADD CONSTRAINT pk_lecturas PRIMARY KEY (id)
USING INDEX TABLESPACE tbs_lab4;

EXEC DBMS_STATS.GATHER_TABLE_STATS('LAB4PRUEBAS', 'LECTURAS')

PROMPT === 4. Verificar filas, estadisticas y objetos ===
SELECT COUNT(*) AS filas_reales
FROM lab4pruebas.lecturas;

SELECT num_rows, avg_row_len, blocks,
       ROUND(blocks * 8192 / 1048576, 2) AS mb_bloques
FROM dba_tables
WHERE owner = 'LAB4PRUEBAS' AND table_name = 'LECTURAS';

COLUMN username FORMAT A18
COLUMN authentication_type FORMAT A20
SELECT username, authentication_type, default_tablespace
FROM dba_users
WHERE username = 'LAB4PRUEBAS';

COLUMN file_name FORMAT A85
SELECT file_name, ROUND(bytes / 1048576) AS mb_actuales,
       autoextensible, ROUND(maxbytes / 1048576) AS mb_maximos
FROM dba_data_files
WHERE tablespace_name = 'TBS_LAB4';

SELECT index_name, status
FROM dba_indexes
WHERE owner = 'LAB4PRUEBAS' AND table_name = 'LECTURAS';

EXIT
