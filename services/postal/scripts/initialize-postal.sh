#!/usr/bin/env bash
# services/postal/scripts/initialize-postal.sh — crea/migra el esquema de
# main_db (y message_db segun aplique) ejecutando el comando "initialize"
# del propio binario de Postal, dentro del servicio "runner" (profile:
# tools, no arranca con "up -d"). Seguro de re-ejecutar: initialize aplica
# migraciones de base de datos, que son idempotentes por diseno de Postal
# (igual que "rails db:migrate").
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

Ejecuta 'postal initialize' dentro del servicio runner de Postal, para
crear/migrar el esquema de main_db. Requiere que services/mariadb este
corriendo y que services/postal/.env y config/signing.key existan.

Nota: la creacion del primer usuario administrador ('postal make-user')
es interactiva por diseno del propio proyecto Postal (no acepta flags
ni variables de entorno) y NO se automatiza aqui - ver README.md,
seccion "Cómo instalarlo".
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

if [[ ! -f "${SERVICE_DIR}/.env" ]]; then
  log_error "No existe ${SERVICE_DIR}/.env. Copia .env.example a .env y completalo."
  exit "$EXIT_MISSING_ENV_FILE"
fi
if [[ ! -f "${SERVICE_DIR}/config/signing.key" ]]; then
  log_error "No existe ${SERVICE_DIR}/config/signing.key. Ejecuta scripts/generate-signing-key.sh primero."
  exit "$EXIT_GENERAL_ERROR"
fi
if ! command_exists docker; then
  log_error "docker no esta disponible."
  exit "$EXIT_GENERAL_ERROR"
fi

main() {
  log_info "Ejecutando 'postal initialize' en el servicio runner."
  (
    cd "$SERVICE_DIR"
    docker compose --env-file .env -f docker-compose.yml run --rm runner postal initialize
  )
  log_success "initialize-postal.sh completado para el entorno '${ENVIRONMENT}'."
  log_info "Siguiente paso manual (interactivo): docker compose -f ${SERVICE_DIR}/docker-compose.yml run --rm -it runner postal make-user"
}

main
