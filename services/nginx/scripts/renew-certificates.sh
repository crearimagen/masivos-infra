#!/usr/bin/env bash
# services/nginx/scripts/renew-certificates.sh — renueva certificados
# proximos a expirar (certbot renew es idempotente: no hace nada si
# ninguno esta cerca de expirar) y recarga nginx solo si renovo algo.
# Pensado para ejecutarse via cron (scripts/backup.sh y demas
# orquestacion de cron llega en el Sprint 12; hasta entonces, invocar a
# mano o desde un cron propio del operador).
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

Ejecuta 'certbot renew' (via el servicio 'certbot') y recarga nginx si
se renovo algun certificado. Idempotente (certbot renew no hace nada si
no hay certificados proximos a expirar).
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

if ! command_exists docker; then
  log_error "docker no esta disponible."
  exit "$EXIT_GENERAL_ERROR"
fi

main() {
  local output
  log_info "Ejecutando certbot renew."
  output="$(cd "$SERVICE_DIR" && docker compose -f docker-compose.yml run --rm certbot renew \
    --dns-cloudflare \
    --dns-cloudflare-credentials /secrets/cloudflare.ini \
    --dns-cloudflare-propagation-seconds 60 2>&1)"
  echo "$output"

  if echo "$output" | grep -q "No renewals were attempted"; then
    log_info "Ningun certificado necesitaba renovacion."
  else
    if docker ps --format '{{.Names}}' | grep -qx masivos-nginx; then
      log_info "Recargando nginx tras renovacion."
      docker exec masivos-nginx nginx -s reload
    fi
  fi

  log_success "renew-certificates.sh completado para el entorno '${ENVIRONMENT}'."
}

main
