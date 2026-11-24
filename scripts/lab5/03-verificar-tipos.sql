WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 220 PAGESIZE 100 FEEDBACK ON VERIFY OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON SIZE UNLIMITED FORMAT WRAPPED

PROMPT === ESTADO FINAL DEL BANCO ===
DECLARE
  n NUMBER;
  PROCEDURE comprobar(ok BOOLEAN, mensaje VARCHAR2) IS
  BEGIN
    IF ok THEN
      DBMS_OUTPUT.PUT_LINE('OK: ' || mensaje);
    ELSE
      RAISE_APPLICATION_ERROR(-20013, mensaje);
    END IF;
  END;
BEGIN
  SELECT COUNT(*) INTO n FROM tiendasur.cliente;
  comprobar(n = 100000, 'CLIENTE conserva 100000 filas');

  SELECT COUNT(*) INTO n FROM tiendasur.pedido;
  comprobar(n = 1000000, 'PEDIDO conserva 1000000 filas');

  SELECT COUNT(*) INTO n FROM dba_indexes
   WHERE owner = 'TIENDASUR';
  comprobar(n = 7, 'Solo quedan siete indices en TIENDASUR');

  SELECT COUNT(*) INTO n FROM dba_indexes
   WHERE owner = 'TIENDASUR'
     AND status = 'VALID' AND visibility = 'VISIBLE'
     AND index_name IN (
       'PK_CLIENTE', 'UX_CLI_EMAIL', 'IX_CLI_PAIS_CIUDAD',
       'PK_PEDIDO', 'IX_PED_CLIENTE', 'IX_PED_FECHA', 'IX_PED_IMPORTE'
     );
  comprobar(n = 7, 'Los siete indices son los originales, validos y visibles');

  SELECT COUNT(*) INTO n FROM dba_tables
   WHERE owner = 'TIENDASUR';
  comprobar(n = 2, 'Solo quedan las dos tablas originales');

  SELECT COUNT(*) INTO n FROM dba_clusters
   WHERE owner = 'TIENDASUR';
  comprobar(n = 0, 'Sin clusters de prueba');

  SELECT COUNT(*) INTO n FROM dba_tab_cols
   WHERE owner = 'TIENDASUR' AND table_name = 'PEDIDO'
     AND column_name = 'FECHA_PENDIENTE';
  comprobar(n = 0, 'Columna virtual temporal eliminada');

  SELECT COUNT(*) INTO n FROM dba_constraints
   WHERE owner = 'TIENDASUR'
     AND constraint_name = 'FK_PED_CLIENTE'
     AND status = 'ENABLED' AND validated = 'VALIDATED';
  comprobar(n = 1, 'Clave ajena habilitada y validada');

  SELECT COUNT(*) INTO n FROM dba_objects
   WHERE owner = 'LAB_TOOLS' AND object_name = 'MEDIR'
     AND object_type IN ('PACKAGE', 'PACKAGE BODY')
     AND status = 'VALID';
  comprobar(n = 2, 'Herramienta MEDIR valida');
END;
/

PROMPT === RETO Q9: LOS 20 PEDIDOS MAS RECIENTES ===
EXEC lab_tools.medir.consulta('D_Q9_actual', 'SELECT * FROM tiendasur.pedido ORDER BY fecha_pedido DESC FETCH FIRST 20 ROWS ONLY')

PROMPT === TAMANOS PARA JUSTIFICAR LA DECISION DE Q9 ===
SELECT segment_name, segment_type,
       ROUND(SUM(bytes) / 1048576, 2) AS mb_asignados
FROM dba_segments
WHERE owner = 'TIENDASUR'
  AND segment_name IN ('PEDIDO', 'IX_PED_FECHA')
GROUP BY segment_name, segment_type
ORDER BY segment_name;

SELECT index_name, blevel + 1 AS altura, leaf_blocks, num_rows
FROM dba_indexes
WHERE owner = 'TIENDASUR' AND table_name = 'PEDIDO'
ORDER BY index_name;

PROMPT PARTE_D_VERIFICADA_OK
EXIT SUCCESS
