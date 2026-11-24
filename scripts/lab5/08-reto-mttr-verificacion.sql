WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 220 PAGESIZE 100 FEEDBACK ON VERIFY OFF
ALTER SESSION SET CONTAINER = CDB$ROOT;

PROMPT === RETO MTTR: FOTO INICIAL DESDE LA RAIZ ===
COLUMN mttr_antes NEW_VALUE mttr_antes NOPRINT
COLUMN redo_antes NEW_VALUE redo_antes NOPRINT
SELECT estimated_mttr AS mttr_antes,
       actual_redo_blks AS redo_antes
FROM v$instance_recovery;

PROMPT === UPDATE DE 20000 FILAS SIN CAMBIAR EL VALOR ===
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON SIZE UNLIMITED
DECLARE
  n NUMBER;
BEGIN
  UPDATE admin_academia.aca_estudiantes SET estado = estado;
  n := SQL%ROWCOUNT;
  IF n <> 20000 THEN
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20018, 'Se esperaban 20000 estudiantes; hay ' || n);
  END IF;
  COMMIT;
  DBMS_OUTPUT.PUT_LINE('OK: 20000 filas actualizadas sin cambiar su estado');
END;
/

ALTER SESSION SET CONTAINER = CDB$ROOT;
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT === FOTO POSTERIOR: SIN CHECKPOINT EXPLICITO ENTRE FOTOS ===
SELECT &mttr_antes AS mttr_antes_s,
       estimated_mttr AS mttr_despues_s,
       estimated_mttr - &mttr_antes AS diferencia_mttr_s,
       &redo_antes AS redo_antes_bloques,
       actual_redo_blks AS redo_despues_bloques,
       actual_redo_blks - &redo_antes AS diferencia_redo_bloques
FROM v$instance_recovery;

PROMPT === VERIFICACION DE DISPONIBILIDAD Y AVANCE DEL SCN ===
DECLARE
  scn1 NUMBER;
  scn2 NUMBER;
  modo VARCHAR2(30);
  n NUMBER;
BEGIN
  SELECT open_mode, current_scn INTO modo, scn1 FROM v$database;
  IF modo <> 'READ WRITE' THEN
    RAISE_APPLICATION_ERROR(-20018, 'CDB no esta en READ WRITE');
  END IF;

  DBMS_SESSION.SLEEP(3);
  SELECT current_scn INTO scn2 FROM v$database;
  IF scn2 <= scn1 THEN
    RAISE_APPLICATION_ERROR(-20018, 'No se ha observado avance del SCN');
  END IF;

  DBMS_OUTPUT.PUT_LINE('OK: SCN inicial=' || scn1 || ' posterior=' || scn2);

  SELECT COUNT(*) INTO n FROM v$pdbs
   WHERE name = 'FREEPDB1' AND open_mode = 'READ WRITE';
  IF n <> 1 THEN
    RAISE_APPLICATION_ERROR(-20018, 'FREEPDB1 no esta en READ WRITE');
  END IF;

  SELECT COUNT(*) INTO n FROM v$datafile_header WHERE error IS NOT NULL;
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20018, 'Hay errores al leer cabeceras de datafiles');
  END IF;

  DBMS_OUTPUT.PUT_LINE('OK: CDB y PDB abiertas; cabeceras legibles sin errores');
END;
/

PROMPT === COMPARACION ACTUAL DE CHECKPOINTS POR ARCHIVO ===
COLUMN archivo FORMAT A80
SELECT d.file#, d.con_id, d.name AS archivo,
       d.checkpoint_change# AS scn_controlfile,
       h.checkpoint_change# AS scn_cabecera,
       h.recover, h.fuzzy
FROM v$datafile d
JOIN v$datafile_header h
  ON h.file# = d.file# AND h.con_id = d.con_id
ORDER BY d.file#;

PROMPT PARTE_I_VERIFICADA_OK
EXIT SUCCESS
