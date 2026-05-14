#!/usr/bin/env bash
# Проверка bootstrap: офлайн (fmt, init, validate с фиктивными переменными) или --live (plan в облаке).
#
# Из корня репозитория:
#   ./Task2Advanced/scripts/bootstrap_verify.sh
#   ./Task2Advanced/scripts/bootstrap_verify.sh --live
# Опции: --skip-fmt, --no-terraformrc (как в Task1Advanced/scripts/verify_taskadvanced1), --live

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TASK2_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)

SKIP_FMT=0
WARN_TFRC=1
LIVE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-fmt) SKIP_FMT=1 ;;
    --no-terraformrc) WARN_TFRC=0 ;;
    --live) LIVE=1 ;;
    -h | --help)
      echo "Использование: $0 [--skip-fmt] [--no-terraformrc] [--live]"
      exit 0
      ;;
    *)
      echo "Неизвестный аргумент: $1" >&2
      exit 2
      ;;
  esac
  shift
done

log() { echo "[bootstrap-verify] $*"; }
fail() { echo "[bootstrap-verify] ОШИБКА: $*" >&2; exit 1; }

[[ -d "${TASK2_ROOT}/bootstrap" ]] || fail "Нет каталога ${TASK2_ROOT}/bootstrap"

if ! command -v terraform >/dev/null 2>&1; then
  fail "terraform не найден в PATH."
fi

if [[ "${WARN_TFRC}" -eq 1 ]] && [[ ! -f "${HOME}/.terraformrc" ]]; then
  echo "[bootstrap-verify] Предупреждение: нет ${HOME}/.terraformrc (зеркало Yandex). См. ${REPO_ROOT}/scripts/terraformrc.yandex.example" >&2
fi

if [[ "${SKIP_FMT}" -eq 0 ]]; then
  log "terraform fmt -check -recursive ${TASK2_ROOT}"
  terraform fmt -check -recursive "${TASK2_ROOT}" || fail "terraform fmt -recursive ${TASK2_ROOT}"
fi

if [[ "${LIVE}" -eq 0 ]]; then
  TMPBASE=$(mktemp -d)
  trap 'rm -rf "${TMPBASE}"' EXIT
  export TF_DATA_DIR="${TMPBASE}/tfdata"
  cd "${TASK2_ROOT}/bootstrap"
  export TF_VAR_cloud_id="b1gverify000000000000"
  export TF_VAR_folder_id="b1gverify000000000001"
  export TF_VAR_zone="ru-central1-a"
  export TF_VAR_service_account_id="aje000000000000000001"
  export TF_VAR_bucket_name="bootstrap-verify-fake-bucket-000000"
  log "офлайн: init + validate"
  terraform init -input=false -no-color
  terraform validate -no-color
  log "Готово (офлайн). Реальный plan/облако не вызывались."
  exit 0
fi

[[ -n "${YC_SERVICE_ACCOUNT_ID:-}" ]] || fail "Для --live задайте YC_SERVICE_ACCOUNT_ID."

# shellcheck source=../../scripts/auth_cloud.sh
source "${REPO_ROOT}/scripts/auth_cloud.sh"

export TF_VAR_cloud_id="${TF_VAR_cloud_id:-${YC_CLOUD_ID}}"
export TF_VAR_folder_id="${TF_VAR_folder_id:-${YC_FOLDER_ID}}"
export TF_VAR_service_account_id="${YC_SERVICE_ACCOUNT_ID}"

if [[ -z "${TF_VAR_zone:-}" ]]; then
  if command -v yc >/dev/null 2>&1 && z="$(yc config get compute-default-zone 2>/dev/null)" && [[ -n "${z}" ]]; then
    export TF_VAR_zone="${z}"
  else
    export TF_VAR_zone="ru-central1-a"
  fi
fi

cd "${TASK2_ROOT}/bootstrap"
log "--live: init + plan"
terraform init -input=false -no-color
set +e
terraform plan -input=false -no-color -detailed-exitcode
ec=$?
set -e
if [[ "${ec}" -eq 1 ]]; then
  fail "terraform plan завершился с ошибкой"
fi
if [[ "${ec}" -eq 0 ]]; then
  log "plan: изменений нет (exit 0)."
elif [[ "${ec}" -eq 2 ]]; then
  log "plan: есть изменения или пустой state (exit 2) — ожидаемо после правок конфигурации или до первого apply."
else
  fail "неожиданный код выхода terraform plan: ${ec}"
fi
log "Готово (--live)."
