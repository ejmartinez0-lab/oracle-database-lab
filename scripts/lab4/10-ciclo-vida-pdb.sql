-- Lab 4 v3, I.4: usuarios y ciclo de vida de PDBLAB4.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 180 PAGESIZE 100 FEEDBACK ON VERIFY OFF TAB OFF
ALTER SESSION SET CONTAINER = CDB$ROOT;
SET SERVEROUTPUT ON SIZE UNLIMITED
COLUMN name FORMAT A18
COLUMN open_mode FORMAT A12
COLUMN username FORMAT A20
COLUMN archivo FORMAT A100
COLUMN network_name FORMAT A40

PROMPT === 1. Guardias: no reutilizar objetos existentes ===
DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM v$pdbs WHERE name = 'PDBLAB4';
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20030, 'PDBLAB4 ya existe. Se detiene.');
  END IF;
  SELECT COUNT(*) INTO n FROM cdb_users
  WHERE username IN ('LAB4LOCAL', 'C##LAB4COMUN');
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20031, 'Ya existen usuarios reservados para la prueba.');
  END IF;
END;
/

PROMPT === 2. Crear usuario sin C## en la raiz: ORA-65096 esperado ===
BEGIN
  BEGIN
    EXECUTE IMMEDIATE 'CREATE USER lab4local NO AUTHENTICATION';
  EXCEPTION WHEN OTHERS THEN
    IF SQLCODE = -65096 THEN
      DBMS_OUTPUT.PUT_LINE('ESPERADO: ' || SQLERRM);
      RETURN;
    ELSE
      RAISE;
    END IF;
  END;
  EXECUTE IMMEDIATE 'DROP USER lab4local';
  RAISE_APPLICATION_ERROR(-20032, 'No se rechazo el nombre sin prefijo. Revisar.');
END;
/

ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT === 3. Crear usuario C## dentro de la PDB: ORA-65094 esperado ===
BEGIN
  BEGIN
    EXECUTE IMMEDIATE 'CREATE USER c##lab4comun NO AUTHENTICATION';
  EXCEPTION WHEN OTHERS THEN
    IF SQLCODE = -65094 THEN
      DBMS_OUTPUT.PUT_LINE('ESPERADO: ' || SQLERRM);
      RETURN;
    ELSE
      RAISE;
    END IF;
  END;
  EXECUTE IMMEDIATE 'DROP USER c##lab4comun';
  RAISE_APPLICATION_ERROR(-20033, 'No se rechazo el nombre comun en la PDB.');
END;
/

PROMPT === 4. Usuario local correcto, sin autenticacion, y limpieza ===
CREATE USER lab4local NO AUTHENTICATION;
SELECT username, common, authentication_type
FROM dba_users WHERE username = 'LAB4LOCAL';
DROP USER lab4local;

ALTER SESSION SET CONTAINER = CDB$ROOT;
SET SERVEROUTPUT ON SIZE UNLIMITED

PROMPT === 5. Crear PDBLAB4 desde la semilla ===
DECLARE
  pwd VARCHAR2(30) := 'L4a' || DBMS_RANDOM.STRING('a', 18) || '29';
BEGIN
  EXECUTE IMMEDIATE
    'CREATE PLUGGABLE DATABASE pdblab4 ADMIN USER pdblab4admin IDENTIFIED BY "' ||
    pwd || '" FILE_NAME_CONVERT = (' ||
    '''/opt/oracle/oradata/FREE/pdbseed/'',' ||
    '''/opt/oracle/oradata/FREE/PDBLAB4/'')';
END;
/

SELECT con_id, name, open_mode FROM v$pdbs ORDER BY con_id;

PROMPT === 6. Abrir la PDB y mostrar archivos, servicio y usuario comun ===
ALTER PLUGGABLE DATABASE pdblab4 OPEN;

SELECT con_id, name, open_mode FROM v$pdbs ORDER BY con_id;

SELECT name AS archivo FROM v$datafile
WHERE con_id = (SELECT con_id FROM v$pdbs WHERE name = 'PDBLAB4');

SELECT con_id, name, network_name FROM v$services
WHERE con_id = (SELECT con_id FROM v$pdbs WHERE name = 'PDBLAB4');

SELECT con_id, username, common FROM cdb_users
WHERE username = 'C##OPS_RO'
AND con_id = (SELECT con_id FROM v$pdbs WHERE name = 'PDBLAB4');

PROMPT === 7. Intentar borrar la PDB abierta: ORA-65025 esperado ===
BEGIN
  BEGIN
    EXECUTE IMMEDIATE 'DROP PLUGGABLE DATABASE pdblab4 INCLUDING DATAFILES';
  EXCEPTION WHEN OTHERS THEN
    IF SQLCODE = -65025 THEN
      DBMS_OUTPUT.PUT_LINE('ESPERADO: ' || SQLERRM);
      RETURN;
    ELSE
      RAISE;
    END IF;
  END;
  RAISE_APPLICATION_ERROR(-20034, 'No se rechazo el borrado de la PDB abierta.');
END;
/

PROMPT === 8. Cerrar y eliminar solo PDBLAB4 con sus archivos ===
ALTER PLUGGABLE DATABASE pdblab4 CLOSE IMMEDIATE;
DROP PLUGGABLE DATABASE pdblab4 INCLUDING DATAFILES;

SELECT con_id, name, open_mode FROM v$pdbs ORDER BY con_id;

SELECT COUNT(*) AS pdb_prueba_restante
FROM v$pdbs WHERE name = 'PDBLAB4';

SELECT COUNT(*) AS usuarios_prueba_restantes
FROM cdb_users
WHERE username IN ('LAB4LOCAL', 'C##LAB4COMUN',
                   'LAB4ANALISTA', 'C##LAB4AUDITOR');

EXIT
