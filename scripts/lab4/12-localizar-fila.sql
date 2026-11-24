-- Lab 4 v3, K.1-K.3: almacenamiento y direccion fisica de la fila 101.
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET LINESIZE 200 PAGESIZE 100 FEEDBACK ON VERIFY OFF TAB OFF
ALTER SESSION SET CONTAINER = FREEPDB1;

COLUMN tablespace_name FORMAT A20
COLUMN segment_name FORMAT A30
COLUMN segment_type FORMAT A15
COLUMN file_name FORMAT A85
COLUMN rowid_fila FORMAT A20
COLUMN columna FORMAT A20
COLUMN bytes_internos FORMAT A100
COLUMN object_name FORMAT A25

PROMPT === 1. Tablespace de ACA_ESTUDIANTES ===
SELECT ts.tablespace_name, ts.bigfile, ts.block_size,
       ts.extent_management, ts.allocation_type,
       ts.segment_space_management,
       t.pct_free, t.ini_trans
FROM dba_tables t
JOIN dba_tablespaces ts ON ts.tablespace_name = t.tablespace_name
WHERE t.owner = 'ADMIN_ACADEMIA'
  AND t.table_name = 'ACA_ESTUDIANTES';

PROMPT === 2. Segmentos del esquema Academia ===
SELECT segment_name, segment_type, tablespace_name,
       extents, blocks, ROUND(bytes / 1024) AS kb
FROM dba_segments
WHERE owner = 'ADMIN_ACADEMIA'
ORDER BY bytes DESC, segment_name;

PROMPT === 3. Extensiones de ACA_ESTUDIANTES ===
SELECT extent_id, file_id, block_id, blocks,
       ROUND(bytes / 1024) AS kb
FROM dba_extents
WHERE owner = 'ADMIN_ACADEMIA'
  AND segment_name = 'ACA_ESTUDIANTES'
  AND segment_type = 'TABLE'
ORDER BY extent_id;

PROMPT === 4. Direccion fisica de la fila 101 ===
SELECT e.estudiante_id, e.estado,
       ROWIDTOCHAR(e.ROWID) AS rowid_fila,
       DBMS_ROWID.ROWID_OBJECT(e.ROWID) AS data_object_id,
       DBMS_ROWID.ROWID_TO_ABSOLUTE_FNO(
         e.ROWID, 'ADMIN_ACADEMIA', 'ACA_ESTUDIANTES'
       ) AS archivo,
       DBMS_ROWID.ROWID_BLOCK_NUMBER(
         e.ROWID,
         CASE WHEN ts.bigfile = 'YES' THEN 'BIGFILE' ELSE 'SMALLFILE' END
       ) AS bloque,
       DBMS_ROWID.ROWID_ROW_NUMBER(e.ROWID) AS ranura
FROM admin_academia.aca_estudiantes e
CROSS JOIN (
  SELECT ts.bigfile
  FROM dba_tables t
  JOIN dba_tablespaces ts ON ts.tablespace_name = t.tablespace_name
  WHERE t.owner = 'ADMIN_ACADEMIA'
    AND t.table_name = 'ACA_ESTUDIANTES'
) ts
WHERE e.estudiante_id = 101;

PROMPT === 5. Archivo y objeto correspondientes ===
SELECT file_id, relative_fno, tablespace_name, file_name
FROM dba_data_files
WHERE file_id = (
  SELECT DBMS_ROWID.ROWID_TO_ABSOLUTE_FNO(
    ROWID, 'ADMIN_ACADEMIA', 'ACA_ESTUDIANTES'
  )
  FROM admin_academia.aca_estudiantes
  WHERE estudiante_id = 101
);

SELECT owner, object_name, object_type, data_object_id
FROM dba_objects
WHERE data_object_id = (
  SELECT DBMS_ROWID.ROWID_OBJECT(ROWID)
  FROM admin_academia.aca_estudiantes
  WHERE estudiante_id = 101
);

PROMPT === 6. Representacion interna de valores de la fila ===
SELECT 'ESTUDIANTE_ID' AS columna, DUMP(estudiante_id, 16) AS bytes_internos
FROM admin_academia.aca_estudiantes WHERE estudiante_id = 101
UNION ALL
SELECT 'DNI', DUMP(dni, 16)
FROM admin_academia.aca_estudiantes WHERE estudiante_id = 101
UNION ALL
SELECT 'NOMBRES', DUMP(nombres, 16)
FROM admin_academia.aca_estudiantes WHERE estudiante_id = 101
UNION ALL
SELECT 'ESTADO', DUMP(estado, 16)
FROM admin_academia.aca_estudiantes WHERE estudiante_id = 101
UNION ALL
SELECT 'FECHA_REGISTRO', DUMP(fecha_registro, 16)
FROM admin_academia.aca_estudiantes WHERE estudiante_id = 101;

PROMPT === 7. Bytes de valores frente a longitud media estadistica ===
SELECT VSIZE(estudiante_id) + VSIZE(dni) + VSIZE(nombres)
       + VSIZE(apellidos) + VSIZE(email_institucional)
       + NVL(VSIZE(estado), 0) + VSIZE(fecha_registro)
         AS bytes_valores_fila_101,
       (SELECT avg_row_len FROM dba_tables
        WHERE owner = 'ADMIN_ACADEMIA'
          AND table_name = 'ACA_ESTUDIANTES') AS avg_row_len
FROM admin_academia.aca_estudiantes
WHERE estudiante_id = 101;

EXIT
