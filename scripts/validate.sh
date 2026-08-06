#!/usr/bin/env bash
# scripts/validate.sh — valida el stack completo de un entorno: Docker
# (delega en docker/validate.sh), salud de contenedores (delega en
# healthcheck.sh), resolucion DNS real contra docs/dns.md, expiracion del
# certificado TLS, y reglas de UFW. Solo lectura, no modifica nada.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../bootstrap/lib.sh
source "${REPO_ROOT}/bootstrap/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod>

Valida, sin modificar nada:
  - docker/validate.sh (daemon, red, volumenes)
  - healthcheck.sh (todos los contenedores masivos-*)
  - Resolucion DNS de DOMAIN_ROOT, mail.DOMAIN_ROOT, y los hostnames
    publicos configurados en services/nginx/.env
  - Expiracion del certificado TLS (advierte si quedan menos de 14 dias)
  - Reglas de UFW (SSH_PORT, 25, 80, 443 deben estar ALLOW)

Requiere root (a diferencia de docker/validate.sh y healthcheck.sh, que
no lo requieren): 'ufw status' necesita privilegios.

Exit 0 si todo pasa, 1 si algo falla.
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
load_environment_file "$ENVIRONMENT" "$REPO_ROOT"

FAILURES=0

check() {
  local description="$1"
  local status="$2"
  if [[ "$status" -eq 0 ]]; then
    log_info "[PASS] ${description}"
  else
    log_error "[FAIL] ${description}"
    FAILURES=$((FAILURES + 1))
  fi
}

resolve_host() {
  local host="$1"
  if command_exists getent; then
    getent hosts "$host" >/dev/null 2>&1
  elif command_exists dig; then
    [[ -n "$(dig +short "$host")" ]]
  else
    return 2
  fi
}

run_docker_validate() {
  log_info "--- docker/validate.sh ---"
  if "${REPO_ROOT}/docker/validate.sh" --environment "$ENVIRONMENT"; then
    check "docker/validate.sh" 0
  else
    check "docker/validate.sh" 1
  fi
}

run_healthcheck() {
  log_info "--- healthcheck.sh ---"
  if "${SCRIPT_DIR}/healthcheck.sh"; then
    check "healthcheck.sh (todos los contenedores)" 0
  else
    check "healthcheck.sh (todos los contenedores)" 1
  fi
}

run_dns_checks() {
  log_info "--- Resolucion DNS ---"
  if [[ -z "${DOMAIN_ROOT:-}" ]]; then
    check "DOMAIN_ROOT definido en environments/${ENVIRONMENT}/.env" 1
    return
  fi

  resolve_host "$DOMAIN_ROOT"
  check "resuelve ${DOMAIN_ROOT}" $?

  resolve_host "mail.${DOMAIN_ROOT}"
  check "resuelve mail.${DOMAIN_ROOT}" $?

  local nginx_env="${REPO_ROOT}/services/nginx/.env"
  if [[ -f "$nginx_env" ]]; then
    local host_var
    for host_var in POSTAL_WEB_HOSTNAME GRAFANA_WEB_HOSTNAME UPTIME_KUMA_WEB_HOSTNAME; do
      local host_value
      host_value="$(grep -E "^${host_var}=" "$nginx_env" | cut -d= -f2-)"
      if [[ -n "$host_value" ]]; then
        resolve_host "$host_value"
        check "resuelve ${host_value} (${host_var})" $?
      fi
    done
  else
    log_info "services/nginx/.env no existe; se omiten los hostnames de Nginx."
  fi
}

run_certificate_check() {
  log_info "--- Certificado TLS ---"
  local cert_path="${REPO_ROOT}/services/nginx/ssl/live/${DOMAIN_ROOT}/fullchain.pem"
  if [[ ! -f "$cert_path" ]]; then
    check "certificado existe en ${cert_path}" 1
    return
  fi
  check "certificado existe en ${cert_path}" 0

  if ! command_exists openssl; then
    log_info "openssl no disponible; se omite la verificacion de expiracion."
    return
  fi

  local end_date end_epoch now_epoch days_left
  end_date="$(openssl x509 -enddate -noout -in "$cert_path" 2>/dev/null | cut -d= -f2)"
  if [[ -z "$end_date" ]]; then
    check "certificado legible con openssl" 1
    return
  fi
  end_epoch="$(date -d "$end_date" +%s 2>/dev/null || echo 0)"
  now_epoch="$(date +%s)"
  days_left=$(( (end_epoch - now_epoch) / 86400 ))

  if [[ "$days_left" -lt 14 ]]; then
    log_error "El certificado expira en ${days_left} dias (${end_date}). Ejecuta services/nginx/scripts/renew-certificates.sh."
    check "certificado con vigencia suficiente (>=14 dias)" 1
  else
    check "certificado con vigencia suficiente (${days_left} dias restantes)" 0
  fi
}

run_ufw_check() {
  log_info "--- UFW ---"
  if ! command_exists ufw; then
    check "ufw instalado" 1
    return
  fi

  local ufw_status
  ufw_status="$(ufw status 2>/dev/null || true)"

  local port
  for port in "${SSH_PORT:-}" 25 80 443; do
    [[ -z "$port" ]] && continue
    if echo "$ufw_status" | grep -qE "^${port}/tcp[[:space:]]+ALLOW"; then
      check "UFW permite el puerto ${port}/tcp" 0
    else
      check "UFW permite el puerto ${port}/tcp" 1
    fi
  done
}

main() {
  run_docker_validate
  run_healthcheck
  run_dns_checks
  run_certificate_check
  run_ufw_check

  echo
  if [[ "$FAILURES" -eq 0 ]]; then
    log_success "validate.sh: todas las verificaciones pasaron para '${ENVIRONMENT}'."
    exit "$EXIT_OK"
  else
    log_error "validate.sh: ${FAILURES} verificacion(es) fallaron para '${ENVIRONMENT}'."
    exit "$EXIT_GENERAL_ERROR"
  fi
}

main
