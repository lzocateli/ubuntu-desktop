#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  HOOK="${REPO_ROOT}/.githooks/pre-commit"
  TEST_REPO="${BATS_TEST_TMPDIR}/repo"
  STUB_DIR="${BATS_TEST_TMPDIR}/bin"
  PODMAN_ARGS="${BATS_TEST_TMPDIR}/podman-args"
  PODMAN_STDIN="${BATS_TEST_TMPDIR}/podman-stdin"
  export PODMAN_ARGS PODMAN_STDIN

  mkdir -p "${TEST_REPO}" "${STUB_DIR}"
  git -C "${TEST_REPO}" init --quiet
  git -C "${TEST_REPO}" config user.name Test
  git -C "${TEST_REPO}" config user.email test@example.invalid
  printf 'baseline\n' >"${TEST_REPO}/config.txt"
  git -C "${TEST_REPO}" add config.txt
  git -C "${TEST_REPO}" commit --quiet --message baseline
}

create_podman_stub() {
  cat >"${STUB_DIR}/podman" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" >"${PODMAN_ARGS}"
cat >"${PODMAN_STDIN}"
exit "${PODMAN_STATUS:-0}"
STUB
  chmod +x "${STUB_DIR}/podman"
}

@test "pre-commit bloqueia quando Podman nao esta disponivel" {
  empty_path="${BATS_TEST_TMPDIR}/empty"
  mkdir "${empty_path}"

  run env PATH="${empty_path}" /bin/sh "${HOOK}"

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"Podman nao foi encontrado no PATH"* ]]
}

@test "pre-commit envia somente o diff staged ao Gitleaks" {
  create_podman_stub
  printf 'API_TOKEN=sentinel\n' >>"${TEST_REPO}/config.txt"
  git -C "${TEST_REPO}" add config.txt
  printf 'UNSTAGED_SENTINEL\n' >>"${TEST_REPO}/config.txt"

  cd "${TEST_REPO}"
  run env PATH="${STUB_DIR}:${PATH}" /bin/sh "${HOOK}"

  [ "${status}" -eq 0 ]
  grep -Fx -- "run" "${PODMAN_ARGS}"
  grep -Fx -- "--read-only" "${PODMAN_ARGS}"
  grep -Fx -- "docker.io/lzocateli/gitleaks:8.30.1" "${PODMAN_ARGS}"
  grep -Fx -- "stdin" "${PODMAN_ARGS}"
  grep -Fx -- "--redact" "${PODMAN_ARGS}"
  grep -F -- "+API_TOKEN=sentinel" "${PODMAN_STDIN}"
  ! grep -F -- "UNSTAGED_SENTINEL" "${PODMAN_STDIN}"
}

@test "pre-commit propaga falha do Gitleaks" {
  create_podman_stub
  printf 'API_TOKEN=sentinel\n' >>"${TEST_REPO}/config.txt"
  git -C "${TEST_REPO}" add config.txt

  cd "${TEST_REPO}"
  run env PODMAN_STATUS=23 PATH="${STUB_DIR}:${PATH}" /bin/sh "${HOOK}"

  [ "${status}" -eq 23 ]
}