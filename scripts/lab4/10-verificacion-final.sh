#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh

fallos=0
ok() { printf 'OK: %s\n' "$1"; }
fallo() {
  printf 'FALLO: %s\n' "$1"
  fallos=$((fallos+1))
}
comprobar() {
  if [[ "$2" == "$3" ]]; then
    ok "$1 = $2"
  else
    fallo "$1: obtenido '$2', esperado '$3'"
  fi
}

echo "=== Parte B: integridad del backup ==="
BK=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d \
  -name '*_lab3-final' | sort | tail -n 1)

if [[ -n "$BK" ]] &&
   (cd "$BK" && sha256sum --check --quiet SHA256SUMS); then
  ok "Backup integro: $BK"
else
  fallo "No se encuentra un backup lab3-final integro"
fi

echo "=== Estado SQL ==="
if ! VALORES=$(docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba" \
  < scripts/lab4/10-verificacion-final.sql); then
  echo "$VALORES"
  echo "FALLO: no se pudo completar la consulta SQL."
  exit 1
fi

val() {
  printf '%s\n' "$VALORES" |
    awk -F'|' -v clave="$1" '$1==clave {print $2}' |
    tr -d '[:space:]'
}

comprobar "Tablespaces de negocio" "$(val tbs)" "5"
comprobar "Tablespaces de negocio ONLINE" "$(val tbs_online)" "5"
comprobar "Datafiles fuera de carpeta estandar" "$(val fuera_carpeta)" "0"
comprobar "Propietarios sin autenticacion" "$(val sin_auth)" "5"
comprobar "Datos V002" "$(val v002)" "20000/40/60000"
comprobar "CDB abierta" "$(val cdb)" "READWRITE"
comprobar "PDB abierta" "$(val pdb)" "READWRITE"
comprobar "Cuenta comun C##OPS_RO" "$(val ops_ro)" "YES"
comprobar "OPEN_CURSORS raiz" "$(val open_cursors)" "300"
comprobar "OPEN_CURSORS PDB" "$(val pdb_cursors)" "300"
comprobar "DB_FILES sin cambio pendiente" "$(val db_files_spfile)" "FALSE"

echo "=== Rutas reales de los archivos de la base ==="
INVENTARIO=$(docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba" \
  < scripts/ops/inventario-archivos.sql)
FUERA=0
while IFS= read -r f; do
  real=$(docker exec "$CONTNAME" readlink -f "$f")
  if [[ "$real" != "$DATA_ROOT/"* ]]; then
    echo "Fuera del volumen: $f -> $real"
    FUERA=$((FUERA+1))
  fi
done < <(printf '%s\n' "$INVENTARIO" |
  grep '^FILE|' | cut -d'|' -f3 | sort -u)
comprobar "Archivos reales fuera del volumen" "$FUERA" "0"

PUERTOS=$(docker port "$CONTNAME")
if grep -q 8181 <<< "$PUERTOS"; then
  fallo "Puerto 8181 sigue publicado"
else
  ok "Puerto 8181 no publicado"
fi

echo "=== Evidencias 00 a 09 ==="
for n in 00 01 02 03 04 05 06 07 08 09; do
  ARCHIVO=$(find "$EVID_LAB4" -type f -size +0c \
    -name "*_${n}-*" -print -quit)
  if [[ -n "$ARCHIVO" ]]; then
    ok "Evidencia $n"
  else
    fallo "Falta evidencia $n"
  fi
done

if git ls-files --error-unmatch \
  "$EVID_LAB4/config/initFREE-lab4.ora" >/dev/null 2>&1; then
  ok "PFILE versionado"
else
  fallo "Falta PFILE versionado"
fi

echo "=== Proteccion del repositorio ==="
if git ls-files --error-unmatch config.env >/dev/null 2>&1; then
  fallo "config.env esta versionado"
else
  ok "config.env fuera de Git"
fi

PROHIBIDOS=$(git ls-files |
  grep -E '(^|/)backups/|\.tar\.gz$' || true)
if [[ -z "$PROHIBIDOS" ]]; then
  ok "Sin backups ni tar.gz versionados"
else
  fallo "Hay copias versionadas: $PROHIBIDOS"
fi

if git diff --quiet lab3-final -- \
  database/migrations/V000__setup_entornos_negocio.sql \
  database/migrations/V001__create_esquemas_negocio.sql; then
  ok "V000 y V001 sin cambios"
else
  fallo "V000 o V001 modificadas"
fi

echo
if (( fallos == 0 )); then
  echo "RESULTADO: TODO OK. Verificacion tecnica completada."
else
  echo "RESULTADO: $fallos FALLOS."
fi
exit "$fallos"
