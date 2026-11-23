-- Lab 4 v3, Parte M: coste de busquedas en filas migradas.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 180 PAGESIZE 100 FEEDBACK ON VERIFY OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT === 1. Estado previo del indice ===
SELECT index_name, status, blevel
FROM dba_indexes
WHERE owner = 'LAB4PRUEBAS' AND index_name = 'PK_MIGRA';

PROMPT === 2. Comparar 1000 busquedas por grupo ===
DECLARE
  v VARCHAR2(400);
  id_busqueda NUMBER;
  l0 NUMBER;
  l1 NUMBER;
  c0 NUMBER;
  c1 NUMBER;
  p0 NUMBER;
  p1 NUMBER;
  etiqueta VARCHAR2(80);
  FUNCTION estad(p_nombre VARCHAR2) RETURN NUMBER IS
    x NUMBER;
  BEGIN
    SELECT m.value INTO x
    FROM v$mystat m
    JOIN v$statname s ON s.statistic# = m.statistic#
    WHERE s.name = p_nombre;
    RETURN x;
  END;
BEGIN
  FOR grupo IN 1 .. 3 LOOP
    etiqueta := CASE grupo
      WHEN 1 THEN 'No ampliadas: ids 1, 6, ..., 4996'
      WHEN 2 THEN 'Ampliadas: ids 5, 10, ..., 5000'
      ELSE 'Mixtas: ids 1 a 1000'
    END;
    FOR pasada IN 1 .. 2 LOOP
      IF pasada = 2 THEN
        p0 := estad('physical reads');
        c0 := estad('table fetch continued row');
        l0 := estad('session logical reads');
      END IF;
      FOR i IN 1 .. 1000 LOOP
        id_busqueda := CASE grupo
          WHEN 1 THEN (i - 1) * 5 + 1
          WHEN 2 THEN i * 5
          ELSE i
        END;
        SELECT /*+ INDEX(m PK_MIGRA) */ m.txt INTO v
        FROM lab4pruebas.migra m
        WHERE m.id = id_busqueda;
      END LOOP;
      IF pasada = 2 THEN
        l1 := estad('session logical reads');
        c1 := estad('table fetch continued row');
        p1 := estad('physical reads');
        DBMS_OUTPUT.PUT_LINE(etiqueta);
        DBMS_OUTPUT.PUT_LINE(
          '  Lecturas logicas=' || (l1 - l0) ||
          '; por busqueda=' || ROUND((l1 - l0) / 1000, 3));
        DBMS_OUTPUT.PUT_LINE(
          '  table fetch continued row=' || (c1 - c0) ||
          '; lecturas fisicas=' || (p1 - p0));
      END IF;
    END LOOP;
  END LOOP;
END;
/

PROMPT === 3. Confirmar que se conserva el diagnostico ===
SELECT num_rows, blocks, chain_cnt
FROM dba_tables
WHERE owner = 'LAB4PRUEBAS' AND table_name = 'MIGRA';

EXIT
