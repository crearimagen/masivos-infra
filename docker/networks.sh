#!/usr/bin/env bash
# docker/networks.sh — crea la red masivos-network con subnet fija.
# Idempotente: si ya existe con la subnet correcta, no hace nada. Si existe
# con una subnet distinta, falla explicitamente en vez de recrearla (recrear
# desconectaria los contenedores ya adjuntos).
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../bootstrap/lib.sh
source "${REPO_ROOT}/bootstrap/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod>

Crea la red Docker 'masivos-network' (bridge) con la subnet definida en
DOCKER_NETWORK_SUBNET (environments/<env>/.env). Idempotente.
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

require_root
load_environment_file "$ENVIRONMENT" "$REPO_ROOT"

if [[ -z "${DOCKER_NETWORK_SUBNET:-}" ]]; then
  log_error "DOCKER_NETWORK_SUBNET no esta definido en environments/${ENVIRONMENT}/.env"
  exit "$EXIT_INVALID_USAGE"
fi

if ! command_exists docker; then
  log_error "docker no esta instalado. Ejecuta docker/install.sh primero."
  exit "$EXIT_GENERAL_ERROR"
fi

readonly NETWORK_NAME="masivos-network"

main() {
  if docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
    local current_subnet
    current_subnet="$(docker network inspect "$NETWORK_NAME" --format '{{(index .IPAM.Config 0).Subnet}}')"
    if [[ "$current_subnet" == "$DOCKER_NETWORK_SUBNET" ]]; then
      log_info "La red '${NETWORK_NAME}' ya existe con la subnet correcta (${current_subnet}); se omite."
    else
      log_error "La red '${NETWORK_NAME}' ya existe con subnet '${current_subnet}', distinta de la esperada '${DOCKER_NETWORK_SUBNET}'."
      log_error "Recrearla desconectaria los contenedores existentes. Resuelvelo manualmente: docker network rm ${NETWORK_NAME} (tras detener los servicios que la usan)."
      exit "$EXIT_GENERAL_ERROR"
    fi
  else
    log_info "Creando red '${NETWORK_NAME}' con subnet ${DOCKER_NETWORK_SUBNET}."
    docker network create \
      --driver bridge \
      --subnet "$DOCKER_NETWORK_SUBNET" \
      "$NETWORK_NAME"
  fi
  log_success "networks.sh completado para el entorno '${ENVIRONMENT}'."
}

main
