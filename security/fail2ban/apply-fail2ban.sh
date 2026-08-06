#!/usr/bin/env bash
# security/fail2ban/apply-fail2ban.sh — instala y configura Fail2Ban para sshd.
# Idempotente. Jails adicionales (Postal, Nginx) se agregan en sus propios
# sprints (services/postal, services/nginx) como archivos separados en
# /etc/fail2ban/jail.d/, sin modificar este script.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=../../bootstrap/lib.sh
source "${REPO_ROOT}/bootstrap/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod>

Instala fail2ban si falta y configura el jail [sshd] apuntando a
SSH_PORT, con backoff exponencial de baneo. Idempotente.
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

readonly JAIL_PATH="/etc/fail2ban/jail.d/masivos-sshd.local"
readonly TEMPLATE_PATH="${SCRIPT_DIR}/jail-masivos-sshd.local.template"

ensure_fail2ban_installed() {
  if command_exists fail2ban-client; then
    log_info "fail2ban ya esta instalado; se omite instalacion."
    return
  fi
  log_info "Instalando fail2ban."
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends fail2ban
}

apply_jail_config() {
  local rendered
  rendered="$(sed -e "s/__SSH_PORT__/${SSH_PORT}/g" "$TEMPLATE_PATH")"

  if [[ -f "$JAIL_PATH" ]] && [[ "$(cat "$JAIL_PATH")" == "$rendered" ]]; then
    log_info "El jail de sshd ya esta actualizado; se omite."
    return 1
  fi

  printf '%s\n' "$rendered" | install -m 644 -o root -g root /dev/stdin "$JAIL_PATH"
  log_info "Jail de fail2ban instalado en ${JAIL_PATH} (puerto ${SSH_PORT})."
  return 0
}

enable_and_reload() {
  systemctl enable --now fail2ban >/dev/null 2>&1 || true
  systemctl reload fail2ban || systemctl restart fail2ban
  log_info "fail2ban recargado."
}

main() {
  ensure_fail2ban_installed
  if apply_jail_config; then
    enable_and_reload
  elif ! systemctl is-active --quiet fail2ban; then
    enable_and_reload
  fi
  log_success "apply-fail2ban.sh completado para el entorno '${ENVIRONMENT}'."
}

main
