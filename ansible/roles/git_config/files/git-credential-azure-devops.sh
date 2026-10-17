#!/usr/bin/env bash
set +x
set -euo pipefail

usage() {
  printf '%s\n' \
    'Uso: git-credential-azure-devops.sh [opcoes] get|store|erase' \
    'Helper Git HTTPS para Azure DevOps; Bash >= 4.4, sem rede ou privilegios.' \
    'Le stdin e AZURE_DEVOPS_EXT_PAT do ambiente; nao persiste credenciais.' \
    '--organization NOME  Organizacao autorizada, obrigatoria.' \
    '--username NOME      Usuario HTTPS, obrigatorio.' \
    '--help, -help, -h    Ajuda sem ler stdin ou criar arquivos.' \
    '--dry-run, -dryrun   Valida sem retornar credenciais.' \
    '--verbose           Diagnostico em stderr sem dados sensiveis.' \
    '--                  Encerra opcoes; informe get, store ou erase.' \
    'store/erase nao alteram estado. Nao cria logs em arquivo.' \
    'Saida: protocolo Git; 0 sucesso, 1 PAT invalido/ausente, 2 uso invalido.' \
    'Exemplo: --organization exemplo --username usuario get'
}

main() {
  local organization='' username='' operation=''
  local dry_run=false verbose=false field protocol='' host='' credential_path=''
  while (($#)); do
    case "$1" in
      --help | -help | -h)
        usage
        return 0
        ;;
      --organization | --username)
        if (($# < 2)) || [[ -z "$2" || "$2" == -* ]]; then
          printf 'Erro: opcao exige um valor.\n' >&2
          return 2
        fi
        if [[ "$1" == --organization ]]; then organization=$2; else username=$2; fi
        shift 2
        ;;
      --dry-run | -dryrun)
        dry_run=true
        shift
        ;;
      --verbose)
        verbose=true
        shift
        ;;
      --)
        shift
        (($# == 1)) && [[ -z "$operation" ]] || return 2
        operation=$1
        shift
        ;;
      get | store | erase)
        [[ -z "$operation" ]] || return 2
        operation=$1
        shift
        ;;
      *)
        printf 'Erro: argumento nao reconhecido. Consulte --help.\n' >&2
        return 2
        ;;
    esac
  done
  if [[ ! "$organization" =~ ^[a-zA-Z0-9_-]+$ || -z "$username" || "$username" == *$'\n'* || "$username" == *$'\r'* ]]; then
    printf 'Erro: organizacao ou usuario invalido.\n' >&2
    return 2
  fi
  case "$operation" in
    store | erase) return 0 ;;
    get) ;;
    *)
      printf 'Erro: informe get, store ou erase.\n' >&2
      return 2
      ;;
  esac
  while IFS= read -r field || [[ -n "$field" ]]; do
    [[ -n "$field" ]] || break
    case "$field" in
      protocol=*) protocol=${field#protocol=} ;;
      host=*) host=${field#host=} ;;
      path=*) credential_path=${field#path=} ;;
    esac
  done
  [[ "$protocol" == https && "$host" == dev.azure.com ]] || return 0
  case "$credential_path" in
    "$organization" | "$organization/"*) ;;
    *) return 0 ;;
  esac
  if [[ "$dry_run" == true ]]; then
    printf 'Simulacao: requisicao autorizada; nenhuma credencial retornada.\n' >&2
    return 0
  fi
  if [[ -z "${AZURE_DEVOPS_EXT_PAT:-}" || "$AZURE_DEVOPS_EXT_PAT" == *$'\n'* || "$AZURE_DEVOPS_EXT_PAT" == *$'\r'* ]]; then
    printf 'quit=true\n\n'
    printf 'Erro: exporte AZURE_DEVOPS_EXT_PAT com um PAT valido.\n' >&2
    return 1
  fi
  if [[ "$verbose" == true ]]; then
    printf 'Credential helper: requisicao HTTPS autorizada; PAT obtido do ambiente.\n' >&2
  fi
  printf 'username=%s\npassword=%s\n\n' "$username" "$AZURE_DEVOPS_EXT_PAT"
}

main "$@"
