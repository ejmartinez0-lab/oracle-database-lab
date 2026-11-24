WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 200 PAGESIZE 100 FEEDBACK ON VERIFY OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON SIZE UNLIMITED FORMAT WRAPPED

PROMPT === RETO: ALTURA PREVISTA PARA UX_CLI_EMAIL ===
PROMPT Modelo: 30 bytes por entrada de hoja, PCTFREE 10 y fo maximo de IX_PED_CLIENTE.

ANALYZE INDEX tiendasur.ix_ped_cliente VALIDATE STRUCTURE;

DECLARE
  s index_stats%ROWTYPE;
  fo NUMBER;
  capacidad NUMBER;
  hojas NUMBER;
  altura NUMBER;
BEGIN
  SELECT * INTO s FROM index_stats;
  fo := FLOOR(s.br_blk_len / (s.br_rows_len / s.br_rows));
  capacidad := FLOOR(s.lf_blk_len / 30);
  hojas := CEIL(100000 / (capacidad * 0.9));
  altura := 1 + CEIL(LN(hojas) / LN(fo));

  DBMS_OUTPUT.PUT_LINE('Factor maximo de ramificacion: ' || fo);
  DBMS_OUTPUT.PUT_LINE('Capacidad teorica por hoja: ' || capacidad);
  DBMS_OUTPUT.PUT_LINE('Hojas previstas al 90%: ' || hojas);
  DBMS_OUTPUT.PUT_LINE('Altura prevista UX_CLI_EMAIL: ' || altura);
END;
/

PROMPT === CONTRASTE CON LA ESTRUCTURA REAL ===
ANALYZE INDEX tiendasur.ux_cli_email VALIDATE STRUCTURE;

SELECT name, height, lf_rows, lf_blks,
       ROUND(lf_rows / NULLIF(lf_blks, 0), 2) AS entradas_por_hoja,
       ROUND(lf_rows_len / NULLIF(lf_rows, 0), 2) AS bytes_por_entrada,
       pct_used
FROM index_stats;

DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM index_stats
   WHERE name = 'UX_CLI_EMAIL' AND lf_rows = 100000 AND height >= 1;
  IF n <> 1 THEN
    RAISE_APPLICATION_ERROR(-20012, 'Estructura de UX_CLI_EMAIL no verificada');
  END IF;
END;
/

PROMPT === COMPARACION CON PK_CLIENTE ===
SELECT index_name, blevel + 1 AS altura, leaf_blocks, num_rows
FROM dba_indexes
WHERE owner = 'TIENDASUR'
  AND index_name IN ('PK_CLIENTE', 'UX_CLI_EMAIL')
ORDER BY index_name;

PROMPT === MEDICION VISIBLE DE LA BUSQUEDA POR PK ===
EXEC lab_tools.medir.consulta('parte_C_pk', 'SELECT id_pedido, importe FROM tiendasur.pedido WHERE id_pedido = 4711')

PROMPT PARTE_C_RETO_OK
EXIT SUCCESS
