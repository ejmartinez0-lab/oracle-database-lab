#!/usr/bin/env bash
set -euo pipefail
source scripts/deployment/env/00-config.sh

SPID=${1:?Uso: 09-procesos-so.sh SPID}
[[ "$SPID" =~ ^[0-9]+$ ]] || {
  echo "ERROR: el SPID debe ser numerico."
  exit 2
}

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

docker exec -i "$CONTNAME" bash -s <<'SH' > "$TMP"
printf '%-8s %-10s %s\n' PID RSS_MB PROCESO
for d in /proc/[0-9]*; do
  pid=${d##*/}
  [[ -r "$d/cmdline" ]] || continue
  cmd=$(tr '\0' ' ' < "$d/cmdline" 2>/dev/null) || continue
  [[ -n "$cmd" ]] || continue
  rss=$(awk '/^VmRSS:/ {printf "%.1f", $2/1024}' \
    "$d/status" 2>/dev/null) || continue
  printf '%-8s %-10s %s\n' "$pid" "${rss:-0}" "$cmd"
done
SH

echo "=== 1. Procesos clave desde /proc dentro del contenedor ==="
grep -E '(db|ora)_(pmon|lreg|smon|dbw0|lgwr|ckpt|mmon|mmnl|reco)_FREE' \
  "$TMP" || true

echo "=== 2. Recuento observado desde /proc ==="
printf 'Background: '
grep -cE '(db|ora)_[a-z0-9]+_FREE' "$TMP" || true
printf 'Servidores dedicados: '
grep -c 'oracleFREE' "$TMP" || true
printf 'Listener: '
grep -c 'tnslsnr' "$TMP" || true

echo "=== 3. Procesos servidor activos en esta captura ==="
grep 'oracleFREE' "$TMP" ||
  echo "No aparecen servidores dedicados en esta captura."

echo "=== 4. Proceso con el SPID solicitado: $SPID ==="
awk -v p="$SPID" '$1 == p' "$TMP"

echo "=== 5. Identidad directa de /proc/$SPID ==="
docker exec "$CONTNAME" bash -c '
  test -r "/proc/$1/status"
  grep -E "^(Name|Pid|PPid|NSpid):" "/proc/$1/status"
  printf "Comando: "
  tr "\0" " " < "/proc/$1/cmdline"
  printf "\n"
' bash "$SPID"

echo "=== 6. El mismo LGWR visto desde docker top ==="
docker top "$CONTNAME" -eo pid,user,args |
  grep -E '(db|ora)_lgwr_FREE'
