WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 220 PAGESIZE 100 FEEDBACK ON VERIFY OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON SIZE UNLIMITED

DECLARE
  n NUMBER;
  lista VARCHAR2(1000);
  PROCEDURE comprobar(ok BOOLEAN, mensaje VARCHAR2) IS
  BEGIN
    IF ok THEN
      DBMS_OUTPUT.PUT_LINE('OK: ' || mensaje);
    ELSE
      RAISE_APPLICATION_ERROR(-20016, mensaje);
    END IF;
  END;
BEGIN
  SELECT COUNT(*) INTO n FROM tiendasur.cliente;
  comprobar(n = 100000, 'CLIENTE conserva 100000 filas');

  SELECT COUNT(*) INTO n FROM tiendasur.pedido;
  comprobar(n = 1000000, 'PEDIDO conserva 1000000 filas');

  SELECT LISTAGG(index_name, ',') WITHIN GROUP (ORDER BY index_name)
    INTO lista
    FROM dba_indexes
   WHERE owner = 'TIENDASUR' AND table_name = 'PEDIDO';
  comprobar(
    lista = 'IX_PED_CLI_FEC_CUB,IX_PED_CP,IX_PED_FECHA,IX_PED_PENDIENTES,PK_PEDIDO',
    'PEDIDO tiene exactamente los cinco indices de V005'
  );

  SELECT COUNT(*) INTO n FROM dba_indexes WHERE owner = 'TIENDASUR';
  comprobar(n = 9, 'Nueve indices totales: cuatro en CLIENTE y cinco en PEDIDO');

  SELECT COUNT(*) INTO n FROM dba_indexes
   WHERE owner = 'TIENDASUR'
     AND (status <> 'VALID' OR visibility <> 'VISIBLE');
  comprobar(n = 0, 'Todos los indices validos y visibles');

  SELECT COUNT(*) INTO n FROM dba_indexes
   WHERE owner = 'TIENDASUR' AND index_name = 'UX_CLI_DNI'
     AND table_name = 'CLIENTE' AND uniqueness = 'UNIQUE';
  comprobar(n = 1, 'DNI protegido por indice unico');

  SELECT LISTAGG(column_name, ',') WITHIN GROUP (ORDER BY column_position)
    INTO lista FROM dba_ind_columns
   WHERE index_owner = 'TIENDASUR' AND index_name = 'UX_CLI_DNI';
  comprobar(lista = 'DNI', 'El indice unico corresponde a DNI');

  SELECT LISTAGG(column_name, ',') WITHIN GROUP (ORDER BY column_position)
    INTO lista FROM dba_ind_columns
   WHERE index_owner = 'TIENDASUR' AND index_name = 'IX_PED_CLI_FEC_CUB';
  comprobar(
    lista = 'ID_CLIENTE,FECHA_PEDIDO,IMPORTE,ESTADO,ID_PEDIDO',
    'Cubriente correcto, con ID_CLIENTE como primera columna'
  );

  SELECT COUNT(*) INTO n FROM dba_constraints
   WHERE owner = 'TIENDASUR' AND constraint_name = 'FK_PED_CLIENTE'
     AND status = 'ENABLED' AND validated = 'VALIDATED';
  comprobar(n = 1, 'Clave ajena habilitada y validada');

  SELECT COUNT(*) INTO n FROM dba_tab_cols
   WHERE owner = 'TIENDASUR' AND table_name = 'PEDIDO'
     AND column_name = 'FECHA_PENDIENTE' AND virtual_column = 'YES';
  comprobar(n = 1, 'Columna virtual FECHA_PENDIENTE presente');

  SELECT COUNT(*) INTO n FROM tiendasur.pedido
   WHERE fecha_pendiente IS NOT NULL;
  comprobar(n = 20000, 'Columna parcial con 20000 valores no nulos');

  SELECT COUNT(*) INTO n FROM tiendasur.pedido
   WHERE (estado = 'P' AND
          (fecha_pendiente IS NULL OR fecha_pendiente <> fecha_pedido))
      OR (estado <> 'P' AND fecha_pendiente IS NOT NULL);
  comprobar(n = 0, 'Columna virtual coherente con estado y fecha');

  SELECT COUNT(*) INTO n FROM dba_tables WHERE owner = 'TIENDASUR';
  comprobar(n = 2, 'Sin tablas adicionales de prueba');

  SELECT COUNT(*) INTO n FROM dba_objects
   WHERE owner = 'LAB_TOOLS' AND object_name = 'MEDIR'
     AND object_type IN ('PACKAGE', 'PACKAGE BODY') AND status = 'VALID';
  comprobar(n = 2, 'Paquete MEDIR valido');
END;
/

SELECT table_name, index_name, uniqueness, status, visibility
FROM dba_indexes
WHERE owner = 'TIENDASUR'
ORDER BY table_name, index_name;

PROMPT PARTE_G_VERIFICADA_OK
EXIT SUCCESS
