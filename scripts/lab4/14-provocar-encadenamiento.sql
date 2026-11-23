-- Lab 4 v3, Parte M: fila grande que no cabe en un bloque.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 180 PAGESIZE 100 FEEDBACK ON VERIFY OFF TAB OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
COLUMN table_name FORMAT A20

PROMPT === 1. Comprobar bloque de 8 KiB y ausencia de objetos ===
DECLARE
  b NUMBER;
  n NUMBER;
BEGIN
  SELECT block_size INTO b
  FROM dba_tablespaces
  WHERE tablespace_name = 'TBS_LAB4';
  IF b <> 8192 THEN
    RAISE_APPLICATION_ERROR(-20053, 'El experimento requiere bloques de 8192 bytes.');
  END IF;
  SELECT COUNT(*) INTO n
  FROM dba_objects
  WHERE owner = 'LAB4PRUEBAS'
    AND object_name IN ('ANCHA', 'CHAINED_ROWS_ANCHA');
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20054, 'Ya existen objetos de encadenamiento. No se han modificado.');
  END IF;
END;
/

PROMPT === 2. Crear una fila grande y una corta ===
CREATE TABLE lab4pruebas.ancha (
  id NUMBER,
  a VARCHAR2(4000 BYTE),
  b VARCHAR2(4000 BYTE),
  c VARCHAR2(4000 BYTE)
)
TABLESPACE tbs_lab4;

INSERT INTO lab4pruebas.ancha (id, a, b, c)
VALUES (1, RPAD('a', 4000, 'a'),
           RPAD('b', 4000, 'b'),
           RPAD('c', 4000, 'c'));

INSERT INTO lab4pruebas.ancha (id, a, b, c)
VALUES (2, 'corta', NULL, NULL);

COMMIT;

SELECT id,
       NVL(LENGTHB(a), 0) + NVL(LENGTHB(b), 0) +
       NVL(LENGTHB(c), 0) AS bytes_texto
FROM lab4pruebas.ancha
ORDER BY id;

PROMPT === 3. Obtener CHAIN_CNT ===
ANALYZE TABLE lab4pruebas.ancha COMPUTE STATISTICS;

SELECT table_name, num_rows, blocks, avg_row_len, chain_cnt
FROM dba_tables
WHERE owner = 'LAB4PRUEBAS' AND table_name = 'ANCHA';

PROMPT === 4. Identificar la fila encadenada sin tocar la lista de MIGRA ===
CREATE TABLE lab4pruebas.chained_rows_ancha (
  owner_name VARCHAR2(128),
  table_name VARCHAR2(128),
  cluster_name VARCHAR2(128),
  partition_name VARCHAR2(128),
  subpartition_name VARCHAR2(128),
  head_rowid ROWID,
  analyze_timestamp DATE
)
TABLESPACE tbs_lab4;

ANALYZE TABLE lab4pruebas.ancha
LIST CHAINED ROWS INTO lab4pruebas.chained_rows_ancha;

SELECT a.id,
       ROWIDTOCHAR(c.head_rowid) AS rowid_cabeza
FROM lab4pruebas.chained_rows_ancha c
JOIN lab4pruebas.ancha a ON a.ROWID = c.head_rowid
ORDER BY a.id;

PROMPT === 5. Conservar el estado de MIGRA antes de su reparacion ===
SELECT table_name, num_rows, blocks, chain_cnt
FROM dba_tables
WHERE owner = 'LAB4PRUEBAS'
  AND table_name IN ('MIGRA', 'ANCHA')
ORDER BY table_name;

EXIT
