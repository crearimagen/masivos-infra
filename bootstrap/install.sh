#!/usr/bin/env bash
# bootstrap/install.sh — orquesta la provision base de un Ubuntu 24.04 recien instalado.
# Ejecuta en orden: packages.sh, timezone.sh, hostname.sh, users.sh. Idempotente.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=./lib.sh
source "${SCRIPT_DIR}/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod>

Orquesta la provision base del servidor ejecutando, en orden:
  1. packages.sh   — paquetes base + actualizaciones automaticas
  2. timezone.sh    — zona horaria + sincronizacion NTP
  3. hostname.sh    — hostname mail.<DOMAIN_ROOT> + /etc/hosts
  4. users.sh       — usuario de despliegue con sudo y SSH por clave

Idempotente: puede re-ejecutarse sin efectos secundarios. Al terminar,
el servidor queda listo para ./security/hardening.sh.
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

readonly STEPS=(packages.sh timezone.sh hostname.sh users.sh)

main() {
  log_info "Iniciando bootstrap del entorno '${ENVIRONMENT}': ${STEPS[*]}"

  local step
  for step in "${STEPS[@]}"; do
    log_info "==> Ejecutando ${step}"
    if ! "${SCRIPT_DIR}/${step}" --environment "$ENVIRONMENT"; then
      log_error "${step} fallo. Bootstrap detenido; corrige el error e intenta de nuevo (es idempotente)."
      exit "$EXIT_GENERAL_ERROR"
    fi
  done

  log_success "Bootstrap completo para el entorno '${ENVIRONMENT}'."
  log_info "Siguiente paso: ./security/hardening.sh --environment ${ENVIRONMENT}"
}

main
