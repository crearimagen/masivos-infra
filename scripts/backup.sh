#!/usr/bin/env bash
# scripts/backup.sh — orquesta el backup de todos los servicios que tienen
# uno implementado (postgres, mariadb). redis/rabbitmq/postal quedaron
# deliberadamente sin backup formal en sus sprints (ver docs/backup.md) -
# este script no fabrica soporte para ellos. Pensado para cron.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../bootstrap/lib.sh
source "${REPO_ROOT}/bootstrap/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod>

Ejecuta, en orden, el backup de cada servicio que tiene uno
implementado:
  - services/postgres/backup/backup-postgres.sh
  - services/mariadb/backup/backup-mariadb.sh

redis, rabbitmq y postal no tienen backup implementado (ver
docs/backup.md) - no se invocan aqui. Continua con el resto si uno
falla, y reporta un resumen al final; exit 1 si alguno fallo.
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

load_environment_file "$ENVIRONMENT" "$REPO_ROOT"

readonly BACKUP_SCRIPTS=(
  "services/postgres/backup/backup-postgres.sh"
  "services/mariadb/backup/backup-mariadb.sh"
)

FAILURES=0

main() {
  local script
  for script in "${BACKUP_SCRIPTS[@]}"; do
    log_info "==> Ejecutando ${script}"
    if "${REPO_ROOT}/${script}" --environment "$ENVIRONMENT"; then
      log_info "[PASS] ${script}"
    else
      log_error "[FAIL] ${script}"
      FAILURES=$((FAILURES + 1))
    fi
  done

  if [[ "$FAILURES" -eq 0 ]]; then
    log_success "backup.sh completado sin errores para el entorno '${ENVIRONMENT}'."
    exit "$EXIT_OK"
  else
    log_error "backup.sh: ${FAILURES} backup(s) fallaron para el entorno '${ENVIRONMENT}'."
    exit "$EXIT_GENERAL_ERROR"
  fi
}

main
