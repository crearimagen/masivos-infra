#!/usr/bin/env bash
# bootstrap/users.sh — crea el usuario de despliegue no-root con sudo y acceso SSH por clave.
# Bloquea el login por password de ese usuario y de root. Idempotente.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=./lib.sh
source "${SCRIPT_DIR}/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod>

Crea (si no existe) el usuario definido en DEPLOY_USER, lo agrega al
grupo sudo, instala la clave publica DEPLOY_USER_SSH_PUBLIC_KEY en su
authorized_keys y bloquea el login por password para ese usuario y
para root (solo queda disponible el acceso por clave SSH). Idempotente.
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

if [[ -z "${DEPLOY_USER:-}" ]]; then
  log_error "DEPLOY_USER no esta definido en environments/${ENVIRONMENT}/.env"
  exit "$EXIT_INVALID_USAGE"
fi

if [[ -z "${DEPLOY_USER_SSH_PUBLIC_KEY:-}" ]]; then
  log_error "DEPLOY_USER_SSH_PUBLIC_KEY no esta definido en environments/${ENVIRONMENT}/.env"
  exit "$EXIT_INVALID_USAGE"
fi

if [[ "$DEPLOY_USER" == "root" ]]; then
  log_error "DEPLOY_USER no puede ser 'root'."
  exit "$EXIT_INVALID_USAGE"
fi

create_user() {
  if id "$DEPLOY_USER" >/dev/null 2>&1; then
    log_info "El usuario '${DEPLOY_USER}' ya existe; se omite creacion."
  else
    log_info "Creando usuario '${DEPLOY_USER}'."
    useradd --create-home --shell /bin/bash "$DEPLOY_USER"
  fi
}

grant_sudo() {
  if id -nG "$DEPLOY_USER" | tr ' ' '\n' | grep -qx sudo; then
    log_info "'${DEPLOY_USER}' ya pertenece al grupo sudo; se omite."
  else
    log_info "Agregando '${DEPLOY_USER}' al grupo sudo."
    usermod -aG sudo "$DEPLOY_USER"
  fi
}

install_ssh_key() {
  local home_dir ssh_dir auth_keys
  home_dir="$(getent passwd "$DEPLOY_USER" | cut -d: -f6)"
  if [[ -z "$home_dir" || ! -d "$home_dir" ]]; then
    log_error "No se pudo resolver el home de '${DEPLOY_USER}'."
    exit "$EXIT_GENERAL_ERROR"
  fi
  ssh_dir="${home_dir}/.ssh"
  auth_keys="${ssh_dir}/authorized_keys"

  install -d -m 700 -o "$DEPLOY_USER" -g "$DEPLOY_USER" "$ssh_dir"
  [[ -f "$auth_keys" ]] || install -m 600 -o "$DEPLOY_USER" -g "$DEPLOY_USER" /dev/null "$auth_keys"

  if grep -qF "$DEPLOY_USER_SSH_PUBLIC_KEY" "$auth_keys"; then
    log_info "La clave publica ya esta registrada para '${DEPLOY_USER}'; se omite."
  else
    log_info "Instalando clave publica SSH para '${DEPLOY_USER}'."
    printf '%s\n' "$DEPLOY_USER_SSH_PUBLIC_KEY" >> "$auth_keys"
  fi

  chmod 600 "$auth_keys"
  chown "${DEPLOY_USER}:${DEPLOY_USER}" "$auth_keys"
}

lock_password_logins() {
  local user status
  for user in "$DEPLOY_USER" root; do
    status="$(passwd -S "$user" 2>/dev/null | awk '{print $2}')"
    if [[ "$status" == "L" ]]; then
      log_info "El login por password de '${user}' ya esta bloqueado; se omite."
    else
      log_info "Bloqueando login por password para '${user}' (solo acceso por clave SSH)."
      passwd -l "$user" >/dev/null
    fi
  done
}

main() {
  create_user
  grant_sudo
  install_ssh_key
  lock_password_logins
  log_success "users.sh completado para el entorno '${ENVIRONMENT}'. Usuario de despliegue: ${DEPLOY_USER}"
}

main
