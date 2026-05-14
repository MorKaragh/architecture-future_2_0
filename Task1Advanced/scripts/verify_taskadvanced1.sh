#!/usr/bin/env bash
# Проверка TaskAdvanced1: Terraform в PATH, форматирование, init + validate
# по каждому окружению. Реальные ID облака не нужны (подставляются фиктивные
# значения только для прохождения validate). Облако и API не вызываются.
#
# Использование: из корня репозитория — ./TaskAdvanced1/scripts/verify_taskadvanced1.sh
# Опции:
#   --skip-fmt     не запускать terraform fmt -check
#   --no-terraformrc  не предупреждать об отсутствии ~/.terraformrc

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TASK1_ROOT=$(cd "${SCRIPT_DIR}/.." && pwd)
REPO_ROOT=$(cd "${SCRIPT_DIR}/../.." && pwd)
TF_ROOT="${TASK1_ROOT}"

SKIP_FMT=0
WARN_TFRC=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-fmt) SKIP_FMT=1 ;;
    --no-terraformrc) WARN_TFRC=0 ;;
    -h | --help)
      echo "Использование: $0 [--skip-fmt] [--no-terraformrc]"
      exit 0
      ;;
    *)
      echo "Неизвестный аргумент: $1" >&2
      exit 2
      ;;
  esac
  shift
done

log() { echo "[verify] $*"; }
fail() { echo "[verify] ОШИБКА: $*" >&2; exit 1; }

[[ -d "${TF_ROOT}" ]] || fail "Нет каталога ${TF_ROOT}"

if ! command -v terraform >/dev/null 2>&1; then
  fail "terraform не найден в PATH. Установите CLI и повторите."
fi

log "Версия: $(terraform version | head -n 1)"

if [[ "${WARN_TFRC}" -eq 1 ]] && [[ ! -f "${HOME}/.terraformrc" ]]; then
  echo "[verify] Предупреждение: нет ${HOME}/.terraformrc (зеркало Yandex). См. ${REPO_ROOT}/scripts/terraformrc.yandex.example" >&2
fi

if command -v yc >/dev/null 2>&1; then
  log "yc CLI: $(yc version 2>/dev/null | head -n 1 || echo установлен)"
else
  log "yc CLI не найден (необязательно для validate)"
fi

if [[ "${SKIP_FMT}" -eq 0 ]]; then
  log "terraform fmt -check -recursive"
  terraform fmt -check -recursive "${TF_ROOT}" || fail "Исправьте форматирование: terraform fmt -recursive ${TF_ROOT}"
fi

# Фиктивные значения: validate не ходит в API провайдера Yandex.
export TF_VAR_cloud_id="b1gverify000000000000"
export TF_VAR_folder_id="b1gverify000000000001"
export TF_VAR_zone="ru-central1-a"
export TF_VAR_subnet_id="e9bverify000000000001"
export TF_VAR_ssh_public_key="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGZvbyBiYXIgdmVyaWZ5IHNjcmlwdA"

TMPBASE=$(mktemp -d)
trap 'rm -rf "${TMPBASE}"' EXIT

# Копия конфигурации во временный каталог: init не пишет .terraform и lock в ваши envs/*.
WORK="${TMPBASE}/TaskAdvanced1"
cp -a "${TF_ROOT}" "${WORK}"

for env in dev stage prod; do
  ENV_DIR="${WORK}/envs/${env}"
  VARFILE="${env}.tfvars"
  [[ -d "${ENV_DIR}" ]] || fail "Нет ${ENV_DIR}"
  [[ -f "${ENV_DIR}/${VARFILE}" ]] || fail "Нет ${ENV_DIR}/${VARFILE}"

  log "окружение ${env}: init + validate (изолированная копия)"
  (
    cd "${ENV_DIR}"
    export TF_DATA_DIR="${TMPBASE}/tfdata-${env}"
    terraform init -backend=false -input=false -no-color
    terraform validate -no-color
  ) || fail "сбой в ${env}"
done

log "Готово: fmt (если не отключён), init и validate для dev/stage/prod прошли успешно."
log "Это не проверяет YC_TOKEN и реальный plan/apply в облаке."
