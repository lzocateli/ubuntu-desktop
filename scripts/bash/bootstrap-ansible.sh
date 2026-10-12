#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../.." && pwd)"
readonly REPO_ROOT
readonly ARTIFACTS_DIR="${REPO_ROOT}/artifacts"
readonly DEFAULT_ANSIBLE_VERSION="2.19.2"
readonly DEFAULT_PYWINRM_VERSION="0.5.0"
readonly DEFAULT_UV_VERSION="0.8.22"
readonly DEFAULT_COMMUNITY_GENERAL_VERSION="11.3.0"

DRY_RUN=false
VERBOSE=false
ANSIBLE_VERSION="${DEFAULT_ANSIBLE_VERSION}"
PYWINRM_VERSION="${DEFAULT_PYWINRM_VERSION}"
UV_VERSION="${DEFAULT_UV_VERSION}"
LOG_FILE=""
TEMP_DIR=""

usage() {
  cat <<'EOF'
Uso: bootstrap-ansible.sh [opcoes]

Instala uv, ansible-core, pywinrm e as collections do projeto no usuario atual.
Requer Bash 4.4+, Linux amd64, curl, tar e acesso HTTPS. Nao usa sudo.

Opcoes:
  --ansible-version VERSAO  Versao do ansible-core (padrao: 2.19.2)
  --pywinrm-version VERSAO Versao do pywinrm (padrao: 0.5.0)
  --uv-version VERSAO      Versao do uv (padrao: 0.8.22)
  --dry-run, -dryrun       Exibe o plano sem instalar
  --verbose                Exibe detalhes adicionais
  --help, -help, -h        Exibe esta ajuda
  --                       Encerra o processamento de opcoes

Codigos de saida:
  0 sucesso; 2 erro de uso; demais valores indicam falha operacional.

Exemplos:
  scripts/bash/bootstrap-ansible.sh --dry-run --verbose
  scripts/bash/bootstrap-ansible.sh
  scripts/bash/bootstrap-ansible.sh --ansible-version 2.19.2
EOF
}

fail_usage() {
  printf 'Erro: %s\n\n' "$1" >&2
  usage >&2
  exit 2
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --help | -help | -h)
        usage
        exit 0
        ;;
      --dry-run | -dryrun)
        DRY_RUN=true
        shift
        ;;
      --verbose)
        VERBOSE=true
        shift
        ;;
      --ansible-version | --pywinrm-version | --uv-version)
        (($# >= 2)) || fail_usage "A opcao $1 exige um valor."
        [[ -n "$2" && "$2" != -* ]] || fail_usage "Valor invalido para $1."
        case "$1" in
          --ansible-version) ANSIBLE_VERSION="$2" ;;
          --pywinrm-version) PYWINRM_VERSION="$2" ;;
          --uv-version) UV_VERSION="$2" ;;
        esac
        shift 2
        ;;
      --)
        shift
        (($# == 0)) || fail_usage "Argumentos posicionais nao sao aceitos."
        ;;
      *) fail_usage "Opcao desconhecida: $1" ;;
    esac
  done
}

initialize_log() {
  local run_id timestamp
  run_id="$(date -u +%Y%m%dT%H%M%SZ)-$$"
  timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p -- "${ARTIFACTS_DIR}/logs"
  LOG_FILE="${ARTIFACTS_DIR}/logs/bootstrap-ansible-${run_id}.log"
  : >"${LOG_FILE}"
  chmod 600 "${LOG_FILE}"
  printf '%s INFO run_id=%s mode=%s bootstrap iniciado\n' \
    "${timestamp}" "${run_id}" "$([[ "${DRY_RUN}" == true ]] && printf simulated || printf real)" |
    tee -a "${LOG_FILE}"
}

log() {
  local level="$1"
  shift
  printf '%s %s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "${level}" "$*" |
    tee -a "${LOG_FILE}"
}

cleanup() {
  local status=$?
  if [[ -n "${TEMP_DIR}" && -d "${TEMP_DIR}" ]]; then
    rm -rf -- "${TEMP_DIR}"
  fi
  exit "${status}"
}

validate_environment() {
  [[ "$(uname -s)" == Linux ]] || {
    log ERROR "O controller deve executar em Linux ou WSL."
    return 1
  }
  [[ "$(uname -m)" == x86_64 ]] || {
    log ERROR "Arquitetura nao suportada: $(uname -m)."
    return 1
  }
  command -v curl >/dev/null || {
    log ERROR "Dependencia ausente: curl."
    return 1
  }
  command -v tar >/dev/null || {
    log ERROR "Dependencia ausente: tar."
    return 1
  }
}

show_command() {
  local quoted=() argument
  for argument in "$@"; do
    printf -v argument '%q' "${argument}"
    quoted+=("${argument}")
  done
  log INFO "comando: ${quoted[*]}"
}

install_uv() {
  local archive url install_dir current_version
  url="https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz"
  install_dir="${HOME}/.local/bin"
  export PATH="${install_dir}:${PATH}"
  if command -v uv >/dev/null; then
    current_version="$(uv --version)"
    if [[ "${current_version}" == "uv ${UV_VERSION}" ]]; then
      log INFO "uv ja esta disponivel: ${current_version}"
      return
    fi
    log INFO "uv sera atualizado de ${current_version} para ${UV_VERSION}."
  fi

  show_command curl --fail --location --silent --show-error "${url}"
  show_command tar -xzf "uv-${UV_VERSION}.tar.gz"
  if [[ "${DRY_RUN}" == true ]]; then
    return
  fi

  TEMP_DIR="$(mktemp -d "${ARTIFACTS_DIR}/uv-bootstrap.XXXXXX")"
  archive="${TEMP_DIR}/uv-${UV_VERSION}.tar.gz"
  curl --fail --location --silent --show-error --output "${archive}" "${url}"
  tar -xzf "${archive}" -C "${TEMP_DIR}"
  mkdir -p -- "${install_dir}"
  install -m 0755 "${TEMP_DIR}/uv-x86_64-unknown-linux-gnu/uv" "${install_dir}/uv"
  install -m 0755 "${TEMP_DIR}/uv-x86_64-unknown-linux-gnu/uvx" "${install_dir}/uvx"
  export PATH="${install_dir}:${PATH}"
}

install_ansible() {
  local requirements="${REPO_ROOT}/ansible/requirements.yml"
  local ansible_dir="${REPO_ROOT}/ansible"
  show_command uv tool install --force "ansible-core==${ANSIBLE_VERSION}" --with "pywinrm==${PYWINRM_VERSION}"
  show_command ansible-galaxy collection install --requirements-file "${requirements}"
  if [[ "${DRY_RUN}" == true ]]; then
    return
  fi

  uv tool install --force "ansible-core==${ANSIBLE_VERSION}" --with "pywinrm==${PYWINRM_VERSION}"
  export PATH="${HOME}/.local/bin:${PATH}"
  (
    cd -- "${ansible_dir}"
    ansible-galaxy collection install --requirements-file "${requirements}"
  )
}

validate_installation() {
  if [[ "${DRY_RUN}" == true ]]; then
    log INFO "simulacao concluida; nenhuma ferramenta foi instalada."
    return
  fi
  local uv_output ansible_output community_general_version
  uv_output="$(uv --version)"
  [[ "${uv_output}" == "uv ${UV_VERSION}" ]] || {
    log ERROR "uv esperado ${UV_VERSION}; encontrado: ${uv_output}"
    return 1
  }
  log INFO "${uv_output}"

  ansible_output="$(ansible-playbook --version)"
  [[ "${ansible_output}" == *"ansible [core ${ANSIBLE_VERSION}]"* ]] || {
    log ERROR "ansible-core esperado ${ANSIBLE_VERSION}; versao instalada divergente."
    return 1
  }
  log INFO "${ansible_output%%$'\n'*}"

  community_general_version="$(
    ansible-galaxy collection list community.general |
      awk '$1 == "community.general" {print $2; exit}'
  )"
  [[ "${community_general_version}" == "${DEFAULT_COMMUNITY_GENERAL_VERSION}" ]] || {
    log ERROR "community.general esperado ${DEFAULT_COMMUNITY_GENERAL_VERSION}; encontrado: ${community_general_version:-ausente}"
    return 1
  }
  log INFO "community.general ${community_general_version}"

  local tool_dir
  tool_dir="$(uv tool dir)"
  local pywinrm_version
  pywinrm_version="$("${tool_dir}/ansible-core/bin/python" -c 'import winrm; print(winrm.__version__)')"
  [[ "${pywinrm_version}" == "${PYWINRM_VERSION}" ]] || {
    log ERROR "pywinrm esperado ${PYWINRM_VERSION}; encontrado: ${pywinrm_version}"
    return 1
  }
  log INFO "pywinrm ${pywinrm_version}"
  log INFO "bootstrap validado com sucesso."
}

main() {
  parse_args "$@"
  initialize_log
  trap cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM
  validate_environment
  [[ "${VERBOSE}" == true ]] && log INFO "repositorio=${REPO_ROOT}"
  install_uv
  install_ansible
  validate_installation
}

main "$@"
