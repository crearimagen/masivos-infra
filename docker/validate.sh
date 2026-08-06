#!/usr/bin/env bash
# docker/validate.sh — verifica que la instalacion de Docker este completa y
# correcta: daemon activo, daemon.json aplicado, red y volumenes presentes,
# DEPLOY_USER en el grupo docker. No modifica nada; solo reporta.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../bootstrap/lib.sh
source "${REPO_ROOT}/bootstrap/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod>

Valida (sin modificar nada) que docker/install.sh se aplico
correctamente: daemon activo, daemon.json aplicado, red
masivos-network con la subnet esperada, los 10 volumenes nombrados, y
DEPLOY_USER en el grupo docker. Exit 0 si todo pasa, 1 si algo falla.
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

readonly VOLUMES=(
  masivos-mariadb-data
  masivos-postgres-data
  masivos-rabbitmq-data
  masivos-redis-data
  masivos-postal-data
  masivos-nginx-data
  masivos-prometheus-data
  masivos-grafana-data
  masivos-loki-data
  masivos-uptime-kuma-data
)

FAILURES=0

check() {
  local description="$1"
  local status="$2"
  if [[ "$status" -eq 0 ]]; then
    log_info "[PASS] ${description}"
  else
    log_error "[FAIL] ${description}"
    FAILURES=$((FAILURES + 1))
  fi
}

main() {
  command_exists docker
  check "docker esta instalado" "$?"

  docker info >/dev/null 2>&1
  check "el daemon de docker responde" "$?"

  docker compose version >/dev/null 2>&1
  check "el plugin 'docker compose' esta disponible" "$?"

  if [[ -f /etc/docker/daemon.json ]] && cmp -s "${SCRIPT_DIR}/daemon.json" /etc/docker/daemon.json; then
    check "/etc/docker/daemon.json coincide con docker/daemon.json" 0
  else
    check "/etc/docker/daemon.json coincide con docker/daemon.json" 1
  fi

  if docker network inspect masivos-network >/dev/null 2>&1; then
    local current_subnet
    current_subnet="$(docker network inspect masivos-network --format '{{(index .IPAM.Config 0).Subnet}}')"
    if [[ "$current_subnet" == "${DOCKER_NETWORK_SUBNET:-}" ]]; then
      check "red masivos-network existe con subnet ${DOCKER_NETWORK_SUBNET:-?}" 0
    else
      log_error "masivos-network tiene subnet '${current_subnet}', se esperaba '${DOCKER_NETWORK_SUBNET:-?}'"
      check "red masivos-network con subnet correcta" 1
    fi
  else
    check "red masivos-network existe" 1
  fi

  local vol
  for vol in "${VOLUMES[@]}"; do
    docker volume inspect "$vol" >/dev/null 2>&1
    check "volumen ${vol} existe" "$?"
  done

  if [[ -n "${DEPLOY_USER:-}" ]] && id -nG "$DEPLOY_USER" 2>/dev/null | tr ' ' '\n' | grep -qx docker; then
    check "'${DEPLOY_USER}' pertenece al grupo docker" 0
  else
    check "'${DEPLOY_USER:-?}' pertenece al grupo docker" 1
  fi

  if [[ "$FAILURES" -eq 0 ]]; then
    log_success "docker/validate.sh: todas las verificaciones pasaron para '${ENVIRONMENT}'."
    exit "$EXIT_OK"
  else
    log_error "docker/validate.sh: ${FAILURES} verificacion(es) fallaron para '${ENVIRONMENT}'."
    exit "$EXIT_GENERAL_ERROR"
  fi
}

main
