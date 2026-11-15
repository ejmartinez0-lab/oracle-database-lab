WHENEVER SQLERROR EXIT FAILURE
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 400 TRIMOUT ON

SELECT 'cdb|' || REPLACE(open_mode,' ','') FROM v$database;
SELECT 'pdb|' || REPLACE(open_mode,'','')
FROM v$pdbs WHERE name='FREEPDB1';
SELECT 'open_cursors|' || value
FROM v$parameter WHERE name='open_cursors';
SELECT 'db_files_spfile|' || isspecified
FROM v$spparameter WHERE name='db_files' AND sid='*';
SELECT 'ops_ro|' || common
FROM cdb_users WHERE username='C##OPS_RO' AND con_id=1;

ALTER SESSION SET CONTAINER=FREEPDB1;

SELECT 'tbs|' || COUNT(*)
FROM dba_tablespaces WHERE tablespace_name LIKE 'TBS\_%' ESCAPE '\';

SELECT 'fuera_carpeta|' || COUNT(*)
FROM dba_data_files
WHERE tablespace_name LIKE 'TBS\_%' ESCAPE '\'
AND file_name NOT LIKE '/opt/oracle/oradata/FREE/FREEPDB1/%';

SELECT 'tbs_online|' || COUNT(*)
FROM dba_tablespaces
WHERE tablespace_name LIKE 'TBS\_%' ESCAPE '\' AND status='ONLINE';

SELECT 'sin_auth|' || COUNT(*)
FROM dba_users
WHERE username IN (
 'ADMIN_ACADEMIA','ADMIN_CLINICA','ADMIN_FINTECH',
 'ADMIN_LOGISTICA','ADMIN_RETAIL'
) AND authentication_type='NONE';

SELECT 'v002|' ||
 (SELECT COUNT(*) FROM admin_academia.aca_estudiantes) || '/' ||
 (SELECT COUNT(*) FROM admin_academia.aca_asignaturas) || '/' ||
 (SELECT COUNT(*) FROM admin_academia.aca_matriculas)
FROM dual;

SELECT 'pdb_cursors|' || value
FROM v$parameter WHERE name='open_cursors';

EXIT
