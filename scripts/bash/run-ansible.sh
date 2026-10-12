#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly REPO_ROOT
readonly ANSIBLE_DIR="${REPO_ROOT}/ansible"
readonly PLAYBOOK="${ANSIBLE_DIR}/playbooks/configure-workstation.yml"
readonly ARTIFACTS_DIR="${REPO_ROOT}/artifacts"

INVENTORY=""
LIMIT=""
TAGS=""
DRY_RUN=false
VERBOSE=false
REMOVE_SNAP=false
CONFIRM_REMOVE_SNAP=false
LOG_FILE=""
SECRETS_DIR="${ANSIBLE_SECRETS_DIR:-}"
SECRETS_DIR_EXPLICIT=false
VAULT_FILE=""
VAULT_PASSWORD_FILE=""

if [[ -n "${ANSIBLE_SECRETS_DIR:-}" ]]; then
  SECRETS_DIR_EXPLICIT=true
fi

usage() {
  cat <<'EOF'
Uso: run-ansible.sh --inventory CAMINHO --limit ALVO [opcoes]

Configura uma estacao Ubuntu Desktop 26.04 via Ansible. Requer controller Linux
ou WSL, bootstrap concluido, acesso SSH/local e privilegios become no alvo.

Opcoes obrigatorias:
  --inventory CAMINHO      Inventario Ansible explicito
  --limit ALVO             Host ou grupo limitado explicitamente

Opcoes:
  --tags LISTA             Tags Ansible separadas por virgula
  --secrets-dir CAMINHO    Diretorio externo com vault.yml e vault-password
  --remove-snap            Habilita a role destrutiva de migracao do Snap
  --confirm-remove-snap    Confirma remocao real do Snap e de seus dados
  --dry-run, -dryrun       Executa com --check --diff
  --verbose                Executa Ansible com -v
  --help, -help, -h        Exibe esta ajuda
  --                       Encerra o processamento de opcoes

Logs: artifacts/logs/ansible-<timestamp>-<pid>.log, permissao 0600.
Secrets: ANSIBLE_SECRETS_DIR ou ~/.microsoft/usersecrets/ansible, se existir.
Codigos: 0 sucesso; 2 erro de uso; demais valores sao retornados pelo Ansible.

Exemplos:
  scripts/bash/run-ansible.sh --inventory ansible/inventories/lab/hosts.yml \
    --limit workstation01 --dry-run --verbose
  scripts/bash/run-ansible.sh --inventory ansible/inventories/lab/hosts.yml \
    --limit workstation01
  ANSIBLE_SECRETS_DIR="$HOME/.microsoft/usersecrets/ansible" \
    scripts/bash/run-ansible.sh --inventory ansible/inventories/lab/hosts.yml \
    --limit workstation01
  scripts/bash/run-ansible.sh --inventory ansible/inventories/lab/hosts.yml \
    --limit workstation01 --remove-snap --confirm-remove-snap
EOF
}

fail_usage() {
  printf 'Erro: %s\n\n' "$1" >&2
  usage >&2
  exit 2
}

require_value() {
  (($# >= 2)) || fail_usage "A opcao $1 exige um valor."
  [[ -n "$2" && "$2" != -* ]] || fail_usage "Valor invalido para $1."
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --help | -help | -h)
        usage
        exit 0
        ;;
      --inventory)
        require_value "$@"
        INVENTORY="$2"
        shift 2
        ;;
      --limit)
        require_value "$@"
        LIMIT="$2"
        shift 2
        ;;
      --tags)
        require_value "$@"
        TAGS="$2"
        shift 2
        ;;
      --secrets-dir)
        require_value "$@"
        SECRETS_DIR="$2"
        SECRETS_DIR_EXPLICIT=true
        shift 2
        ;;
      --remove-snap)
        REMOVE_SNAP=true
        shift
        ;;
      --confirm-remove-snap)
        CONFIRM_REMOVE_SNAP=true
        shift
        ;;
      --dry-run | -dryrun)
        DRY_RUN=true
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      --)
        shift
        (($# == 0)) || fail_usage "Argumentos posicionais nao sao aceitos."
        ;;
      *) fail_usage "Opcao desconhecida: $1" ;;
    esac
  done
}

validate_posix_secret_permissions() {
  local path="$1" expected_kind="$2" mode

  [[ "${path}" != /mnt/?/* ]] || return 0
  mode="$(stat -c '%a' -- "${path}")" || fail_usage "Nao foi possivel consultar permissoes: ${path}"
  if ((8#${mode} & 077)); then
    fail_usage "Permissoes inseguras em ${expected_kind}: ${path}. Remova acesso de grupo/outros."
  fi
}

configure_external_secrets() {
  if [[ -z "${SECRETS_DIR}" && -n "${HOME:-}" ]]; then
    SECRETS_DIR="${HOME}/.microsoft/usersecrets/ansible"
  fi

  if [[ -z "${SECRETS_DIR}" || ! -e "${SECRETS_DIR}" ]]; then
    [[ "${SECRETS_DIR_EXPLICIT}" == false ]] || fail_usage "Diretorio de secrets nao encontrado: ${SECRETS_DIR}"
    SECRETS_DIR=""
    return
  fi

  [[ -d "${SECRETS_DIR}" ]] || fail_usage "Caminho de secrets nao e diretorio: ${SECRETS_DIR}"
  SECRETS_DIR="$(cd -- "${SECRETS_DIR}" && pwd -P)"
  VAULT_FILE="${SECRETS_DIR}/vault.yml"
  VAULT_PASSWORD_FILE="${SECRETS_DIR}/vault-password"

  [[ -f "${VAULT_FILE}" ]] || fail_usage "Vault externo nao encontrado: ${VAULT_FILE}"
  [[ -f "${VAULT_PASSWORD_FILE}" ]] || fail_usage "Senha do Vault nao encontrada: ${VAULT_PASSWORD_FILE}"
  validate_posix_secret_permissions "${SECRETS_DIR}" "diretorio de secrets"
  validate_posix_secret_permissions "${VAULT_FILE}" "arquivo Vault"
  validate_posix_secret_permissions "${VAULT_PASSWORD_FILE}" "senha do Vault"
}

validate_args() {
  [[ -n "${INVENTORY}" ]] || fail_usage "--inventory e obrigatorio."
  [[ -f "${INVENTORY}" ]] || fail_usage "Inventario nao encontrado: ${INVENTORY}"
  INVENTORY="$(cd -- "$(dirname -- "${INVENTORY}")" && pwd)/$(basename -- "${INVENTORY}")"
  [[ -n "${LIMIT}" ]] || fail_usage "--limit e obrigatorio."
  if [[ "${CONFIRM_REMOVE_SNAP}" == true && "${REMOVE_SNAP}" != true ]]; then
    fail_usage "--confirm-remove-snap exige --remove-snap."
  fi
  if [[ "${REMOVE_SNAP}" == true && "${DRY_RUN}" != true && "${CONFIRM_REMOVE_SNAP}" != true ]]; then
    fail_usage "A remocao real do Snap exige --confirm-remove-snap."
  fi
  configure_external_secrets
}

initialize_log() {
  local run_id mode
  run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  mode="$([[ "${DRY_RUN}" == true ]] && printf simulated || printf real)"
  mkdir -p -- "${ARTIFACTS_DIR}/logs"
  LOG_FILE="${ARTIFACTS_DIR}/logs/ansible-${run_id}.log"
  : >"${LOG_FILE}"
  chmod 600 "${LOG_FILE}"
  export ANSIBLE_LOG_PATH="${LOG_FILE}"
  printf '%s INFO run_id=%s mode=%s wrapper iniciado\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${run_id}" "${mode}" | tee -a "${LOG_FILE}"
}

run_playbook() {
  local command=(ansible-playbook --inventory "${INVENTORY}" "${PLAYBOOK}" --limit "${LIMIT}")
  local effective_tags="${TAGS}"

  if [[ "${DRY_RUN}" == true ]]; then
    command+=(--check --diff)
  fi
  if [[ "${VERBOSE}" == true ]]; then
    command+=(-v)
  fi
  if [[ "${REMOVE_SNAP}" == true ]]; then
    effective_tags="${effective_tags:+${effective_tags},}snap_migration"
    command+=(--extra-vars "snap_migration_remove_snap=true")
    command+=(--extra-vars "snap_migration_confirm_remove_snap=true")
  fi
  if [[ -n "${effective_tags}" ]]; then
    command+=(--tags "${effective_tags}")
  fi
  if [[ -n "${SECRETS_DIR}" ]]; then
    command+=(--extra-vars "@${VAULT_FILE}")
    command+=(--vault-password-file "${VAULT_PASSWORD_FILE}")
  fi

  if [[ "${VERBOSE}" == true ]]; then
    printf 'Comando:' | tee -a "${LOG_FILE}"
    printf ' %q' "${command[@]}" | tee -a "${LOG_FILE}"
    printf '\n' | tee -a "${LOG_FILE}"
  fi

  (
    cd -- "${ANSIBLE_DIR}"
    "${command[@]}"
  )
}

main() {
  parse_args "$@"
  validate_args
  initialize_log
  command -v ansible-playbook >/dev/null || {
    printf 'Erro: ansible-playbook nao encontrado; execute o bootstrap.\n' | tee -a "${LOG_FILE}" >&2
    exit 1
  }
  run_playbook
}

main "$@"
