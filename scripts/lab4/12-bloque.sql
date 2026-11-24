-- Lab 4 v3: ocupacion del segmento y volcado del bloque de la fila 101.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 200 PAGESIZE 100 FEEDBACK OFF VERIFY OFF TAB OFF
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT === 1. Ocupacion del segmento mediante ASSM ===
DECLARE
  unf NUMBER; unf_b NUMBER;
  fs1 NUMBER; fs1_b NUMBER;
  fs2 NUMBER; fs2_b NUMBER;
  fs3 NUMBER; fs3_b NUMBER;
  fs4 NUMBER; fs4_b NUMBER;
  llenos NUMBER; llenos_b NUMBER;
BEGIN
  DBMS_SPACE.SPACE_USAGE(
    'ADMIN_ACADEMIA', 'ACA_ESTUDIANTES', 'TABLE',
    unf, unf_b, fs1, fs1_b, fs2, fs2_b,
    fs3, fs3_b, fs4, fs4_b, llenos, llenos_b
  );
  DBMS_OUTPUT.PUT_LINE('FULL: ' || llenos);
  DBMS_OUTPUT.PUT_LINE('FS1, 0-25% libre: ' || fs1);
  DBMS_OUTPUT.PUT_LINE('FS2, 25-50% libre: ' || fs2);
  DBMS_OUTPUT.PUT_LINE('FS3, 50-75% libre: ' || fs3);
  DBMS_OUTPUT.PUT_LINE('FS4, 75-100% libre: ' || fs4);
  DBMS_OUTPUT.PUT_LINE('Sin formatear: ' || unf);
END;
/

PROMPT === 2. Obtener archivo, bloque y ranura actuales ===
COLUMN f NEW_VALUE f NOPRINT
COLUMN b NEW_VALUE b NOPRINT
COLUMN s NEW_VALUE s NOPRINT
SELECT TO_CHAR(DBMS_ROWID.ROWID_TO_ABSOLUTE_FNO(
         e.ROWID, 'ADMIN_ACADEMIA', 'ACA_ESTUDIANTES'),
         'FM9999999990') AS f,
       TO_CHAR(DBMS_ROWID.ROWID_BLOCK_NUMBER(e.ROWID, 'BIGFILE'),
         'FM9999999990') AS b,
       TO_CHAR(DBMS_ROWID.ROWID_ROW_NUMBER(e.ROWID),
         'FM9999999990') AS s
FROM admin_academia.aca_estudiantes e
WHERE estudiante_id = 101;

PROMPT ARCHIVO_LAB4=&f
PROMPT BLOQUE_LAB4=&b
PROMPT RANURA_LAB4=&s

PROMPT === 3. Generar volcado del bloque ===
ALTER SESSION SET tracefile_identifier = 'lab4bloque';
ALTER SYSTEM DUMP DATAFILE &f BLOCK &b;

SET HEADING OFF PAGESIZE 0 LINESIZE 1000
SELECT 'TRAZA_LAB4=' || value
FROM v$diag_info
WHERE name = 'Default Trace File';

EXIT
