#!/usr/bin/env bash
# services/nginx/scripts/issue-certificate.sh — emite el certificado
# wildcard inicial via certbot-dns-cloudflare (DNS-01). Ejecutar una sola
# vez por entorno (o cuando se agregue un dominio nuevo) - las renovaciones
# las hace renew-certificates.sh.
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

Emite (via el servicio 'certbot' de docker-compose.yml) un certificado
para DOMAIN_ROOT y *.DOMAIN_ROOT usando DNS-01 sobre Cloudflare. Requiere
services/nginx/secrets/cloudflare.ini (generate-cloudflare-credentials.sh).
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

if [[ -z "${DOMAIN_ROOT:-}" || -z "${TLS_ADMIN_EMAIL:-}" ]]; then
  log_error "DOMAIN_ROOT y TLS_ADMIN_EMAIL deben estar definidos en environments/${ENVIRONMENT}/.env"
  exit "$EXIT_INVALID_USAGE"
fi
if [[ ! -f "${SERVICE_DIR}/secrets/cloudflare.ini" ]]; then
  log_error "No existe ${SERVICE_DIR}/secrets/cloudflare.ini. Ejecuta generate-cloudflare-credentials.sh primero."
  exit "$EXIT_GENERAL_ERROR"
fi
if ! command_exists docker; then
  log_error "docker no esta disponible."
  exit "$EXIT_GENERAL_ERROR"
fi

main() {
  log_info "Emitiendo certificado para ${DOMAIN_ROOT} y *.${DOMAIN_ROOT}."
  (
    cd "$SERVICE_DIR"
    docker compose -f docker-compose.yml run --rm certbot certonly \
      --dns-cloudflare \
      --dns-cloudflare-credentials /secrets/cloudflare.ini \
      --dns-cloudflare-propagation-seconds 60 \
      -d "$DOMAIN_ROOT" \
      -d "*.${DOMAIN_ROOT}" \
      --email "$TLS_ADMIN_EMAIL" \
      --agree-tos \
      --non-interactive
  )
  log_success "issue-certificate.sh completado para el entorno '${ENVIRONMENT}'. Certificado en services/nginx/ssl/live/${DOMAIN_ROOT}/"
}

main
