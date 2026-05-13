#!/usr/bin/env bash
# Создание бакета Object Storage и (опционально) статического ключа для remote state.
# Токен: через корневой scripts/auth_cloud.sh (нужен YC_SERVICE_ACCOUNT_ID и yc config).
#
# Использование (из любого каталога):
#   export YC_SERVICE_ACCOUNT_ID=aje...
#   ./Task2Advanced/scripts/bootstrap_apply.sh
# Неинтерактивно:
#   ./Task2Advanced/scripts/bootstrap_apply.sh --yes
#
# Дополнительно (опционально): TF_VAR_bucket_name, TF_VAR_bucket_prefix, TF_VAR_zone,
# TF_VAR_create_static_access_key, TF_VAR_cloud_id / TF_VAR_folder_id (если не брать из auth).

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TASK2_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)

AUTO_APPROVE=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes)
      AUTO_APPROVE=(-auto-approve)
      ;;
    -h | --help)
      echo "Использование: $0 [--yes]"
      echo "  --yes   terraform apply -auto-approve"
      exit 0
      ;;
    *)
      echo "Неизвестный аргумент: $1" >&2
      exit 2
      ;;
  esac
  shift
done

[[ -n "${YC_SERVICE_ACCOUNT_ID:-}" ]] || {
  echo "Задайте YC_SERVICE_ACCOUNT_ID (идентификатор сервисного аккаунта)." >&2
  exit 1
}

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
terraform init -input=false
terraform apply -input=false "${AUTO_APPROVE[@]}"

echo ""
echo "Имя бакета (TF_STATE_BUCKET / Variables):"
terraform output -raw bucket_name
echo ""
echo "Рекомендуемый ключ state (TF_STATE_KEY):"
terraform output -raw recommended_state_key
echo ""
echo "Если create_static_access_key = true, смотрите чувствительные выходы в каталоге bootstrap:"
echo "  cd \"${TASK2_ROOT}/bootstrap\" && terraform output"
echo "Подставьте в GitHub Secrets: YC_S3_ACCESS_KEY_ID, YC_S3_SECRET_ACCESS_KEY (поля s3_access_key_id и s3_secret_access_key)."
