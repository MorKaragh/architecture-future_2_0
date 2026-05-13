# shellcheck shell=bash
# Экспорт AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, TF_STATE_BUCKET, TF_STATE_KEY
# для основного стека из bootstrap: сначала terraform output -json, при пустых
# sensitive — чтение из bootstrap/terraform.tfstate, затем переменные окружения.
#
# Требует: TASK2_ROOT, jq, terraform. Вызов: source …; bootstrap_export_s3_for_main_stack

bootstrap_export_s3_for_main_stack() {
  [[ -n "${TASK2_ROOT:-}" ]] || {
    echo "bootstrap_export_s3_for_main_stack: не задан TASK2_ROOT" >&2
    return 1
  }

  local st="${TASK2_ROOT}/bootstrap/terraform.tfstate"
  local BOOT_JSON
  BOOT_JSON=$(cd "${TASK2_ROOT}/bootstrap" && terraform output -json)

  local AK SK BN RK
  AK=$(jq -r '.s3_access_key_id.value // empty' <<<"${BOOT_JSON}")
  SK=$(jq -r '.s3_secret_access_key.value // empty' <<<"${BOOT_JSON}")
  BN=$(jq -r '.bucket_name.value // empty' <<<"${BOOT_JSON}")
  RK=$(jq -r '.recommended_state_key.value // empty' <<<"${BOOT_JSON}")

  if [[ -f "${st}" ]]; then
    if [[ -z "${AK}" || "${AK}" == "null" || -z "${SK}" || "${SK}" == "null" ]]; then
      AK=$(jq -r '(.resources // [])[] | select(.type == "yandex_iam_service_account_static_access_key") | .instances[]?.attributes.access_key // empty' "${st}" | head -n1)
      SK=$(jq -r '(.resources // [])[] | select(.type == "yandex_iam_service_account_static_access_key") | .instances[]?.attributes.secret_key // empty' "${st}" | head -n1)
    fi
    if [[ -z "${BN}" || "${BN}" == "null" ]]; then
      BN=$(jq -r '(.resources // [])[] | select(.type == "yandex_storage_bucket") | .instances[]?.attributes.bucket // empty' "${st}" | head -n1)
    fi
  fi

  if [[ -z "${AK}" || "${AK}" == "null" ]]; then AK="${AWS_ACCESS_KEY_ID:-}"; fi
  if [[ -z "${SK}" || "${SK}" == "null" ]]; then SK="${AWS_SECRET_ACCESS_KEY:-}"; fi
  if [[ -z "${BN}" || "${BN}" == "null" ]]; then BN="${TF_STATE_BUCKET:-}"; fi

  if [[ -z "${AK}" || "${AK}" == "null" || -z "${SK}" || "${SK}" == "null" ]]; then
    echo "Не удалось получить S3-ключи: в output они часто скрыты (sensitive), в bootstrap/terraform.tfstate нет static_access_key, и не заданы AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY. Задайте ключи вручную или восстановите bootstrap." >&2
    return 1
  fi
  if [[ -z "${BN}" || "${BN}" == "null" ]]; then
    echo "Не удалось получить имя бакета: задайте TF_STATE_BUCKET." >&2
    return 1
  fi

  export AWS_ACCESS_KEY_ID="${AK}"
  export AWS_SECRET_ACCESS_KEY="${SK}"
  export TF_STATE_BUCKET="${BN}"
  export TF_STATE_KEY="${TF_STATE_KEY:-${RK:-task2/terraform.tfstate}}"
}
