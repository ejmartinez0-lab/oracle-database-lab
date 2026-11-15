#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh

DEST="$EVID_LAB4/config"
mkdir -p "$DEST"

for f in initFREE-lab4-antes.ora initFREE-lab4.ora initFREE-lab4-memoria.ora; do
  docker cp "$CONTNAME:/tmp/$f" "$DEST/$f"
done

echo "=== Lineas de los PFILE ==="
wc -l "$DEST/"initFREE-lab4*.ora

nombres() {
  sed -n 's/^[^=]*\.\([A-Za-z][A-Za-z0-9_]*\)=.*/\1/p' "$1" |
    sort -u
}

echo "=== Parametros presentes en MEMORY pero no escritos en SPFILE ==="
comm -13 \
  <(nombres "$DEST/initFREE-lab4.ora") \
  <(nombres "$DEST/initFREE-lab4-memoria.ora")

echo "=== Archivos guardados ==="
ls -lh "$DEST/"initFREE-lab4*.ora
