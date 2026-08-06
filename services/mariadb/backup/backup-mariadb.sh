#!/usr/bin/env bash
# services/mariadb/backup/backup-mariadb.sh — respaldo completo de MariaDB
# (mariadb-dump --all-databases, ya que Postal aprovisiona una base de datos
# nueva por cada mail server y no hay un unico nombre de base fijo que
# respaldar). Comprimido con gzip. Idempotente: cada ejecucion produce un
# archivo con timestamp propio; aplica retencion despues de cada corrida
# exitosa.
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

Ejecuta 'mariadb-dump --all-databases' dentro del contenedor
masivos-mariadb y guarda el resultado comprimido en
backups/<env>/mariadb/. Aplica retencion segun
MARIADB_BACKUP_RETENTION_DAYS (services/mariadb/.env). Idempotente: no
sobreescribe backups anteriores, cada corrida crea un archivo nuevo.
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

if [[ -z "${MARIADB_ROOT_PASSWORD:-}" ]]; then
  log_error "MARIADB_ROOT_PASSWORD debe estar definido en ${SERVICE_ENV_FILE}"
  exit "$EXIT_INVALID_USAGE"
fi

readonly CONTAINER_NAME="masivos-mariadb"
readonly RETENTION_DAYS="${MARIADB_BACKUP_RETENTION_DAYS:-14}"
readonly BACKUP_DIR="${REPO_ROOT}/backups/${ENVIRONMENT}/mariadb"
readonly TIMESTAMP="$(date -u '+%Y%m%dT%H%M%SZ')"
readonly BACKUP_FILE="${BACKUP_DIR}/mariadb_all_${TIMESTAMP}.sql.gz"

verify_container_running() {
  if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    log_error "El contenedor '${CONTAINER_NAME}' no esta corriendo."
    exit "$EXIT_GENERAL_ERROR"
  fi
}

run_backup() {
  mkdir -p "$BACKUP_DIR"
  log_info "Respaldando todas las bases de datos a ${BACKUP_FILE}"
  if ! docker exec "$CONTAINER_NAME" mariadb-dump \
      -uroot -p"${MARIADB_ROOT_PASSWORD}" \
      --all-databases --single-transaction --routines --events \
      | gzip > "$BACKUP_FILE"; then
    log_error "mariadb-dump fallo; eliminando archivo parcial."
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
  find "$BACKUP_DIR" -name 'mariadb_all_*.sql.gz' -type f -mtime "+${RETENTION_DAYS}" -print -delete | while read -r removed; do
    log_info "Eliminado por retencion: ${removed}"
  done
}

main() {
  verify_container_running
  run_backup
  apply_retention
  log_success "backup-mariadb.sh completado para el entorno '${ENVIRONMENT}'."
}

main
