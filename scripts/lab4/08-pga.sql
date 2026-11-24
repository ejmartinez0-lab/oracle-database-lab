-- Lab 4 v3, G.4: ordenacion en PGA frente a TEMP.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 180 PAGESIZE 100 FEEDBACK OFF VERIFY OFF TAB OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET WORKAREA_SIZE_POLICY = AUTO;
SET SERVEROUTPUT ON SIZE UNLIMITED FORMAT WRAPPED

PROMPT === 1. Ordenacion con PGA automatica y con area manual de 64 KB ===
DECLARE
  n NUMBER;
  m0 NUMBER;
  d0 NUMBER;
  t0 NUMBER;
  FUNCTION estad(p VARCHAR2) RETURN NUMBER IS
    x NUMBER;
  BEGIN
    SELECT m.value INTO x
    FROM v$mystat m JOIN v$statname s ON s.statistic# = m.statistic#
    WHERE s.name = p;
    RETURN x;
  END;
  PROCEDURE ordenar(etiqueta VARCHAR2) IS
    m1 NUMBER;
    d1 NUMBER;
    t1 NUMBER;
  BEGIN
    m0 := estad('sorts (memory)');
    d0 := estad('sorts (disk)');
    t0 := DBMS_UTILITY.GET_TIME;
    EXECUTE IMMEDIATE
      'SELECT /* ' || etiqueta || ' */ MAX(rn) FROM (' ||
      'SELECT ROW_NUMBER() OVER (ORDER BY m.fecha_matricula, m.matricula_id) rn ' ||
      'FROM admin_academia.aca_matriculas m)'
      INTO n;
    m1 := estad('sorts (memory)');
    d1 := estad('sorts (disk)');
    t1 := DBMS_UTILITY.GET_TIME;
    DBMS_OUTPUT.PUT_LINE(
      RPAD(etiqueta, 16) || ' filas ordenadas=' || n ||
      ' sorts memory=' || (m1 - m0) ||
      ' sorts disk=' || (d1 - d0) ||
      ' tiempo=' || ((t1 - t0) * 10) || ' ms'
    );
  END;
BEGIN
  ordenar('lab4_pga_auto');
  EXECUTE IMMEDIATE 'ALTER SESSION SET workarea_size_policy = MANUAL';
  EXECUTE IMMEDIATE 'ALTER SESSION SET sort_area_size = 65536';
  ordenar('lab4_pga_64k');
  EXECUTE IMMEDIATE 'ALTER SESSION SET workarea_size_policy = AUTO';
END;
/

PROMPT === 2. Areas de trabajo de las consultas medidas ===
COLUMN etiqueta FORMAT A18
COLUMN operation_type FORMAT A18
COLUMN policy FORMAT A8
COLUMN ultima FORMAT A15
SELECT CASE
         WHEN s.sql_text LIKE 'SELECT /* lab4_pga_auto */%' THEN 'PGA automatica'
         ELSE 'Manual 64 KB'
       END AS etiqueta,
       w.operation_type,
       w.policy,
       ROUND(w.estimated_optimal_size / 1024) AS kb_optimo,
       ROUND(w.last_memory_used / 1024) AS kb_usados,
       w.last_execution AS ultima,
       ROUND(NVL(w.last_tempseg_size, 0) / 1024) AS kb_en_temp
FROM v$sql_workarea w
JOIN v$sql s ON s.sql_id = w.sql_id
            AND s.child_number = w.child_number
WHERE s.sql_text LIKE 'SELECT /* lab4_pga_auto */%'
   OR s.sql_text LIKE 'SELECT /* lab4_pga_64k */%'
ORDER BY etiqueta, w.operation_id;

PROMPT === 3. Politica de sesion al finalizar ===
SELECT name, value FROM v$parameter
WHERE name = 'workarea_size_policy';

PROMPT === 4. PGA de toda la instancia desde la raiz ===
ALTER SESSION SET CONTAINER = CDB$ROOT;
COLUMN name FORMAT A40
COLUMN unidad FORMAT A12
SELECT name,
       ROUND(value / CASE WHEN unit = 'bytes' THEN 1048576 ELSE 1 END, 1) AS valor,
       CASE WHEN unit = 'bytes' THEN 'MB' ELSE unit END AS unidad
FROM v$pgastat
WHERE name IN (
  'aggregate PGA target parameter',
  'total PGA allocated',
  'maximum PGA allocated',
  'cache hit percentage',
  'over allocation count'
)
AND con_id = 0;

PROMPT === 5. Histograma acumulado de areas de trabajo ===
SELECT SUM(optimal_executions) AS optimas,
       SUM(onepass_executions) AS una_pasada,
       SUM(multipasses_executions) AS varias_pasadas
FROM v$sql_workarea_histogram
WHERE con_id = 0;

EXIT
