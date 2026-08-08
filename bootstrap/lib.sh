#!/usr/bin/env bash
# bootstrap/lib.sh — helpers compartidos por los scripts de bootstrap/, security/ y scripts/.
# Es una libreria: se debe hacer `source`, nunca ejecutar directamente.

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "lib.sh es una libreria; hazle 'source' desde otro script en vez de ejecutarla." >&2
  exit 1
fi

set -Eeuo pipefail

# shellcheck disable=SC2034  # usadas por los scripts que hacen 'source' de este archivo, no aqui
readonly EXIT_OK=0
# shellcheck disable=SC2034
readonly EXIT_GENERAL_ERROR=1
# shellcheck disable=SC2034
readonly EXIT_INVALID_USAGE=2
readonly EXIT_UNSUPPORTED_OS=3
readonly EXIT_NOT_ROOT=4
readonly EXIT_MISSING_ENV_FILE=5

readonly MASIVOS_LOG_DIR="/var/log/masivos"
readonly MASIVOS_LOG_FILE="${MASIVOS_LOG_DIR}/bootstrap.log"

_masivos_ensure_log_dir() {
  [[ -d "$MASIVOS_LOG_DIR" ]] && return 0
  mkdir -p "$MASIVOS_LOG_DIR"
}

_log() {
  local level="$1"; shift
  local ts script_name line
  ts="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  script_name="$(basename "${BASH_SOURCE[-1]}")"
  line="[$ts] [$level] [$script_name] $*"
  if _masivos_ensure_log_dir 2>/dev/null; then
    echo "$line" | tee -a "$MASIVOS_LOG_FILE" >&2
  else
    echo "$line" >&2
  fi
}

log_info()    { _log "INFO"  "$*"; }
log_warn()    { _log "WARN"  "$*"; }
log_error()   { _log "ERROR" "$*"; }
log_success() { _log "OK"    "$*"; }

# Uso: trap 'masivos_on_error $LINENO' ERR
masivos_on_error() {
  local exit_code=$?
  local line_no="${1:-desconocida}"
  log_error "Fallo inesperado en linea ${line_no} (exit code ${exit_code})."
  exit "$exit_code"
}

require_root() {
  if [[ "$(id -u)" -ne 0 ]]; then
    log_error "Este script debe ejecutarse como root (usa sudo)."
    exit "$EXIT_NOT_ROOT"
  fi
}

require_ubuntu_24_04() {
  if [[ ! -r /etc/os-release ]]; then
    log_error "No se pudo leer /etc/os-release; sistema operativo no verificable."
    exit "$EXIT_UNSUPPORTED_OS"
  fi
  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID:-}" != "ubuntu" || "${VERSION_ID:-}" != "24.04" ]]; then
    log_error "Sistema operativo no soportado: ${PRETTY_NAME:-desconocido}. Se requiere Ubuntu 24.04."
    exit "$EXIT_UNSUPPORTED_OS"
  fi
}

# Uso: load_environment_file <nombre_entorno> <repo_root>
load_environment_file() {
  local env_name="$1"
  local repo_root="$2"
  local env_file="${repo_root}/environments/${env_name}/.env"
  if [[ ! -f "$env_file" ]]; then
    log_error "No existe ${env_file}. Copia environments/${env_name}/.env.example a .env y completa los valores."
    exit "$EXIT_MISSING_ENV_FILE"
  fi
  set -o allexport
  # shellcheck disable=SC1090
  source "$env_file"
  set +o allexport
  log_info "Entorno '${env_name}' cargado desde ${env_file}"
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}
