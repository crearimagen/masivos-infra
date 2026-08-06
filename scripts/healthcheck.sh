#!/usr/bin/env bash
# scripts/healthcheck.sh — agrega el estado de "docker healthcheck" de
# todos los contenedores masivos-* en un solo reporte. Solo lectura, no
# modifica nada. Exit 0 si todos estan healthy (o sin healthcheck definido
# pero corriendo), 1 si alguno esta unhealthy o no esta corriendo.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../bootstrap/lib.sh
source "${REPO_ROOT}/bootstrap/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0")

Reporta el estado de todos los contenedores masivos-*. No requiere
--environment: inspecciona el estado real de Docker, no configuracion.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit "$EXIT_OK"
fi

if ! command_exists docker; then
  log_error "docker no esta disponible."
  exit "$EXIT_GENERAL_ERROR"
fi

FAILURES=0

main() {
  local containers container running health
  containers="$(docker ps -a --filter "name=masivos-" --format '{{.Names}}' | sort)"

  if [[ -z "$containers" ]]; then
    log_error "No se encontro ningun contenedor 'masivos-*'. ¿Esta desplegado el stack?"
    exit "$EXIT_GENERAL_ERROR"
  fi

  printf '%-32s %-10s %-12s\n' "CONTENEDOR" "ESTADO" "HEALTHCHECK"
  printf '%-32s %-10s %-12s\n' "----------" "------" "-----------"

  while IFS= read -r container; do
    running="$(docker inspect --format '{{.State.Status}}' "$container" 2>/dev/null || echo "desconocido")"
    health="$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}(sin healthcheck){{end}}' "$container" 2>/dev/null || echo "desconocido")"

    printf '%-32s %-10s %-12s\n' "$container" "$running" "$health"

    if [[ "$running" != "running" ]]; then
      FAILURES=$((FAILURES + 1))
    elif [[ "$health" == "unhealthy" ]]; then
      FAILURES=$((FAILURES + 1))
    fi
  done <<< "$containers"

  echo
  if [[ "$FAILURES" -eq 0 ]]; then
    log_success "healthcheck.sh: todos los contenedores estan corriendo y saludables."
    exit "$EXIT_OK"
  else
    log_error "healthcheck.sh: ${FAILURES} contenedor(es) con problemas."
    exit "$EXIT_GENERAL_ERROR"
  fi
}

main
