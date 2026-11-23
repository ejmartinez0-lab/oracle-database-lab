-- Lab 4 v3: detectar familias de SQL con muchos literales.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 200 PAGESIZE 100 FEEDBACK ON VERIFY OFF TAB OFF
ALTER SESSION SET CONTAINER = FREEPDB1;

COLUMN firma FORMAT A22
COLUMN ejemplo FORMAT A85 WORD_WRAPPED

PROMPT === Familias con mas de 50 textos SQL distintos ===
SELECT TO_CHAR(force_matching_signature) AS firma,
       COUNT(DISTINCT sql_id) AS textos_distintos,
       COUNT(*) AS cursores_hijos,
       SUM(executions) AS ejecuciones,
       ROUND(SUM(sharable_mem) / 1024, 1) AS kb_shared_pool,
       MIN(SUBSTR(sql_text, 1, 85)) AS ejemplo
FROM v$sql
WHERE force_matching_signature <> 0
GROUP BY force_matching_signature
HAVING COUNT(DISTINCT sql_id) > 50
ORDER BY textos_distintos DESC;

EXIT
