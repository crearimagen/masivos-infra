#!/usr/bin/env bash
# security/ufw/apply-ufw-rules.sh — configura UFW con politica deny-by-default.
# Abre unicamente los puertos definidos en docs/architecture.md. Idempotente
# (los comandos de ufw son naturalmente idempotentes: repetir una regla existente
# es un no-op).
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=../../bootstrap/lib.sh
source "${REPO_ROOT}/bootstrap/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod>

Instala ufw si falta, configura politica deny-incoming/allow-outgoing,
abre SSH_PORT, 25, 587, 465, 80, 443, y habilita ufw. Idempotente.
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
require_ubuntu_24_04
load_environment_file "$ENVIRONMENT" "$REPO_ROOT"

if [[ -z "${SSH_PORT:-}" ]]; then
  log_error "SSH_PORT no esta definido en environments/${ENVIRONMENT}/.env"
  exit "$EXIT_INVALID_USAGE"
fi

# Puertos HTTP/SMTP fijos segun docs/architecture.md — no dependen del entorno.
readonly TCP_PORTS=("$SSH_PORT" 25 587 465 80 443)

ensure_ufw_installed() {
  if command_exists ufw; then
    log_info "ufw ya esta instalado; se omite instalacion."
    return
  fi
  log_info "Instalando ufw."
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ufw
}

configure_defaults() {
  log_info "Configurando politicas por defecto (deny incoming, allow outgoing)."
  ufw default deny incoming
  ufw default allow outgoing
}

open_required_ports() {
  local port
  for port in "${TCP_PORTS[@]}"; do
    log_info "Permitiendo puerto ${port}/tcp."
    ufw allow "${port}/tcp"
  done
}

enable_ufw() {
  if ufw status | grep -q "Status: active"; then
    log_info "ufw ya esta activo; se omite 'ufw enable'."
  else
    log_info "Habilitando ufw."
    ufw --force enable
  fi
}

main() {
  ensure_ufw_installed
  configure_defaults
  open_required_ports
  enable_ufw
  log_success "apply-ufw-rules.sh completado para el entorno '${ENVIRONMENT}'."
  ufw status verbose
}

main
