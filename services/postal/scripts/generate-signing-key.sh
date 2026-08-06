#!/usr/bin/env bash
# services/postal/scripts/generate-signing-key.sh — genera la clave privada
# RSA que Postal usa para firmar mensajes/tokens (POSTAL_SIGNING_KEY_PATH).
# Idempotente: si el archivo ya existe, no lo toca.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${SERVICE_DIR}/../.." && pwd)"
# shellcheck source=../../../bootstrap/lib.sh
source "${REPO_ROOT}/bootstrap/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0")

Genera services/postal/config/signing.key (RSA 2048) si no existe.
Idempotente. No requiere --environment: la clave no varia por entorno,
es especifica de cada servidor donde corre Postal.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit "$EXIT_OK"
fi

if ! command_exists openssl; then
  log_error "openssl no esta disponible."
  exit "$EXIT_GENERAL_ERROR"
fi

readonly KEY_PATH="${SERVICE_DIR}/config/signing.key"

main() {
  if [[ -f "$KEY_PATH" ]]; then
    log_info "signing.key ya existe en ${KEY_PATH}; se omite (no se sobreescribe)."
    exit "$EXIT_OK"
  fi

  log_info "Generando ${KEY_PATH} (RSA 2048)."
  openssl genrsa -out "$KEY_PATH" 2048 2>/dev/null
  chmod 600 "$KEY_PATH"
  log_success "signing.key generado. Este archivo NUNCA debe versionarse (ver .gitignore)."
}

main
