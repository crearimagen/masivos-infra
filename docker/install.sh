#!/usr/bin/env bash
# docker/install.sh — instala Docker Engine (repositorio oficial), aplica
# daemon.json de produccion, agrega DEPLOY_USER al grupo docker, y crea la
# red y los volumenes. Idempotente.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../bootstrap/lib.sh
source "${REPO_ROOT}/bootstrap/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod>

Instala Docker Engine desde el repositorio oficial de Docker, aplica
docker/daemon.json, agrega DEPLOY_USER al grupo 'docker', y ejecuta
networks.sh y volumes.sh. Idempotente. Requiere que
security/hardening.sh se haya ejecutado antes (necesita
net.ipv4.ip_forward=1, ya garantizado por security/sysctl/).
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

readonly DOCKER_PACKAGES=(
  docker-ce
  docker-ce-cli
  containerd.io
  docker-buildx-plugin
  docker-compose-plugin
)
readonly DAEMON_JSON_SOURCE="${SCRIPT_DIR}/daemon.json"
readonly DAEMON_JSON_TARGET="/etc/docker/daemon.json"

ensure_docker_repo() {
  local keyring="/etc/apt/keyrings/docker.asc"
  local list_file="/etc/apt/sources.list.d/docker.list"

  if [[ -f "$keyring" ]] && [[ -f "$list_file" ]]; then
    log_info "El repositorio oficial de Docker ya esta configurado; se omite."
    return
  fi

  log_info "Configurando el repositorio oficial de Docker."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o "$keyring"
  chmod a+r "$keyring"

  local arch codename
  arch="$(dpkg --print-architecture)"
  # shellcheck disable=SC1091
  codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"

  echo "deb [arch=${arch} signed-by=${keyring}] https://download.docker.com/linux/ubuntu ${codename} stable" \
    > "$list_file"

  DEBIAN_FRONTEND=noninteractive apt-get update -y
}

ensure_docker_packages() {
  local pkg missing=()
  for pkg in "${DOCKER_PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      missing+=("$pkg")
    fi
  done

  if [[ "${#missing[@]}" -eq 0 ]]; then
    log_info "Todos los paquetes de Docker ya estan instalados; nada que hacer."
    return
  fi

  log_info "Instalando paquetes de Docker: ${missing[*]}"
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${missing[@]}"
}

enable_docker_service() {
  systemctl enable --now docker
  log_info "Servicio docker habilitado y activo."
}

apply_daemon_json() {
  mkdir -p /etc/docker

  if [[ -f "$DAEMON_JSON_TARGET" ]] && cmp -s "$DAEMON_JSON_SOURCE" "$DAEMON_JSON_TARGET"; then
    log_info "${DAEMON_JSON_TARGET} ya esta actualizado; se omite."
    return
  fi

  install -m 644 -o root -g root "$DAEMON_JSON_SOURCE" "$DAEMON_JSON_TARGET"
  log_info "${DAEMON_JSON_TARGET} instalado/actualizado; reiniciando docker (live-restore mantiene los contenedores activos)."
  systemctl restart docker
}

add_deploy_user_to_docker_group() {
  if ! getent group docker >/dev/null 2>&1; then
    log_error "El grupo 'docker' no existe tras instalar Docker; algo fallo en la instalacion."
    exit "$EXIT_GENERAL_ERROR"
  fi
  if id -nG "$DEPLOY_USER" | tr ' ' '\n' | grep -qx docker; then
    log_info "'${DEPLOY_USER}' ya pertenece al grupo docker; se omite."
  else
    log_info "Agregando '${DEPLOY_USER}' al grupo docker."
    usermod -aG docker "$DEPLOY_USER"
    log_warn "'${DEPLOY_USER}' debe cerrar sesion y volver a entrar para que la membresia al grupo docker tenga efecto."
  fi
}

verify_docker_functional() {
  if ! docker info >/dev/null 2>&1; then
    log_error "El daemon de Docker no responde tras la instalacion."
    exit "$EXIT_GENERAL_ERROR"
  fi
  if ! docker compose version >/dev/null 2>&1; then
    log_error "El plugin 'docker compose' no esta disponible."
    exit "$EXIT_GENERAL_ERROR"
  fi
  log_info "Docker Engine y el plugin compose responden correctamente."
}

main() {
  ensure_docker_repo
  ensure_docker_packages
  enable_docker_service
  apply_daemon_json
  add_deploy_user_to_docker_group
  verify_docker_functional

  log_info "==> Ejecutando networks.sh"
  "${SCRIPT_DIR}/networks.sh" --environment "$ENVIRONMENT"

  log_info "==> Ejecutando volumes.sh"
  "${SCRIPT_DIR}/volumes.sh" --environment "$ENVIRONMENT"

  log_success "docker/install.sh completado para el entorno '${ENVIRONMENT}'."
  log_info "Siguiente paso: implementar y desplegar services/postgres (Sprint 4)."
}

main
