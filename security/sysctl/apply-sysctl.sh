#!/usr/bin/env bash
# security/sysctl/apply-sysctl.sh — instala los parametros de kernel endurecidos.
# Idempotente: solo copia y reaplica si el contenido cambio.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=../../bootstrap/lib.sh
source "${REPO_ROOT}/bootstrap/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod>

Instala security/sysctl/99-masivos-hardening.conf en
/etc/sysctl.d/ y aplica los valores con 'sysctl --system'. Idempotente.
Nota: ip_forward se mantiene activo a proposito (requerido por Docker).
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

readonly SOURCE_CONF="${SCRIPT_DIR}/99-masivos-hardening.conf"
readonly TARGET_CONF="/etc/sysctl.d/99-masivos-hardening.conf"

apply_sysctl_file() {
  if [[ -f "$TARGET_CONF" ]] && cmp -s "$SOURCE_CONF" "$TARGET_CONF"; then
    log_info "${TARGET_CONF} ya esta actualizado; se omite copia."
  else
    install -m 644 -o root -g root "$SOURCE_CONF" "$TARGET_CONF"
    log_info "${TARGET_CONF} instalado/actualizado."
  fi

  log_info "Aplicando parametros con sysctl --system."
  sysctl --system >/dev/null
}

verify_ip_forward() {
  local value
  value="$(sysctl -n net.ipv4.ip_forward)"
  if [[ "$value" != "1" ]]; then
    log_error "net.ipv4.ip_forward quedo en '${value}' tras aplicar; Docker (Sprint 3) requiere que sea 1."
    exit "$EXIT_GENERAL_ERROR"
  fi
  log_info "Verificado: net.ipv4.ip_forward=1"
}

main() {
  apply_sysctl_file
  verify_ip_forward
  log_success "apply-sysctl.sh completado para el entorno '${ENVIRONMENT}'."
}

main
