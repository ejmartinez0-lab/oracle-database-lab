WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 220 PAGESIZE 100 FEEDBACK ON VERIFY OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON SIZE UNLIMITED FORMAT WRAPPED

PROMPT === RETO: CONSULTA ORIGINAL, SIN INDICES ADICIONALES ===
EXEC lab_tools.medir.consulta('F_reto_original', q'[SELECT * FROM tiendasur.cliente WHERE SUBSTR(telefono, 1, 3) = '600' OR UPPER(apellidos) = 'GIL']')

PROMPT === SELECTIVIDAD DE CADA RAMA ===
SELECT COUNT(*) AS total_clientes,
       SUM(CASE WHEN SUBSTR(telefono, 1, 3) = '600' THEN 1 ELSE 0 END) AS prefijo_600,
       SUM(CASE WHEN UPPER(apellidos) = 'GIL' THEN 1 ELSE 0 END) AS apellido_exacto_gil
FROM tiendasur.cliente;

PROMPT === INDICES TEMPORALES PARA LAS DOS RAMAS DEL OR ===
CREATE INDEX tiendasur.ix_cli_telefono ON tiendasur.cliente(telefono);
CREATE INDEX tiendasur.ix_f_upper_apellidos ON tiendasur.cliente(UPPER(apellidos));

PROMPT === CONSULTA REESCRITA, CON INDICES DISPONIBLES ===
PROMPT Se mantiene la igualdad exacta del apellido; no se sustituye por un prefijo.
EXEC lab_tools.medir.consulta('F_reto_reescrita', q'[SELECT * FROM tiendasur.cliente WHERE telefono LIKE '600%' OR UPPER(apellidos) = 'GIL']')

PROMPT === COMPROBACION DE EQUIVALENCIA EN AMBOS SENTIDOS ===
DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM (
    SELECT id_cliente FROM tiendasur.cliente
    WHERE SUBSTR(telefono, 1, 3) = '600' OR UPPER(apellidos) = 'GIL'
    MINUS
    SELECT id_cliente FROM tiendasur.cliente
    WHERE telefono LIKE '600%' OR UPPER(apellidos) = 'GIL'
  );
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20015, 'La reescritura pierde filas');
  END IF;

  SELECT COUNT(*) INTO n FROM (
    SELECT id_cliente FROM tiendasur.cliente
    WHERE telefono LIKE '600%' OR UPPER(apellidos) = 'GIL'
    MINUS
    SELECT id_cliente FROM tiendasur.cliente
    WHERE SUBSTR(telefono, 1, 3) = '600' OR UPPER(apellidos) = 'GIL'
  );
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20015, 'La reescritura agrega filas');
  END IF;

  DBMS_OUTPUT.PUT_LINE('OK: mismos identificadores en ambas consultas');
END;
/

PROMPT === COSTE DE ESPACIO DE LOS INDICES DEL RETO ===
SELECT segment_name, ROUND(bytes / 1048576, 2) AS mb_asignados
FROM dba_segments
WHERE owner = 'TIENDASUR'
  AND segment_name IN ('IX_CLI_TELEFONO', 'IX_F_UPPER_APELLIDOS')
ORDER BY segment_name;

DROP INDEX tiendasur.ix_cli_telefono;
DROP INDEX tiendasur.ix_f_upper_apellidos;

PROMPT === VERIFICACION FINAL ===
DECLARE
  n NUMBER;
  PROCEDURE comprobar(ok BOOLEAN, mensaje VARCHAR2) IS
  BEGIN
    IF ok THEN
      DBMS_OUTPUT.PUT_LINE('OK: ' || mensaje);
    ELSE
      RAISE_APPLICATION_ERROR(-20015, mensaje);
    END IF;
  END;
BEGIN
  SELECT COUNT(*) INTO n FROM tiendasur.cliente;
  comprobar(n = 100000, 'CLIENTE conserva 100000 filas');

  SELECT COUNT(*) INTO n FROM tiendasur.pedido;
  comprobar(n = 1000000, 'PEDIDO conserva 1000000 filas');

  SELECT COUNT(*) INTO n FROM dba_indexes WHERE owner = 'TIENDASUR';
  comprobar(n = 7, 'Solo quedan siete indices');

  SELECT COUNT(*) INTO n FROM dba_indexes
   WHERE owner = 'TIENDASUR'
     AND status = 'VALID' AND visibility = 'VISIBLE'
     AND index_name IN (
       'PK_CLIENTE', 'UX_CLI_EMAIL', 'IX_CLI_PAIS_CIUDAD',
       'PK_PEDIDO', 'IX_PED_CLIENTE', 'IX_PED_FECHA', 'IX_PED_IMPORTE'
     );
  comprobar(n = 7, 'Son los siete indices iniciales, validos y visibles');

  SELECT COUNT(*) INTO n FROM dba_tables WHERE owner = 'TIENDASUR';
  comprobar(n = 2, 'Solo quedan las dos tablas originales');

  SELECT COUNT(*) INTO n FROM dba_constraints
   WHERE owner = 'TIENDASUR' AND constraint_name = 'FK_PED_CLIENTE'
     AND status = 'ENABLED' AND validated = 'VALIDATED';
  comprobar(n = 1, 'Clave ajena habilitada y validada');

  SELECT COUNT(*) INTO n FROM dba_objects
   WHERE owner = 'LAB_TOOLS' AND object_name = 'MEDIR'
     AND object_type IN ('PACKAGE', 'PACKAGE BODY') AND status = 'VALID';
  comprobar(n = 2, 'Paquete MEDIR valido');
END;
/
PROMPT PARTE_F_VERIFICADA_OK
EXIT SUCCESS
