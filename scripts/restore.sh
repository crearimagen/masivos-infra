#!/usr/bin/env bash
# scripts/restore.sh — envuelve el restore-<servicio>.sh correspondiente.
# Solo soporta los servicios que tienen restore implementado (postgres,
# mariadb) - ver docs/restore.md. Destructivo: delega el flag --force a
# cada script de servicio, que ya se niega a ejecutar sin el.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../bootstrap/lib.sh
source "${REPO_ROOT}/bootstrap/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod> --service <postgres|mariadb> --file <ruta> --force

Ejecuta el restore-<servicio>.sh correspondiente. DESTRUCTIVO. El flag
--force es obligatorio (se reenvia al script del servicio, que ya se
niega a ejecutar sin el).
EOF
}

ENVIRONMENT=""
SERVICE=""
FILE=""
FORCE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment) ENVIRONMENT="${2:-}"; shift 2 ;;
    --service) SERVICE="${2:-}"; shift 2 ;;
    --file) FILE="${2:-}"; shift 2 ;;
    --force) FORCE=1; shift ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    *) log_error "Argumento desconocido: $1"; usage; exit "$EXIT_INVALID_USAGE" ;;
  esac
done

if [[ -z "$ENVIRONMENT" || -z "$SERVICE" || -z "$FILE" ]]; then
  log_error "Faltan argumentos: --environment, --service y --file son obligatorios."
  usage
  exit "$EXIT_INVALID_USAGE"
fi

load_environment_file "$ENVIRONMENT" "$REPO_ROOT"

readonly SUPPORTED_SERVICES=(postgres mariadb)
if ! printf '%s\n' "${SUPPORTED_SERVICES[@]}" | grep -qx "$SERVICE"; then
  log_error "Servicio '${SERVICE}' no tiene restore implementado. Soportados: ${SUPPORTED_SERVICES[*]} (ver docs/restore.md)."
  exit "$EXIT_INVALID_USAGE"
fi

readonly RESTORE_SCRIPT="${REPO_ROOT}/services/${SERVICE}/backup/restore-${SERVICE}.sh"
if [[ ! -x "$RESTORE_SCRIPT" ]]; then
  log_error "No existe o no es ejecutable: ${RESTORE_SCRIPT}"
  exit "$EXIT_GENERAL_ERROR"
fi

main() {
  local args=(--environment "$ENVIRONMENT" --file "$FILE")
  if [[ "$FORCE" -eq 1 ]]; then
    args+=(--force)
  fi
  "$RESTORE_SCRIPT" "${args[@]}"
  log_success "restore.sh completado para '${SERVICE}' en el entorno '${ENVIRONMENT}'."
}

main
