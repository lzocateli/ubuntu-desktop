#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  HOOK="${REPO_ROOT}/.githooks/pre-commit"
  TEST_REPO="${BATS_TEST_TMPDIR}/repo"
  STUB_DIR="${BATS_TEST_TMPDIR}/bin"
  DOCKER_ARGS="${BATS_TEST_TMPDIR}/docker-args"
  DOCKER_STDIN="${BATS_TEST_TMPDIR}/docker-stdin"
  export DOCKER_ARGS DOCKER_STDIN

  mkdir -p "${TEST_REPO}" "${STUB_DIR}"
  git -C "${TEST_REPO}" init --quiet
  git -C "${TEST_REPO}" config user.name Test
  git -C "${TEST_REPO}" config user.email test@example.invalid
  printf 'baseline\n' >"${TEST_REPO}/config.txt"
  git -C "${TEST_REPO}" add config.txt
  git -C "${TEST_REPO}" commit --quiet --message baseline
}

create_docker_stub() {
  cat >"${STUB_DIR}/docker" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >"${DOCKER_ARGS}"
cat >"${DOCKER_STDIN}"
exit "${DOCKER_STATUS:-0}"
STUB
  chmod +x "${STUB_DIR}/docker"
}

@test "pre-commit bloqueia quando Docker nao esta disponivel" {
  empty_path="${BATS_TEST_TMPDIR}/empty"
  mkdir "${empty_path}"

  run env PATH="${empty_path}" /bin/sh "${HOOK}"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"Docker nao foi encontrado no PATH"* ]]
}

@test "pre-commit envia somente o diff staged ao Gitleaks" {
  create_docker_stub
  printf 'API_TOKEN=sentinel\n' >>"${TEST_REPO}/config.txt"
  git -C "${TEST_REPO}" add config.txt
  printf 'UNSTAGED_SENTINEL\n' >>"${TEST_REPO}/config.txt"

  cd "${TEST_REPO}"
  run env PATH="${STUB_DIR}:${PATH}" /bin/sh "${HOOK}"

  [ "${status}" -eq 0 ]
  grep -Fx -- "run" "${DOCKER_ARGS}"
  grep -Fx -- "--read-only" "${DOCKER_ARGS}"
  grep -Fx -- "lzocateli/gitleaks:8.30.1" "${DOCKER_ARGS}"
  grep -Fx -- "stdin" "${DOCKER_ARGS}"
  grep -Fx -- "--redact" "${DOCKER_ARGS}"
  grep -F -- "+API_TOKEN=sentinel" "${DOCKER_STDIN}"
  ! grep -F -- "UNSTAGED_SENTINEL" "${DOCKER_STDIN}"
}

@test "pre-commit propaga falha do Gitleaks" {
  create_docker_stub
  printf 'API_TOKEN=sentinel\n' >>"${TEST_REPO}/config.txt"
  git -C "${TEST_REPO}" add config.txt

  cd "${TEST_REPO}"
  run env DOCKER_STATUS=23 PATH="${STUB_DIR}:${PATH}" /bin/sh "${HOOK}"

  [ "${status}" -eq 23 ]
}