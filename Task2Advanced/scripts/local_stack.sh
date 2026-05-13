#!/usr/bin/env bash
# Локально: auth (как в задании 1), TF_VAR из terraform_env.sh, ключи S3 и bucket/key из bootstrap,
# генерация backend.auto.hcl, terraform init + plan или apply.
#
# Требования: yc, terraform, jq. Выполненный bootstrap (есть bootstrap/terraform.tfstate).
#
# Из корня репозитория:
#   export YC_SERVICE_ACCOUNT_ID=aje...
#   ./Task2Advanced/scripts/local_stack.sh plan
#   ./Task2Advanced/scripts/local_stack.sh apply --yes
#
# Переопределения: любые TF_VAR_*, TF_STATE_KEY (ключ объекта state), TF_VAR_vm_name и т.д.

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
  echo "Использование: $0 plan | apply [--yes] | help" >&2
  echo "  Перед запуском: export YC_SERVICE_ACCOUNT_ID=aje..." >&2
  echo "  Опционально: source корневых scripts/terraform_env.sh (или скрипт сделает это сам)." >&2
  exit "${1:-2}"
}

[[ "${BASH_SOURCE[0]}" == "${0}" ]] || _die "Запускайте как исполняемый файл, не source."

CMD="${1:-}"
[[ -n "${CMD}" ]] || usage
shift || true

case "${CMD}" in
  help | -h | --help) usage 0 ;;
  plan | apply) ;;
  *) echo "Неизвестная команда: ${CMD}" >&2 && usage ;;
esac

[[ -n "${YC_SERVICE_ACCOUNT_ID:-}" ]] || _die "Задайте YC_SERVICE_ACCOUNT_ID."

[[ -f "${TASK2_ROOT}/bootstrap/terraform.tfstate" ]] || _die "Нет ${TASK2_ROOT}/bootstrap/terraform.tfstate — сначала выполните bootstrap_apply.sh."

# shellcheck source=../../scripts/auth_cloud.sh
source "${REPO_ROOT}/scripts/auth_cloud.sh"

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
bootstrap_export_s3_for_main_stack || _die "Не удалось настроить доступ к S3 backend из bootstrap."

export TF_BACKEND_OUT="${TASK2_ROOT}/terraform/backend.auto.hcl"
bash "${TASK2_ROOT}/scripts/render-backend-ci.sh"

cd "${TASK2_ROOT}/terraform"
terraform init -input=false -backend-config=backend.auto.hcl

case "${CMD}" in
  plan)
    terraform plan -input=false
    ;;
  apply)
    AUTO=()
    if [[ "${1:-}" == "--yes" ]]; then
      AUTO=(-auto-approve)
    elif [[ -n "${1:-}" ]]; then
      echo "Неизвестный аргумент для apply: $1 (ожидается только --yes)" >&2
      exit 2
    fi
    terraform apply -input=false "${AUTO[@]}"
    ;;
esac
