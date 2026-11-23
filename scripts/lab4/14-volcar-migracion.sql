-- Lab 4 v3, Parte M: inspeccionar la cabeza de la fila id=5.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 220 PAGESIZE 100 FEEDBACK ON VERIFY OFF TAB OFF
SET TRIMSPOOL ON
ALTER SESSION SET CONTAINER = FREEPDB1;

COLUMN archivo NEW_VALUE archivo NOPRINT
COLUMN bloque NEW_VALUE bloque NOPRINT
COLUMN ranura NEW_VALUE ranura NOPRINT
COLUMN traza NEW_VALUE traza NOPRINT
COLUMN rowid_cabeza FORMAT A20
COLUMN ruta_traza FORMAT A160
COLUMN payload FORMAT A200

PROMPT === 1. Comprobar que id=5 sigue en la lista de diagnostico ===
DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n
  FROM lab4pruebas.migra m
  JOIN lab4pruebas.chained_rows c ON c.head_rowid = m.ROWID
  WHERE m.id = 5;
  IF n <> 1 THEN
    RAISE_APPLICATION_ERROR(-20052, 'id=5 no tiene una unica cabeza en el diagnostico.');
  END IF;
END;
/

SELECT DBMS_ROWID.ROWID_TO_ABSOLUTE_FNO(
         m.ROWID, 'LAB4PRUEBAS', 'MIGRA'
       ) AS archivo,
       DBMS_ROWID.ROWID_BLOCK_NUMBER(m.ROWID, 'BIGFILE') AS bloque,
       DBMS_ROWID.ROWID_ROW_NUMBER(m.ROWID) AS ranura
FROM lab4pruebas.migra m
WHERE m.id = 5;

SELECT id, ROWIDTOCHAR(ROWID) AS rowid_cabeza,
       LENGTH(txt) AS longitud_txt,
       &archivo AS archivo, &bloque AS bloque, &ranura AS ranura
FROM lab4pruebas.migra
WHERE id = 5;

PROMPT === 2. Generar el volcado del bloque de la cabeza ===
ALTER SESSION SET tracefile_identifier = 'lab4_migra_cabeza';
ALTER SYSTEM CHECKPOINT;
ALTER SYSTEM DUMP DATAFILE &archivo BLOCK &bloque;

SELECT value AS ruta_traza
FROM v$diag_info
WHERE name = 'Default Trace File';

SELECT SUBSTR(value, INSTR(value, '/', -1) + 1) AS traza
FROM v$diag_info
WHERE name = 'Default Trace File';

PROMPT === 3. Extraer la ranura de id=5 y sus lineas siguientes ===
WITH contenido AS (
  SELECT line_number AS n, payload
  FROM v$diag_trace_file_contents
  WHERE trace_filename = '&traza'
    AND adr_home = (
      SELECT value FROM v$diag_info WHERE name = 'ADR Home'
    )
),
cabeza AS (
  SELECT MIN(n) AS inicio
  FROM contenido
  WHERE payload LIKE 'tab 0, row &ranura,%'
)
SELECT t.n AS linea, t.payload
FROM contenido t
CROSS JOIN cabeza c
WHERE t.n BETWEEN c.inicio AND c.inicio + 3
ORDER BY t.n;

PROMPT === 4. Confirmar que no se ha reorganizado la tabla ===
SELECT num_rows, blocks, chain_cnt
FROM dba_tables
WHERE owner = 'LAB4PRUEBAS' AND table_name = 'MIGRA';

EXIT
