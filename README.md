# ubuntu-desktop

## Sumario

- [ubuntu-desktop](#ubuntu-desktop)
  - [Sumario](#sumario)
  - [Objetivo](#objetivo)
  - [Estado Atual](#estado-atual)
  - [Organizacao](#organizacao)
  - [Documentacao](#documentacao)
  - [Uso Rapido](#uso-rapido)
  - [Contrato Operacional](#contrato-operacional)
  - [Desenvolvimento e Validacao](#desenvolvimento-e-validacao)

## Objetivo

Automacoes Bash, PowerShell e Ansible para configurar e manter Ubuntu Desktop
com execucao previsivel, simulacao segura e documentacao operacional.

## Estado Atual

Automacao Ansible implementada para Ubuntu Desktop 24.04 LTS amd64. O projeto
instala aplicativos Flatpak, ferramentas de terminal, Docker, .NET, PowerShell,
Azure CLI, Terraform, kubectl, GitHub CLI, 1Password, VS Code e uv. A migracao do
Snap e opt-in e exige confirmacao explicita.

Aplicacao, check mode e idempotencia ainda precisam ser comprovados em VM Ubuntu
Desktop 24.04 descartavel. Nao execute mutacoes no desktop de trabalho sem
autorizacao e backup.

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

## Uso Rapido

Execute no Ubuntu ou WSL, a partir da raiz do repositorio:

```bash
bash scripts/bash/bootstrap-ansible.sh --dry-run --verbose
bash scripts/bash/bootstrap-ansible.sh
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01 \
  --secrets-dir "$HOME/.microsoft/usersecrets/ansible" \
  --dry-run --verbose
```

Crie o inventario privado a partir de `ansible/inventories/example/` e consulte
o guia Ansible antes da aplicacao real. Mantenha `vault.yml` e `vault-password`
fora do repositorio em `~/.microsoft/usersecrets/ansible` no Linux ou em
`%APPDATA%\Microsoft\UserSecrets\ansible` no Windows.

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
| Git hooks | Gitleaks 8.30.1 via Docker e testes Bats com stub |
| PowerShell | Parser, PSScriptAnalyzer e Pester |
| Ansible | yamllint, ansible-lint, syntax-check, check mode e idempotencia; Molecule para roles |

Declare versao/SO de PowerShell; controller Ansible usa Linux/WSL. Teste mutacoes
somente em ambiente descartavel autorizado. Instrucoes nao substituem testes e
revisao; gates de CI serao definidos quando existirem automacoes concretas.
