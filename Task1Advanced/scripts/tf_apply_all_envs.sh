#!/usr/bin/env bash
# Поднимает ВМ во всех средах TaskAdvanced1 (dev, stage, prod), ждёт RUNNING, проверяет outputs.
# Из корня репозитория. Нужны yc, python3, terraform; TF_VAR_* и YC_TOKEN (см. scripts/terraform_env.sh, auth_cloud.sh).

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TASK1_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
COMMON_SCRIPTS="${REPO_ROOT}/scripts"
TF_ROOT="${TASK1_ROOT}"

log() { echo "[tf-apply-all] $*"; }
fail() { echo "[tf-apply-all] ОШИБКА: $*" >&2; exit 1; }

cd "${REPO_ROOT}"

command -v terraform >/dev/null 2>&1 || fail "terraform не в PATH"
command -v yc >/dev/null 2>&1 || fail "yc не в PATH"
command -v python3 >/dev/null 2>&1 || fail "python3 не в PATH"

# shellcheck disable=SC1091
source "${COMMON_SCRIPTS}/terraform_env.sh" || fail "terraform_env.sh"

if [[ -z "${YC_TOKEN:-}" ]]; then
  [[ -n "${YC_SERVICE_ACCOUNT_ID:-}" ]] || fail "Задайте YC_TOKEN или YC_SERVICE_ACCOUNT_ID"
  # shellcheck disable=SC1091
  source "${COMMON_SCRIPTS}/auth_cloud.sh" || fail "auth_cloud.sh"
fi
[[ -n "${YC_TOKEN:-}" ]] || fail "YC_TOKEN пуст"

_instance_status() {
  yc compute instance get --id "$1" --format json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("status",""))'
}

_wait_running() {
  local id="$1"
  local env="$2"
  local waited=0
  local max_wait=300
  local step=10
  local st
  log "${env}: ожидание статуса RUNNING для ${id} (до ${max_wait} с)..."
  while [[ "${waited}" -lt "${max_wait}" ]]; do
    st=$(_instance_status "${id}" || true)
    if [[ "${st}" == "RUNNING" ]]; then
      log "${env}: экземпляр RUNNING"
      return 0
    fi
    log "${env}: статус «${st:-нет данных}», пауза ${step} с..."
    sleep "${step}"
    waited=$((waited + step))
  done
  fail "${env}: экземпляр не перешёл в RUNNING за ${max_wait} с"
}

_verify_env_outputs() {
  local env="$1"
  local dir="${TF_ROOT}/envs/${env}"
  local id name ext int
  cd "${dir}"
  id=$(terraform output -raw instance_id)
  name=$(terraform output -raw instance_name)
  ext=$(terraform output -raw external_ip 2>/dev/null || true)
  int=$(terraform output -raw internal_ip 2>/dev/null || true)
  [[ -n "${id}" ]] || fail "${env}: пустой output instance_id"
  [[ -n "${name}" ]] || fail "${env}: пустой output instance_name"
  log "${env}: instance_id=${id} name=${name} internal_ip=${int:-?} external_ip=${ext:-?}"
  if [[ -z "${ext}" ]]; then
    log "${env}: предупреждение: нет external_ip (NAT выключен?)"
  fi
}

for env in dev stage prod; do
  ENV_DIR="${TF_ROOT}/envs/${env}"
  VARFILE="${env}.tfvars"
  [[ -d "${ENV_DIR}" ]] || fail "Нет ${ENV_DIR}"
  [[ -f "${ENV_DIR}/${VARFILE}" ]] || fail "Нет ${VARFILE}"

  log "=== ${env}: terraform init ==="
  (
    cd "${ENV_DIR}"
    terraform init -input=false -no-color
  )

  log "=== ${env}: terraform apply ==="
  (
    cd "${ENV_DIR}"
    terraform apply -var-file="${VARFILE}" -input=false -auto-approve -no-color
  )

  _verify_env_outputs "${env}"
  instance_id=$(cd "${ENV_DIR}" && terraform output -raw instance_id)
  _wait_running "${instance_id}" "${env}"
  cd "${REPO_ROOT}"
done

log "Готово: dev, stage, prod применены и проверены (RUNNING + outputs)."
