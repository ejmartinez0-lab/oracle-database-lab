-- Lab 4 v3, J.1: permiso puntual de lectura del alert log.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 170 PAGESIZE 100 FEEDBACK ON VERIFY OFF
ALTER SESSION SET CONTAINER = CDB$ROOT;

GRANT SELECT ON sys.v_$diag_alert_ext
TO c##ops_ro CONTAINER=ALL;

COLUMN grantee FORMAT A18
COLUMN owner FORMAT A10
COLUMN table_name FORMAT A25
COLUMN privilege FORMAT A12

SELECT grantee, owner, table_name, privilege, common
FROM dba_tab_privs
WHERE grantee = 'C##OPS_RO'
  AND owner = 'SYS'
  AND table_name = 'V_$DIAG_ALERT_EXT';

EXIT
