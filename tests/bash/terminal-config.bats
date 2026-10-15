#!/usr/bin/env bats

setup() {
  REPO_ROOT="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
  SSH_TEMPLATE="${REPO_ROOT}/ansible/roles/terminal/templates/ssh-config.j2"
  NUGET_TEMPLATE="${REPO_ROOT}/ansible/roles/terminal/templates/NuGet.Config.j2"
  INVENTORY="${REPO_ROOT}/ansible/inventories/example/hosts.yml"
  SSH_CONFIG="${BATS_TEST_TMPDIR}/ssh-config"
  NUGET_CONFIG="${BATS_TEST_TMPDIR}/NuGet.Config"
  INVENTORY_VARS="$(ansible-inventory -i "${INVENTORY}" --host ubuntu-workstation.example.invalid)"

  ansible localhost --connection local \
    --module-name ansible.builtin.template \
    --args "src=${SSH_TEMPLATE} dest=${SSH_CONFIG} mode=0600" \
    --extra-vars "${INVENTORY_VARS}" \
    >/dev/null
  ansible localhost --connection local \
    --module-name ansible.builtin.template \
    --args "src=${NUGET_TEMPLATE} dest=${NUGET_CONFIG} mode=0600" \
    --extra-vars "${INVENTORY_VARS}" \
    >/dev/null
}

@test "SSH config mapeia hosts, usuarios e chaves sem alterar host-key checking" {
  python3 - "${SSH_CONFIG}" "${INVENTORY}" <<'PY'
import json
import subprocess
import sys

inventory = json.loads(subprocess.check_output([
    "ansible-inventory", "-i", sys.argv[2], "--host",
    "ubuntu-workstation.example.invalid",
], text=True))
hosts = inventory["terminal_ssh_hosts"]
assert set(inventory["terminal_ssh_key_items"]) == {
  host["identity_file"] for host in hosts
}
assert {host["alias"] for host in hosts} == {
  "pve01", "pve02", "pve03", "pve04", "pve05",
  "vm-nginx", "vm-postgres", "vm-monitor", "unifi",
  "hostinger-root", "hostinger-vps", "interserver", "truenas", "truenas-root",
  "github.com",
}

for host in hosts:
    output = subprocess.check_output(
        ["ssh", "-G", "-F", sys.argv[1], host["alias"]], text=True
    ).splitlines()
    assert f"hostname {host['hostname']}" in output
    assert f"user {host['user']}" in output
    assert f"identityfile /home/lzocateli/.ssh/{host['identity_file']}" in output
    assert "port 22" in output
    assert "identitiesonly yes" in output
    assert "stricthostkeychecking no" not in output
PY
}

@test "NuGet config inclui somente nuget.org e nugettest" {
  python3 - "${NUGET_CONFIG}" "${INVENTORY}" <<'PY'
import json
import sys
import xml.etree.ElementTree as ET
import subprocess

root = ET.parse(sys.argv[1]).getroot()
sources = {
    source.attrib["key"]: source.attrib["value"]
    for source in root.findall("./packageSources/add")
}
inventory = json.loads(subprocess.check_output([
    "ansible-inventory", "-i", sys.argv[2], "--host",
    "ubuntu-workstation.example.invalid",
], text=True))
assert sources == {
    "nuget.org": "https://api.nuget.org/v3/index.json",
    "nugettest": inventory["terminal_nuget_test_source"],
}
PY
}
