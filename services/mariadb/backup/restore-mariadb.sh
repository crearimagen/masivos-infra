#!/usr/bin/env bash
# services/mariadb/backup/restore-mariadb.sh — restaura un dump generado por
# backup-mariadb.sh (mariadb-dump --all-databases, comprimido con gzip).
# Operacion destructiva: requiere --force explicito, no hay prompt
# interactivo (debe poder automatizarse), pero por defecto se niega a
# ejecutar sin el.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${SERVICE_DIR}/../.." && pwd)"
# shellcheck source=../../../bootstrap/lib.sh
source "${REPO_ROOT}/bootstrap/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod> --file <ruta_al_dump.sql.gz> --force

Restaura un dump (.sql.gz de mariadb-dump --all-databases) en el
contenedor masivos-mariadb, ejecutando el SQL directamente contra el
servidor. DESTRUCTIVO: sobreescribe/crea bases de datos con los mismos
nombres que contiene el dump. Requiere --force explicito; sin el, el
script se niega a ejecutar.
EOF
}

ENVIRONMENT=""
DUMP_FILE=""
FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment) ENVIRONMENT="${2:-}"; shift 2 ;;
    --file) DUMP_FILE="${2:-}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    *) log_error "Argumento desconocido: $1"; usage; exit "$EXIT_INVALID_USAGE" ;;
  esac
done

if [[ -z "$ENVIRONMENT" ]]; then
  log_error "Falta --environment <dev|test|prod>"
  usage
  exit "$EXIT_INVALID_USAGE"
fi
if [[ -z "$DUMP_FILE" ]]; then
  log_error "Falta --file <ruta_al_dump.sql.gz>"
  usage
  exit "$EXIT_INVALID_USAGE"
fi
if [[ ! -f "$DUMP_FILE" ]]; then
  log_error "No existe el archivo de dump: ${DUMP_FILE}"
  exit "$EXIT_INVALID_USAGE"
fi
if [[ "$FORCE" -ne 1 ]]; then
  log_error "Operacion destructiva: se requiere el flag --force explicito."
  log_error "Esto sobreescribe/crea bases de datos en '${ENVIRONMENT}'. Verifica el archivo antes de forzar."
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

verify_container_running() {
  if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER_NAME"; then
    log_error "El contenedor '${CONTAINER_NAME}' no esta corriendo."
    exit "$EXIT_GENERAL_ERROR"
  fi
}

main() {
  verify_container_running

  log_info "Restaurando ${DUMP_FILE} en '${CONTAINER_NAME}'."
  if ! gunzip -c "$DUMP_FILE" | docker exec -i "$CONTAINER_NAME" mariadb -uroot -p"${MARIADB_ROOT_PASSWORD}"; then
    log_error "La restauracion fallo. Revisa la salida anterior."
    exit "$EXIT_GENERAL_ERROR"
  fi

  log_success "restore-mariadb.sh completado para el entorno '${ENVIRONMENT}' desde ${DUMP_FILE}."
}

main
