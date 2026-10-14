#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  BOOTSTRAP="${REPO_ROOT}/scripts/bash/bootstrap-ansible.sh"
  WRAPPER="${REPO_ROOT}/scripts/bash/run-ansible.sh"
  INVENTORY="${REPO_ROOT}/ansible/inventories/example/hosts.yml"
  HOME="${BATS_TEST_TMPDIR}/home"
  export HOME
  mkdir -p "${HOME}"
}

@test "bootstrap exibe ajuda sem criar artifacts" {
  before="$(find "${REPO_ROOT}/artifacts" -type f -print 2>/dev/null || true)"

  run bash "${BOOTSTRAP}" --help

  [ "${status}" -eq 0 ]
  [[ "${output}" == *"Uso: bootstrap-ansible.sh"* ]]
  after="$(find "${REPO_ROOT}/artifacts" -type f -print 2>/dev/null || true)"
  [ "${before}" = "${after}" ]
}

@test "wrapper exige inventario e limit" {
  run bash "${WRAPPER}" --inventory "${INVENTORY}"

  [ "${status}" -eq 2 ]
  [[ "${output}" == *"--limit e obrigatorio"* ]]
}

@test "wrapper propaga check diff limit e verbose" {
  stub_dir="${BATS_TEST_TMPDIR}/bin"
  capture="${BATS_TEST_TMPDIR}/arguments.txt"
  mkdir -p "${stub_dir}"
  cat >"${stub_dir}/ansible-playbook" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >"${capture}"
EOF
  chmod +x "${stub_dir}/ansible-playbook"

  run env PATH="${stub_dir}:${PATH}" bash "${WRAPPER}" \
    --inventory "${INVENTORY}" --limit workstation01 --dry-run --verbose

  [ "${status}" -eq 0 ]
  grep -Fx -- "--check" "${capture}"
  grep -Fx -- "--diff" "${capture}"
  grep -Fx -- "--limit" "${capture}"
  grep -Fx -- "workstation01" "${capture}"
  grep -Fx -- "-v" "${capture}"
}

@test "wrapper bloqueia remocao real do Snap sem confirmacao" {
  run bash "${WRAPPER}" --inventory "${INVENTORY}" --limit workstation01 --remove-snap

  [ "${status}" -eq 2 ]
  [[ "${output}" == *"exige --confirm-remove-snap"* ]]
}

@test "wrapper bloqueia remocao real do dotnet legado sem confirmacao" {
  run bash "${WRAPPER}" --inventory "${INVENTORY}" --limit workstation01 --remove-legacy-dotnet

  [ "${status}" -eq 2 ]
  [[ "${output}" == *"exige --confirm-remove-legacy-dotnet"* ]]
}

@test "wrapper rejeita confirmacao dotnet sem pedido de remocao" {
  run bash "${WRAPPER}" --inventory "${INVENTORY}" --limit workstation01 --confirm-remove-legacy-dotnet

  [ "${status}" -eq 2 ]
  [[ "${output}" == *"exige --remove-legacy-dotnet"* ]]
}

@test "wrapper propaga migracao dotnet e check mode sem confirmar remocao real" {
  stub_dir="${BATS_TEST_TMPDIR}/bin"
  capture="${BATS_TEST_TMPDIR}/arguments.txt"
  mkdir -p "${stub_dir}"
  cat >"${stub_dir}/ansible-playbook" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >"${capture}"
EOF
  chmod +x "${stub_dir}/ansible-playbook"

  run env PATH="${stub_dir}:${PATH}" bash "${WRAPPER}" \
    --inventory "${INVENTORY}" --limit workstation01 --tags dotnet,dotnet_env \
    --remove-legacy-dotnet --dry-run

  [ "${status}" -eq 0 ]
  grep -Fx -- '--check' "${capture}"
  grep -Fx -- '--diff' "${capture}"
  grep -Fx -- 'dotnet,dotnet_env,dotnet_migration' "${capture}"
  grep -Fx -- 'host_tools_remove_legacy_dotnet=true' "${capture}"
  grep -Fx -- 'host_tools_confirm_remove_legacy_dotnet=false' "${capture}"
}

@test "wrapper carrega Ansible Vault de diretorio externo sem expor senha" {
  stub_dir="${BATS_TEST_TMPDIR}/bin"
  capture="${BATS_TEST_TMPDIR}/arguments.txt"
  secrets_dir="${BATS_TEST_TMPDIR}/secrets"
  mkdir "${stub_dir}" "${secrets_dir}"
  chmod 700 "${secrets_dir}"
  printf '%s\n' '$ANSIBLE_VAULT;1.1;AES256' '64616461' >"${secrets_dir}/vault.yml"
  printf '%s\n' 'sentinel-secret' >"${secrets_dir}/vault-password"
  chmod 600 "${secrets_dir}/vault.yml" "${secrets_dir}/vault-password"
  cat >"${stub_dir}/ansible-playbook" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >"${capture}"
EOF
  chmod +x "${stub_dir}/ansible-playbook"

  run env PATH="${stub_dir}:${PATH}" bash "${WRAPPER}" \
    --inventory "${INVENTORY}" --limit workstation01 \
    --secrets-dir "${secrets_dir}" --dry-run --verbose

  [ "${status}" -eq 0 ]
  grep -Fx -- "--extra-vars" "${capture}"
  grep -Fx -- "@${secrets_dir}/vault.yml" "${capture}"
  grep -Fx -- "--vault-password-file" "${capture}"
  grep -Fx -- "${secrets_dir}/vault-password" "${capture}"
  [[ "${output}" != *"sentinel-secret"* ]]
}
