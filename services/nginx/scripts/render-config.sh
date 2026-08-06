#!/usr/bin/env bash
# services/nginx/scripts/render-config.sh — renderiza conf.d/*.conf.template
# a conf.d/*.conf sustituyendo los valores de services/nginx/.env.
# Idempotente: solo reescribe si el contenido renderizado cambio, y en ese
# caso recarga nginx si el contenedor esta corriendo.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${SERVICE_DIR}/../.." && pwd)"
# shellcheck source=../../../bootstrap/lib.sh
source "${REPO_ROOT}/bootstrap/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0")

Renderiza services/nginx/conf.d/*.conf.template a *.conf sustituyendo
POSTAL_WEB_HOSTNAME y DOMAIN_ROOT desde services/nginx/.env. Idempotente.
No requiere --environment: opera unicamente sobre services/nginx/.env,
que ya es especifico del servidor donde corre.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit "$EXIT_OK"
fi

readonly SERVICE_ENV_FILE="${SERVICE_DIR}/.env"
if [[ ! -f "$SERVICE_ENV_FILE" ]]; then
  log_error "No existe ${SERVICE_ENV_FILE}. Copia .env.example a .env y completalo."
  exit "$EXIT_MISSING_ENV_FILE"
fi
set -o allexport
# shellcheck disable=SC1090
source "$SERVICE_ENV_FILE"
set +o allexport

if [[ -z "${POSTAL_WEB_HOSTNAME:-}" ]]; then
  log_error "POSTAL_WEB_HOSTNAME no esta definido en ${SERVICE_ENV_FILE}"
  exit "$EXIT_INVALID_USAGE"
fi
if [[ -z "${DOMAIN_ROOT:-}" ]]; then
  log_error "DOMAIN_ROOT no esta definido en ${SERVICE_ENV_FILE}"
  exit "$EXIT_INVALID_USAGE"
fi

readonly CONF_DIR="${SERVICE_DIR}/conf.d"
CHANGED=0

render_template() {
  local template="$1"
  local output="${template%.template}"
  local rendered
  rendered="$(sed \
    -e "s/__POSTAL_WEB_HOSTNAME__/${POSTAL_WEB_HOSTNAME}/g" \
    -e "s/__DOMAIN_ROOT__/${DOMAIN_ROOT}/g" \
    "$template")"

  if [[ -f "$output" ]] && [[ "$(cat "$output")" == "$rendered" ]]; then
    log_info "$(basename "$output") ya esta actualizado; se omite."
    return
  fi

  printf '%s\n' "$rendered" > "$output"
  log_info "$(basename "$output") renderizado desde $(basename "$template")."
  CHANGED=1
}

reload_nginx_if_running() {
  if [[ "$CHANGED" -eq 0 ]]; then
    return
  fi
  if docker ps --format '{{.Names}}' | grep -qx masivos-nginx; then
    log_info "Recargando nginx (config cambio)."
    docker exec masivos-nginx nginx -s reload
  else
    log_info "masivos-nginx no esta corriendo; el cambio se aplicara en el proximo arranque."
  fi
}

main() {
  local template
  for template in "$CONF_DIR"/*.conf.template; do
    [[ -e "$template" ]] || continue
    render_template "$template"
  done
  reload_nginx_if_running
  log_success "render-config.sh completado."
}

main
