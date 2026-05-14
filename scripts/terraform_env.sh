#!/usr/bin/env bash
# Переменные Terraform (TF_VAR_*) для Task1Advanced.
# При настроенном yc и типовой сети в каталоге можно выставить только то, чего нет в config:
#   cloud_id / folder_id / zone — из yc config;
#   subnet — подсеть с именем default-<зона> или первая подсеть в этой зоне (yc vpc subnet list);
#   ssh — файл: $TF_SSH_PUBKEY_FILE, иначе ~/.ssh/id_ed25519.pub, ~/.ssh/id_rsa.pub.
# Уже заданные в окружении TF_VAR_* не перезаписываются.
#
# Нужны: yc, python3.
# Скрипт рассчитан на «source». Не используйте exit при ошибке — закроется ваш shell.

set -uo pipefail

_die() {
  echo "$*" >&2
  if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    return 1
  fi
  exit 1
}

command -v yc >/dev/null 2>&1 || _die "Нужен yc в PATH."
command -v python3 >/dev/null 2>&1 || _die "Нужен python3 в PATH (разбор JSON от yc)."

_json_subnet_id_from_get() {
  python3 -c '
import json, sys
d = json.load(sys.stdin)
if "id" in d:
    print(d["id"])
elif isinstance(d.get("subnet"), dict) and "id" in d["subnet"]:
    print(d["subnet"]["id"])
else:
    sys.exit(1)
'
}

_resolve_subnet_id() {
  local folder zone out
  folder=$(yc config get folder-id) || return 1
  zone="${TF_VAR_zone:-$(yc config get compute-default-zone 2>/dev/null || true)}"
  [[ -n "${zone}" ]] || {
    echo "Задайте TF_VAR_zone или compute-default-zone в yc config." >&2
    return 1
  }

  if out=$(yc vpc subnet get --name "default-${zone}" --folder-id "${folder}" --format json 2>/dev/null); then
    echo "${out}" | _json_subnet_id_from_get
    return 0
  fi

  yc vpc subnet list --folder-id "${folder}" --format json 2>/dev/null | python3 -c "
import json, sys
zone = sys.argv[1]
raw = sys.stdin.read()
if not raw.strip():
    sys.exit(1)
data = json.loads(raw)
items = data if isinstance(data, list) else data.get('subnets') or []
for s in items:
    z = s.get('zone_id') or s.get('zone')
    if z == zone:
        print(s['id'])
        sys.exit(0)
sys.exit(1)
" "${zone}"
}

_resolve_ssh_public_key() {
  local f candidates home_dir line
  home_dir="${HOME}"
  candidates=()
  [[ -n "${TF_SSH_PUBKEY_FILE:-}" ]] && candidates+=("${TF_SSH_PUBKEY_FILE}")
  candidates+=("${home_dir}/.ssh/id_ed25519.pub" "${home_dir}/.ssh/id_rsa.pub")

  for f in "${candidates[@]}"; do
    [[ -f "${f}" ]] || continue
    line=$(head -n 1 "${f}" | tr -d '\r')
    if [[ "${line}" =~ ^ssh-(rsa|ed25519|ecdsa) ]]; then
      export TF_VAR_ssh_public_key="${line}"
      return 0
    fi
  done
  echo "Не найден публичный SSH-ключ. Укажите TF_SSH_PUBKEY_FILE или TF_VAR_ssh_public_key." >&2
  return 1
}

if [[ -z "${TF_VAR_cloud_id:-}" ]]; then
  TF_VAR_cloud_id=$(yc config get cloud-id) || _die "yc config get cloud-id не выполнился."
  export TF_VAR_cloud_id
fi
if [[ -z "${TF_VAR_folder_id:-}" ]]; then
  TF_VAR_folder_id=$(yc config get folder-id) || _die "yc config get folder-id не выполнился."
  export TF_VAR_folder_id
fi
if [[ -z "${TF_VAR_zone:-}" ]]; then
  _z=$(yc config get compute-default-zone 2>/dev/null || true)
  if [[ -n "${_z}" ]]; then
    export TF_VAR_zone="${_z}"
  else
    _die "В yc config нет compute-default-zone; задайте TF_VAR_zone вручную."
  fi
fi

if [[ -z "${TF_VAR_subnet_id:-}" ]]; then
  TF_VAR_subnet_id=$(_resolve_subnet_id) || _die "Не удалось определить TF_VAR_subnet_id. Задайте TF_VAR_subnet_id вручную."
  export TF_VAR_subnet_id
fi

if [[ -z "${TF_VAR_ssh_public_key:-}" ]]; then
  _resolve_ssh_public_key || _die "Не удалось прочитать публичный SSH-ключ."
fi

export TF_VAR_cloud_id TF_VAR_folder_id TF_VAR_zone TF_VAR_subnet_id TF_VAR_ssh_public_key
