#!/usr/bin/env bash
set -euo pipefail
set +x

fail() {
  printf 'Erro: %s\n' "$1" >&2
  exit 1
}

main() {
  (($# == 3 || $# == 4)) || fail 'uso interno: render-1password-env.sh VAULT DOCUMENTO CONTA [PROFILE]'
  command -v op >/dev/null 2>&1 || fail '1Password CLI nao encontrado.'

  local op_vault="$1" op_document="$2" op_account="$3"
  local env_content line name value escaped
  local managed_block=false exported_count=0
  local -A existing_names=()
  if [[ -n "${4:-}" && -f "$4" ]]; then
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        '# BEGIN ANSIBLE 1PASSWORD ENV')
          managed_block=true
          continue
          ;;
        '# END ANSIBLE 1PASSWORD ENV')
          managed_block=false
          continue
          ;;
      esac
      [[ "$managed_block" == false ]] || continue
      if [[ "$line" =~ ^[[:space:]]*(export[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*)(=|[[:space:]]|$) ]]; then
        existing_names["${BASH_REMATCH[2]}"]=1
      fi
    done <"$4"
  fi

  if [[ -n "${op_account}" ]]; then
    env_content="$(op document get "${op_document}" --vault "${op_vault}" --account "${op_account}")" ||
      fail 'nao foi possivel baixar o documento do 1Password.'
  else
    env_content="$(op document get "${op_document}" --vault "${op_vault}")" ||
      fail 'nao foi possivel baixar o documento do 1Password.'
  fi

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%$'\r'}"
    [[ -z "${line}" || "${line}" == \#* ]] && continue
    [[ "${line}" == export\ * ]] && line="${line#export }"
    [[ "${line}" == *=* ]] || fail 'linha invalida no documento de ambiente.'
    name="${line%%=*}"
    [[ "${name}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] ||
      fail 'nome de variavel invalido no documento de ambiente.'
  done <<<"${env_content}"

  while IFS= read -r line || [[ -n "${line}" ]]; do
    line="${line%$'\r'}"
    [[ -z "${line}" || "${line}" == \#* ]] && continue
    [[ "${line}" == export\ * ]] && line="${line#export }"
    name="${line%%=*}"
    value="${line#*=}"
    [[ ! -v "existing_names[$name]" ]] || continue
    if [[ "${value}" == \"*\" && "${value}" == *\" && ${#value} -ge 2 ]] ||
      [[ "${value}" == \'*\' && "${value}" == *\' && ${#value} -ge 2 ]]; then
      value="${value:1:${#value}-2}"
    fi
    escaped="${value//\'/\'\\\'\'}"
    printf "export %s='%s'\n" "${name}" "${escaped}"
    exported_count=$((exported_count + 1))
  done <<<"${env_content}"
  if ((exported_count == 0)); then
    printf ':\n'
  fi
}

main "$@"
