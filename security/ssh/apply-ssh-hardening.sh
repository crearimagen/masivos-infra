#!/usr/bin/env bash
# security/ssh/apply-ssh-hardening.sh — endurece sshd: solo clave publica, sin
# root, solo DEPLOY_USER, puerto SSH_PORT. Idempotente. Se niega a aplicar si
# no puede verificar que DEPLOY_USER ya tiene una clave publica instalada,
# para evitar dejar el servidor inaccesible por SSH.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# shellcheck source=../../bootstrap/lib.sh
source "${REPO_ROOT}/bootstrap/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod>

Instala /etc/ssh/sshd_config.d/99-masivos-hardening.conf: deshabilita
login por password y por root, restringe el acceso a DEPLOY_USER, y
cambia sshd al puerto SSH_PORT. Idempotente.

Requiere que bootstrap/users.sh se haya ejecutado antes (DEPLOY_USER
debe existir y tener una clave publica en authorized_keys).
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
if ! [[ "$SSH_PORT" =~ ^[0-9]+$ ]] || [[ "$SSH_PORT" -lt 1 || "$SSH_PORT" -gt 65535 ]]; then
  log_error "SSH_PORT invalido: '${SSH_PORT}'"
  exit "$EXIT_INVALID_USAGE"
fi
if [[ -z "${DEPLOY_USER:-}" ]]; then
  log_error "DEPLOY_USER no esta definido en environments/${ENVIRONMENT}/.env"
  exit "$EXIT_INVALID_USAGE"
fi

readonly DROPIN_PATH="/etc/ssh/sshd_config.d/99-masivos-hardening.conf"
readonly TEMPLATE_PATH="${SCRIPT_DIR}/sshd-masivos.conf.template"

verify_deploy_user_has_ssh_key() {
  local home_dir auth_keys
  if ! id "$DEPLOY_USER" >/dev/null 2>&1; then
    log_error "El usuario '${DEPLOY_USER}' no existe. Ejecuta bootstrap/users.sh primero."
    exit "$EXIT_GENERAL_ERROR"
  fi
  home_dir="$(getent passwd "$DEPLOY_USER" | cut -d: -f6)"
  auth_keys="${home_dir}/.ssh/authorized_keys"
  if [[ ! -s "$auth_keys" ]]; then
    log_error "'${auth_keys}' no existe o esta vacio. Aplicar este hardening ahora dejaria el servidor sin acceso SSH. Ejecuta bootstrap/users.sh primero y verifica la clave."
    exit "$EXIT_GENERAL_ERROR"
  fi
  log_info "Verificado: '${DEPLOY_USER}' tiene al menos una clave publica en authorized_keys."
}

render_dropin() {
  sed \
    -e "s/__SSH_PORT__/${SSH_PORT}/g" \
    -e "s/__DEPLOY_USER__/${DEPLOY_USER}/g" \
    "$TEMPLATE_PATH"
}

apply_dropin() {
  local rendered backup_file
  rendered="$(render_dropin)"

  if [[ -f "$DROPIN_PATH" ]] && [[ "$(cat "$DROPIN_PATH")" == "$rendered" ]]; then
    log_info "El drop-in de sshd ya esta actualizado; se omite."
    return 1
  fi

  backup_file=""
  if [[ -f "$DROPIN_PATH" ]]; then
    backup_file="$(mktemp)"
    cp "$DROPIN_PATH" "$backup_file"
  fi

  printf '%s\n' "$rendered" | install -m 600 -o root -g root /dev/stdin "$DROPIN_PATH"

  if ! sshd -t 2>/tmp/masivos-sshd-test.err; then
    log_error "La configuracion de sshd resultante es invalida; revirtiendo:"
    cat /tmp/masivos-sshd-test.err >&2
    if [[ -n "$backup_file" ]]; then
      install -m 600 -o root -g root "$backup_file" "$DROPIN_PATH"
      rm -f "$backup_file"
    else
      rm -f "$DROPIN_PATH"
    fi
    rm -f /tmp/masivos-sshd-test.err
    exit "$EXIT_GENERAL_ERROR"
  fi
  rm -f /tmp/masivos-sshd-test.err
  [[ -n "$backup_file" ]] && rm -f "$backup_file"

  log_info "Drop-in de sshd instalado en ${DROPIN_PATH} (puerto ${SSH_PORT}, usuario permitido: ${DEPLOY_USER})."
  return 0
}

reload_sshd() {
  systemctl reload ssh
  log_info "sshd recargado. Antes de cerrar esta sesion, verifica en OTRA terminal: ssh -p ${SSH_PORT} ${DEPLOY_USER}@<IP>"
}

main() {
  verify_deploy_user_has_ssh_key
  if apply_dropin; then
    reload_sshd
  fi
  log_success "apply-ssh-hardening.sh completado para el entorno '${ENVIRONMENT}'."
}

main
