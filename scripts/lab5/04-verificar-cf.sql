WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 200 PAGESIZE 100 FEEDBACK ON VERIFY OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
  calculado NUMBER;
  diccionario NUMBER;
  n NUMBER;
BEGIN
  FOR r IN (
    SELECT 'IX_PED_FECHA' AS indice, 'FECHA_PEDIDO' AS columna FROM dual
    UNION ALL
    SELECT 'IX_PED_CLIENTE', 'ID_CLIENTE' FROM dual
  ) LOOP
    EXECUTE IMMEDIATE
      'SELECT SUM(cambia) FROM (' ||
      'SELECT CASE WHEN ' ||
      'DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID, ''BIGFILE'') = ' ||
      'LAG(DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID, ''BIGFILE'')) ' ||
      'OVER (ORDER BY ' || r.columna || ', ROWID) ' ||
      'THEN 0 ELSE 1 END AS cambia FROM tiendasur.pedido)'
      INTO calculado;

    SELECT clustering_factor INTO diccionario FROM dba_indexes
    WHERE owner = 'TIENDASUR' AND index_name = r.indice
      AND status = 'VALID' AND visibility = 'VISIBLE';

    IF calculado <> diccionario THEN
      RAISE_APPLICATION_ERROR(-20014, 'CF no coincide: ' || r.indice);
    END IF;

    DBMS_OUTPUT.PUT_LINE('OK: ' || r.indice ||
      ' CF calculado=' || calculado || ' diccionario=' || diccionario);
  END LOOP;

  SELECT COUNT(*) INTO n FROM tiendasur.pedido;
  IF n <> 1000000 THEN
    RAISE_APPLICATION_ERROR(-20014, 'Recuento de PEDIDO incorrecto');
  END IF;

  SELECT COUNT(*) INTO n FROM dba_indexes
  WHERE owner = 'TIENDASUR';
  IF n <> 7 THEN
    RAISE_APPLICATION_ERROR(-20014, 'No quedan siete indices iniciales');
  END IF;

  DBMS_OUTPUT.PUT_LINE('OK: PEDIDO conserva un millon de filas y siete indices en TIENDASUR');
END;
/
PROMPT PARTE_E_VERIFICADA_OK
EXIT SUCCESS
