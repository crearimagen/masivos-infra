#!/usr/bin/env bash
# bootstrap/timezone.sh — configura la zona horaria del servidor y la sincronizacion NTP.
# Idempotente: solo cambia la zona horaria si difiere de TIMEZONE y solo habilita chrony si no esta activo.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=./lib.sh
source "${SCRIPT_DIR}/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod>

Configura la zona horaria del sistema (timedatectl) usando la variable
TIMEZONE de environments/<env>/.env, y habilita chrony para
sincronizacion NTP. Idempotente. Requiere que bootstrap/packages.sh se
haya ejecutado antes (provee chrony).
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

if [[ -z "${TIMEZONE:-}" ]]; then
  log_error "TIMEZONE no esta definido en environments/${ENVIRONMENT}/.env"
  exit "$EXIT_INVALID_USAGE"
fi

if ! command_exists timedatectl; then
  log_error "timedatectl no esta disponible en este sistema."
  exit "$EXIT_GENERAL_ERROR"
fi

if ! timedatectl list-timezones | grep -Fxq "$TIMEZONE"; then
  log_error "'${TIMEZONE}' no es una zona horaria valida (ver: timedatectl list-timezones)."
  exit "$EXIT_INVALID_USAGE"
fi

set_timezone() {
  local current
  current="$(timedatectl show --property=Timezone --value)"
  if [[ "$current" == "$TIMEZONE" ]]; then
    log_info "La zona horaria ya es '${TIMEZONE}'; se omite."
  else
    log_info "Cambiando zona horaria de '${current}' a '${TIMEZONE}'."
    timedatectl set-timezone "$TIMEZONE"
  fi
}

enable_chrony() {
  if ! command_exists chronyd && ! dpkg -s chrony >/dev/null 2>&1; then
    log_error "chrony no esta instalado. Ejecuta bootstrap/packages.sh primero."
    exit "$EXIT_GENERAL_ERROR"
  fi
  if systemctl is-active --quiet chrony; then
    log_info "chrony ya esta activo; se omite."
  else
    log_info "Habilitando y arrancando chrony para sincronizacion NTP."
    systemctl enable --now chrony
  fi
}

main() {
  set_timezone
  enable_chrony
  log_success "timezone.sh completado para el entorno '${ENVIRONMENT}'."
}

main
