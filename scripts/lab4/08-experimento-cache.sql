WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 180 PAGESIZE 100 FEEDBACK OFF
COLUMN table_name FORMAT A22
COLUMN object_name FORMAT A22

ALTER SESSION SET CONTAINER=FREEPDB1;
SET SERVEROUTPUT ON

PROMPT === 1. Estadisticas de la tabla ===
SELECT table_name, num_rows, blocks, avg_row_len
FROM dba_tables
WHERE owner='ADMIN_ACADEMIA'
AND table_name='ACA_ESTUDIANTES';

PROMPT === 2. Vaciar Buffer Cache: solo laboratorio ===
ALTER SYSTEM FLUSH BUFFER_CACHE;

PROMPT === 3. Misma consulta: dos rondas ===
DECLARE
  FUNCTION estad(p_nombre VARCHAR2) RETURN NUMBER IS
    v NUMBER;
  BEGIN
    SELECT m.value INTO v
    FROM v$mystat m
    JOIN v$statname n ON n.statistic#=m.statistic#
    WHERE n.name=p_nombre;
    RETURN v;
  END;

  PROCEDURE ronda(p_titulo VARCHAR2) IS
    l0 NUMBER := estad('session logical reads');
    f0 NUMBER := estad('physical reads');
    filas NUMBER;
    logicas NUMBER;
    fisicas NUMBER;
  BEGIN
    SELECT /*+ FULL(e) */ COUNT(*) INTO filas
    FROM admin_academia.aca_estudiantes e
    WHERE estado='ACTIVO';

    logicas := estad('session logical reads') - l0;
    fisicas := estad('physical reads') - f0;

    DBMS_OUTPUT.PUT_LINE(
      p_titulo ||
      ' | filas ACTIVO=' || filas ||
      ' | logicas=' || logicas ||
      ' | fisicas=' || fisicas
    );

    IF logicas > 0 THEN
      DBMS_OUTPUT.PUT_LINE(
        'Tasa de acierto estimada (%)=' ||
        ROUND(100 * (1 - fisicas/logicas), 2)
      );
    END IF;
  END;
BEGIN
  ronda('Ronda 1: cache fria');
  ronda('Ronda 2: cache caliente');
END;
/

PROMPT === 4. Bloques de la tabla presentes en cache ===
SELECT o.object_name, COUNT(*) AS bloques_en_cache
FROM v$bh b
JOIN dba_objects o ON o.data_object_id=b.objd
WHERE o.owner='ADMIN_ACADEMIA'
AND o.object_name='ACA_ESTUDIANTES'
AND b.status <> 'free'
GROUP BY o.object_name;

EXIT
