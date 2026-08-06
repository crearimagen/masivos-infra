#!/usr/bin/env bash
# services/postgres/backup/backup-postgres.sh — respaldo de Postgres con
# pg_dump -Fc (formato custom, comprimido, restaurable en paralelo).
# Idempotente en el sentido de que cada ejecucion produce un archivo con
# timestamp propio y nunca sobreescribe uno anterior; aplica retencion
# despues de cada corrida exitosa.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${SERVICE_DIR}/../.." && pwd)"
# shellcheck source=../../../bootstrap/lib.sh
source "${REPO_ROOT}/bootstrap/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod>

Ejecuta 'pg_dump -Fc' dentro del contenedor masivos-postgres y guarda el
resultado en backups/<env>/postgres/. Aplica retencion segun
POSTGRES_BACKUP_RETENTION_DAYS (services/postgres/.env). Idempotente:
no sobreescribe backups anteriores, cada corrida crea un archivo nuevo.
EOF
}

ENVIRONMENT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment) ENVIRONMENT="${2:-}"; shift 2 ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    *) log_error "Argumento desconocido: $1"; usage; exit "$EXIT_INVALID_USAGE" ;;
  esac
done

if [[ -z "$ENVIRONMENT" ]]; then
  log_error "Falta --environment <dev|test|prod>"
  usage
  exit "$EXIT_INVALID_USAGE"
fi

load_environment_file "$ENVIRONMENT" "$REPO_ROOT"

readonly SERVICE_ENV_FILE="${SERVICE_DIR}/.env"
if [[ ! -f "$SERVICE_ENV_FILE" ]]; then
  log_error "No existe ${SERVICE_ENV_FILE}. Copia .env.example a .env y completalo."
  exit "$EXIT_MISSING_ENV_FILE"
fi
set -o allexport
# shellcheck disable=SC1090
source "$SERVICE_ENV_FILE"
set +o allexport

if [[ -z "${POSTGRES_USER:-}" || -z "${POSTGRES_DB:-}" ]]; then
  log_error "POSTGRES_USER y POSTGRES_DB deben estar definidos en ${SERVICE_ENV_FILE}"
  exit "$EXIT_INVALID_USAGE"
fi

readonly CONTAINER_NAME="masivos-postgres"
readonly RETENTION_DAYS="${POSTGRES_BACKUP_RETENTION_DAYS:-14}"
readonly BACKUP_DIR="${REPO_ROOT}/backups/${ENVIRONMENT}/postgres"
readonly TIMESTAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
readonly BACKUP_FILE="${BACKUP_DIR}/postgres_${POSTGRES_DB}_${TIMESTAMP}.dump"

verify_container_running() {
  if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    log_error "El contenedor '${CONTAINER_NAME}' no esta corriendo."
    exit "$EXIT_GENERAL_ERROR"
  fi
}

run_backup() {
  mkdir -p "$BACKUP_DIR"
  log_info "Respaldando '${POSTGRES_DB}' a ${BACKUP_FILE}"
  if ! docker exec "$CONTAINER_NAME" pg_dump -Fc -U "$POSTGRES_USER" "$POSTGRES_DB" > "$BACKUP_FILE"; then
    log_error "pg_dump fallo; eliminando archivo parcial."
    rm -f "$BACKUP_FILE"
    exit "$EXIT_GENERAL_ERROR"
  fi
  if [[ ! -s "$BACKUP_FILE" ]]; then
    log_error "El backup resultante esta vacio."
    rm -f "$BACKUP_FILE"
    exit "$EXIT_GENERAL_ERROR"
  fi
  log_success "Backup completado: ${BACKUP_FILE} ($(du -h "$BACKUP_FILE" | cut -f1))"
}

apply_retention() {
  log_info "Aplicando retencion de ${RETENTION_DAYS} dias en ${BACKUP_DIR}"
  find "$BACKUP_DIR" -name 'postgres_*.dump' -type f -mtime "+${RETENTION_DAYS}" -print -delete | while read -r removed; do
    log_info "Eliminado por retencion: ${removed}"
  done
}

main() {
  verify_container_running
  run_backup
  apply_retention
  log_success "backup-postgres.sh completado para el entorno '${ENVIRONMENT}'."
}

main
