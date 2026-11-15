-- Invalida las contrasenas expuestas en V000.
-- Los propietarios conservan sus objetos, pero no pueden iniciar sesion.
WHENEVER SQLERROR EXIT FAILURE
SET VERIFY OFF FEEDBACK ON
ALTER SESSION SET CONTAINER = FREEPDB1;

ALTER USER admin_academia NO AUTHENTICATION;
ALTER USER admin_clinica NO AUTHENTICATION;
ALTER USER admin_retail NO AUTHENTICATION;
ALTER USER admin_logistica NO AUTHENTICATION;
ALTER USER admin_fintech NO AUTHENTICATION;

SET LINESIZE 140 PAGESIZE 50
COLUMN username FORMAT A22
COLUMN authentication_type FORMAT A22
COLUMN account_status FORMAT A20

SELECT username, authentication_type, account_status
FROM dba_users
WHERE username IN (
  'ADMIN_ACADEMIA', 'ADMIN_CLINICA', 'ADMIN_RETAIL',
  'ADMIN_LOGISTICA', 'ADMIN_FINTECH'
)
ORDER BY username;

EXIT
