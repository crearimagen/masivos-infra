#!/usr/bin/env bash
# services/nginx/scripts/generate-cloudflare-credentials.sh — genera el
# archivo de credenciales que certbot-dns-cloudflare necesita, a partir de
# CLOUDFLARE_API_TOKEN (environments/<env>/.env, ver docs/dns.md). El
# archivo nunca se versiona (permisos 600, excluido por .gitignore).
# Idempotente: solo reescribe si el contenido cambio.
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

Genera services/nginx/secrets/cloudflare.ini a partir de
CLOUDFLARE_API_TOKEN (environments/<env>/.env). Idempotente.
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

if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  log_error "CLOUDFLARE_API_TOKEN no esta definido en environments/${ENVIRONMENT}/.env"
  exit "$EXIT_INVALID_USAGE"
fi

readonly SECRETS_DIR="${SERVICE_DIR}/secrets"
readonly CREDENTIALS_FILE="${SECRETS_DIR}/cloudflare.ini"

main() {
  mkdir -p "$SECRETS_DIR"
  chmod 700 "$SECRETS_DIR"

  local rendered="dns_cloudflare_api_token = ${CLOUDFLARE_API_TOKEN}"

  if [[ -f "$CREDENTIALS_FILE" ]] && [[ "$(cat "$CREDENTIALS_FILE")" == "$rendered" ]]; then
    log_info "cloudflare.ini ya esta actualizado; se omite."
  else
    printf '%s\n' "$rendered" > "$CREDENTIALS_FILE"
    chmod 600 "$CREDENTIALS_FILE"
    log_info "cloudflare.ini generado en ${CREDENTIALS_FILE}."
  fi

  log_success "generate-cloudflare-credentials.sh completado para el entorno '${ENVIRONMENT}'."
}

main
