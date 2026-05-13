#!/usr/bin/env bash
# Удаление инфраструктуры Task2Advanced: сначала основной стек (remote state в бакете),
# затем bootstrap (бакет + статический ключ). Те же переменные, что и у local_stack.sh.
#
# Из корня репозитория:
#   export YC_SERVICE_ACCOUNT_ID=aje...
#   ./Task2Advanced/scripts/cleanup_stack.sh           # два интерактивных destroy
#   ./Task2Advanced/scripts/cleanup_stack.sh --yes     # без подтверждений
#
# Только основной стек: CLEANUP_MAIN_ONLY=1
# Только bootstrap (бакет уже пуст / state основного стека удалён вручную): CLEANUP_BOOTSTRAP_ONLY=1
# Если S3-ключей нет в bootstrap state, для основного стека создаётся временный ключ (yc iam access-key create) и удаляется в конце.

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TASK2_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)

_die() {
  echo "$*" >&2
  exit 1
}

command -v terraform >/dev/null 2>&1 || _die "Нужен terraform в PATH."
command -v jq >/dev/null 2>&1 || _die "Нужен jq в PATH."

usage() {
  echo "Использование: $0 [--yes]" >&2
  echo "  Перед запуском: export YC_SERVICE_ACCOUNT_ID=aje..." >&2
  echo "  --yes  — terraform destroy -auto-approve (для основного стека и bootstrap)." >&2
  echo "  CLEANUP_MAIN_ONLY=1      — только terraform/ (не трогать bootstrap)." >&2
  echo "  CLEANUP_BOOTSTRAP_ONLY=1 — только bootstrap/ (бакет должен быть пустым или force_destroy)." >&2
  exit "${1:-2}"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] || _die "Запускайте как исполняемый файл, не source."

AUTO=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) AUTO=(-auto-approve) ;;
    -h | --help) usage 0 ;;
    *) echo "Неизвестный аргумент: $1" >&2 && usage ;;
  esac
  shift
done

[[ -n "${YC_SERVICE_ACCOUNT_ID:-}" ]] || _die "Задайте YC_SERVICE_ACCOUNT_ID."

CLEANUP_TEMP_KEY_ID=""

_cleanup_delete_temp_key() {
  [[ -z "${CLEANUP_TEMP_KEY_ID:-}" ]] && return 0
  if command -v yc >/dev/null 2>&1; then
    echo "[cleanup] Удаление временного статического ключа ${CLEANUP_TEMP_KEY_ID}..." >&2
    yc iam access-key delete "${CLEANUP_TEMP_KEY_ID}" 2>/dev/null || true
  fi
  CLEANUP_TEMP_KEY_ID=""
}

_cleanup_try_temp_yc_access_key() {
  command -v yc >/dev/null 2>&1 || return 1
  local st="${TASK2_ROOT}/bootstrap/terraform.tfstate"
  [[ -f "${st}" ]] || return 1
  local BN
  BN=$(jq -r '(.resources // [])[] | select(.type == "yandex_storage_bucket") | .instances[]?.attributes.bucket // empty' "${st}" | head -n1)
  [[ -n "${BN}" && "${BN}" != "null" ]] || return 1
  local js ak sk
  js=$(yc iam access-key create --service-account-id "${YC_SERVICE_ACCOUNT_ID}" --description "task2-cleanup-temp" --format json 2>/dev/null) || return 1
  ak=$(jq -r '.key_id // .access_key.key_id // empty' <<<"${js}")
  sk=$(jq -r '.secret // .access_key.secret // empty' <<<"${js}")
  [[ -n "${ak}" && -n "${sk}" ]] || return 1
  export AWS_ACCESS_KEY_ID="${ak}"
  export AWS_SECRET_ACCESS_KEY="${sk}"
  export TF_STATE_BUCKET="${BN}"
  export TF_STATE_KEY="${TF_STATE_KEY:-task2/terraform.tfstate}"
  CLEANUP_TEMP_KEY_ID="${ak}"
  echo "[cleanup] Временный ключ доступа к Object Storage создан (будет удалён после очистки)." >&2
  return 0
}

trap '_cleanup_delete_temp_key' EXIT

MAIN_ONLY="${CLEANUP_MAIN_ONLY:-0}"
BOOT_ONLY="${CLEANUP_BOOTSTRAP_ONLY:-0}"

[[ "${MAIN_ONLY}" == "1" && "${BOOT_ONLY}" == "1" ]] && _die "Нельзя одновременно CLEANUP_MAIN_ONLY и CLEANUP_BOOTSTRAP_ONLY."

if [[ "${BOOT_ONLY}" != "1" ]]; then
  [[ -f "${TASK2_ROOT}/bootstrap/terraform.tfstate" ]] || _die "Нет bootstrap/terraform.tfstate — для destroy основного стека нужны ключи из bootstrap."
fi

# shellcheck source=../../scripts/auth_cloud.sh
source "${REPO_ROOT}/scripts/auth_cloud.sh"

if [[ "${BOOT_ONLY}" != "1" ]]; then
  if [[ -f "${REPO_ROOT}/scripts/terraform_env.sh" ]]; then
    # shellcheck source=../../scripts/terraform_env.sh
    source "${REPO_ROOT}/scripts/terraform_env.sh"
  else
    _die "Не найден ${REPO_ROOT}/scripts/terraform_env.sh"
  fi

  export TF_VAR_cloud_id="${TF_VAR_cloud_id:-${YC_CLOUD_ID}}"
  export TF_VAR_folder_id="${TF_VAR_folder_id:-${YC_FOLDER_ID}}"

  export TF_VAR_vm_name="${TF_VAR_vm_name:-future20-task2}"
  export TF_VAR_cores="${TF_VAR_cores:-2}"
  export TF_VAR_memory="${TF_VAR_memory:-4}"
  export TF_VAR_attach_disk_size="${TF_VAR_attach_disk_size:-20}"

  # shellcheck source=bootstrap_aws_env.inc.sh
  source "${SCRIPT_DIR}/bootstrap_aws_env.inc.sh"
  if ! bootstrap_export_s3_for_main_stack; then
    echo "[cleanup] Нет S3-ключей в output/state bootstrap — пробую временный ключ через yc iam access-key create..." >&2
    _cleanup_try_temp_yc_access_key || _die "Не удалось настроить S3: задайте AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY и TF_STATE_BUCKET, либо проверьте права СА на iam.accessKey.create."
  fi

  export TF_BACKEND_OUT="${TASK2_ROOT}/terraform/backend.auto.hcl"
  bash "${TASK2_ROOT}/scripts/render-backend-ci.sh"

  echo "[cleanup] Основной стек Task2Advanced/terraform (remote state)..."
  cd "${TASK2_ROOT}/terraform"
  terraform init -input=false -backend-config=backend.auto.hcl
  terraform destroy -input=false "${AUTO[@]}"
  echo "[cleanup] Основной стек: destroy завершён."
fi

if [[ "${MAIN_ONLY}" != "1" ]]; then
  echo "[cleanup] Bootstrap (бакет Object Storage, статический ключ)..."
  export TF_VAR_service_account_id="${YC_SERVICE_ACCOUNT_ID}"
  export TF_VAR_cloud_id="${TF_VAR_cloud_id:-${YC_CLOUD_ID}}"
  export TF_VAR_folder_id="${TF_VAR_folder_id:-${YC_FOLDER_ID}}"
  if [[ -z "${TF_VAR_zone:-}" ]]; then
    if command -v yc >/dev/null 2>&1 && z="$(yc config get compute-default-zone 2>/dev/null)" && [[ -n "${z}" ]]; then
      export TF_VAR_zone="${z}"
    else
      export TF_VAR_zone="ru-central1-a"
    fi
  fi
  cd "${TASK2_ROOT}/bootstrap"
  terraform init -input=false
  # Иначе в облаке остаётся force_destroy=false и удаление бакета с объектами (в т.ч. remote state) даёт BucketNotEmpty.
  echo "[cleanup] Синхронизация бакета (в т.ч. force_destroy)..."
  terraform apply -input=false "${AUTO[@]}" -target=yandex_storage_bucket.tf_state
  echo "[cleanup] Удаление bootstrap..."
  terraform destroy -input=false "${AUTO[@]}"
  echo "[cleanup] Bootstrap: destroy завершён."
fi

echo "[cleanup] Готово."
