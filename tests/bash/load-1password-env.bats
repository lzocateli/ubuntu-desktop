#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  RENDERER="${REPO_ROOT}/ansible/roles/terminal/files/render-1password-env.sh"
  STUB_DIR="${BATS_TEST_TMPDIR}/bin"
  mkdir "${STUB_DIR}"
}

@test "renderizador gera exports literais sem executar valores" {
  marker="${BATS_TEST_TMPDIR}/must-not-exist"
  capture="${BATS_TEST_TMPDIR}/arguments.txt"
  rendered="${BATS_TEST_TMPDIR}/profile.sh"
  cat >"${STUB_DIR}/op" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >"${capture}"
printf '%s\n' \
  'API_TOKEN=fake-token' \
  'WITH_SPACES="hello world"' \
  "WITH_QUOTE=O'Reilly" \
  'LITERAL=\$(touch ${marker})'
EOF
  chmod +x "${STUB_DIR}/op"

  run env PATH="${STUB_DIR}:${PATH}" bash "${RENDERER}" \
    Engineering development.env Corporate

  [ "${status}" -eq 0 ]
  printf '%s\n' "${output}" >"${rendered}"
  bash -n "${rendered}"
  run bash -c 'source "$1"; printf "%s|%s|%s|%s\n" \
    "$API_TOKEN" "$WITH_SPACES" "$WITH_QUOTE" "$LITERAL"' _ "${rendered}"
  [ "${status}" -eq 0 ]
  [ "${output}" = "fake-token|hello world|O'Reilly|\$(touch ${marker})" ]
  [ ! -e "${marker}" ]
  grep -Fx -- "document" "${capture}"
  grep -Fx -- "get" "${capture}"
  grep -Fx -- "--account" "${capture}"
  grep -Fx -- "Corporate" "${capture}"
}

@test "renderizador rejeita nome de variavel invalido" {
  cat >"${STUB_DIR}/op" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'INVALID-NAME=value'
EOF
  chmod +x "${STUB_DIR}/op"

  run env PATH="${STUB_DIR}:${PATH}" bash "${RENDERER}" \
    Engineering development.env ''

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"nome de variavel invalido"* ]]
}

@test "renderizador nao produz export parcial para documento invalido" {
  cat >"${STUB_DIR}/op" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' 'VALID_BEFORE_ERROR=must-not-be-exported' 'INVALID-NAME=value'
EOF
  chmod +x "${STUB_DIR}/op"

  run env PATH="${STUB_DIR}:${PATH}" bash "${RENDERER}" \
    Engineering development.env ''

  [ "${status}" -eq 1 ]
  [[ "${output}" != *"export VALID_BEFORE_ERROR="* ]]
}

@test "renderizador falha quando documento nao pode ser baixado" {
  cat >"${STUB_DIR}/op" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
  chmod +x "${STUB_DIR}/op"

  run env PATH="${STUB_DIR}:${PATH}" bash "${RENDERER}" \
    Engineering development.env ''

  [ "${status}" -eq 1 ]
  [[ "${output}" == *"nao foi possivel baixar"* ]]
}

@test "profile preexistente preserva variaveis sem executar codigo e renova bloco gerenciado" {
  profile="${BATS_TEST_TMPDIR}/profile"
  marker="${BATS_TEST_TMPDIR}/nao-executar"
  printf 'export EXISTING=local\ntouch %s\n# BEGIN ANSIBLE 1PASSWORD ENV\nexport MANAGED=old\n# END ANSIBLE 1PASSWORD ENV\n' "$marker" >"$profile"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" EXISTING=remote MANAGED=new\n' >"${STUB_DIR}/op"
  chmod +x "${STUB_DIR}/op"
  run env PATH="${STUB_DIR}:${PATH}" bash "${RENDERER}" Engineering development.env '' "$profile"
  [ "$status" -eq 0 ]
  [ "$output" = "export MANAGED='new'" ]
  [ ! -e "$marker" ]
}

@test "profile com todas as variaveis preexistentes produz bloco vazio valido" {
  profile="${BATS_TEST_TMPDIR}/profile"
  printf 'export EXISTING=local\n' >"$profile"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" EXISTING=remote\n' >"${STUB_DIR}/op"
  chmod +x "${STUB_DIR}/op"
  run env PATH="${STUB_DIR}:${PATH}" bash "${RENDERER}" Engineering development.env '' "$profile"
  [ "$status" -eq 0 ]
  [ "$output" = ':' ]
}
