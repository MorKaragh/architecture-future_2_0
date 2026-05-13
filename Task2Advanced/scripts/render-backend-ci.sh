#!/usr/bin/env bash
# Собирает файл параметров S3-backend для terraform init -backend-config=...
#
# Зачем: в репозитории лежит только шаблон terraform/backend.ci.template (без имён
# бакета и ключа объекта state). Реальные значения приходят из переменных окружения
# — в CI из GitHub Secrets/Variables, локально из export. Так bucket/key не
# попадают в git, а пайплайн и скрипты получают готовый .hcl за один шаг.
#
# Что делает: подставляет @BUCKET@ и @KEY@ в шаблон и записывает результат в файл
# (по умолчанию terraform/backend.generated.hcl от корня Task2Advanced).
#
# Обязательно: TF_STATE_BUCKET, TF_STATE_KEY.
# Опционально: TF_BACKEND_OUT — путь к выходному файлу (иначе см. OUT ниже).
#
# Пример (из корня Task2Advanced):
#   export TF_STATE_BUCKET=my-bucket TF_STATE_KEY=task2/prod.tfstate
#   bash scripts/render-backend-ci.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${TF_BACKEND_OUT:-${ROOT}/terraform/backend.generated.hcl}"
TEMPLATE="${ROOT}/terraform/backend.ci.template"

: "${TF_STATE_BUCKET:?укажите TF_STATE_BUCKET}"
: "${TF_STATE_KEY:?укажите TF_STATE_KEY}"

sed \
  -e "s|@BUCKET@|${TF_STATE_BUCKET}|g" \
  -e "s|@KEY@|${TF_STATE_KEY}|g" \
  "${TEMPLATE}" >"${OUT}"

echo "Записан ${OUT}"
