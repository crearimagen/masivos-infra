#!/usr/bin/env bash
# bootstrap/packages.sh — instala y mantiene actualizados los paquetes base del sistema.
# Idempotente: solo instala paquetes faltantes y solo refresca el indice de apt si esta desactualizado.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=./lib.sh
source "${SCRIPT_DIR}/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod>

Instala los paquetes base necesarios en Ubuntu 24.04 y configura
actualizaciones de seguridad automaticas (unattended-upgrades).
Idempotente.
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

readonly BASE_PACKAGES=(
  ca-certificates
  curl
  wget
  gnupg
  lsb-release
  apt-transport-https
  software-properties-common
  unzip
  git
  jq
  htop
  net-tools
  chrony
  logrotate
  unattended-upgrades
  apt-listchanges
)

readonly APT_CACHE_MAX_AGE_SECONDS=86400

apt_index_is_stale() {
  local stamp_file="/var/lib/apt/periodic/update-success-stamp"
  if [[ ! -f "$stamp_file" ]]; then
    return 0
  fi
  local now last_update age
  now="$(date +%s)"
  last_update="$(stat -c %Y "$stamp_file")"
  age=$(( now - last_update ))
  [[ "$age" -ge "$APT_CACHE_MAX_AGE_SECONDS" ]]
}

update_apt_index() {
  if apt_index_is_stale; then
    log_info "Indice de apt desactualizado (>24h); ejecutando apt-get update."
    DEBIAN_FRONTEND=noninteractive apt-get update -y
  else
    log_info "Indice de apt actualizado recientemente; se omite apt-get update."
  fi
}

missing_packages() {
  local pkg
  for pkg in "${BASE_PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      echo "$pkg"
    fi
  done
}

install_missing_packages() {
  local missing=()
  while IFS= read -r pkg; do
    [[ -n "$pkg" ]] && missing+=("$pkg")
  done < <(missing_packages)

  if [[ "${#missing[@]}" -eq 0 ]]; then
    log_info "Todos los paquetes base ya estan instalados; nada que hacer."
    return
  fi

  log_info "Instalando paquetes faltantes: ${missing[*]}"
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
}

configure_unattended_upgrades() {
  local conf="/etc/apt/apt.conf.d/20auto-upgrades"
  local desired
  desired='APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
'
  if [[ -f "$conf" ]] && [[ "$(cat "$conf")" == "$desired" ]]; then
    log_info "unattended-upgrades ya esta configurado; se omite."
    return
  fi
  log_info "Configurando actualizaciones de seguridad automaticas."
  printf '%s' "$desired" > "$conf"
}

main() {
  update_apt_index
  install_missing_packages
  configure_unattended_upgrades
  log_success "packages.sh completado para el entorno '${ENVIRONMENT}'."
}

main
