-- Cuenta comun de observabilidad. Ejecutar en CDB$ROOT.
SET ECHO OFF VERIFY OFF FEEDBACK ON
WHENEVER SQLERROR EXIT FAILURE

DECLARE
  v_existe NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_existe
  FROM dba_users
  WHERE username = 'C##OPS_RO';

  IF v_existe = 0 THEN
    EXECUTE IMMEDIATE
      'CREATE USER c##ops_ro IDENTIFIED BY "&ops_pwd" CONTAINER=ALL';
  ELSE
    EXECUTE IMMEDIATE
      'ALTER USER c##ops_ro IDENTIFIED BY "&ops_pwd" CONTAINER=ALL';
  END IF;
END;
/

UNDEFINE ops_pwd

GRANT CREATE SESSION, SET CONTAINER TO c##ops_ro CONTAINER=ALL;
GRANT SELECT_CATALOG_ROLE TO c##ops_ro CONTAINER=ALL;
ALTER USER c##ops_ro SET CONTAINER_DATA=ALL CONTAINER=CURRENT;

PROMPT === Verificacion de la cuenta comun ===
SET LINESIZE 150 PAGESIZE 50
COLUMN username FORMAT A16
COLUMN contenedor FORMAT A16
COLUMN account_status FORMAT A20

SELECT u.con_id, c.name AS contenedor,
       u.username, u.common, u.account_status
FROM cdb_users u
JOIN v$containers c ON c.con_id = u.con_id
WHERE u.username = 'C##OPS_RO'
ORDER BY u.con_id;

EXIT
