-- Lab 4 v3, Parte L: coste medido de distintas lecturas.
-- SOLO LABORATORIO: vacia la cache de buffers de Oracle.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 200 PAGESIZE 100 FEEDBACK ON VERIFY OFF TAB OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
  v VARCHAR2(60);
  n NUMBER;
  lr0 NUMBER; lr1 NUMBER;
  pr0 NUMBER; pr1 NUMBER;
  rq0 NUMBER; rq1 NUMBER;
  mb0 NUMBER; mb1 NUMBER;
  cpu0 NUMBER; cpu1 NUMBER;
  t0 TIMESTAMP;
  us_aleat NUMBER; us_secu NUMBER;
  lat_us NUMBER;
  bfr NUMBER;
  bloques NUMBER;
  filas NUMBER;
  tam_bloque NUMBER;
  FUNCTION estad(p VARCHAR2) RETURN NUMBER IS
    x NUMBER;
  BEGIN
    SELECT m.value INTO x
    FROM v$mystat m JOIN v$statname s ON s.statistic# = m.statistic#
    WHERE s.name = p;
    RETURN x;
  END;
  FUNCTION micros(t TIMESTAMP) RETURN NUMBER IS
    d INTERVAL DAY(3) TO SECOND(6) := SYSTIMESTAMP - t;
  BEGIN
    RETURN EXTRACT(DAY FROM d) * 86400e6
         + EXTRACT(HOUR FROM d) * 3600e6
         + EXTRACT(MINUTE FROM d) * 60e6
         + EXTRACT(SECOND FROM d) * 1e6;
  END;
BEGIN
  SELECT t.blocks, t.num_rows, ts.block_size
  INTO bloques, filas, tam_bloque
  FROM dba_tables t
  JOIN dba_tablespaces ts ON ts.tablespace_name = t.tablespace_name
  WHERE t.owner = 'LAB4PRUEBAS' AND t.table_name = 'LECTURAS';
  bfr := filas / bloques;

  DBMS_OUTPUT.PUT_LINE('=== 1. Lectura logica: calentamiento y 100000 busquedas ===');
  FOR i IN 1 .. 2000 LOOP
    SELECT relleno INTO v FROM lab4pruebas.lecturas
    WHERE id = i * 200;
  END LOOP;
  lr0 := estad('session logical reads');
  pr0 := estad('physical reads');
  cpu0 := DBMS_UTILITY.GET_CPU_TIME;
  FOR i IN 1 .. 100000 LOOP
    SELECT relleno INTO v FROM lab4pruebas.lecturas
    WHERE id = MOD(i, 2000) * 200 + 200;
  END LOOP;
  cpu1 := DBMS_UTILITY.GET_CPU_TIME;
  lr1 := estad('session logical reads') - lr0;
  pr1 := estad('physical reads') - pr0;
  DBMS_OUTPUT.PUT_LINE('Lecturas logicas=' || lr1 ||
    '; por busqueda=' || ROUND(lr1 / 100000, 3) ||
    '; fisicas=' || pr1);
  DBMS_OUTPUT.PUT_LINE('CPU=' || ((cpu1 - cpu0) * 10) ||
    ' ms; CPU/lectura logica=' ||
    ROUND((cpu1 - cpu0) * 10000 / NULLIF(lr1, 0), 3) || ' us');

  DBMS_OUTPUT.PUT_LINE('=== 2. Cache vacia: 2000 busquedas repartidas por PK ===');
  EXECUTE IMMEDIATE 'ALTER SYSTEM FLUSH BUFFER_CACHE';
  pr0 := estad('physical reads');
  t0 := SYSTIMESTAMP;
  FOR i IN 1 .. 2000 LOOP
    SELECT relleno INTO v FROM lab4pruebas.lecturas
    WHERE id = i * 197;
  END LOOP;
  us_aleat := micros(t0);
  pr1 := estad('physical reads') - pr0;
  lat_us := us_aleat / NULLIF(pr1, 0);
  DBMS_OUTPUT.PUT_LINE('Lecturas fisicas=' || pr1 ||
    '; tiempo=' || ROUND(us_aleat / 1000, 3) || ' ms' ||
    '; tiempo/lectura=' || ROUND(lat_us, 3) || ' us');

  DBMS_OUTPUT.PUT_LINE('=== 3. Cache vacia: recorrido completo de la tabla ===');
  EXECUTE IMMEDIATE 'ALTER SYSTEM FLUSH BUFFER_CACHE';
  pr0 := estad('physical reads');
  rq0 := estad('physical read total IO requests');
  mb0 := estad('physical read total multi block requests');
  t0 := SYSTIMESTAMP;
  SELECT /*+ FULL(t) NO_PARALLEL(t) */ COUNT(*) INTO n
  FROM lab4pruebas.lecturas t WHERE relleno IS NOT NULL;
  us_secu := micros(t0);
  pr1 := estad('physical reads') - pr0;
  rq1 := estad('physical read total IO requests') - rq0;
  mb1 := estad('physical read total multi block requests') - mb0;
  DBMS_OUTPUT.PUT_LINE('Filas=' || n || '; bloques fisicos=' || pr1 ||
    '; peticiones=' || rq1 || '; peticiones multibloque=' || mb1);
  DBMS_OUTPUT.PUT_LINE('Bloques/peticion=' ||
    ROUND(pr1 / NULLIF(rq1, 0), 3) ||
    '; tiempo=' || ROUND(us_secu / 1000, 3) || ' ms');
  DBMS_OUTPUT.PUT_LINE('Caudal aproximado=' ||
    ROUND(pr1 * tam_bloque / 1048576 / NULLIF(us_secu, 0) * 1e6, 3) ||
    ' MiB/s; tiempo/bloque=' ||
    ROUND(us_secu / NULLIF(pr1, 0), 3) || ' us');

  DBMS_OUTPUT.PUT_LINE('=== 4. Modelo aproximado y limites de la medida ===');
  DBMS_OUTPUT.PUT_LINE('Bloques estadisticos=' || bloques ||
    '; filas=' || filas || '; bfr estadistico=' || ROUND(bfr, 3));
  DBMS_OUTPUT.PUT_LINE('Tiempo aleatorio estimado para ' || pr1 ||
    ' bloques=' || ROUND(pr1 * lat_us / 1000, 3) || ' ms');
  DBMS_OUTPUT.PUT_LINE('Cociente coste secuencial/aleatorio por bloque=' ||
    ROUND(us_secu / NULLIF(pr1, 0) / NULLIF(lat_us, 0), 5));
  DBMS_OUTPUT.PUT_LINE('Umbral orientativo con CF malo=' ||
    ROUND(100 * us_secu / NULLIF(pr1, 0) / NULLIF(lat_us, 0)
      / NULLIF(bfr, 0), 5) || ' %');
  DBMS_OUTPUT.PUT_LINE('FLUSH BUFFER_CACHE no vacia la cache de paginas de Linux.');
  DBMS_OUTPUT.PUT_LINE('Las medidas incluyen CPU y trabajo adicional de la sesion.');
END;
/

EXIT
