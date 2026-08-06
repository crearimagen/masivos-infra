#!/usr/bin/env bash
# scripts/rollback.sh — revierte el docker-compose.yml de UN servicio a una
# referencia de Git anterior (commit/tag/rama) y recrea ese contenedor.
#
# LIMITE IMPORTANTE, no resuelto por este script: esto solo revierte la
# DEFINICION del servicio (tag de imagen, config montada) - NUNCA datos ni
# migraciones de esquema aplicadas. Si la version nueva ejecuto una
# migracion de base de datos incompatible con la version anterior, este
# script no la deshace. Para ese caso, la via es restore.sh con un backup
# anterior a la migracion.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../bootstrap/lib.sh
source "${REPO_ROOT}/bootstrap/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod> --service <nombre> --ref <git-ref>

Revierte services/<nombre>/docker-compose.yml al contenido que tenia en
<git-ref> (commit, tag o rama) y recrea el contenedor. Requiere que el
directorio de trabajo de Git este limpio para ese archivo (no
sobreescribe cambios sin commitear sin avisar).

LIMITE: solo revierte la definicion del servicio (imagen, config), NUNCA
datos ni migraciones de base de datos. Ver comentario al inicio del
script.
EOF
}

ENVIRONMENT=""
SERVICE=""
GIT_REF=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment) ENVIRONMENT="${2:-}"; shift 2 ;;
    --service) SERVICE="${2:-}"; shift 2 ;;
    --ref) GIT_REF="${2:-}"; shift 2 ;;
    -h|--help) usage; exit "$EXIT_OK" ;;
    *) log_error "Argumento desconocido: $1"; usage; exit "$EXIT_INVALID_USAGE" ;;
  esac
done

if [[ -z "$ENVIRONMENT" || -z "$SERVICE" || -z "$GIT_REF" ]]; then
  log_error "Faltan argumentos: --environment, --service y --ref son obligatorios."
  usage
  exit "$EXIT_INVALID_USAGE"
fi

load_environment_file "$ENVIRONMENT" "$REPO_ROOT"

readonly SERVICE_DIR="${REPO_ROOT}/services/${SERVICE}"
readonly COMPOSE_FILE="${SERVICE_DIR}/docker-compose.yml"
readonly RELATIVE_PATH="services/${SERVICE}/docker-compose.yml"

if [[ ! -d "$SERVICE_DIR" ]]; then
  log_error "No existe services/${SERVICE}/"
  exit "$EXIT_INVALID_USAGE"
fi
if ! command_exists git; then
  log_error "git no esta disponible."
  exit "$EXIT_GENERAL_ERROR"
fi

verify_ref_has_file() {
  if ! git -C "$REPO_ROOT" cat-file -e "${GIT_REF}:${RELATIVE_PATH}" 2>/dev/null; then
    log_error "No existe ${RELATIVE_PATH} en la referencia '${GIT_REF}'."
    exit "$EXIT_INVALID_USAGE"
  fi
}

verify_clean_worktree() {
  if ! git -C "$REPO_ROOT" diff --quiet -- "$RELATIVE_PATH" 2>/dev/null; then
    log_error "${RELATIVE_PATH} tiene cambios sin commitear. Guardalos (commit o stash) antes de hacer rollback."
    exit "$EXIT_GENERAL_ERROR"
  fi
}

main() {
  verify_ref_has_file
  verify_clean_worktree

  local current_content target_content
  current_content="$(cat "$COMPOSE_FILE")"
  target_content="$(git -C "$REPO_ROOT" show "${GIT_REF}:${RELATIVE_PATH}")"

  if [[ "$current_content" == "$target_content" ]]; then
    log_info "${RELATIVE_PATH} ya coincide con '${GIT_REF}'; se omite."
    exit "$EXIT_OK"
  fi

  log_info "Revirtiendo ${RELATIVE_PATH} a '${GIT_REF}'."
  printf '%s\n' "$target_content" > "$COMPOSE_FILE"

  log_info "Recreando el contenedor de '${SERVICE}'."
  (
    cd "$SERVICE_DIR"
    if [[ "$SERVICE" == "postal" ]]; then
      docker compose --env-file .env -f docker-compose.yml up -d web smtp worker
    else
      docker compose --env-file .env -f docker-compose.yml up -d
    fi
  )

  log_success "rollback.sh completado: services/${SERVICE} revertido a '${GIT_REF}'."
  log_info "RECUERDA: esto NO revirtio datos ni migraciones de base de datos, solo la definicion del contenedor."
}

main
