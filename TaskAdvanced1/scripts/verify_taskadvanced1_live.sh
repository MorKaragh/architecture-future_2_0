#!/usr/bin/env bash
# Проверка TaskAdvanced1 против реального Yandex Cloud: terraform init + plan.
# Нужны yc и python3 для автоподстановки TF_VAR_* через scripts/terraform_env.sh при отсутствии
# переменных. YC_TOKEN либо YC_SERVICE_ACCOUNT_ID + yc (scripts/auth_cloud.sh).
#
# Примеры (из корня репозитория):
#   ./TaskAdvanced1/scripts/verify_taskadvanced1_live.sh
#   ./TaskAdvanced1/scripts/verify_taskadvanced1_live.sh stage
#   ./TaskAdvanced1/scripts/verify_taskadvanced1_live.sh prod --apply   # осторожно

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TASK1_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
COMMON_SCRIPTS="${REPO_ROOT}/scripts"
TF_ROOT="${TASK1_ROOT}"

ENV="dev"
DO_APPLY=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    dev | stage | prod)
      ENV="$1"
      ;;
    --apply)
      DO_APPLY=1
      ;;
    -h | --help)
      echo "Использование: $0 [dev|stage|prod] [--apply]"
      echo "  Либо задайте TF_VAR_* вручную, либо yc + python3 для source ${COMMON_SCRIPTS}/terraform_env.sh (в т.ч. автоматически в этом скрипте)."
      exit 0
      ;;
    *)
      echo "Неизвестный аргумент: $1" >&2
      exit 2
      ;;
  esac
  shift
done

log() { echo "[live] $*"; }
fail() { echo "[live] ОШИБКА: $*" >&2; exit 1; }

[[ "${ENV}" =~ ^(dev|stage|prod)$ ]] || fail "среда должна быть dev, stage или prod, получено: ${ENV}"

ENV_DIR="${TF_ROOT}/envs/${ENV}"
VARFILE="${ENV}.tfvars"

[[ -d "${ENV_DIR}" ]] || fail "Нет каталога ${ENV_DIR}"
[[ -f "${ENV_DIR}/${VARFILE}" ]] || fail "Нет ${VARFILE} в ${ENV_DIR}"

if ! command -v terraform >/dev/null 2>&1; then
  fail "terraform не найден в PATH"
fi

# Недостающие TF_VAR_* из yc и стандартных путей (см. scripts/terraform_env.sh)
if [[ -z "${TF_VAR_cloud_id:-}" || -z "${TF_VAR_folder_id:-}" || -z "${TF_VAR_zone:-}" || -z "${TF_VAR_subnet_id:-}" || -z "${TF_VAR_ssh_public_key:-}" ]]; then
  if command -v yc >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
    log "подстановка недостающих TF_VAR_* через ${COMMON_SCRIPTS}/terraform_env.sh"
    # shellcheck disable=SC1091
    source "${COMMON_SCRIPTS}/terraform_env.sh"
  fi
fi

if [[ -z "${YC_TOKEN:-}" ]]; then
  if [[ -n "${YC_SERVICE_ACCOUNT_ID:-}" ]] && command -v yc >/dev/null 2>&1; then
    log "YC_TOKEN пуст, получение токена через ${COMMON_SCRIPTS}/auth_cloud.sh"
    # shellcheck disable=SC1091
    source "${COMMON_SCRIPTS}/auth_cloud.sh"
  else
    fail "Нет YC_TOKEN. Экспортируйте YC_TOKEN или задайте YC_SERVICE_ACCOUNT_ID и установите yc для вызова auth_cloud.sh"
  fi
fi

[[ -n "${YC_TOKEN:-}" ]] || fail "YC_TOKEN по-прежнему пуст"

for name in TF_VAR_cloud_id TF_VAR_folder_id TF_VAR_zone TF_VAR_subnet_id TF_VAR_ssh_public_key; do
  if [[ -z "${!name:-}" ]]; then
    fail "Должна быть задана непустая переменная окружения ${name} (или установите yc и python3 и выполните source ${COMMON_SCRIPTS}/terraform_env.sh из корня репозитория)"
  fi
done

log "terraform init (${ENV})"
(
  cd "${ENV_DIR}"
  terraform init -input=false -no-color
)

run_plan() {
  (
    cd "${ENV_DIR}"
    terraform plan -var-file="${VARFILE}" -input=false -no-color -detailed-exitcode
  )
}

if [[ "${DO_APPLY}" -eq 1 ]]; then
  log "ВНИМАНИЕ: будет выполнен terraform apply -auto-approve в ${ENV}"
  read -r -p "Введите yes для подтверждения: " confirm
  [[ "${confirm}" == "yes" ]] || fail "отменено пользователем"
  (
    cd "${ENV_DIR}"
    terraform apply -var-file="${VARFILE}" -input=false -auto-approve -no-color
  )
  log "apply завершён"
  exit 0
fi

log "terraform plan (${ENV})"
set +e
run_plan
plan_ec=$?
set -e

if [[ "${plan_ec}" -eq 0 ]]; then
  log "plan: изменений нет (detailed-exitcode 0)"
elif [[ "${plan_ec}" -eq 2 ]]; then
  log "plan: есть изменения, готов к apply (detailed-exitcode 2)"
else
  fail "terraform plan завершился с кодом ${plan_ec} (1 — ошибка)"
fi

log "Готово. Для создания ресурсов: cd ${ENV_DIR} && terraform apply -var-file=${VARFILE}"
log "Либо: ${SCRIPT_DIR}/verify_taskadvanced1_live.sh ${ENV} --apply"
