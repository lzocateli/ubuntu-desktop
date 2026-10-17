#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  TEMPLATE="${REPO_ROOT}/ansible/roles/terminal/templates/development-shell.sh.j2"
  RUNTIME="${BATS_TEST_TMPDIR}/development-shell.sh"
  HOME="${BATS_TEST_TMPDIR}/home"
  export HOME RUNTIME
  unset DOTNET_ROOT SSL_CERT_DIR POSH_HAS_AZ POSH_HAS_ANSIBLE POSH_HAS_TERRAFORM
  mkdir -p "${HOME}"
  FUNCTION_DIR="$HOME/.local/lib/ubuntu-desktop"
  mkdir -p "$FUNCTION_DIR"
  for function_name in node npm npx ng op lh lhr; do
    cp -- "${REPO_ROOT}/ansible/roles/terminal/templates/${function_name}.sh.j2" \
      "$FUNCTION_DIR/${function_name}.sh"
  done

  ansible localhost --connection local \
    --module-name ansible.builtin.template \
    --args "src=${TEMPLATE} dest=${RUNTIME} mode=0600" \
    --extra-vars '{"terminal_devops_image":"example/devops:test"}' \
    >/dev/null
}

create_podman_stub() {
  stub_dir="${BATS_TEST_TMPDIR}/bin"
  capture="${BATS_TEST_TMPDIR}/podman-arguments.txt"
  export capture
  mkdir -p "${stub_dir}"
  cat >"${stub_dir}/podman" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"${capture}"
EOF
  chmod +x "${stub_dir}/podman"
  export PATH="${stub_dir}:${PATH}"
}

create_eza_stub() {
  mkdir -p "${BATS_TEST_TMPDIR}/bin"
  printf '#!/usr/bin/env bash\nwhile [[ "$1" != -- ]]; do shift; done\nshift\nif (($#)); then printf "%%s\\n" "$@"; else printf "eza-color-auto\\n"; fi\n' >"${BATS_TEST_TMPDIR}/bin/eza"
  chmod +x "${BATS_TEST_TMPDIR}/bin/eza"
  export PATH="${BATS_TEST_TMPDIR}/bin:${PATH}"
}

@test "runtime prioriza .NET do usuario sem duplicar PATH ao recarregar" {
  for shell in bash zsh; do
    run "${shell}" -c '
      . "$RUNTIME"
      previous_path="$PATH"
      . "$RUNTIME"
      test "$DOTNET_ROOT" = "$HOME/.dotnet" &&
        test "$PATH" = "$previous_path" &&
        case "$PATH" in
          "$DOTNET_ROOT:$DOTNET_ROOT/tools:"*) exit 0 ;;
          *) exit 1 ;;
        esac
    '

    [ "${status}" -eq 0 ]
  done
}

@test "runtime configura certificado e funcoes nos shells suportados" {
  run bash -c '. "$RUNTIME"; declare -F node npm npx >/dev/null; printf "%s" "$SSL_CERT_DIR"'

  [ "${status}" -eq 0 ]
  [ "${output}" = "${HOME}/.aspnet/dev-certs/trust:/usr/lib/ssl/certs" ]

  run zsh -c '. "$RUNTIME"; whence -w node npm npx >/dev/null'

  [ "${status}" -eq 0 ]
}

@test "aliases de listagem usam argumentos corretos no Bash apos recarregar" {
  create_eza_stub
  run bash -O expand_aliases -c $'. "$RUNTIME"\n. "$RUNTIME"\nls() { printf "%s\\n" "$@"; }\nlh'

  [ "${status}" -eq 0 ]
  [ "${output}" = 'eza-color-auto' ]
}

@test "aliases de listagem usam argumentos corretos no ZSH apos recarregar" {
  create_eza_stub
  run zsh -f <<'ZSH'
. "$RUNTIME"
. "$RUNTIME"
ls() { printf '%s\n' "$@"; }
lh
ZSH

  [ "${status}" -eq 0 ]
  [ "${output}" = 'eza-color-auto' ]
}

@test "lhr busca multiplos padroes recursivamente sem glob local no ZSH" {
  create_eza_stub
  workspace="${BATS_TEST_TMPDIR}/workspace com espaco"
  export workspace
  mkdir -p "${workspace}/subpasta"
  touch "${workspace}/subpasta/config.yml" "${workspace}/subpasta/dados com espaco.json" \
    "${workspace}/subpasta/.oculto.json" "${workspace}/subpasta/ignorado.txt"

  run zsh -f -c '. "$RUNTIME"; . "$RUNTIME"; . /dev/stdin' <<'ZSH'
cd "$workspace"
lhr *.yml *.json
ZSH

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"./subpasta/config.yml"* ]]
  [[ "${output}" == *"./subpasta/dados com espaco.json"* ]]
  [[ "${output}" == *"./subpasta/.oculto.json"* ]]
  [[ "${output}" != *"ignorado.txt"* ]]
}

@test "lhr preserva padroes no Bash e nao lista a pasta quando nao encontra arquivos" {
  create_eza_stub
  workspace="${BATS_TEST_TMPDIR}/workspace"
  export workspace
  mkdir -p "${workspace}/subpasta"
  touch "${workspace}/local.yml" "${workspace}/subpasta/remoto.yml" \
    "${workspace}/subpasta/remoto.json"

  run bash -O expand_aliases -c '. "$RUNTIME"; . "$RUNTIME"; . /dev/stdin' <<'BASH'
cd "$workspace"
lhr '*.yml' '*.json'
BASH

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"./local.yml"* ]]
  [[ "${output}" == *"./subpasta/remoto.yml"* ]]
  [[ "${output}" == *"./subpasta/remoto.json"* ]]

  for shell in bash zsh; do
    run "${shell}" -c '. "$RUNTIME"; cd "$workspace"; _ubuntu_desktop_lhr "*.inexistente"'

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
  done
}

@test "node usa Podman com imagem, usuario e workspace" {
  create_podman_stub
  workspace="${BATS_TEST_TMPDIR}/workspace com espaco"
  mkdir -p "${workspace}"

  run bash -c 'cd "$1"; . "$RUNTIME"; node --version' _ "${workspace}"

  [ "${status}" -eq 0 ]
  grep -Fx -- "--userns=keep-id" "${capture}"
  grep -Fx -- "$(id -u):$(id -g)" "${capture}"
  grep -Fx -- "type=bind,source=${workspace},target=/workspace" "${capture}"
  grep -Fx -- "example/devops:test" "${capture}"
  grep -Fx -- "node" "${capture}"
  grep -Fx -- "--version" "${capture}"

  run grep -F -- "/run/podman/podman.sock" "${capture}"

  [ "${status}" -ne 0 ]
}

@test "runtime rootless fica restrito a node npm e npx" {
  run bash -c '. "$RUNTIME"; declare -F copilot'

  [ "${status}" -ne 0 ]

  run grep -Eq 'COPILOT_GITHUB_TOKEN|GH_TOKEN|GITHUB_TOKEN|\.copilot|@github/copilot' "${RUNTIME}"

  [ "${status}" -ne 0 ]
}

@test "ng usa imagem preparada sem download implicito e op encaminha argumentos" {
  create_podman_stub
  for shell in bash zsh; do
    run "${shell}" -c '. "$RUNTIME"; ng version'
    [ "${status}" -eq 0 ]
    grep -Fx -- '--pull=never' "${capture}"
    grep -Fx -- 'ng' "${capture}"
    mkdir -p "$HOME/.local/bin"
    printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$@"\n' >"$HOME/.local/bin/op"
    chmod +x "$HOME/.local/bin/op"
    run "${shell}" -c '. "$RUNTIME"; op item get "nome com espaco"'
    [ "${status}" -eq 0 ]
    [ "${lines[2]}" = 'nome com espaco' ]
  done
}

@test "runtime preserva indicadores do prompt definidos pelo profile e PATH local" {
  for shell in bash zsh; do
    run "$shell" -c '
      export POSH_HAS_AZ=custom POSH_HAS_ANSIBLE=false POSH_HAS_TERRAFORM=true
      export DOTNET_ROOT="$HOME/sdk-custom" SSL_CERT_DIR="$HOME/certificados"
      . "$RUNTIME"
      test "$POSH_HAS_AZ" = custom && test "$POSH_HAS_ANSIBLE" = false &&
        test "$POSH_HAS_TERRAFORM" = true &&
        test "$DOTNET_ROOT" = "$HOME/sdk-custom" && test "$SSL_CERT_DIR" = "$HOME/certificados" &&
        case ":$PATH:" in *":$HOME/.local/bin:"*) exit 0;; *) exit 1;; esac
    '
    [ "$status" -eq 0 ]
  done
}

@test "runtime migra alias lh antigo sem erro de parse" {
  create_eza_stub
  for shell in bash zsh; do
    run "$shell" -c 'alias lh="ls -lha"; . "$RUNTIME"; lh'
    [ "$status" -eq 0 ]
    [ "$output" = eza-color-auto ]
  done
}

@test "falha de auditoria impede executar container" {
  create_podman_stub
  mkdir -p "$HOME/.local/share/ubuntu-desktop"
  touch "$HOME/.local/share/ubuntu-desktop/artifacts"
  run bash -c '. "$RUNTIME"; node --version'
  [ "$status" -ne 0 ]
  [ ! -e "$capture" ]
}

@test "runtime carrega todas as funcoes de arquivos individuais sem deixar variaveis auxiliares" {
  for shell in bash zsh; do
    run "$shell" -c '
      . "$RUNTIME"
      for function_name in node npm npx ng op lh lhr; do
        command -v "$function_name" >/dev/null || exit 1
      done
      test -z "${_ubuntu_desktop_function+x}" &&
        test -z "${_ubuntu_desktop_function_file+x}"
    '
    [ "$status" -eq 0 ]
  done
  run grep -E '^(node|npm|npx|ng|op|lh|lhr)\(\)' "$RUNTIME"
  [ "$status" -eq 1 ]
}

@test "runtime nao define indicadores de apps instalados" {
  for shell in bash zsh; do
    run "$shell" -c '
      . "$RUNTIME"
      test -z "${POSH_HAS_AZ+x}" && test -z "${POSH_HAS_ANSIBLE+x}" &&
        test -z "${POSH_HAS_TERRAFORM+x}"
    '
    [ "$status" -eq 0 ]
  done
}

render_context_prompt() {
  local workspace="$1"
  local theme="${BATS_TEST_TMPDIR}/context.omp.json"
  jq '{version: .version, blocks: [.blocks[] | select(.alignment == "right") |
    .segments = [.segments[] | select(.type == "text")]]}' \
    "${REPO_ROOT}/ansible/roles/terminal/files/atomic.omp.json" >"$theme"
  (
    cd "$workspace" || exit 1
    export HOME="${BATS_TEST_TMPDIR}/prompt-home"
    export XDG_CACHE_HOME="${BATS_TEST_TMPDIR}/prompt-cache"
    export POSH_CACHE_DIR="$XDG_CACHE_HOME"
    export POSH_HAS_AZ=true POSH_HAS_ANSIBLE=true POSH_HAS_TERRAFORM=true
    oh-my-posh print primary --config "$theme" --shell zsh --pwd "$workspace" \
      --terminal-width 200 --plain
  )
}

@test "prompt oculta apps em pasta vazia mesmo com indicadores antigos ativos" {
  workspace="${BATS_TEST_TMPDIR}/pasta vazia"
  mkdir -p "$workspace"
  run render_context_prompt "$workspace"
  [ "$status" -eq 0 ]
  [[ "$output" != *'Azure CLI'* && "$output" != *Ansible* && "$output" != *Terraform* ]]
  mkdir "$workspace/.azure"
  run render_context_prompt "$workspace"
  [ "$status" -eq 0 ]
  [[ "$output" != *'Azure CLI'* ]]
}

@test "prompt identifica somente o contexto presente na pasta" {
  local marker expected
  for marker in azure.yaml ansible.cfg main.tf; do
    workspace="${BATS_TEST_TMPDIR}/projeto-$marker"
    mkdir -p "$workspace"
    touch "$workspace/$marker"
    case "$marker" in
      azure.yaml) expected='Azure CLI' ;;
      ansible.cfg) expected=Ansible ;;
      main.tf) expected=Terraform ;;
    esac
    run render_context_prompt "$workspace"
    [ "$status" -eq 0 ]
    [[ "$output" == *"$expected"* ]]
    for indicator in 'Azure CLI' Ansible Terraform; do
      if [[ "$indicator" != "$expected" ]]; then
        [[ "$output" != *"$indicator"* ]]
      fi
    done
  done
}
