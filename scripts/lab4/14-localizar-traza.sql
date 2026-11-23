-- Diagnostico de la extraccion: reutiliza la traza ya generada.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 240 PAGESIZE 100 FEEDBACK ON VERIFY OFF TAB OFF
SET TRIMSPOOL ON
COLUMN payload FORMAT A200
DEFINE traza = FREE_ora_4035_lab4_migra_cabeza.trc

ALTER SESSION SET CONTAINER = FREEPDB1;

PROMPT === 1. Lineas visibles desde FREEPDB1, sin filtrar ADR_HOME ===
SELECT COUNT(*) AS lineas_visibles
FROM v$diag_trace_file_contents
WHERE trace_filename = '&traza';

ALTER SESSION SET CONTAINER = CDB$ROOT;

PROMPT === 2. Lineas visibles desde CDB$ROOT ===
SELECT COUNT(*) AS lineas_visibles
FROM v$diag_trace_file_contents
WHERE trace_filename = '&traza';

PROMPT === 3. Primeras lineas para comprobar el contenido ===
SELECT line_number, payload
FROM v$diag_trace_file_contents
WHERE trace_filename = '&traza'
ORDER BY line_number
FETCH FIRST 15 ROWS ONLY;

PROMPT === 4. Buscar la ranura 4 con tolerancia a espacios ===
WITH contenido AS (
  SELECT line_number AS n, payload
  FROM v$diag_trace_file_contents
  WHERE trace_filename = '&traza'
),
coincidencias AS (
  SELECT n
  FROM contenido
  WHERE REGEXP_LIKE(
    payload,
    'tab[[:space:]]+0,[[:space:]]*row[[:space:]]+4,'
  )
)
SELECT t.n AS linea, t.payload
FROM contenido t
WHERE EXISTS (
  SELECT 1 FROM coincidencias c
  WHERE t.n BETWEEN c.n AND c.n + 4
)
ORDER BY t.n;

PROMPT === 5. Si no aparece la ranura, mostrar marcadores del volcado ===
SELECT line_number, payload
FROM v$diag_trace_file_contents
WHERE trace_filename = '&traza'
  AND (
    INSTR(payload, 'block_row_dump') > 0
    OR INSTR(payload, 'Block dump') > 0
    OR INSTR(payload, 'nrid:') > 0
  )
ORDER BY line_number
FETCH FIRST 12 ROWS ONLY;

EXIT
