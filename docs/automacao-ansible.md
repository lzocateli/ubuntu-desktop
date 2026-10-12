# Automacao Ansible do Ubuntu Desktop

## Sumario

- [Objetivo e escopo](#objetivo-e-escopo)
- [Dependencias](#dependencias)
- [Estrutura](#estrutura)
- [Bootstrap](#bootstrap)
- [Inventario](#inventario)
- [Secrets e Ansible Vault](#secrets-e-ansible-vault)
- [Configuracao Git do usuario](#configuracao-git-do-usuario)
- [Ferramentas de desenvolvimento](#ferramentas-de-desenvolvimento)
- [Chaves SSH e NuGet](#chaves-ssh-e-nuget)
- [Ambiente Linux pelo 1Password](#ambiente-linux-pelo-1password)
- [Parametros e variaveis](#parametros-e-variaveis)
- [Uso rapido](#uso-rapido)
- [Simulacao](#simulacao)
- [Remocao do Snap](#remocao-do-snap)
- [Tags](#tags)
- [Logs e saidas](#logs-e-saidas)
- [Seguranca e impacto](#seguranca-e-impacto)
- [Validacao](#validacao)
- [Troubleshooting](#troubleshooting)
- [Recuperacao](#recuperacao)

## Objetivo e escopo

Aplicar o estado descrito no [tutorial da stack de desenvolvimento](stack-desenvolvimento.md)
e nas fases de Flatpak/Snap do documento original. O alvo suportado e Ubuntu
Desktop 26.04 LTS amd64. O controller deve executar em Linux ou WSL; Windows
nativo nao e suportado pelo Ansible.

A automacao instala aplicativos, repositorios APT, SDKs, CLIs, Podman rootless,
shell e fontes. A remocao do Snap e separada, destrutiva e opt-in.

## Dependencias

Controller:

- Bash 4.4+, `curl`, `tar` e acesso HTTPS.
- `uv` 0.8.22, `ansible-core` 2.19.2 e `pywinrm` 0.5.0, instalados pelo bootstrap.
- Collection `community.general` 11.3.0.

Alvo:

- Ubuntu Desktop 26.04 LTS amd64.
- Python disponivel para o Ansible.
- Usuario SSH/local `lzocateli`, home `/home/lzocateli` e membro do grupo `sudo`.
- Faixas subordinadas do usuario configuradas em `/etc/subuid` e `/etc/subgid`.
- Acesso HTTPS aos repositorios oficiais e ao Flathub.
- Sessao GNOME para validacao funcional de aplicativos graficos.

O bootstrap nao instala `curl` ou `tar`; dependencias ausentes causam falha antes
de qualquer download.

## Estrutura

| Caminho | Responsabilidade |
| --- | --- |
| `ansible/playbooks/configure-workstation.yml` | Orquestracao principal |
| `ansible/roles/preflight/` | Validacao de SO, arquitetura e usuario |
| `ansible/roles/base/` | Pacotes Ubuntu e terminal |
| `ansible/roles/flatpak_apps/` | Flathub e aplicativos graficos |
| `ansible/roles/host_tools/` | Repositorios, SDKs, CLIs e Podman rootless |
| `ansible/roles/terminal/` | uv, ZSH, Oh My Posh, Oh My Zsh e fonte |
| `ansible/roles/snap_migration/` | Remocao e bloqueio opt-in do Snap |
| `scripts/bash/bootstrap-ansible.sh` | Dependencias do controller |
| `scripts/bash/run-ansible.sh` | Wrapper operacional |

## Bootstrap

Ajuda e simulacao nao exigem Ansible nem criam instalacoes:

```bash
bash scripts/bash/bootstrap-ansible.sh --help
bash scripts/bash/bootstrap-ansible.sh --dry-run --verbose
```

Instalacao real no usuario atual:

```bash
bash scripts/bash/bootstrap-ansible.sh
```

O bootstrap nao usa `sudo`, nao executa script remoto e instala a ferramenta em
`~/.local/bin`. Versoes podem ser alteradas conscientemente:

```bash
bash scripts/bash/bootstrap-ansible.sh \
  --uv-version 0.8.22 \
  --ansible-version 2.19.2 \
  --pywinrm-version 0.5.0
```

## Inventario

Copie o modelo para o caminho privado ignorado pelo Git:

```bash
mkdir -p ansible/inventories/private/lab/group_vars
cp ansible/inventories/example/hosts.yml \
  ansible/inventories/private/lab/hosts.yml
cp ansible/inventories/example/group_vars/all.yml \
  ansible/inventories/private/lab/group_vars/all.yml
```

Edite host e usuario. Nao desabilite verificacao de host SSH e nao armazene
senha, token ou chave privada no inventario. Use SSH Agent e Ansible Vault ou um
provedor aprovado para secrets.

## Secrets e Ansible Vault

O wrapper procura um Vault externo no diretorio definido por
`ANSIBLE_SECRETS_DIR` ou `--secrets-dir`. Sem configuracao explicita, usa o
diretorio Linux abaixo somente quando ele ja existe:

| Ambiente | Diretorio |
| --- | --- |
| Linux | `~/.microsoft/usersecrets/ansible` |
| Windows | `%APPDATA%\Microsoft\UserSecrets\ansible` |
| WSL acessando Windows | `/mnt/c/Users/<usuario>/AppData/Roaming/Microsoft/UserSecrets/ansible` |

O diretorio deve conter:

| Arquivo | Conteudo |
| --- | --- |
| `vault.yml` | Variaveis criptografadas pelo Ansible Vault |
| `vault-password` | Senha usada para abrir o Vault, nunca versionada |

Crie a estrutura no Linux com permissao restrita:

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

No editor aberto por `ansible-vault create`, informe apenas variaveis realmente
necessarias, por exemplo `ansible_become_password`. Prefira SSH Agent a armazenar
`ansible_password` ou chaves privadas.

Para manter os arquivos no perfil Windows, crie o diretorio no PowerShell e
converta o caminho ao executar pelo WSL:

```powershell
$secretsDir = Join-Path $env:APPDATA 'Microsoft\UserSecrets\ansible'
New-Item -ItemType Directory -Force -Path $secretsDir | Out-Null
icacls $secretsDir /inheritance:r /grant:r "$($env:USERNAME):(OI)(CI)F"
```

```bash
SECRETS_DIR="$(wslpath "$(cmd.exe /c 'echo %APPDATA%' | tr -d '\r')")/Microsoft/UserSecrets/ansible"
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01 --secrets-dir "$SECRETS_DIR" --dry-run
```

Crie `vault-password` e `vault.yml` com o fluxo Linux anterior, usando esse
`SECRETS_DIR`. Em caminhos `/mnt/<unidade>/`, as ACLs do Windows controlam o
acesso; em filesystem Linux, o wrapper rejeita permissao para grupo ou outros.
Se o diretorio for informado explicitamente, arquivos ausentes causam erro de
uso. O conteudo dos arquivos nao e escrito no log.

## Configuracao Git do usuario

A role `terminal` cria `/home/lzocateli/.gitconfig` com proprietario `lzocateli` e
modo `0600`. Se um arquivo anterior existir, a primeira aplicacao preserva uma
copia em `~/.gitconfig.pre-ansible`; execucoes posteriores nao sobrescrevem essa
copia. O Ansible valida o arquivo com o proprio comando `git config` antes de
substitui-lo.

A identidade vem de `terminal_git_user_name` e `terminal_git_user_email`. O
estado gerenciado tambem configura:

- VS Code como editor, editor de rebase, difftool e mergetool;
- LF, `core.autocrlf=input`, verificacao de line endings e file mode do Linux;
- `main` como branch inicial, fetch com prune e push com upstream automatico;
- pull somente fast-forward, rebase com autostash/updateRefs e `rerere`;
- diff `histogram`, conflitos `zdiff3` e ordenacao operacional de branches/tags.

O arquivo nao armazena tokens nem configura um helper dependente do Windows.
`credential.useHttpPath=true` evita colisao entre credenciais de caminhos
distintos quando um helper aprovado for instalado. Para acesso remoto, prefira
SSH, integracao do 1Password ou autentique uma ferramenta apropriada ao servico.

Valide sem revelar credenciais:

```bash
git config --global --get user.name
git config --global --get user.email
git config --global --get core.autocrlf
git config --global --get init.defaultBranch
git config --global --list --show-origin
```

Alteracoes manuais no arquivo gerenciado sao substituidas na proxima aplicacao.
Altere as variaveis ou o template da role para tornar uma mudanca persistente.

## Ferramentas de desenvolvimento

A role `terminal` instala um runtime compartilhado e o carrega em `~/.profile`,
`~/.bashrc` e `~/.zshrc`. As funcoes `node`, `npm` e `npx` executam na imagem
definida por `terminal_devops_image`; Node/npm nao sao instalados no host.

O diretorio atual e montado como `/workspace`, com `--userns=keep-id` e UID/GID
do usuario. O home interno e persistido em
`~/.local/share/ubuntu-desktop/devops-home`. O socket Podman, tokens e
configuracoes do Copilot/GitHub CLI nao sao montados.

O Copilot CLI e instalado localmente a partir do tarball Linux x64 oficial, sem
Node/npm. A versao e o SHA-256 ficam fixados nas variaveis da role, o binario e
extraido em `/opt/copilot-cli/<versao>` e `/usr/local/bin/copilot` aponta para a
versao ativa. A validacao executa `copilot --version` no host.

O mesmo runtime define `SSL_CERT_DIR` para que clientes OpenSSL reconhecam o
certificado HTTPS criado por `.NET 10`. A role `host_tools` consulta a confianca
antes de executar `dotnet dev-certs https --trust`; em check mode, apenas a
consulta ocorre e a mutacao e informada como pendente.

## Chaves SSH e NuGet

Na execucao real, a role `terminal` usa `op` no controller Ansible para ler o
campo `private key` dos itens configurados no vault `Automation`. O controller
precisa ter o 1Password CLI e a variavel de ambiente
`OP_SERVICE_ACCOUNT_TOKEN` definida com acesso somente de leitura ao vault. O
token nao deve ser salvo no inventario nem passado como argumento de linha de
comando. As consultas ao 1Password e a instalacao das chaves sao omitidas em
check mode.

Os itens padrao sao `proxmox`, `interserver-st56165`, `cat-devops-zocatel`,
`pve-brazildevops`, `hostinger-root` e `hostinger-brazildevops`. As chaves sao
gravadas em `~/.ssh/` com modo `0600`, dentro de um diretorio `0700`; respostas
e diffs das tarefas que manipulam material privado sao ocultados. O bloco
gerenciado em `~/.ssh/config` preserva outras entradas e configura:

| Alias | Destino | Usuario | Chave |
| --- | --- | --- | --- |
| `hostinger-root` | `187.77.231.228` | `root` | `hostinger-root` |
| `hostinger-brazildevops` | `187.77.231.228` | `brazildevops` | `hostinger-brazildevops` |
| `interserver-st56165` | `216.158.237.158` | `st56165` | `interserver-st56165` |
| `proxmox01`-`proxmox06` | `172.16.100.10`-`172.16.100.15` | `root` | `proxmox` |
| `pve01`-`pve05` | nomes DNS `pve01`-`pve05` | `root` | `pve-brazildevops` |

A chave `cat-devops-zocatel` e instalada, mas nao recebe alias porque nao ha
destino SSH associado a ela. As conexoes usam a porta 22 e nao desabilitam a
verificacao de host key. A validacao real usa `ssh -G` para confirmar a
expansao de host, usuario, identidade e porta sem abrir conexao de rede.

Depois da instalacao do .NET, a role cria
`~/.nuget/NuGet/NuGet.Config` com permissao `0600` e as fontes nuget.org
(`https://api.nuget.org/v3/index.json`) e nugettest
(`https://int.nugettest.org/`). A configuracao nao inclui credenciais; o
endpoint nugettest precisa permitir acesso sem autenticacao ou ser configurado
separadamente. A validacao real usa `dotnet nuget list source`. Check mode nao
grava nem consulta as chaves; a configuracao SSH e NuGet e simulada sem expor
diffs.

## Ambiente Linux pelo 1Password

Este fluxo e diferente do Ansible Vault do controller. O Ansible configura o
ambiente do usuario durante a aplicacao real: invoca `op document get` com o
vault e documento informados, valida o formato e grava comandos `export` em um
bloco gerenciado de `~/.profile`. O arquivo `.env` bruto nao e persistido.

Os valores ficam em texto claro no profile, protegido com modo `0600`. Isso
atende a disponibilidade no login, mas qualquer processo executado pelo usuario
pode herdar as variaveis. Use este modo somente quando as ferramentas exigirem
segredos via ambiente; prefira referencias `op://` quando houver suporte.

### Preparar o 1Password

1. No aplicativo 1Password, habilite a integracao com o CLI em **Settings >
   Developer > Integrate with 1Password CLI**.
2. Crie ou escolha um vault, por exemplo `Engineering`.
3. Adicione o `.env` como documento/arquivo, por exemplo `development.env`.
4. Desbloqueie o aplicativo e confirme o acesso, no mesmo usuario e contexto de
  conexao usados pelo Ansible, sem imprimir o documento:

```bash
op account list
op vault get Engineering >/dev/null
op document get development.env --vault Engineering >/dev/null
```

O documento aceita linhas vazias, comentarios iniciados por `#`, `NOME=valor`
e `export NOME=valor`. Nomes devem seguir `[A-Za-z_][A-Za-z0-9_]*`. Aspas
externas simples ou duplas sao removidas; o valor permanece literal. Nao use
multilinhas, expansao de variaveis ou interpolacao. O renderizador aplica aspas
seguras antes de incorporar os valores ao profile. Exemplo sem valores reais:

```dotenv
AZURE_TENANT_ID=<tenant-id>
AZURE_CLIENT_ID=<client-id>
TF_VAR_environment=development
API_BASE_URL="https://api.example.invalid"
```

### Habilitar no inventario

Configure apenas os identificadores nao secretos:

```yaml
terminal_onepassword_env_enabled: true
terminal_onepassword_env_account: ''
terminal_onepassword_env_vault: Engineering
terminal_onepassword_env_document: development.env
```

Defina `terminal_onepassword_env_account` com o nome ou ID da conta quando o
CLI estiver conectado a mais de uma conta; vazio usa a selecao padrao do `op`.

Execute primeiro em simulacao e depois aplique:

```bash
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01 --tags terminal --dry-run --verbose
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01 --tags terminal
```

Check mode nao acessa o documento nem altera o bloco secreto, pois nao existe
simulacao segura para autenticar e baixar seu conteudo. Na execucao real, o CLI
`op` pode solicitar autorizacao pelo aplicativo Desktop. O Ansible nao abre nem
desbloqueia automaticamente a interface grafica e falha se o acesso nao estiver
disponivel.

A automacao grava o bloco gerenciado em `~/.profile` com modo `0600`. Finalize a
sessao e entre novamente, ou carregue o profile no Bash atual. Valide sem exibir
valores:

```bash
. "$HOME/.profile"
test -n "${AZURE_TENANT_ID:-}" && printf 'AZURE_TENANT_ID carregada\n'
env | sed 's/=.*$/=<redacted>/' | grep -E '^(AZURE_|TF_VAR_)'
```

Quando o documento mudar, reaplique a tag `terminal` para atualizar o profile.
Para remover as variaveis persistidas, defina
`terminal_onepassword_env_enabled: false`, reaplique a tag e inicie nova sessao.
O Ansible remove o bloco gerenciado, mas nao consegue retirar variaveis ja
herdadas pelos processos existentes. Nao ative `set -x` nem imprima valores.

## Parametros e variaveis

Wrapper:

| Parametro | Obrigatorio | Descricao |
| --- | --- | --- |
| `--inventory CAMINHO` | Sim | Inventario explicito |
| `--limit ALVO` | Sim | Host ou grupo limitado |
| `--tags LISTA` | Nao | Tags separadas por virgula |
| `--secrets-dir CAMINHO` | Nao | Diretorio externo com `vault.yml` e `vault-password` |
| `--dry-run`, `-dryrun` | Nao | Traduz para `--check --diff` |
| `--verbose` | Nao | Adiciona `-v` ao Ansible |
| `--remove-snap` | Nao | Inclui a role Snap |
| `--confirm-remove-snap` | Real com Snap | Confirma impacto destrutivo |

Variaveis principais:

| Variavel | Padrao | Impacto |
| --- | --- | --- |
| `ubuntu_desktop_user` | `lzocateli` | Usuario da conexao e dono da configuracao de desktop |
| `ubuntu_desktop_home` | `/home/lzocateli` | Home validado no `getent` |
| `terminal_git_user_name` | `zocatel` no inventario | Nome de autor registrado nos commits, independente do login Linux |
| `terminal_git_user_email` | E-mail definido no inventario | E-mail registrado nos commits |
| `flatpak_apps_install_firefox` | `false` | Instala Firefox Flatpak |
| `host_tools_install_1password` | `true` | Instala Desktop e CLI |
| `host_tools_configure_dotnet_dev_certificate` | `true` | Cria e confia no certificado HTTPS .NET do usuario |
| `terminal_configure_zsh` | `true` | Configura e define ZSH como shell |
| `terminal_devops_image` | `docker.io/lzocateli/devops:cpu-ubuntu24.04` | Imagem para Node, npm e npx |
| `terminal_copilot_cli_version` | `1.0.91` | Versao standalone do Copilot CLI instalada no host |
| `terminal_copilot_cli_checksum` | SHA-256 do release 1.0.91 | Integridade do tarball Linux x64 |
| `terminal_onepassword_env_enabled` | `false` | Baixa o `.env` e persiste exports no profile |
| `terminal_onepassword_env_account` | Vazio | Conta `op` opcional |
| `terminal_onepassword_env_vault` | Vazio | Nome/ID do vault do documento |
| `terminal_onepassword_env_document` | Vazio | Nome/ID do documento `.env` |
| `terminal_ssh_op_vault` | Vazio | Vault do 1Password que contem as chaves SSH |
| `terminal_ssh_key_items` | `[]` | Itens cujos campos `private key` serao instalados |
| `terminal_ssh_hosts` | `[]` | Aliases, destinos, usuarios e nomes das chaves SSH |
| `terminal_nuget_test_source` | `https://int.nugettest.org/` | URL da fonte NuGet adicional |
| `host_tools_kubernetes_repository_version` | `v1.34` | Serie menor de kubectl |

## Uso rapido

Primeiro simule em um alvo descartavel autorizado:

```bash
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01 \
  --secrets-dir "$HOME/.microsoft/usersecrets/ansible" \
  --dry-run --verbose
```

Aplicacao real, sem remover Snap:

```bash
test -n "${OP_SERVICE_ACCOUNT_TOKEN:-}"
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01
```

O exemplo acima presume `op` instalado no controller e acesso ao vault
configurado. Forneca o token no ambiente via gerenciador de secrets do
controller; nao o grave no shell profile, inventario, argumento de processo ou
log. Se as chaves SSH nao fizerem parte da execucao, configure
`terminal_ssh_key_items: []` e `terminal_ssh_hosts: []` no inventario privado.

O wrapper nao eleva privilegios no controller. O playbook usa `become` somente
nas tasks que alteram o sistema. A conexao remota, o shell, as fontes, o profile
e demais configuracoes pessoais usam `lzocateli`; pacotes, repositorios, Flatpaks
de sistema e servicos usam `sudo` a partir desse usuario. O preflight falha se o
usuario conectado nao for `lzocateli`, se o home divergir ou se faltar o grupo
`sudo`.

## Simulacao

`--dry-run` executa consultas e modulos Ansible em check mode com diff. Pode
acessar o host, ler inventario, consultar pacotes e exigir sudo. O log local em
`artifacts/logs/` e a unica escrita permitida pelo wrapper.

Operacoes `snap remove` nao possuem simulacao confiavel. A role mostra o
inventario detectado e pula esses comandos em check mode. Portanto, a simulacao
da migracao Snap e parcial e nao comprova a ordem real de remocao.

Se o certificado .NET ainda nao for confiavel, check mode nao o cria nem altera
stores de certificados. A execucao real deve ser validada em VM descartavel com
`dotnet dev-certs https --check --trust` como o usuario da estacao.

## Remocao do Snap

Simule a fase isoladamente:

```bash
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01 \
  --remove-snap --dry-run --verbose
```

Depois de confirmar que Edge/Firefox e os demais substitutos funcionam, execute:

```bash
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01 \
  --remove-snap --confirm-remove-snap
```

Essa execucao remove Snaps conhecidos, purga `snapd`, exclui diretorios de dados
e cria `/etc/apt/preferences.d/no-snapd.pref` com prioridade `-1`. Dados removidos
nao possuem rollback automatico.

## Tags

| Tag | Escopo |
| --- | --- |
| `preflight` | Validacoes do alvo |
| `base` | Pacotes Ubuntu e terminal |
| `flatpak` | Flathub e aplicativos |
| `host_tools` | Podman rootless, SDKs e CLIs |
| `terminal` | Shell, Git, chaves SSH, fontes NuGet, uv, prompt e fonte |
| `development` | Ferramentas do host e terminal |
| `snap_migration` | Remocao opt-in do Snap |

Exemplo focado:

```bash
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01 --tags flatpak --dry-run
```

## Logs e saidas

- Console: progresso do wrapper e saida normal do Ansible.
- Arquivo: `artifacts/logs/ansible-<UTC>-<PID>.log` com permissao `0600`.
- Bootstrap: `artifacts/logs/bootstrap-ansible-<UTC>-<PID>.log`.
- Codigo `2`: erro de uso do wrapper; outros codigos preservam a falha operacional.

Logs sao locais, ignorados pelo Git e podem conter nomes de hosts e pacotes. Nao
inclua secrets em variaveis de linha de comando. Defina retencao conforme a
politica local e apague logs antigos apenas apos revisar seu conteudo.

## Seguranca e impacto

- Repositorios externos usam HTTPS, keyrings dedicados e `signed-by`.
- O playbook nao desabilita TLS nem verificacao de host SSH.
- Chaves SSH sao material privado em texto claro no disco; proteja o home com
  criptografia de disco e mantenha os modos `0700`/`0600` gerenciados pela role.
- Podman executa containers como o usuario, sem daemon root ou grupo privilegiado.
- Rootless requer UID/GID subordinados em `/etc/subuid` e `/etc/subgid`.
- `.gitconfig` tem modo `0600`, nao contem tokens e pertence a `lzocateli`.
- `.zshrc` recebe somente um bloco identificado e idempotente.
- Handlers atualizam cache APT e fontes somente quando necessario.
- Remocao do Snap exige duas opcoes e uma execucao separada.
- Credenciais permanecem fora do repositorio em um Vault criptografado.
- O wrapper passa somente caminhos ao Ansible; valores secretos nao sao registrados.

## Validacao

No controller Linux/WSL:

```bash
bash -n scripts/bash/bootstrap-ansible.sh
bash -n scripts/bash/run-ansible.sh
shellcheck scripts/bash/*.sh tests/bash/*.bats
shfmt -d scripts/bash/*.sh tests/bash/*.bats
bats tests/bash/
cd ansible
yamllint .
ansible-lint .
ansible-playbook -i inventories/example/hosts.yml \
  playbooks/configure-workstation.yml --syntax-check
ansible-playbook -i inventories/example/hosts.yml \
  playbooks/configure-workstation.yml --list-hosts --list-tasks
```

Check mode, primeira aplicacao e segunda aplicacao devem usar uma VM Ubuntu
Desktop 26.04 descartavel. Na segunda aplicacao, o recap deve informar
`changed=0`; downloads alterados no upstream ou atualizacoes explicitas devem ser
investigados, nao simplesmente ignorados.

## Troubleshooting

### Controller Windows nativo

Sintoma: Ansible nao inicia ou plugins falham. Execute o bootstrap e wrapper no
WSL Ubuntu; caminhos de inventario devem ser acessiveis dentro do WSL.

### Chave ou repositorio APT rejeitado

Confirme hora do sistema, DNS, HTTPS e origem sem desabilitar verificacao:

```bash
timedatectl status
grep -R '^deb ' /etc/apt/sources.list.d/
sudo apt update
```

### Aplicativo Flatpak nao abre

```bash
flatpak info ID_DO_APLICATIVO
flatpak run ID_DO_APLICATIVO
journalctl --user --since '10 minutes ago'
```

### ZSH falha ao iniciar

Inicie sem configuracao e revise o bloco gerenciado:

```bash
zsh -f
grep -n 'ANSIBLE UBUNTU DESKTOP' "$HOME/.zshrc"
```

### Git rejeita pull divergente

`pull.ff=only` impede merges implicitos. Escolha conscientemente entre rebase e
merge depois de revisar o historico:

```bash
git fetch --prune
git status
git rebase '@{upstream}'
```

## Recuperacao

Para reativar Snap apos uma migracao confirmada:

```bash
sudo rm /etc/apt/preferences.d/no-snapd.pref
sudo apt update
sudo apt install -y snapd
sudo systemctl enable --now snapd.socket
snap version
```

Aplicativos e dados Snap removidos precisam ser reinstalados ou restaurados de
backup. Para outras ferramentas, siga a secao de recuperacao do tutorial da
stack de desenvolvimento. Nunca remova repositorios, grupos ou dados em lote
sem revisar o estado real do host.

Para restaurar temporariamente a configuracao Git anterior:

```bash
install -m 0600 "$HOME/.gitconfig.pre-ansible" "$HOME/.gitconfig"
git config --global --list --show-origin
```

A proxima aplicacao restaura o estado gerenciado. Para uma recuperacao
permanente, ajuste as variaveis ou o template antes de reaplicar a role.
