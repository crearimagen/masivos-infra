#!/usr/bin/env bash
# security/hardening.sh — orquesta el endurecimiento de seguridad del servidor.
# Orden: sysctl, ufw, fail2ban, ssh (el mas riesgoso, al final), logrotate.
# Idempotente. Requiere que bootstrap/install.sh se haya ejecutado antes.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../bootstrap/lib.sh
source "${REPO_ROOT}/bootstrap/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod>

Orquesta el endurecimiento de seguridad ejecutando, en orden:
  1. sysctl/apply-sysctl.sh          — kernel hardening (preserva ip_forward)
  2. ufw/apply-ufw-rules.sh          — firewall deny-by-default
  3. fail2ban/apply-fail2ban.sh      — baneo automatico sobre sshd
  4. ssh/apply-ssh-hardening.sh      — solo clave publica, puerto SSH_PORT
  5. logrotate/apply-logrotate.sh    — rotacion de logs propios

El orden importa: ufw abre SSH_PORT antes de que sshd deje de escuchar
en el 22, y ssh se endurece al final por ser el paso de mayor riesgo.
Idempotente. Al terminar, el servidor queda listo para ./docker/install.sh.
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

readonly STEPS=(
  "sysctl/apply-sysctl.sh"
  "ufw/apply-ufw-rules.sh"
  "fail2ban/apply-fail2ban.sh"
  "ssh/apply-ssh-hardening.sh"
  "logrotate/apply-logrotate.sh"
)

main() {
  log_info "Iniciando hardening del entorno '${ENVIRONMENT}': ${STEPS[*]}"

  local step
  for step in "${STEPS[@]}"; do
    log_info "==> Ejecutando ${step}"
    if ! "${SCRIPT_DIR}/${step}" --environment "$ENVIRONMENT"; then
      log_error "${step} fallo. Hardening detenido; corrige el error e intenta de nuevo (es idempotente)."
      exit "$EXIT_GENERAL_ERROR"
    fi
  done

  log_success "Hardening completo para el entorno '${ENVIRONMENT}'."
  log_info "SSH ahora requiere: ssh -p ${SSH_PORT} ${DEPLOY_USER}@<IP>"
  log_info "Siguiente paso: ./docker/install.sh --environment ${ENVIRONMENT}"
}

main
