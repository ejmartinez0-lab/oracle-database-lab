#!/usr/bin/env bash
# Lab 4 v3: verificacion de solo lectura; no restaura ni corrige.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
source scripts/deployment/env/00-config.sh
export CONTNAME

python3 - <<'PY'
from pathlib import Path
import os
import re
import subprocess
import tempfile

fallos = 0

def comprobar(nombre, condicion, detalle=""):
    global fallos
    print(f"{'OK' if condicion else 'FALLO'}: {nombre}", flush=True)
    if detalle:
        print(f"  {detalle}", flush=True)
    if not condicion:
        fallos += 1

def ejecutar(args, **kwargs):
    return subprocess.run(args, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.STDOUT, **kwargs)

sql = r"""
WHENEVER OSERROR EXIT FAILURE
WHENEVER SQLERROR EXIT FAILURE
SET HEADING OFF FEEDBACK OFF PAGESIZE 0 LINESIZE 250 VERIFY OFF
SELECT 'cdb=' || REPLACE(open_mode, ' ', '') FROM v$database;
SELECT 'pdb_abierta=' || COUNT(*) FROM v$pdbs
WHERE name='FREEPDB1' AND open_mode='READ WRITE';
SELECT 'open_cursors=' || value FROM v$parameter WHERE name='open_cursors';
SELECT 'dbfiles_pendiente=' || COUNT(*) FROM v$spparameter
WHERE name='db_files' AND isspecified='TRUE';
SELECT 'ops_comun=' || COUNT(*) FROM cdb_users
WHERE username='C##OPS_RO' AND con_id=1 AND common='YES';
SELECT 'ops_alert=' || COUNT(*) FROM dba_tab_privs
WHERE grantee='C##OPS_RO' AND owner='SYS'
AND table_name='V_$DIAG_ALERT_EXT' AND privilege='SELECT';
SELECT 'ops_any_nolectura=' || COUNT(*) FROM dba_sys_privs
WHERE grantee='C##OPS_RO' AND privilege LIKE '%ANY%'
AND privilege NOT LIKE 'SELECT %' AND privilege NOT LIKE 'READ %';
SELECT 'pdb_prueba=' || COUNT(*) FROM v$pdbs WHERE name='PDBLAB4';
SELECT 'usuarios_prueba=' || COUNT(*) FROM cdb_users
WHERE username LIKE 'LAB4%' OR username LIKE 'C##LAB4%';
ALTER SESSION SET CONTAINER=FREEPDB1;
SELECT 'tbs_prueba=' || COUNT(*) FROM dba_tablespaces
WHERE tablespace_name='TBS_LAB4';
SELECT 'tbs_negocio=' || COUNT(*) FROM dba_tablespaces
WHERE tablespace_name IN
('TBS_ACADEMIA','TBS_CLINICA','TBS_FINTECH','TBS_LOGISTICA','TBS_RETAIL');
SELECT 'admin_esquema=' || COUNT(*) FROM dba_users
WHERE username IN
('ADMIN_ACADEMIA','ADMIN_CLINICA','ADMIN_FINTECH','ADMIN_LOGISTICA','ADMIN_RETAIL')
AND authentication_type='NONE';
SELECT 'datafiles_fuera=' || COUNT(*) FROM dba_data_files
WHERE tablespace_name IN
('TBS_ACADEMIA','TBS_CLINICA','TBS_FINTECH','TBS_LOGISTICA','TBS_RETAIL')
AND file_name NOT LIKE '/opt/oracle/oradata/FREE/FREEPDB1/%';
SELECT 'estudiantes=' || COUNT(*) FROM admin_academia.aca_estudiantes;
SELECT 'asignaturas=' || COUNT(*) FROM admin_academia.aca_asignaturas;
SELECT 'matriculas=' || COUNT(*) FROM admin_academia.aca_matriculas;
EXIT
"""
print("=== 1. Estado de Oracle ===", flush=True)
with tempfile.NamedTemporaryFile(mode="w", suffix=".sql", delete=False) as f:
    f.write(sql)
    temporal = Path(f.name)
try:
    resultado = ejecutar(["bash", "scripts/ops/sysdba.sh", str(temporal)])
finally:
    temporal.unlink(missing_ok=True)

comprobar("consulta de verificacion terminada sin error", resultado.returncode == 0)
if resultado.returncode:
    print(resultado.stdout, flush=True)

valores = {}
for linea in resultado.stdout.splitlines():
    m = re.fullmatch(r"\s*([a-z_]+)=(.*?)\s*", linea)
    if m:
        valores.setdefault(m[1], []).append(m[2])

esperados = {
    "cdb": "READWRITE", "pdb_abierta": "1", "open_cursors": "300",
    "dbfiles_pendiente": "0", "ops_comun": "1", "ops_alert": "1",
    "ops_any_nolectura": "0", "pdb_prueba": "0", "usuarios_prueba": "0",
    "tbs_prueba": "0", "tbs_negocio": "5", "admin_esquema": "5",
    "datafiles_fuera": "0", "estudiantes": "20000",
    "asignaturas": "40", "matriculas": "60000",
}
for clave, esperado in esperados.items():
    recibido = valores.get(clave, [])
    comprobar(clave, recibido == [esperado],
              f"esperado={esperado}; recibido={recibido}")

print("\n=== 2. Contenedor y archivo eliminado ===", flush=True)
contenedor = os.environ["CONTNAME"]
r = ejecutar(["docker", "port", contenedor])
comprobar("puerto 8181 no publicado",
          r.returncode == 0 and not re.search(r"^8181/", r.stdout, re.M))

r = ejecutar(["docker", "exec", contenedor, "sh", "-c", r'''
set -eu
d=/opt/oracle/oradata/FREE/FREEPDB1
test -d "$d"
test -x "$d"
test ! -e "$d/lab4pruebas01.dbf"
test ! -L "$d/lab4pruebas01.dbf"
for f in "$d"/*.dbf; do
  test -e "$f" || continue
  real=$(readlink -f "$f")
  case "$real" in
    /opt/oracle/oradata/*) ;;
    *) echo "Ruta fuera del volumen: $f -> $real"; exit 1 ;;
  esac
done
'''])
comprobar("banco eliminado y rutas reales de .dbf dentro del volumen",
          r.returncode == 0, r.stdout.strip())

print("\n=== 3. Integridad del respaldo Lab 3; puede tardar ===", flush=True)
respaldos = sorted(
    p for p in Path("backups").glob("*_lab3-final")
    if (p / "SHA256SUMS").is_file()
)
if respaldos:
    respaldo = respaldos[-1]
    r = ejecutar(["sha256sum", "--check", "--quiet", "SHA256SUMS"],
                 cwd=respaldo)
    comprobar("respaldo lab3-final coincide con SHA256SUMS",
              r.returncode == 0,
              str(respaldo) + ("\n" + r.stdout.strip() if r.stdout.strip() else ""))
else:
    comprobar("respaldo lab3-final con SHA256SUMS disponible", False)

print("\n=== 4. Evidencias y entregables ===", flush=True)
raiz = Path("docs/bitacora/lab4/evidencia")
archivos = [p for p in raiz.rglob("*") if p.is_file() and p.stat().st_size > 0]
for n in range(16):
    patron = re.compile(rf"(?:^|_){n:02d}-")
    comprobar(f"evidencia {n:02d}",
              any(patron.search(p.name) for p in archivos))

comprobar("volcado de bloque Parte K",
          any(p.name.endswith("_12-volcado-bloque.trc.txt") for p in archivos))
for ruta in [
    "docs/bitacora/lab4/evidencia/config/initFREE-lab4.ora",
    "docs/bitacora/lab4/evidencia/config/14-migracion-cabeza.trc.txt",
    "docs/bitacora/lab4-autopsia.md",
    "docs/bitacora/lab4-respuestas.md",
]:
    p = Path(ruta)
    comprobar(f"archivo no vacio: {ruta}", p.is_file() and p.stat().st_size > 0)

print("\n=== 5. Exclusiones basicas de Git ===", flush=True)
r = ejecutar(["git", "ls-files", "-z"])
comprobar("inventario de Git accesible", r.returncode == 0)
versionados = r.stdout.split("\0") if r.returncode == 0 else []
prohibidos = [
    p for p in versionados
    if p == "config.env" or p.startswith("backups/")
]
comprobar("config.env y backups fuera del indice de Git",
          r.returncode == 0 and not prohibidos, ", ".join(prohibidos))

print(f"\nRESULTADO: {fallos} FALLOS.", flush=True)
if fallos == 0:
    print("Criterios comprobados: OK. Pendientes la revision completa de secretos y el PR.",
          flush=True)
raise SystemExit(min(fallos, 125))
PY
