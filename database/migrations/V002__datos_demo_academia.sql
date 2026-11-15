-- Datos sinteticos de Academia.
-- Si ya existen estudiantes, no vuelve a insertar.
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
SET FEEDBACK ON
ALTER SESSION SET CONTAINER = FREEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = admin_academia;
SET SERVEROUTPUT ON

DECLARE
  v_hay NUMBER;
BEGIN
  SELECT COUNT(*) INTO v_hay FROM aca_estudiantes;

  IF v_hay > 0 THEN
    DBMS_OUTPUT.PUT_LINE(
      'V002: ya hay ' || v_hay || ' estudiantes; no se inserta nada.'
    );
    RETURN;
  END IF;

  INSERT INTO aca_estudiantes
    (dni, nombres, apellidos, email_institucional, estado)
  SELECT
    LPAD(LEVEL, 8, '0') || 'X',
    'Nombre ' || LEVEL,
    'Apellido ' || MOD(LEVEL, 997),
    'est' || LEVEL || '@alu.ucam.edu',
    CASE
      WHEN MOD(LEVEL, 10) = 0 THEN 'EGRESADO'
      WHEN MOD(LEVEL, 25) = 0 THEN 'INACTIVO'
      ELSE 'ACTIVO'
    END
  FROM dual
  CONNECT BY LEVEL <= 20000;

  INSERT INTO aca_asignaturas (codigo, nombre, creditos)
  SELECT
    'ABD' || LPAD(LEVEL, 3, '0'),
    'Asignatura ' || LEVEL,
    MOD(LEVEL, 6) + 3
  FROM dual
  CONNECT BY LEVEL <= 40;

  INSERT INTO aca_matriculas (estudiante_id, asignatura_id, periodo)
  SELECT e.estudiante_id, a.asignatura_id, '2026-1'
  FROM aca_estudiantes e
  JOIN (SELECT LEVEL AS k FROM dual CONNECT BY LEVEL <= 3) n
    ON 1 = 1
  JOIN aca_asignaturas a
    ON a.codigo =
       'ABD' || LPAD(MOD(e.estudiante_id * 7 + n.k, 40) + 1, 3, '0');

  COMMIT;
  DBMS_STATS.GATHER_SCHEMA_STATS('ADMIN_ACADEMIA');
  DBMS_OUTPUT.PUT_LINE('V002 aplicada.');
END;
/

PROMPT === Recuento final ===
SELECT
  (SELECT COUNT(*) FROM aca_estudiantes) AS estudiantes,
  (SELECT COUNT(*) FROM aca_asignaturas) AS asignaturas,
  (SELECT COUNT(*) FROM aca_matriculas) AS matriculas
FROM dual;

PROMPT === Fila de referencia ===
SELECT estudiante_id, dni, estado
FROM aca_estudiantes
WHERE estudiante_id = 101;

EXIT
