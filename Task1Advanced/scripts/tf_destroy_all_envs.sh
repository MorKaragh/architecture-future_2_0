#!/usr/bin/env bash
# Удаляет инфраструктуру во всех средах Task1Advanced (dev, stage, prod), где есть terraform state.
# Из корня репозитория. Нужны те же TF_VAR_* / YC_TOKEN, что и для apply.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TASK1_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
COMMON_SCRIPTS="${REPO_ROOT}/scripts"
TF_ROOT="${TASK1_ROOT}"

log() { echo "[tf-destroy-all] $*"; }
fail() { echo "[tf-destroy-all] ОШИБКА: $*" >&2; exit 1; }

cd "${REPO_ROOT}"

command -v terraform >/dev/null 2>&1 || fail "terraform не в PATH"

# shellcheck disable=SC1091
source "${COMMON_SCRIPTS}/terraform_env.sh" || fail "terraform_env.sh"

if [[ -z "${YC_TOKEN:-}" ]]; then
  [[ -n "${YC_SERVICE_ACCOUNT_ID:-}" ]] || fail "Задайте YC_TOKEN или YC_SERVICE_ACCOUNT_ID"
  # shellcheck disable=SC1091
  source "${COMMON_SCRIPTS}/auth_cloud.sh" || fail "auth_cloud.sh"
fi
[[ -n "${YC_TOKEN:-}" ]] || fail "YC_TOKEN пуст"

for env in dev stage prod; do
  ENV_DIR="${TF_ROOT}/envs/${env}"
  VARFILE="${env}.tfvars"
  [[ -d "${ENV_DIR}" ]] || fail "Нет ${ENV_DIR}"
  [[ -f "${ENV_DIR}/${VARFILE}" ]] || fail "Нет ${VARFILE}"

  (
    cd "${ENV_DIR}"
    terraform init -input=false -no-color
    if ! terraform state list -no-color 2>/dev/null | grep -q .; then
      echo "[tf-destroy-all] ${env}: нет ресурсов в state, пропуск"
      exit 0
    fi
    log "${env}: terraform destroy"
    terraform destroy -var-file="${VARFILE}" -input=false -auto-approve -no-color
  )
done

log "Готово: destroy выполнен для сред, где был state."
