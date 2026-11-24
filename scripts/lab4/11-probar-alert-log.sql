-- Prueba real de acceso como C##OPS_RO.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET SQLFORMAT DEFAULT
SET LINESIZE 180 PAGESIZE 100 FEEDBACK ON VERIFY OFF TAB OFF
COLUMN usuario FORMAT A18
COLUMN contenedor FORMAT A18
COLUMN cuando FORMAT A19
COLUMN mensaje FORMAT A130 WORD_WRAPPED

SELECT SYS_CONTEXT('USERENV', 'SESSION_USER') AS usuario,
       SYS_CONTEXT('USERENV', 'CON_NAME') AS contenedor
FROM dual;

PROMPT === Ultimos ocho mensajes visibles del alert log ===
SELECT TO_CHAR(originating_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS cuando,
       REPLACE(message_text, CHR(10), ' ') AS mensaje
FROM v$diag_alert_ext
WHERE con_id IN (0, 1)
ORDER BY originating_timestamp DESC
FETCH FIRST 8 ROWS ONLY;

EXIT
