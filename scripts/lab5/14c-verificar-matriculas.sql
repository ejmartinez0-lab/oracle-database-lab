WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
ALTER SESSION SET CONTAINER = FREEPDB1;
SET SERVEROUTPUT ON SIZE UNLIMITED
DECLARE
  n NUMBER;
BEGIN
  SELECT COUNT(*) INTO n FROM admin_academia.aca_matriculas;
  IF n <> 60000 THEN
    RAISE_APPLICATION_ERROR(-20025, 'Se esperaban 60000 matriculas');
  END IF;

  SELECT COUNT(*) INTO n FROM dba_constraints
  WHERE owner = 'ADMIN_ACADEMIA' AND table_name = 'ACA_MATRICULAS';
  IF n <> 9 THEN
    RAISE_APPLICATION_ERROR(-20025, 'Se esperaban nueve restricciones');
  END IF;

  SELECT COUNT(*) INTO n FROM dba_constraints
  WHERE owner = 'ADMIN_ACADEMIA' AND table_name = 'ACA_MATRICULAS'
    AND (status <> 'ENABLED' OR validated <> 'VALIDATED');
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20025, 'Hay restricciones no habilitadas o no validadas');
  END IF;

  SELECT COUNT(*) INTO n FROM dba_constraints
  WHERE owner = 'ADMIN_ACADEMIA' AND table_name = 'ACA_MATRICULAS'
    AND constraint_type = 'R'
    AND constraint_name IN ('FK_ACA_MAT_ASI', 'FK_ACA_MAT_EST');
  IF n <> 2 THEN
    RAISE_APPLICATION_ERROR(-20025, 'Faltan las dos claves ajenas originales');
  END IF;

  SELECT COUNT(*) INTO n FROM dba_indexes
  WHERE table_owner = 'ADMIN_ACADEMIA' AND table_name = 'ACA_MATRICULAS';
  IF n <> 4 THEN
    RAISE_APPLICATION_ERROR(-20025, 'Se esperaban cuatro indices');
  END IF;

  SELECT COUNT(*) INTO n FROM dba_indexes
  WHERE table_owner = 'ADMIN_ACADEMIA' AND table_name = 'ACA_MATRICULAS'
    AND status <> 'VALID';
  IF n <> 0 THEN
    RAISE_APPLICATION_ERROR(-20025, 'Hay indices no validos');
  END IF;

  DBMS_OUTPUT.PUT_LINE('OK: 60000 matriculas');
  DBMS_OUTPUT.PUT_LINE('OK: nueve restricciones ENABLED y VALIDATED');
  DBMS_OUTPUT.PUT_LINE('OK: ambas claves ajenas originales presentes');
  DBMS_OUTPUT.PUT_LINE('OK: cuatro indices VALID');
END;
/
PROMPT MATRICULAS_VERIFICADAS_OK
EXIT SUCCESS
