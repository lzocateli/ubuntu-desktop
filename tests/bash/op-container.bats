#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  FIXTURE_HOME="${BATS_TEST_TMPDIR}/home com espaco"
  FIXTURE_BIN="${BATS_TEST_TMPDIR}/bin"
  IMAGE_STATE="${BATS_TEST_TMPDIR}/image-present"
  CAPTURE="${BATS_TEST_TMPDIR}/calls"
  WRAPPER="${FIXTURE_HOME}/.local/bin/op"
  FIXTURE_UID="$(id -u)"
  FIXTURE_GID="$(id -g)"
  export FIXTURE_HOME FIXTURE_BIN FIXTURE_UID FIXTURE_GID IMAGE_STATE CAPTURE
  mkdir -p "$FIXTURE_BIN" "$FIXTURE_HOME/.local/bin" \
    "$FIXTURE_HOME/.local/share/ubuntu-desktop/devops-home"
  cat >"$FIXTURE_BIN/podman" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >>"$CAPTURE"
case "$1 $2" in
  'image exists')
    if [[ -n "${IMAGE_PROBE_RC:-}" ]]; then exit "$IMAGE_PROBE_RC"; fi
    test -f "$IMAGE_STATE"
    ;;
  'pull docker.io/lzocateli/devops:cpu-v1')
    [[ "${SIMULATION:-false}" == false ]] || exit 97
    touch "$IMAGE_STATE"
    ;;
  'run --pull=never')
    [[ "${SIMULATION:-false}" == false ]] || exit 97
    if [[ "$*" == *'npm install --global'* ]]; then
      mkdir -p "$FIXTURE_HOME/.local/share/ubuntu-desktop/devops-home/.local/npm/bin"
      touch "$FIXTURE_HOME/.local/share/ubuntu-desktop/devops-home/.local/npm/bin/ng"
    fi
    exit "${OP_STATUS:-0}"
    ;;
  *) exit 98 ;;
esac
STUB
  chmod +x "$FIXTURE_BIN/podman"
  export PATH="$FIXTURE_BIN:$PATH"
  export ANSIBLE_ROLES_PATH="$REPO_ROOT/ansible/roles"
}

render_wrapper() {
  ansible localhost --connection local -m ansible.builtin.template \
    -a "src=$REPO_ROOT/ansible/roles/terminal/templates/op-container.sh.j2 dest='$WRAPPER' mode=0750" \
    -e "$(jq -n --arg home "$FIXTURE_HOME" '{terminal_devops_image:"docker.io/lzocateli/devops:cpu-v1",terminal_onepassword_home_dir:($home + "/op-home")}')" \
    >/dev/null
}

@test "op ajuda e aliases funcionam sem Podman e nao escrevem estado" {
  render_wrapper
  rm "$FIXTURE_BIN/podman"
  for option in --help -help -h; do
    run "$WRAPPER" "$option"
    [ "$status" -eq 0 ]
    [[ "$output" == *'CLI 1Password'* ]]
    [ ! -e "$CAPTURE" ]
    [ ! -e "$IMAGE_STATE" ]
  done
}

@test "op dry-run inclusive apos verbose nao chama Podman" {
  render_wrapper
  for option in --dry-run -dryrun; do
    run "$WRAPPER" --verbose "$option" item list
    [ "$status" -eq 0 ]
    [[ "$output" == *'Nenhuma consulta realizada'* ]]
    [ ! -e "$CAPTURE" ]
  done
}

@test "op encaminha token por nome sem segredo em argumentos e propaga falha" {
  render_wrapper
  touch "$IMAGE_STATE"
  export OP_SERVICE_ACCOUNT_TOKEN=segredo-ficticio OP_STATUS=23
  run "$WRAPPER" item get 'nome com espaco'
  [ "$status" -eq 23 ]
  [[ "$output" != *segredo-ficticio* ]]
  grep -Fx -- OP_SERVICE_ACCOUNT_TOKEN "$CAPTURE"
  grep -Fx -- 'nome com espaco' "$CAPTURE"
  grep -Fx -- '--pull=never' "$CAPTURE"
  run grep -F -- segredo-ficticio "$CAPTURE"
  [ "$status" -eq 1 ]
  run grep -R -F -- segredo-ficticio "$FIXTURE_HOME/op-home/artifacts/logs"
  [ "$status" -eq 1 ]
}

@test "op imagem ausente falha sem download automatico" {
  render_wrapper
  run "$WRAPPER" --version
  [ "$status" -eq 1 ]
  [[ "$output" == *'Imagem ausente'* ]]
  run grep -Fx -- pull "$CAPTURE"
  [ "$status" -eq 1 ]
  run grep -Fx -- run "$CAPTURE"
  [ "$status" -eq 1 ]
}

@test "imagem publica e Angular sao preparados uma vez e reaplicacao converge" {
  run ansible-playbook -i localhost, "$REPO_ROOT/tests/ansible/terminal-container.yml"
  [ "$status" -eq 0 ]
  [ -f "$IMAGE_STATE" ]
  run ansible-playbook -i localhost, "$REPO_ROOT/tests/ansible/terminal-container.yml"
  [ "$status" -eq 0 ]
  [[ "$output" == *'changed=0'* ]]
  [ "$(grep -Fxc pull "$CAPTURE")" -eq 1 ]
  [ "$(grep -Fxc run "$CAPTURE")" -eq 1 ]
  run grep -Fx login "$CAPTURE"
  [ "$status" -eq 1 ]
}

@test "check mode nao baixa imagem nem executa containers" {
  export SIMULATION=true
  before="$(find "$FIXTURE_HOME" -printf '%P %m %s\n' | sort)"
  run ansible-playbook -i localhost, "$REPO_ROOT/tests/ansible/terminal-container.yml" --check --diff
  [ "$status" -eq 0 ]
  [ ! -e "$IMAGE_STATE" ]
  [ ! -e "$WRAPPER" ]
  [ "$(find "$FIXTURE_HOME" -printf '%P %m %s\n' | sort)" = "$before" ]
  run grep -Fx -- pull "$CAPTURE"
  [ "$status" -eq 1 ]
  run grep -Fx -- run "$CAPTURE"
  [ "$status" -eq 1 ]
}

@test "erro operacional do Podman nao e confundido com imagem ausente" {
  export IMAGE_PROBE_RC=125
  run ansible-playbook -i localhost, "$REPO_ROOT/tests/ansible/terminal-container.yml"
  [ "$status" -ne 0 ]
  run grep -Fx -- pull "$CAPTURE"
  [ "$status" -eq 1 ]
}
