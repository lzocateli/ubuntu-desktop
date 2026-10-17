#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  HELPER="${REPO_ROOT}/ansible/roles/git_config/files/git-credential-azure-devops.sh"
  TEST_HOME="${BATS_TEST_TMPDIR}/home com espacos"
  TEST_USER="$(id -un)"
  TEST_GROUP="$(id -gn)"
  export TEST_HOME TEST_USER TEST_GROUP
  export GIT_ROLE_PATH="${REPO_ROOT}/ansible/roles/git_config"
  export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="${TEST_HOME}/.gitconfig" GIT_TERMINAL_PROMPT=0
  export AZURE_DEVOPS_EXT_PAT=FAKE_PAT_FOR_TEST_ONLY
  mkdir -p "${TEST_HOME}"
  cat >"${BATS_TEST_TMPDIR}/git-playbook.yml" <<'YAML'
---
- name: Testar configuracao Git em perfil descartavel
  hosts: localhost
  connection: local
  gather_facts: false
  vars:
    ubuntu_desktop_user: "{{ lookup('env', 'TEST_USER') }}"
    ubuntu_desktop_home: "{{ lookup('env', 'TEST_HOME') }}"
    git_config_group: "{{ lookup('env', 'TEST_GROUP') }}"
  tasks:
    - ansible.builtin.include_role:
        name: "{{ lookup('env', 'GIT_ROLE_PATH') }}"
YAML
}

run_git_role() {
  ansible-playbook -i localhost, --limit localhost "${BATS_TEST_TMPDIR}/git-playbook.yml" "$@"
}

run_git_role_with_pat() {
  run_git_role -e '{"git_config_azure_devops_pat_enabled":true,"git_config_azure_devops_organization":"example-org","git_config_azure_devops_username":"example-user"}' "$@"
}

invoke_helper() {
  printf 'protocol=%s\nhost=%s\npath=%s\n\n' "$1" "$2" "$3" |
    bash "$HELPER" --organization example-org --username example-user "${@:4}"
}

fill_credential() {
  printf 'protocol=%s\nhost=%s\npath=%s\n\n' "$1" "$2" "$3" | HOME="$TEST_HOME" git credential fill
}

fill_credential_without_pat() {
  printf 'protocol=https\nhost=dev.azure.com\npath=example-org/projeto/_git/repo\n\n' |
    env -u AZURE_DEVOPS_EXT_PAT HOME="$TEST_HOME" git credential fill
}

invoke_helper_without_pat() {
  printf 'protocol=https\nhost=dev.azure.com\npath=example-org/repo\n\n' |
    env -u AZURE_DEVOPS_EXT_PAT bash "$HELPER" --organization example-org --username example-user get
}

invoke_helper_with_invalid_pat() {
  printf 'protocol=https\nhost=dev.azure.com\npath=example-org/repo\n\n' |
    env AZURE_DEVOPS_EXT_PAT=$'PRIVATE_SENTINEL\npassword=outro' \
      bash "$HELPER" --organization example-org --username example-user get
}

@test "role preserva identidade existente backup e converge sem dados corporativos" {
  git config --global user.name 'Usuario Existente'
  git config --global user.email usuario@example.invalid
  cp "${TEST_HOME}/.gitconfig" "${BATS_TEST_TMPDIR}/original"
  run run_git_role
  [ "$status" -eq 0 ]
  [ "$(git config --global user.name)" = 'Usuario Existente' ]
  cmp "${TEST_HOME}/.gitconfig.pre-ansible" "${BATS_TEST_TMPDIR}/original"
  [ "$(stat -c '%a' "${TEST_HOME}/.gitconfig")" = 600 ]
  [ "$(git config --global help.autocorrect)" = 0 ]
  run run_git_role
  [ "$status" -eq 0 ]
  [[ "$output" == *'changed=0'* ]]
  run grep -F cat.com "${TEST_HOME}/.gitconfig"
  [ "$status" -eq 1 ]
}

@test "role aceita identidade legada do inventario terminal" {
  run run_git_role -e '{"terminal_git_user_name":"Usuario Inventario","terminal_git_user_email":"inventario@example.invalid"}'
  [ "$status" -eq 0 ]
  [ "$(git config --global user.name)" = 'Usuario Inventario' ]
  [ "$(git config --global user.email)" = inventario@example.invalid ]
}

@test "check mode nao cria configuracao ou backup" {
  run run_git_role --check --diff
  [ "$status" -eq 0 ]
  [ ! -e "${TEST_HOME}/.gitconfig" ]
  [ ! -e "${TEST_HOME}/.gitconfig.pre-ansible" ]
}

@test "helper ajuda aliases e simulacao nao retornam credenciais nem criam arquivos" {
  for option in --help -help -h; do
    run env -u AZURE_DEVOPS_EXT_PAT bash "$HELPER" "$option"
    [ "$status" -eq 0 ]
    [[ "$output" == *'Uso:'* ]]
  done
  for option in --dry-run -dryrun; do
    run invoke_helper https dev.azure.com example-org/repo get "$option"
    [ "$status" -eq 0 ]
    [[ "$output" == *'Simulacao:'* ]]
    [[ "$output" != *'password='* ]]
  done
  [ ! -e "$TEST_HOME/.git-credentials" ]
}

@test "helper restringe PAT ao HTTPS host e organizacao exatos" {
  run invoke_helper https dev.azure.com example-org/projeto/_git/repo get
  [ "$status" -eq 0 ]
  [[ "$output" == *'username=example-user'* ]]
  [[ "$output" == *'password=FAKE_PAT_FOR_TEST_ONLY'* ]]
  for request in 'http dev.azure.com example-org/repo' \
    'https github.com example-org/repo' \
    'https dev.azure.com.evil.invalid example-org/repo' \
    'https dev.azure.com outra-org/repo' \
    'https dev.azure.com example-org-evil/repo' \
    'https dev.azure.com example-org%2Frepo'; do
    read -r -a fields <<<"$request"
    run invoke_helper "${fields[@]}" get
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
}

@test "helper falha sem PAT e rejeita injecao sem expor valores" {
  run invoke_helper_without_pat
  [ "$status" -eq 1 ]
  [[ "$output" == *'quit=true'* ]]
  run invoke_helper_with_invalid_pat
  [ "$status" -eq 1 ]
  [[ "$output" != *PRIVATE_SENTINEL* ]]
}

@test "helper nao persiste store ou erase" {
  for operation in store erase; do
    run invoke_helper https dev.azure.com example-org/repo "$operation"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  done
  [ ! -e "$TEST_HOME/.git-credentials" ]
}

@test "role instala helper sem gravar PAT e converge com caminho contendo espacos" {
  printf 'export USER_CONTENT=preserved\n' >"$TEST_HOME/.profile"
  run run_git_role_with_pat
  [ "$status" -eq 0 ]
  [ "$(stat -c '%a' "$TEST_HOME/.local/lib/ubuntu-desktop/git-credential-azure-devops.sh")" = 700 ]
  grep -Fxq 'export USER_CONTENT=preserved' "$TEST_HOME/.profile"
  for profile in .profile .bashrc .zshrc; do
    grep -Fxq 'export AZURE_DEVOPS_EXT_PAT' "$TEST_HOME/$profile"
  done
  run grep -RF -- "$AZURE_DEVOPS_EXT_PAT" "$TEST_HOME"
  [ "$status" -eq 1 ]
  run fill_credential https dev.azure.com example-org/projeto/_git/repo
  [ "$status" -eq 0 ]
  [[ "$output" == *'password=FAKE_PAT_FOR_TEST_ONLY'* ]]
  run run_git_role_with_pat
  [ "$status" -eq 0 ]
  [[ "$output" == *'changed=0'* ]]
}

@test "check mode com PAT nao cria helper ou modifica profiles" {
  printf 'export USER_CONTENT=preserved\n' >"$TEST_HOME/.profile"
  run run_git_role_with_pat --check --diff
  [ "$status" -eq 0 ]
  [ ! -e "$TEST_HOME/.local" ]
  [ ! -e "$TEST_HOME/.gitconfig" ]
  [ ! -e "$TEST_HOME/.bashrc" ]
  [ ! -e "$TEST_HOME/.zshrc" ]
  [ "$(cat "$TEST_HOME/.profile")" = 'export USER_CONTENT=preserved' ]
}

@test "helper restrito impede fallback para credencial antiga apenas na organizacao configurada" {
  run run_git_role_with_pat
  [ "$status" -eq 0 ]
  git config --global --add credential.helper '!printf "username=antigo\npassword=OLD_FAKE_CREDENTIAL\n"'
  run fill_credential https dev.azure.com example-org/projeto/_git/repo
  [ "$status" -eq 0 ]
  [[ "$output" == *'password=FAKE_PAT_FOR_TEST_ONLY'* ]]
  [[ "$output" != *OLD_FAKE_CREDENTIAL* ]]
  run fill_credential https github.com conta/repo
  [ "$status" -eq 0 ]
  [[ "$output" == *OLD_FAKE_CREDENTIAL* ]]
  [[ "$output" != *FAKE_PAT_FOR_TEST_ONLY* ]]
  run fill_credential_without_pat
  [ "$status" -ne 0 ]
  [[ "$output" != *OLD_FAKE_CREDENTIAL* ]]
}

@test "desabilitar PAT remove helper e blocos sem apagar variaveis pessoais" {
  printf 'export USER_CONTENT=preserved\n' >"$TEST_HOME/.profile"
  run run_git_role_with_pat
  [ "$status" -eq 0 ]
  run run_git_role
  [ "$status" -eq 0 ]
  [ ! -e "$TEST_HOME/.local/lib/ubuntu-desktop/git-credential-azure-devops.sh" ]
  grep -Fxq 'export USER_CONTENT=preserved' "$TEST_HOME/.profile"
  run grep -F 'ANSIBLE AZURE DEVOPS PAT ENV' "$TEST_HOME/.profile"
  [ "$status" -eq 1 ]
  run git config --global --get-regexp '^credential\..*\.helper$'
  [ "$status" -eq 1 ]
}
