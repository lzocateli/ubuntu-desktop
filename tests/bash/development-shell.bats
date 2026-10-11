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

create_docker_stub() {
  stub_dir="${BATS_TEST_TMPDIR}/bin"
  capture="${BATS_TEST_TMPDIR}/docker-arguments.txt"
  export capture
  mkdir -p "${stub_dir}"
  cat >"${stub_dir}/docker" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$@" >"${capture}"
EOF
  chmod +x "${stub_dir}/docker"
  export PATH="${stub_dir}:${PATH}"
}

@test "runtime configura certificado e funcoes nos shells suportados" {
  run bash -c '. "$RUNTIME"; declare -F node npm npx >/dev/null; printf "%s" "$SSL_CERT_DIR"'

  [ "${status}" -eq 0 ]
  [ "${output}" = "${HOME}/.aspnet/dev-certs/trust:/usr/lib/ssl/certs" ]

  run zsh -c '. "$RUNTIME"; whence -w node npm npx >/dev/null'

  [ "${status}" -eq 0 ]
}

@test "node usa imagem, usuario e workspace sem montar socket Docker" {
  create_docker_stub
  workspace="${BATS_TEST_TMPDIR}/workspace com espaco"
  mkdir -p "${workspace}"

  run bash -c 'cd "$1"; . "$RUNTIME"; node --version' _ "${workspace}"

  [ "${status}" -eq 0 ]
  grep -Fx -- "$(id -u):$(id -g)" "${capture}"
  grep -Fx -- "type=bind,source=${workspace},target=/workspace" "${capture}"
  grep -Fx -- "example/devops:test" "${capture}"
  grep -Fx -- "node" "${capture}"
  grep -Fx -- "--version" "${capture}"

  run grep -F -- "/var/run/docker.sock" "${capture}"

  [ "${status}" -ne 0 ]
}

@test "runtime Docker fica restrito a node npm e npx" {
  run bash -c '. "$RUNTIME"; declare -F copilot'

  [ "${status}" -ne 0 ]

  run grep -Eq 'COPILOT_GITHUB_TOKEN|GH_TOKEN|GITHUB_TOKEN|\.copilot|@github/copilot' "${RUNTIME}"

  [ "${status}" -ne 0 ]
}