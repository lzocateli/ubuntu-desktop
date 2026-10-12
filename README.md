# ubuntu-desktop

## Sumario

- [ubuntu-desktop](#ubuntu-desktop)
  - [Sumario](#sumario)
  - [Objetivo](#objetivo)
  - [Estado Atual](#estado-atual)
  - [Aplicativos instalados pelo Ansible](#aplicativos-instalados-pelo-ansible)
  - [Organizacao](#organizacao)
  - [Documentacao](#documentacao)
  - [Preparar o ambiente e clonar](#preparar-o-ambiente-e-clonar)
  - [Uso Rapido](#uso-rapido)
  - [Contrato Operacional](#contrato-operacional)
  - [Desenvolvimento e Validacao](#desenvolvimento-e-validacao)

## Objetivo

Automacoes Bash, PowerShell e Ansible para configurar e manter Ubuntu Desktop
com execucao previsivel, simulacao segura e documentacao operacional.

## Estado Atual

Automacao Ansible implementada para Ubuntu Desktop 26.04 LTS amd64. O projeto
instala aplicativos Flatpak, ferramentas de terminal, Podman rootless, .NET, PowerShell,
Azure CLI, Terraform, kubectl, GitHub CLI, 1Password, VS Code e uv. A migracao do
Snap e opt-in e exige confirmacao explicita.

Aplicacao, check mode e idempotencia ainda precisam ser comprovados em VM Ubuntu
Desktop 26.04 descartavel. Nao execute mutacoes no desktop de trabalho sem
autorizacao e backup.

## Aplicativos instalados pelo Ansible

Lista do estado padrao no Ubuntu Desktop 26.04 amd64. Pacotes de suporte,
bibliotecas e dependencias nao estao listados individualmente.

| Categoria | Aplicativo ou ferramenta | Observacao |
| --- | --- | --- |
| Navegadores | Microsoft Edge e Google Chrome | Edge Flatpak e configurado como navegador padrao para HTML e links HTTP/HTTPS; Chrome via repositorio APT oficial |
| Flatpak | Bruno, Microsoft Edge, Remmina, Flatseal e Extension Manager | Instalados em escopo de sistema pelo Flathub; Edge e instalado por padrao |
| Firefox | Firefox Snap | Removido junto com Snap somente se a migracao destrutiva for explicitamente habilitada e confirmada; Firefox Flatpak nao e instalado por padrao |
| Desktop | Visual Studio Code, Tilix e GNOME Software | VS Code pelo repositorio Microsoft; Tilix e GNOME Software via APT |
| Senhas | 1Password Desktop e 1Password CLI | Ambos instalados por padrao; desabilite com `host_tools_install_1password: false` |
| Containers | Podman rootless e Podman Compose | Sem daemon root; imagens e dados ficam no home do usuario |
| VPN | WireGuard CLI e integracao grafica do NetworkManager; Mullvad Desktop e CLI | WireGuard pode ser configurado pelo GNOME Network Settings; Mullvad e instalado sem login nem conexao automatica |
| Desenvolvimento | Git, OpenSSH Client, ZSH e tmux | O Ansible tambem configura Git e ZSH para o usuario |
| SDKs e CLIs | .NET SDK 8 e 10, PowerShell, Azure CLI, Terraform, kubectl e GitHub CLI | kubectl usa o repositorio `v1.34` por padrao |
| Terminal | uv, uvx, Oh My Posh, Oh My Zsh e MesloLGM Nerd Font | Instalados/configurados pelo perfil do usuario ou pelo Ansible |
| Copilot | GitHub Copilot CLI 1.0.91 | Binario standalone instalado no host |
| Node.js | Node, npm e npx | Disponiveis por funcoes shell que executam a imagem `docker.io/lzocateli/devops:cpu-ubuntu24.04` via Podman; nao sao instalados no host |

Firefox Snap so e removido quando a migracao do Snap e solicitada com as duas
confirmacoes exigidas; essa operacao tambem remove o Snap e seus dados
configurados pela role. Firefox Flatpak pode ser instalado separadamente com
`flatpak_apps_install_firefox: true`. O Edge Flatpak e instalado por padrao e
definido como navegador principal nos handlers de HTML e HTTP/HTTPS; Chrome
tambem fica instalado e pode ser aberto como alternativa.
Veja a lista canonica e detalhes em
[Aplicativos cobertos pelo Ansible](docs/aplicativos-ansible.md).

## Organizacao

| Caminho | Conteudo |
| --- | --- |
| `scripts/bash/` | Scripts e bibliotecas Bash |
| `scripts/powershell/` | Scripts/modulos PowerShell |
| `ansible/` | Playbooks, roles e inventarios |
| `tests/` | Bats, Pester e testes Ansible |
| `docs/` | Guias operacionais; planos em `docs/plan/` |
| `artifacts/` | Logs/temporarios ignorados pelo Git |

Pastas sem implementacao permanecem ausentes. Veja o
[mapa de instrucoes](.github/README.md) e as
[regras gerais](.github/copilot-instructions.md).

## Documentacao

- [Tutorial da stack de desenvolvimento](docs/stack-desenvolvimento.md)
- [Aplicativos cobertos pelo Ansible](docs/aplicativos-ansible.md)
- [Guia operacional da automacao Ansible](docs/automacao-ansible.md)
- [Referencia do Gitconfig gerenciado](docs/README_gitconfig.md)
- [Git hooks e Gitleaks](docs/githooks.md)
- [Plano de implementacao](docs/plan/plano-automacao-ubuntu-desktop.md)

## Preparar o ambiente e clonar

Sequencia para Ubuntu 26.04 LTS amd64. Git e necessario para clonar; o Copilot
CLI e opcional para usar o assistente; Ansible e instalado pelo bootstrap depois
do clone, pois o script de instalacao faz parte deste repositorio.

Instale Git e as dependencias de download/descompactacao:

```bash
sudo apt update
sudo apt install -y ca-certificates curl git tar
git --version
```

Instale o Copilot CLI standalone 1.0.91 no perfil do usuario. O arquivo e
validado pelo SHA-256 fixado pela automacao antes de ser instalado:

```bash
(
  set -euo pipefail
  COPILOT_VERSION=1.0.91
  COPILOT_SHA256=0e7a0e85290228afecce4d4eed42fda80c0f5b9c86f433deb246cde1d5eec8e5
  TEMP_DIR="$(mktemp -d)"
  trap 'rm -rf -- "$TEMP_DIR"' EXIT
  curl --fail --silent --show-error --location \
    "https://github.com/github/copilot-cli/releases/download/v${COPILOT_VERSION}/copilot-linux-x64.tar.gz" \
    --output "${TEMP_DIR}/copilot-linux-x64.tar.gz"
  printf '%s  %s\n' "${COPILOT_SHA256}" "${TEMP_DIR}/copilot-linux-x64.tar.gz" |
    sha256sum --check
  tar -xzf "${TEMP_DIR}/copilot-linux-x64.tar.gz" -C "${TEMP_DIR}"
  install -d "$HOME/.local/bin"
  install -m 0755 "${TEMP_DIR}/copilot" "$HOME/.local/bin/copilot"
)
export PATH="$HOME/.local/bin:$PATH"
copilot --version
```

Configure uma chave SSH autorizada na conta GitHub e clone o repositorio:

```bash
git clone git@github.com:lzocateli/ubuntu-desktop.git
cd ubuntu-desktop
```

Instale `uv`, `ansible-core` 2.19.2, `pywinrm` e as collections fixadas pelo
projeto no usuario atual, sem `sudo`:

```bash
bash scripts/bash/bootstrap-ansible.sh --help
bash scripts/bash/bootstrap-ansible.sh --dry-run --verbose
bash scripts/bash/bootstrap-ansible.sh
export PATH="$HOME/.local/bin:$PATH"
ansible-playbook --version
```

O `export PATH` vale para a sessao atual; inclua `~/.local/bin` no PATH do shell
para novas sessoes. O bootstrap requer Linux/WSL amd64, Bash 4.4+, `curl`, `tar`
e acesso HTTPS. Consulte [Uso Rapido](#uso-rapido) e o
[guia operacional Ansible](docs/automacao-ansible.md) para prosseguir.

## Uso Rapido

Execute no Ubuntu ou WSL, a partir da raiz do repositorio:

```bash
bash scripts/bash/bootstrap-ansible.sh --dry-run --verbose
bash scripts/bash/bootstrap-ansible.sh
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01 \
  --secrets-dir "$HOME/.microsoft/usersecrets/ansible" \
  --remove-snap --dry-run --verbose
```

Crie o inventario privado a partir de `ansible/inventories/example/` e revise o
plano. A simulacao inclui a fase Snap, mas nao executa as remocoes destrutivas.
Para aplicar, confirme antes que os aplicativos substitutos funcionam e que os
dados importantes foram preservados; a operacao remove o Snap e dados
associados, sem rollback automatico. O diretório
`$HOME/.microsoft/usersecrets/ansible` deve conter `vault.yml` e
`vault-password`. Crie os arquivos fora do repositorio com permissoes restritas:

```bash
SECRETS_DIR="$HOME/.microsoft/usersecrets/ansible"
install -d -m 700 "$SECRETS_DIR"
read -r -s -p 'Senha do Ansible Vault: ' VAULT_PASSWORD
printf '\n'
printf '%s\n' "$VAULT_PASSWORD" >"$SECRETS_DIR/vault-password"
unset VAULT_PASSWORD
chmod 600 "$SECRETS_DIR/vault-password"
ansible-vault create "$SECRETS_DIR/vault.yml" \
  --vault-password-file "$SECRETS_DIR/vault-password"
chmod 600 "$SECRETS_DIR/vault.yml"
```

No editor do `ansible-vault`, informe `ansible_become_password: "..."` somente
se o `sudo` do alvo pedir senha. Use autenticação SSH por chave/agent; somente
se autenticar por senha SSH, inclua também `ansible_password`. O
`vault-password` armazena a senha que criptografa `vault.yml`.
**Não inclua `OP_SERVICE_ACCOUNT_TOKEN` nesses arquivos**: essa variável deve
estar exportada no ambiente do controller para o `op`.

O comando real, com os parâmetros de remoção e confirmação exigidos, é:

```bash
test -n "${OP_SERVICE_ACCOUNT_TOKEN:-}"
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01 \
  --secrets-dir "$HOME/.microsoft/usersecrets/ansible" \
  --remove-snap --confirm-remove-snap
```

Mantenha `vault.yml` e `vault-password` fora do repositorio em
`~/.microsoft/usersecrets/ansible` no Linux ou
`%APPDATA%\Microsoft\UserSecrets\ansible` no Windows. Veja os detalhes e
limites da simulacao no [guia operacional Ansible](docs/automacao-ansible.md).

## Contrato Operacional

- Bash: `--help`/`-help`, `--dry-run`/`-dryrun`, `--verbose`.
- PowerShell: `-Help`, `Get-Help`, `-DryRun`, `-WhatIf`, `-Verbose`.
- Ansible: wrapper com ajuda propria e simulacao via `--check --diff`; inventario
  explicito e `--limit` para execucao real.
- Secrets: Ansible Vault externo ao repositorio, com senha fora de argumentos e logs.
- Ajuda nao altera estado; simulacao nao aplica mudancas, exceto auditoria local.
- Logs em console e `artifacts/logs/`, sem credenciais; falhas retornam nao zero.
- Cada automacao documenta objetivo, dependencias e exemplos conforme o
  [roteiro operacional](.github/instructions/documentation.instructions.md).

## Desenvolvimento e Validacao

Leia regras da tecnologia antes de implementar. Instale ferramentas separadamente;
nao durante ajuda/dry-run. Git e necessario para obter o repositorio.

| Tecnologia | Verificacoes |
| --- | --- |
| Bash | `bash -n`, ShellCheck, shfmt e Bats |
| Git hooks | Gitleaks 8.30.1 via Podman e testes Bats com stub |
| PowerShell | Parser, PSScriptAnalyzer e Pester |
| Ansible | yamllint, ansible-lint, syntax-check, check mode e idempotencia; Molecule para roles |

Declare versao/SO de PowerShell; controller Ansible usa Linux/WSL. Teste mutacoes
somente em ambiente descartavel autorizado. Instrucoes nao substituem testes e
revisao; gates de CI serao definidos quando existirem automacoes concretas.
