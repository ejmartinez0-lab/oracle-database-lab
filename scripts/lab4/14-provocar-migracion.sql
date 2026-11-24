-- Lab 4 v3, Parte M: provocar migracion en una tabla de pruebas.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 180 PAGESIZE 100 FEEDBACK ON VERIFY OFF TAB OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
COLUMN table_name FORMAT A18
COLUMN rowid_cabeza FORMAT A20

PROMPT === 1. Comprobar el banco y evitar sobrescribir objetos ===
DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM dba_users
  WHERE username = 'LAB4PRUEBAS'
    AND default_tablespace = 'TBS_LAB4';
  IF n <> 1 THEN
    RAISE_APPLICATION_ERROR(-20050, 'Falta el banco LAB4PRUEBAS de la Parte L.');
  END IF;
  SELECT COUNT(*) INTO n FROM dba_objects
  WHERE owner = 'LAB4PRUEBAS'
    AND object_name IN ('MIGRA', 'PK_MIGRA', 'CHAINED_ROWS');
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20051, 'Ya existen objetos de migracion. No se han modificado.');
  END IF;
END;
/

PROMPT === 2. Crear filas pequenas sin reserva para crecimiento ===
CREATE TABLE lab4pruebas.migra (
  id NUMBER CONSTRAINT pk_migra PRIMARY KEY,
  txt VARCHAR2(400)
)
PCTFREE 0 TABLESPACE tbs_lab4;

INSERT INTO lab4pruebas.migra (id, txt)
SELECT LEVEL, 'x' FROM dual CONNECT BY LEVEL <= 5000;
COMMIT;

ANALYZE TABLE lab4pruebas.migra COMPUTE STATISTICS;

SELECT table_name, num_rows, blocks, pct_free, avg_row_len, chain_cnt
FROM dba_tables
WHERE owner = 'LAB4PRUEBAS' AND table_name = 'MIGRA';

PROMPT === 3. Ampliar una de cada cinco filas ===
UPDATE lab4pruebas.migra
SET txt = RPAD('x', 300, 'x')
WHERE MOD(id, 5) = 0;
COMMIT;

ANALYZE TABLE lab4pruebas.migra COMPUTE STATISTICS;

SELECT table_name, num_rows, blocks, pct_free, avg_row_len, chain_cnt,
       ROUND(100 * chain_cnt / NULLIF(num_rows, 0), 2) AS pct_chain_cnt
FROM dba_tables
WHERE owner = 'LAB4PRUEBAS' AND table_name = 'MIGRA';

PROMPT === 4. Preparar la tabla de diagnostico ===
CREATE TABLE lab4pruebas.chained_rows (
  owner_name VARCHAR2(128),
  table_name VARCHAR2(128),
  cluster_name VARCHAR2(128),
  partition_name VARCHAR2(128),
  subpartition_name VARCHAR2(128),
  head_rowid ROWID,
  analyze_timestamp DATE
)
TABLESPACE tbs_lab4;

ANALYZE TABLE lab4pruebas.migra
LIST CHAINED ROWS INTO lab4pruebas.chained_rows;

SELECT COUNT(*) AS filas_listadas
FROM lab4pruebas.chained_rows;

PROMPT === 5. Muestra de filas detectadas y direccion de su cabeza ===
SELECT m.id, LENGTH(m.txt) AS longitud_txt,
       ROWIDTOCHAR(c.head_rowid) AS rowid_cabeza,
       DBMS_ROWID.ROWID_TO_ABSOLUTE_FNO(
         c.head_rowid, 'LAB4PRUEBAS', 'MIGRA'
       ) AS archivo,
       DBMS_ROWID.ROWID_BLOCK_NUMBER(c.head_rowid, 'BIGFILE') AS bloque,
       DBMS_ROWID.ROWID_ROW_NUMBER(c.head_rowid) AS ranura
FROM lab4pruebas.chained_rows c
JOIN lab4pruebas.migra m ON m.ROWID = c.head_rowid
ORDER BY m.id
FETCH FIRST 5 ROWS ONLY;

PROMPT === 6. Verificar filas totales y ampliadas ===
SELECT COUNT(*) AS filas_totales,
       SUM(CASE WHEN LENGTH(txt) = 300 THEN 1 ELSE 0 END) AS filas_ampliadas
FROM lab4pruebas.migra;

EXIT
