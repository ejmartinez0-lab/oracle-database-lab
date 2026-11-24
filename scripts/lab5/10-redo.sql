-- Parte K: adaptacion para conservar el numero real de grupos.
-- No se ejecuta el intento de dejar un unico grupo del ejemplo de dos grupos.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 240 PAGESIZE 100 FEEDBACK ON VERIFY OFF
ALTER SESSION SET CONTAINER = CDB$ROOT;
SET SERVEROUTPUT ON SIZE UNLIMITED
COLUMN member FORMAT A95
COLUMN status FORMAT A12
COLUMN grupos_iniciales NEW_VALUE grupos_iniciales NOPRINT

SELECT COUNT(*) AS grupos_iniciales FROM v$log;

PROMPT === 1. ESTADO INICIAL ===
SELECT group#, thread#, sequence#, bytes / 1048576 AS mb,
       members, archived, status
FROM v$log ORDER BY group#;

SELECT group#, member, type, status
FROM v$logfile ORDER BY group#, member;

PROMPT === 2. SEGUNDO MIEMBRO EN GRUPOS CON UNO SOLO ===
DECLARE
  ruta VARCHAR2(1000);
  nueva VARCHAR2(1000);
  n NUMBER := 0;
BEGIN
  FOR g IN (SELECT group# FROM v$log WHERE members = 1 ORDER BY group#) LOOP
    SELECT MIN(member) INTO ruta FROM v$logfile
     WHERE group# = g.group# AND type = 'ONLINE';

    IF ruta IS NULL OR NOT REGEXP_LIKE(ruta, '\.log$') THEN
      RAISE_APPLICATION_ERROR(-20020, 'Ruta de redo inesperada: ' || ruta);
    END IF;

    nueva := REGEXP_REPLACE(ruta, '\.log$', 'b.log');

    EXECUTE IMMEDIATE
      'ALTER DATABASE ADD LOGFILE MEMBER ''' ||
      REPLACE(nueva, '''', '''''') || ''' TO GROUP ' || g.group#;

    DBMS_OUTPUT.PUT_LINE('Grupo ' || g.group# || ': segundo miembro ' || nueva);
    n := n + 1;
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('Miembros incorporados: ' || n);
END;
/

PROMPT === 3. RECORRIDO DE LOS GRUPOS CON CAMBIOS DE LOG ===
DECLARE
  n NUMBER;
  grupo NUMBER;
  secuencia NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM v$log;
  FOR i IN 1 .. n LOOP
    EXECUTE IMMEDIATE 'ALTER SYSTEM SWITCH LOGFILE';
    SELECT group#, sequence# INTO grupo, secuencia
      FROM v$log WHERE status = 'CURRENT';
    DBMS_OUTPUT.PUT_LINE('Cambio ' || i ||
      ': CURRENT=' || grupo || ' secuencia=' || secuencia);
  END LOOP;
END;
/

SELECT group#, member, status FROM v$logfile ORDER BY group#, member;

PROMPT === 4. PROTECCIONES DEL GRUPO CURRENT ===
DECLARE
  grupo NUMBER;
  miembro VARCHAR2(1000);
  PROCEDURE rechazar(sentencia VARCHAR2, esperado NUMBER, etiqueta VARCHAR2) IS
  BEGIN
    BEGIN
      EXECUTE IMMEDIATE sentencia;
    EXCEPTION WHEN OTHERS THEN
      IF SQLCODE = esperado THEN
        DBMS_OUTPUT.PUT_LINE('OK esperado: ' || etiqueta || ' -> ' || SQLERRM);
        RETURN;
      ELSE
        RAISE;
      END IF;
    END;
    RAISE_APPLICATION_ERROR(-20020,
      'La operacion no fue rechazada: ' || etiqueta);
  END;
BEGIN
  SELECT group# INTO grupo FROM v$log WHERE status = 'CURRENT';
  SELECT MIN(member) INTO miembro FROM v$logfile
   WHERE group# = grupo AND type = 'ONLINE';

  rechazar(
    'ALTER DATABASE DROP LOGFILE GROUP ' || grupo,
    -1623, 'borrar grupo CURRENT'
  );
  rechazar(
    'ALTER DATABASE DROP LOGFILE MEMBER ''' ||
      REPLACE(miembro, '''', '''''') || '''',
    -1609, 'borrar miembro de CURRENT'
  );
  DBMS_OUTPUT.PUT_LINE(
    'OMITIDO: intento de dejar un unico grupo. No se elimina ningun grupo no CURRENT.'
  );
END;
/

PROMPT === 5. HISTORIAL Y DATOS PARA DIMENSIONAR ===
SELECT sequence#, first_change#,
       TO_CHAR(first_time, 'YYYY-MM-DD HH24:MI:SS') AS inicio
FROM v$log_history ORDER BY first_time DESC FETCH FIRST 10 ROWS ONLY;

PROMPT Historial por hora de la base; incluye toda la actividad, no solo TiendaSur.
SELECT TO_CHAR(first_time, 'YYYY-MM-DD HH24') AS hora_base,
       COUNT(*) AS cambios
FROM v$log_history
WHERE first_time >= TRUNC(SYSDATE) - 1
GROUP BY TO_CHAR(first_time, 'YYYY-MM-DD HH24')
ORDER BY hora_base;

PROMPT === 6. VERIFICACION FINAL ===
DECLARE
  n NUMBER;
  modo VARCHAR2(30);
BEGIN
  SELECT COUNT(*) INTO n FROM v$log;
  IF n <> &grupos_iniciales OR n < 2 THEN
    RAISE_APPLICATION_ERROR(-20020, 'Cambio inesperado en el numero de grupos');
  END IF;

  SELECT COUNT(*) INTO n FROM v$log WHERE members < 2;
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20020, 'Quedan grupos con menos de dos miembros');
  END IF;

  SELECT COUNT(*) INTO n FROM v$log l
   WHERE l.members <> (
     SELECT COUNT(*) FROM v$logfile f
      WHERE f.group# = l.group# AND f.type = 'ONLINE'
   );
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20020, 'Recuento de miembros inconsistente');
  END IF;

  SELECT COUNT(*) INTO n FROM v$logfile
   WHERE type = 'ONLINE' AND status IS NOT NULL;
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20020, 'Hay miembros con estado no normal; revisar');
  END IF;

  SELECT open_mode INTO modo FROM v$database;
  IF modo <> 'READ WRITE' THEN
    RAISE_APPLICATION_ERROR(-20020, 'CDB no esta en READ WRITE');
  END IF;

  SELECT COUNT(*) INTO n FROM v$pdbs
   WHERE name = 'FREEPDB1' AND open_mode = 'READ WRITE';
  IF n <> 1 THEN
    RAISE_APPLICATION_ERROR(-20020, 'FREEPDB1 no esta en READ WRITE');
  END IF;

  DBMS_OUTPUT.PUT_LINE('OK: numero inicial de grupos conservado');
  DBMS_OUTPUT.PUT_LINE('OK: todos los grupos tienen al menos dos miembros');
  DBMS_OUTPUT.PUT_LINE('OK: miembros sin estado anomalo y base disponible');
END;
/

SELECT group#, sequence#, bytes / 1048576 AS mb, members, archived, status
FROM v$log ORDER BY group#;
SELECT group#, member, status FROM v$logfile ORDER BY group#, member;

PROMPT PARTE_K_VERIFICADA_OK
EXIT SUCCESS
