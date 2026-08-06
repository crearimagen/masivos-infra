#!/usr/bin/env bash
# security/logrotate/apply-logrotate.sh — instala la rotacion de logs propios
# de masivos-infra (/var/log/masivos/*.log). Idempotente.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=../../bootstrap/lib.sh
source "${REPO_ROOT}/bootstrap/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod>

Instala security/logrotate/masivos.conf en /etc/logrotate.d/masivos y
valida la sintaxis con 'logrotate -d'. Idempotente.
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

readonly SOURCE_CONF="${SCRIPT_DIR}/masivos.conf"
readonly TARGET_CONF="/etc/logrotate.d/masivos"

main() {
  mkdir -p /var/log/masivos

  if [[ -f "$TARGET_CONF" ]] && cmp -s "$SOURCE_CONF" "$TARGET_CONF"; then
    log_info "${TARGET_CONF} ya esta actualizado; se omite."
  else
    install -m 644 -o root -g root "$SOURCE_CONF" "$TARGET_CONF"
    log_info "${TARGET_CONF} instalado/actualizado."
  fi

  if ! logrotate -d "$TARGET_CONF" >/tmp/masivos-logrotate-check.log 2>&1; then
    log_error "logrotate -d reporto un error de sintaxis en ${TARGET_CONF}:"
    cat /tmp/masivos-logrotate-check.log >&2
    rm -f /tmp/masivos-logrotate-check.log
    exit "$EXIT_GENERAL_ERROR"
  fi
  rm -f /tmp/masivos-logrotate-check.log

  log_success "apply-logrotate.sh completado para el entorno '${ENVIRONMENT}'."
}

main
