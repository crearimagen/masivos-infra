#!/usr/bin/env bash
# scripts/deploy.sh — despliegue completo de un entorno: bootstrap,
# hardening, docker, certificados, stack principal y Postal (separado, por
# su network_mode: host). Idempotente en cada paso individual.
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=../bootstrap/lib.sh
source "${REPO_ROOT}/bootstrap/lib.sh"
trap 'masivos_on_error $LINENO' ERR

usage() {
  cat <<EOF
Uso: $(basename "$0") --environment <dev|test|prod> [opciones]

Despliegue completo, en orden:
  1. bootstrap/install.sh          (omitir con --services-only)
  2. security/hardening.sh         (omitir con --services-only)
  3. docker/install.sh             (omitir con --services-only)
  4. Certificados de Nginx (genera credenciales de Cloudflare, renderiza
     conf.d/, emite el certificado si no existe)
  5. Stack principal (docker/compose/docker-compose.yml): mariadb,
     postgres, rabbitmq, redis, nginx, prometheus, grafana, loki,
     uptime-kuma
  6. Postal (aparte: network_mode: host) - genera signing.key, arranca
     web/smtp/worker, ejecuta 'postal initialize'

Opciones:
  --services-only   Salta los pasos 1-3 (bootstrap/security/docker) y va
                     directo a levantar/actualizar los servicios. Util
                     para iterar sobre configuracion de servicios en un
                     servidor ya provisionado.

Idempotente. NO ejecuta 'postal make-user' (creacion del primer admin) -
es interactivo por diseno de Postal (ver services/postal/README.md); al
terminar se imprime el comando para ejecutarlo a mano.
EOF
}

ENVIRONMENT=""
SERVICES_ONLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --environment) ENVIRONMENT="${2:-}"; shift 2 ;;
    --services-only) SERVICES_ONLY=1; shift ;;
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

if [[ -z "${DOMAIN_ROOT:-}" ]]; then
  log_error "DOMAIN_ROOT no esta definido en environments/${ENVIRONMENT}/.env"
  exit "$EXIT_INVALID_USAGE"
fi

readonly COMPOSE_MAIN="${REPO_ROOT}/docker/compose/docker-compose.yml"
readonly POSTAL_DIR="${REPO_ROOT}/services/postal"
readonly NGINX_DIR="${REPO_ROOT}/services/nginx"
readonly WAIT_TIMEOUT_SECONDS=120

step_bootstrap_security_docker() {
  if [[ "$SERVICES_ONLY" -eq 1 ]]; then
    log_info "==> --services-only: se omiten bootstrap/security/docker."
    return
  fi
  log_info "==> Paso 1/6: bootstrap/install.sh"
  "${REPO_ROOT}/bootstrap/install.sh" --environment "$ENVIRONMENT"
  log_info "==> Paso 2/6: security/hardening.sh"
  "${REPO_ROOT}/security/hardening.sh" --environment "$ENVIRONMENT"
  log_info "==> Paso 3/6: docker/install.sh"
  "${REPO_ROOT}/docker/install.sh" --environment "$ENVIRONMENT"
}

step_nginx_certificates() {
  log_info "==> Paso 4/6: certificados de Nginx"
  if [[ ! -f "${NGINX_DIR}/.env" ]]; then
    log_error "No existe ${NGINX_DIR}/.env. Copia .env.example a .env y completalo antes de desplegar."
    exit "$EXIT_MISSING_ENV_FILE"
  fi

  "${NGINX_DIR}/scripts/generate-cloudflare-credentials.sh" --environment "$ENVIRONMENT"
  "${NGINX_DIR}/scripts/render-config.sh"

  local live_cert="${NGINX_DIR}/ssl/live/${DOMAIN_ROOT}/fullchain.pem"
  if [[ -f "$live_cert" ]]; then
    log_info "Certificado ya existe en ${live_cert}; se omite issue-certificate.sh (usa renew-certificates.sh para renovar)."
  else
    "${NGINX_DIR}/scripts/issue-certificate.sh" --environment "$ENVIRONMENT"
  fi
}

step_main_stack() {
  log_info "==> Paso 5/6: stack principal (docker/compose/docker-compose.yml)"
  docker compose -f "$COMPOSE_MAIN" up -d
}

wait_for_healthy() {
  local container="$1"
  local waited=0
  log_info "Esperando a que '${container}' este healthy (timeout ${WAIT_TIMEOUT_SECONDS}s)."
  while [[ "$waited" -lt "$WAIT_TIMEOUT_SECONDS" ]]; do
    local status
    status="$(docker inspect --format '{{.State.Health.Status}}' "$container" 2>/dev/null || echo "missing")"
    if [[ "$status" == "healthy" ]]; then
      log_info "'${container}' esta healthy."
      return 0
    fi
    sleep 5
    waited=$((waited + 5))
  done
  log_error "'${container}' no llego a 'healthy' tras ${WAIT_TIMEOUT_SECONDS}s (estado actual: ${status:-desconocido})."
  return 1
}

step_postal() {
  log_info "==> Paso 6/6: Postal"
  if [[ ! -f "${POSTAL_DIR}/.env" ]]; then
    log_error "No existe ${POSTAL_DIR}/.env. Copia .env.example a .env y completalo antes de desplegar."
    exit "$EXIT_MISSING_ENV_FILE"
  fi

  "${POSTAL_DIR}/scripts/generate-signing-key.sh"

  if ! wait_for_healthy masivos-mariadb; then
    log_error "MariaDB no esta healthy; no se puede continuar con Postal."
    exit "$EXIT_GENERAL_ERROR"
  fi

  (cd "$POSTAL_DIR" && docker compose --env-file .env -f docker-compose.yml up -d web smtp worker)
  "${POSTAL_DIR}/scripts/initialize-postal.sh" --environment "$ENVIRONMENT"
}

main() {
  log_info "Iniciando deploy.sh para el entorno '${ENVIRONMENT}'."

  step_bootstrap_security_docker
  step_nginx_certificates
  step_main_stack
  step_postal

  log_success "deploy.sh completado para el entorno '${ENVIRONMENT}'."
  log_info "Si es la primera vez que se despliega este entorno, crea el primer administrador de Postal (paso manual, interactivo):"
  log_info "  docker compose --env-file ${POSTAL_DIR}/.env -f ${POSTAL_DIR}/docker-compose.yml run --rm -it runner postal make-user"
  log_info "Verifica el stack completo con: ./scripts/validate.sh --environment ${ENVIRONMENT}"
}

main
