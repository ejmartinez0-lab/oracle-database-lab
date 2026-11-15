#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh

ETIQUETA=${1:?Uso: backup-estado.sh etiqueta}
[[ "$ETIQUETA" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]] || {
  echo "ERROR: etiqueta no válida"; exit 2;
}

echo "1. Comprobaciones previas"
docker volume inspect "$VOLNAME" >/dev/null
[[ "$(docker inspect -f '{{.State.Running}}' "$CONTNAME")" == true ]]
MONTAJE=$(docker inspect -f \
  '{{range .Mounts}}{{if eq .Destination "/opt/oracle/oradata"}}{{.Name}}{{end}}{{end}}' \
  "$CONTNAME")
[[ "$MONTAJE" == "$VOLNAME" ]] || {
  echo "ERROR: el volumen configurado no coincide con el montado"; exit 1;
}

mkdir -p "$BACKUP_DIR"
DEST="$(realpath "$BACKUP_DIR")/$(ts)_${ETIQUETA}"
mkdir -p "$DEST/extras"
DUENO="$(id -u):$(id -g)"

docker pull "$HELPER_IMG"
USADO=$(docker run --rm -v "$VOLNAME:/v:ro" "$HELPER_IMG" \
  du -sm /v | cut -f1)
LIBRE=$(df -Pm "$BACKUP_DIR" | awk 'NR==2 {print $4}')
echo "Volumen: $USADO MB; espacio disponible en backups: $LIBRE MB"
(( LIBRE > USADO )) || {
  echo "ERROR: espacio insuficiente"; exit 1;
}

echo "2. Inventario con la base abierta"
docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba" \
  < scripts/ops/inventario-archivos.sql > "$DEST/inventario.txt"
cat "$DEST/inventario.txt"
grep -q '^FILE|datafile|' "$DEST/inventario.txt"

echo "3. Cobertura del volumen: rutas reales"
: > "$DEST/extras.lst"
while IFS= read -r f; do
  real=$(docker exec "$CONTNAME" readlink -f "$f")
  [[ -n "$real" ]] || { echo "ERROR: ruta no resuelta: $f"; exit 1; }
  if [[ "$real" == "$DATA_ROOT/"* ]]; then
    echo "DENTRO: $f -> $real"
  else
    echo "FUERA: $f -> $real"
    printf '%s\n' "$real" >> "$DEST/extras.lst"
  fi
done < <(grep '^FILE|' "$DEST/inventario.txt" | cut -d'|' -f3 | sort -u)
sort -u -o "$DEST/extras.lst" "$DEST/extras.lst"

reiniciar() {
  codigo=$?
  trap - EXIT
  echo "Arranque de seguridad del contenedor"
  docker start "$CONTNAME" >/dev/null || true
  exit "$codigo"
}
trap reiniciar EXIT

echo "4. Parada limpia de Oracle y del contenedor"
printf '%s\n' 'WHENEVER SQLERROR EXIT FAILURE' \
  'SHUTDOWN IMMEDIATE;' 'EXIT' |
  docker exec -i "$CONTNAME" sqlplus -s -L "/ as sysdba"
docker stop -t 120 "$CONTNAME" >/dev/null

echo "5. Copia del volumen conservando propietarios y permisos"
docker run --rm \
  -v "$VOLNAME:/origen:ro" \
  -v "$DEST:/destino" \
  "$HELPER_IMG" sh -c \
  'tar --numeric-owner -czpf /destino/volumen.tar.gz -C /origen . &&
   chown "$1" /destino/volumen.tar.gz' sh "$DUENO"

echo "6. Copia de archivos externos al volumen"
n=0
: > "$DEST/extras/mapa.txt"
while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  n=$((n+1))
  docker cp "$CONTNAME:$f" - | gzip > "$DEST/extras/extra${n}.tar.gz"
  printf 'extra%s.tar.gz|%s\n' "$n" "$f" >> "$DEST/extras/mapa.txt"
  echo "Copiado: $f"
done < "$DEST/extras.lst"
echo "Archivos externos: $n"

echo "7. Manifiesto y SHA-256"
{
  echo "etiqueta=$ETIQUETA"
  echo "fecha_utc=$(ts)"
  echo "contenedor=$CONTNAME"
  echo "volumen=$VOLNAME"
  echo "imagen=$(docker inspect -f '{{.Config.Image}}' "$CONTNAME")"
  echo "git_commit=$(git rev-parse HEAD)"
  echo "tipo=copia en frio consistente tras SHUTDOWN IMMEDIATE"
  echo "archivos_fuera_del_volumen=$n"
} > "$DEST/manifiesto.txt"

(
  cd "$DEST"
  find . -type f ! -name SHA256SUMS -print0 |
    sort -z | xargs -0 sha256sum > SHA256SUMS
  sha256sum --check SHA256SUMS
)

echo "8. Arranque y comprobacion"
docker start "$CONTNAME" >/dev/null
bash scripts/ops/esperar-healthy.sh
trap - EXIT

echo "Copia terminada:"
du -sh "$DEST"
echo "Carpeta: $DEST"
echo "Restauracion: bash scripts/ops/restaurar-estado.sh '$DEST'"
