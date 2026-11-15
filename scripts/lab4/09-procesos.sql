@scripts/ops/marca.sql
SPOOL docs/bitacora/lab4/evidencia/spool/&marca._09-procesos.spool.log

SET SQLFORMAT DEFAULT
SET LINESIZE 220 PAGESIZE 100 FEEDBACK OFF
COLUMN tipo FORMAT A12
COLUMN pname FORMAT A8
COLUMN spid FORMAT A12
COLUMN description FORMAT A48
COLUMN username FORMAT A16
COLUMN machine FORMAT A24
COLUMN program FORMAT A38

PROMPT === 1. Procesos Oracle y procesos Linux distintos ===
SELECT CASE WHEN background='1' THEN 'background'
            ELSE 'servidor' END AS tipo,
       COUNT(*) AS procesos_oracle,
       COUNT(DISTINCT spid) AS procesos_linux
FROM v$process
WHERE spid IS NOT NULL
GROUP BY CASE WHEN background='1' THEN 'background'
              ELSE 'servidor' END;

PROMPT === 2. Procesos de background y sus funciones ===
SELECT b.name AS pname, p.spid, b.description
FROM v$bgprocess b
JOIN v$process p ON p.addr=b.paddr
WHERE b.name IN (
  'PMON','LREG','SMON','DBW0','LGWR','CKPT','MMON','MMNL',
  'RECO','CJQ0','DIAG','DIA0','VKTM','PMAN','CLMN','PSP0',
  'MMAN','ARC0','ARC1','ARC2','ARC3'
)
ORDER BY b.name;

PROMPT === 3. Modo de archivado y archivadores activos ===
SELECT log_mode FROM v$database;
SELECT COUNT(*) AS procesos_arcn
FROM v$process
WHERE pname LIKE 'ARC%' AND spid IS NOT NULL;

PROMPT === 4. Mi sesion y su proceso servidor ===
SELECT s.sid, s.serial#, s.username, s.machine, s.program, p.spid
FROM v$session s
JOIN v$process p ON p.addr=s.paddr
WHERE s.sid=TO_NUMBER(SYS_CONTEXT('USERENV','SID'));

PROMPT === 5. Sesiones de usuario ===
SELECT s.sid, s.username, s.status, s.machine, s.program, p.spid
FROM v$session s
JOIN v$process p ON p.addr=s.paddr
WHERE s.type='USER'
ORDER BY s.sid;

PROMPT === 6. SPID de LGWR para el siguiente paso ===
SELECT pname, spid FROM v$process WHERE pname='LGWR';

SPOOL OFF
