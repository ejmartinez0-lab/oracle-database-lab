#!/usr/bin/env bash
# Constantes del proyecto oracle-database-lab.
# Uso: source scripts/deployment/env/00-config.sh
# No contiene secretos: las contraseñas viven en config.env.

export CONTNAME=oralab-26ai
export VOLNAME=oralab-26ai-data
export IMG=container-registry.oracle.com/database/free:latest
export PORTDB=1521
export PORTORDS=8181
export SERVICE_CDB=FREE
export SERVICE_PDB=FREEPDB1
export BACKUP_DIR="$(pwd)/backups"
export EVID=docs/bitacora/evidencia

ts() {
  date -u +%Y%m%dT%H%M%SZ
}
