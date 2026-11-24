WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET SERVEROUTPUT ON LINESIZE 200 PAGESIZE 100 FEEDBACK ON VERIFY OFF
ALTER SESSION SET CONTAINER = FREEPDB1;

DECLARE
  n NUMBER;
  PROCEDURE comprobar(ok BOOLEAN, mensaje VARCHAR2) IS
  BEGIN
    IF ok THEN
      DBMS_OUTPUT.PUT_LINE('OK: ' || mensaje);
    ELSE
      RAISE_APPLICATION_ERROR(-20011, mensaje);
    END IF;
  END;
BEGIN
  SELECT COUNT(*) INTO n FROM tiendasur.cliente;
  comprobar(n = 100000, 'CLIENTE: 100000 filas');

  SELECT COUNT(*) INTO n FROM tiendasur.pedido;
  comprobar(n = 1000000, 'PEDIDO: 1000000 filas');

  SELECT COUNT(*) INTO n FROM tiendasur.pedido WHERE estado = 'P';
  comprobar(n = 20000, 'Pedidos pendientes: 20000');

  SELECT COUNT(*) INTO n FROM tiendasur.pedido WHERE estado = 'E';
  comprobar(n = 50000, 'Pedidos enviados: 50000');

  SELECT COUNT(*) INTO n FROM tiendasur.cliente WHERE ciudad = 'Lorca';
  comprobar(n = 100, 'Clientes de Lorca: 100');

  SELECT COUNT(*) INTO n
    FROM tiendasur.pedido p
   WHERE NOT EXISTS (
     SELECT 1 FROM tiendasur.cliente c
      WHERE c.id_cliente = p.id_cliente
   );
  comprobar(n = 0, 'Sin pedidos huerfanos');

  SELECT COUNT(*) INTO n FROM dba_users
   WHERE username IN ('TIENDASUR', 'LAB_TOOLS')
     AND authentication_type = 'NONE';
  comprobar(n = 2, 'Esquemas TIENDASUR y LAB_TOOLS sin autenticacion');

  SELECT COUNT(*) INTO n FROM dba_indexes
   WHERE owner = 'TIENDASUR'
     AND status = 'VALID'
     AND visibility = 'VISIBLE'
     AND index_name IN (
       'PK_CLIENTE', 'UX_CLI_EMAIL', 'IX_CLI_PAIS_CIUDAD',
       'PK_PEDIDO', 'IX_PED_CLIENTE', 'IX_PED_FECHA', 'IX_PED_IMPORTE'
     );
  comprobar(n = 7, 'Siete indices iniciales validos y visibles');

  SELECT COUNT(*) INTO n FROM dba_constraints
   WHERE owner = 'TIENDASUR'
     AND constraint_name IN (
       'PK_CLIENTE', 'PK_PEDIDO', 'FK_PED_CLIENTE', 'CK_PED_ESTADO'
     )
     AND status = 'ENABLED'
     AND validated = 'VALIDATED';
  comprobar(n = 4, 'PK, FK y CHECK habilitadas y validadas');

  SELECT COUNT(*) INTO n FROM dba_objects
   WHERE owner = 'LAB_TOOLS'
     AND object_name = 'MEDIR'
     AND object_type IN ('PACKAGE', 'PACKAGE BODY')
     AND status = 'VALID';
  comprobar(n = 2, 'Paquete MEDIR y cuerpo validos');

  SELECT COUNT(*) INTO n FROM dba_errors
   WHERE owner = 'LAB_TOOLS' AND name = 'MEDIR'
     AND attribute = 'ERROR';
  comprobar(n = 0, 'MEDIR sin errores de compilacion');

  SELECT COUNT(*) INTO n FROM dba_tab_col_statistics
   WHERE owner = 'TIENDASUR' AND table_name = 'PEDIDO'
     AND column_name = 'ESTADO' AND histogram <> 'NONE';
  comprobar(n = 1, 'Histograma de ESTADO disponible');

  SELECT COUNT(*) INTO n FROM dba_tablespaces
   WHERE tablespace_name = 'TBS_TIENDASUR' AND bigfile = 'YES';
  comprobar(n = 1, 'Tablespace TiendaSur BIGFILE');

  SELECT COUNT(*) INTO n FROM dba_data_files
   WHERE tablespace_name = 'TBS_TIENDASUR'
     AND file_name = '/opt/oracle/oradata/FREE/FREEPDB1/tiendasur01.dbf';
  comprobar(n = 1, 'Datafile en la ruta prevista del volumen');
END;
/

PROMPT === PRUEBA FUNCIONAL DE LA HERRAMIENTA ===
EXEC lab_tools.medir.consulta('verificacion_B_pk', 'SELECT id_pedido, importe FROM tiendasur.pedido WHERE id_pedido = 4711')

PROMPT === FILAS REALES POR BLOQUE DE PEDIDO ===
SELECT MIN(filas) AS minimo,
       ROUND(AVG(filas), 2) AS media,
       MAX(filas) AS maximo,
       COUNT(*) AS bloques_con_filas
FROM (
  SELECT DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID, 'BIGFILE') AS bloque,
         COUNT(*) AS filas
  FROM tiendasur.pedido
  GROUP BY DBMS_ROWID.ROWID_BLOCK_NUMBER(ROWID, 'BIGFILE')
);

SELECT num_rows, blocks,
       ROUND(num_rows / NULLIF(blocks, 0), 2) AS filas_por_bloque_estadisticas
FROM dba_tables
WHERE owner = 'TIENDASUR' AND table_name = 'PEDIDO';

PROMPT PARTE_B_VERIFICADA_OK
EXIT SUCCESS
