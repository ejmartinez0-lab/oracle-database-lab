-- Diagnostico del resultado vacio del reto de literales.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 200 PAGESIZE 100 FEEDBACK ON VERIFY OFF TAB OFF
ALTER SESSION SET CONTAINER = FREEPDB1;

COLUMN etiqueta FORMAT A12
COLUMN firma FORMAT A22
COLUMN ejemplo FORMAT A95 WORD_WRAPPED

PROMPT === 1. Cursores del experimento agrupados por firma, incluido cero ===
SELECT CASE
         WHEN sql_text LIKE 'SELECT /* lab4_literal */%' THEN 'LITERALES'
         ELSE 'BIND'
       END AS etiqueta,
       TO_CHAR(force_matching_signature) AS firma,
       COUNT(DISTINCT sql_id) AS textos_distintos,
       COUNT(*) AS cursores_hijos,
       SUM(executions) AS ejecuciones
FROM v$sql
WHERE sql_text LIKE 'SELECT /* lab4_literal */%'
   OR sql_text LIKE 'SELECT /* lab4_bind */%'
GROUP BY CASE
           WHEN sql_text LIKE 'SELECT /* lab4_literal */%' THEN 'LITERALES'
           ELSE 'BIND'
         END,
         force_matching_signature
ORDER BY etiqueta, textos_distintos DESC
FETCH FIRST 15 ROWS ONLY;

PROMPT === 2. Muestra de cinco cursores con literales ===
SELECT sql_id,
       child_number,
       TO_CHAR(force_matching_signature) AS firma,
       SUBSTR(sql_text, 1, 95) AS ejemplo
FROM v$sql
WHERE sql_text LIKE 'SELECT /* lab4_literal */%'
ORDER BY sql_id, child_number
FETCH FIRST 5 ROWS ONLY;

EXIT
