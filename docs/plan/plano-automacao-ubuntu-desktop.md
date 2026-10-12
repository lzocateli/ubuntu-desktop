# Plano de automacao do Ubuntu Desktop

## Sumario

- [Plano de automacao do Ubuntu Desktop](#plano-de-automacao-do-ubuntu-desktop)
  - [Sumario](#sumario)
  - [Status do Plano](#status-do-plano)
  - [Objetivo](#objetivo)
  - [Escopo aprovado](#escopo-aprovado)
  - [Arquitetura](#arquitetura)
  - [Fases](#fases)
  - [Validacao](#validacao)
  - [Riscos e recuperacao](#riscos-e-recuperacao)

## Status do Plano

| Campo | Valor |
| --- | --- |
| Status geral | Em andamento |
| Ultima atualizacao | 2026-10-11 |
| Progresso | 6 de 7 etapas concluidas |
| Evidencias | Validacoes de 2026-10-02 sao historicas; mudancas para Ubuntu 26.04 e Podman rootless ainda precisam de validacao |
| Proximo passo | Validar Podman rootless, check mode e idempotencia em VM Ubuntu 26.04 descartavel |

## Objetivo

Automatizar, de forma idempotente e auditavel, a configuracao descrita em
`Instalacao no Ubuntu Desktop.docx` para uma estacao Ubuntu Desktop 26.04 LTS
amd64. A automacao deve oferecer simulacao segura, validacao por ferramenta e
documentacao operacional em `docs/`.

## Escopo aprovado

- Cobrir todas as fases do documento: Flatpak, aplicativos, migracao do Snap,
  bloqueio do Snap e stack de desenvolvimento.
- Instalar Microsoft Edge por Flatpak e Visual Studio Code pelo repositorio
  oficial no host. Firefox permanece opcional por variavel.
- Remover e bloquear Snap somente mediante opcao explicita e confirmacao.
- Instalar aplicativos graficos por Flatpak quando apropriado.
- Instalar Bruno pelo Flathub.
- Instalar SDKs, CLIs, shells e servicos pelos canais oficiais no host.
- Usar Podman rootless no lugar de Docker, com armazenamento no home do usuario.
- Configurar o certificado HTTPS de desenvolvimento .NET para o usuario.
- Executar Node, npm e npx em container e instalar o Copilot CLI standalone no host.
- Manter tutoriais especificos em `docs/`; o `README.md` raiz sera o indice e a
  visao geral do projeto.

## Arquitetura

- `ansible/playbooks/`: playbook principal.
- `ansible/roles/`: roles por responsabilidade, com defaults sobrescreviveis.
- `ansible/inventories/`: inventario local de exemplo sem alvo real padrao.
- `scripts/bash/`: bootstrap de dependencias e wrapper operacional.
- `tests/`: testes de contrato do wrapper e verificacoes estaticas.
- `artifacts/`: logs e temporarios locais ignorados pelo Git.
- `docs/`: tutoriais de instalacao, validacao e recuperacao.

O controller Ansible deve executar em Ubuntu ou WSL, nunca em Windows nativo.
Execucoes reais exigirao inventario explicito, `--limit` e confirmacao para a
remocao do Snap.

## Fases

1. Criar configuracao, inventario de exemplo e playbook principal.
2. Implementar preflight, pacotes base, Flatpak e aplicativos.
3. Implementar terminal, runtimes, Podman rootless, cloud, IaC e Kubernetes.
4. Implementar migracao e bloqueio opt-in do Snap.
5. Criar bootstrap e wrapper com ajuda, dry-run, logs e validacao de entradas.
6. Documentar cada ferramenta e atualizar o indice principal.
7. Executar validacoes estaticas, check mode e idempotencia onde houver VM
   descartavel autorizada.

## Validacao

Validacoes minimas previstas:

```bash
cd ansible
yamllint .
ansible-lint .
ansible-playbook -i inventories/example/hosts.yml \
  playbooks/configure-workstation.yml --syntax-check
bash -n scripts/bash/bootstrap-ansible.sh
bash -n scripts/bash/run-ansible.sh
shellcheck scripts/bash/*.sh tests/bash/*.bats
shfmt -d scripts/bash/*.sh tests/bash/*.bats
bats tests/bash/
```

O check mode, a primeira aplicacao e a segunda aplicacao com `changed=0` serao
executados apenas em VM Ubuntu Desktop 26.04 descartavel e autorizada. Containers
nao comprovam integracao com systemd, GNOME ou sessao grafica.

As evidencias abaixo foram obtidas em 2026-10-02, antes da migracao para Ubuntu
26.04 e Podman; elas nao validam as mudancas atuais. Validacao executada na imagem
`lzocateli/devops:cpu-ubuntu24.04`:

- `bash -n`: aprovado para os dois wrappers.
- `yamllint`: aprovado.
- `ansible-lint`: perfil `production`, zero falhas e zero avisos.
- `ansible-playbook --syntax-check`: aprovado.
- `ansible-playbook --list-hosts --list-tasks`: aprovado.
- Contratos de ajuda, entradas, dry-run e confirmacao Snap: aprovados com stubs.
- Vault externo: argumentos aprovados, senha ausente da saida e modo inseguro bloqueado.
- Cobertura de aplicativos: instalacao, configuracao minima e validacao auditadas.
- Git do usuario: template Linux renderizado e analisado pelo proprio Git.
- Pre-commit: diff staged enviado ao Gitleaks 8.30.1 com redacao e container read-only via Docker.
- Ambiente 1Password: download, renderizacao persistente e rejeicao validados.
- Bruno: ID oficial do Flathub incluido na lista declarativa.
- Certificado .NET: consulta idempotente, mutacao por usuario e check mode validados estaticamente.
- Bats: runtime de containers restrito a Node/npm/npx, com UID/GID e mounts validados.
- Copilot CLI: artefato standalone oficial fixado e validado por SHA-256.
- Dry-run do bootstrap: aprovado, sem instalacao de ferramentas.

`shellcheck`, `shfmt` e Bats foram instalados somente em container efemero para
esta validacao. ShellCheck aprovou o arquivo novo; o `shfmt` para sintaxe Bats
diverge da indentacao vigente na suite. Check mode remoto, primeira
aplicacao e segunda aplicacao idempotente permanecem pendentes por exigirem VM
descartavel.

## Riscos e recuperacao

- Remover Snap pode retirar Firefox e a loja padrao. A role exigira opt-in e
  confirmacao; a recuperacao reinstala `snapd` e remove o pin do APT.
- Repositorios externos alteram a cadeia de confianca do APT. Chaves serao
  armazenadas em keyrings dedicados e repositorios terao origem explicita.
- Podman rootless exige faixas subordinadas corretas em `/etc/subuid` e
  `/etc/subgid`; os containers nao devem ser executados via daemon root.
- Configuracoes de shell serao preservadas e alteradas apenas por blocos geridos.
- O `.gitconfig` anterior sera preservado uma vez antes do estado gerenciado.
- Credenciais, tokens, inventarios privados e logs nao serao versionados.
