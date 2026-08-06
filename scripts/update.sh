#!/usr/bin/env bash
# scripts/update.sh — actualiza las imagenes de un servicio (o de todos) a
# la version fijada actualmente en su docker-compose.yml/.env, preservando
# datos (los volumenes nombrados no se tocan). Idempotente: 'docker compose
# pull' + 'up -d' no hace nada si ya se esta en la ultima imagen descargada.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../bootstrap/lib.sh
source "${REPO_ROOT}/bootstrap/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod> [--service <nombre>]

Ejecuta 'docker compose pull' + 'up -d' para el servicio indicado, o para
todo el stack principal (docker/compose/docker-compose.yml) si se omite
--service. Postal se actualiza aparte (--service postal) por su ciclo de
vida distinto (network_mode: host, ver services/postal/README.md).

Para cambiar de VERSION (no solo repull de la misma tag), edita primero
el tag de imagen en el docker-compose.yml del servicio (o POSTAL_VERSION
en services/postal/.env) y luego ejecuta este script.

Tras actualizar mariadb o postal, ejecuta ademas:
  ./services/postal/scripts/initialize-postal.sh --environment <env>
(aplica migraciones pendientes; idempotente, seguro re-ejecutarlo).
EOF
}

ENVIRONMENT=""
SERVICE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment) ENVIRONMENT="${2:-}"; shift 2 ;;
    --service) SERVICE="${2:-}"; shift 2 ;;
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

if ! command_exists docker; then
  log_error "docker no esta disponible."
  exit "$EXIT_GENERAL_ERROR"
fi

update_main_stack() {
  local compose_file="${REPO_ROOT}/docker/compose/docker-compose.yml"
  log_info "Actualizando stack principal (docker/compose/docker-compose.yml)."
  docker compose -f "$compose_file" pull
  docker compose -f "$compose_file" up -d
}

update_service() {
  local service="$1"
  local service_dir="${REPO_ROOT}/services/${service}"
  if [[ ! -d "$service_dir" ]] || [[ ! -f "${service_dir}/docker-compose.yml" ]]; then
    log_error "No existe services/${service}/docker-compose.yml"
    exit "$EXIT_INVALID_USAGE"
  fi
  if [[ ! -f "${service_dir}/.env" ]]; then
    log_error "No existe ${service_dir}/.env"
    exit "$EXIT_MISSING_ENV_FILE"
  fi
  log_info "Actualizando servicio '${service}'."
  (
    cd "$service_dir"
    if [[ "$service" == "postal" ]]; then
      docker compose --env-file .env -f docker-compose.yml pull web smtp worker
      docker compose --env-file .env -f docker-compose.yml up -d web smtp worker
    else
      docker compose --env-file .env -f docker-compose.yml pull
      docker compose --env-file .env -f docker-compose.yml up -d
    fi
  )
}

main() {
  if [[ -n "$SERVICE" ]]; then
    update_service "$SERVICE"
  else
    update_main_stack
  fi
  log_success "update.sh completado para el entorno '${ENVIRONMENT}'."
}

main
