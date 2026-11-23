-- Lab 4 v3, G.3: literales frente a variables de enlace.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 180 PAGESIZE 100 FEEDBACK OFF VERIFY OFF TAB OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURSOR_SHARING = EXACT;
SET SERVEROUTPUT ON SIZE UNLIMITED FORMAT WRAPPED

PROMPT === 1. Contexto de la prueba ===
SELECT SYS_CONTEXT('USERENV', 'CON_NAME') AS contenedor,
       SYS_CONTEXT('USERENV', 'SESSION_USER') AS usuario
FROM dual;

PROMPT === 2. Mil consultas con literales frente a mil con bind ===
DECLARE
  v NUMBER;
  p0 NUMBER;
  h0 NUMBER;
  c0 NUMBER;
  t0 NUMBER;
  FUNCTION estad(p VARCHAR2) RETURN NUMBER IS
    x NUMBER;
  BEGIN
    SELECT m.value INTO x
    FROM v$mystat m
    JOIN v$statname s ON s.statistic# = m.statistic#
    WHERE s.name = p;
    RETURN x;
  END;
  PROCEDURE informe(modo VARCHAR2) IS
    p1 NUMBER;
    h1 NUMBER;
    c1 NUMBER;
    t1 NUMBER;
  BEGIN
    p1 := estad('parse count (total)');
    h1 := estad('parse count (hard)');
    c1 := estad('parse time cpu');
    t1 := DBMS_UTILITY.GET_TIME;
    DBMS_OUTPUT.PUT_LINE(
      RPAD(modo, 12) ||
      ' analisis totales=' || TO_CHAR(p1 - p0) ||
      ' duros=' || TO_CHAR(h1 - h0) ||
      ' CPU analisis=' || TO_CHAR((c1 - c0) * 10) || ' ms' ||
      ' tiempo total=' || TO_CHAR((t1 - t0) * 10) || ' ms'
    );
  END;
BEGIN
  p0 := estad('parse count (total)');
  h0 := estad('parse count (hard)');
  c0 := estad('parse time cpu');
  t0 := DBMS_UTILITY.GET_TIME;
  FOR i IN 1 .. 1000 LOOP
    EXECUTE IMMEDIATE
      'SELECT /* lab4_literal */ COUNT(*) FROM admin_academia.aca_estudiantes WHERE estudiante_id = ' || i
      INTO v;
  END LOOP;
  informe('LITERALES');
  p0 := estad('parse count (total)');
  h0 := estad('parse count (hard)');
  c0 := estad('parse time cpu');
  t0 := DBMS_UTILITY.GET_TIME;
  FOR i IN 1 .. 1000 LOOP
    EXECUTE IMMEDIATE
      'SELECT /* lab4_bind */ COUNT(*) FROM admin_academia.aca_estudiantes WHERE estudiante_id = :id'
      INTO v USING i;
  END LOOP;
  informe('BIND :id');
END;
/

PROMPT === 3. Cursores que permanecen en la shared pool ===
COLUMN etiqueta FORMAT A18
SELECT CASE
         WHEN sql_text LIKE 'SELECT /* lab4_literal */%' THEN 'LITERALES'
         ELSE 'BIND :id'
       END AS etiqueta,
       COUNT(*) AS cursores,
       SUM(executions) AS ejecuciones,
       ROUND(SUM(sharable_mem) / 1024, 1) AS kb_shared_pool
FROM v$sql
WHERE sql_text LIKE 'SELECT /* lab4_literal */%'
   OR sql_text LIKE 'SELECT /* lab4_bind */%'
GROUP BY CASE
           WHEN sql_text LIKE 'SELECT /* lab4_literal */%' THEN 'LITERALES'
           ELSE 'BIND :id'
         END
ORDER BY etiqueta;

EXIT
