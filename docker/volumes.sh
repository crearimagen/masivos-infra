#!/usr/bin/env bash
# docker/volumes.sh — crea los volumenes Docker nombrados usados por services/*.
# Idempotente: solo crea los que falten.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../bootstrap/lib.sh
source "${REPO_ROOT}/bootstrap/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod>

Crea los volumenes Docker nombrados definidos en docs/architecture.md
(masivos-mariadb-data, masivos-postgres-data, masivos-rabbitmq-data,
masivos-redis-data, masivos-postal-data, masivos-nginx-data,
masivos-prometheus-data, masivos-grafana-data, masivos-loki-data). Idempotente.
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

if ! command_exists docker; then
  log_error "docker no esta instalado. Ejecuta docker/install.sh primero."
  exit "$EXIT_GENERAL_ERROR"
fi

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
)

main() {
  local vol
  for vol in "${VOLUMES[@]}"; do
    if docker volume inspect "$vol" >/dev/null 2>&1; then
      log_info "El volumen '${vol}' ya existe; se omite."
    else
      log_info "Creando volumen '${vol}'."
      docker volume create "$vol" >/dev/null
    fi
  done
  log_success "volumes.sh completado para el entorno '${ENVIRONMENT}'."
}

main
