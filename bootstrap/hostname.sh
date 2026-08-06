#!/usr/bin/env bash
# bootstrap/hostname.sh — configura el hostname del servidor como mail.<DOMAIN_ROOT>.
# Debe coincidir con el registro PTR documentado en docs/dns.md. Idempotente.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=./lib.sh
source "${SCRIPT_DIR}/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod>

Configura el hostname del sistema como mail.<DOMAIN_ROOT> (DOMAIN_ROOT
proviene de environments/<env>/.env) y asegura la entrada
correspondiente en /etc/hosts. Idempotente.
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

if [[ -z "${DOMAIN_ROOT:-}" ]]; then
  log_error "DOMAIN_ROOT no esta definido en environments/${ENVIRONMENT}/.env"
  exit "$EXIT_INVALID_USAGE"
fi

readonly TARGET_HOSTNAME="mail.${DOMAIN_ROOT}"
readonly TARGET_SHORT_NAME="${TARGET_HOSTNAME%%.*}"

set_hostname() {
  local current
  current="$(hostname)"
  if [[ "$current" == "$TARGET_HOSTNAME" ]]; then
    log_info "El hostname ya es '${TARGET_HOSTNAME}'; se omite."
  else
    log_info "Cambiando hostname de '${current}' a '${TARGET_HOSTNAME}'."
    hostnamectl set-hostname "$TARGET_HOSTNAME"
  fi
}

update_etc_hosts() {
  if grep -Eq "^127\.0\.1\.1[[:space:]]+${TARGET_HOSTNAME}([[:space:]]|\$)" /etc/hosts; then
    log_info "/etc/hosts ya contiene la entrada para '${TARGET_HOSTNAME}'; se omite."
    return
  fi
  log_info "Actualizando /etc/hosts con '${TARGET_HOSTNAME}'."
  # elimina cualquier linea previa de 127.0.1.1 para evitar duplicados/entradas obsoletas
  sed -i '/^127\.0\.1\.1[[:space:]]/d' /etc/hosts
  printf '127.0.1.1\t%s\t%s\n' "$TARGET_HOSTNAME" "$TARGET_SHORT_NAME" >> /etc/hosts
}

main() {
  set_hostname
  update_etc_hosts
  log_success "hostname.sh completado para el entorno '${ENVIRONMENT}'. Hostname: ${TARGET_HOSTNAME}"
}

main
