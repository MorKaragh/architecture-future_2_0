#!/usr/bin/env bash
# Выставляет YC_TOKEN через impersonate сервисного аккаунта и YC_CLOUD_ID / YC_FOLDER_ID из yc config.
# Переменные Terraform (TF_VAR_*) — в scripts/terraform_env.sh (source его раньше этого скрипта).
#
# Важно: скрипт рассчитан на «source». Не используйте exit при ошибке — закроется ваш shell.

set -uo pipefail

_die() {
  echo "$*" >&2
  if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    return 1
  fi
  exit 1
}

[[ -n "${YC_SERVICE_ACCOUNT_ID:-}" ]] || _die "Задайте YC_SERVICE_ACCOUNT_ID (идентификатор сервисного аккаунта)."

YC_TOKEN=$(yc iam create-token --impersonate-service-account-id "${YC_SERVICE_ACCOUNT_ID}") || _die "yc iam create-token не выполнился (права SA, сеть, см. сообщение yc выше)."
export YC_TOKEN

YC_CLOUD_ID=$(yc config get cloud-id) || _die "yc config get cloud-id не выполнился."
export YC_CLOUD_ID

YC_FOLDER_ID=$(yc config get folder-id) || _die "yc config get folder-id не выполнился."
export YC_FOLDER_ID
