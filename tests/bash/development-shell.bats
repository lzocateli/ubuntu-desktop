#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  TEMPLATE="${REPO_ROOT}/ansible/roles/terminal/templates/development-shell.sh.j2"
  RUNTIME="${BATS_TEST_TMPDIR}/development-shell.sh"
  HOME="${BATS_TEST_TMPDIR}/home"
  export HOME RUNTIME
  mkdir -p "${HOME}"

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

@test "runtime configura certificado e funcoes nos shells suportados" {
  run bash -c '. "$RUNTIME"; declare -F node npm npx >/dev/null; printf "%s" "$SSL_CERT_DIR"'

  [ "${status}" -eq 0 ]
  [ "${output}" = "${HOME}/.aspnet/dev-certs/trust:/usr/lib/ssl/certs" ]

  run zsh -c '. "$RUNTIME"; whence -w node npm npx >/dev/null'

  [ "${status}" -eq 0 ]
}

@test "aliases de listagem usam argumentos corretos no Bash apos recarregar" {
  run bash -O expand_aliases -c $'. "$RUNTIME"\n. "$RUNTIME"\nls() { printf "%s\\n" "$@"; }\nlh'

  [ "${status}" -eq 0 ]
  [ "${output}" = '-lha' ]
}

@test "aliases de listagem usam argumentos corretos no ZSH apos recarregar" {
  run zsh -f <<'ZSH'
. "$RUNTIME"
. "$RUNTIME"
ls() { printf '%s\n' "$@"; }
lh
ZSH

  [ "${status}" -eq 0 ]
  [ "${output}" = '-lha' ]
}

@test "lhr busca multiplos padroes recursivamente sem glob local no ZSH" {
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