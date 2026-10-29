# Stack de desenvolvimento

## Sumario

- [Stack de desenvolvimento](#stack-de-desenvolvimento)
  - [Sumario](#sumario)
  - [Objetivo](#objetivo)
  - [Requisitos](#requisitos)
  - [Aplicativos Flatpak](#aplicativos-flatpak)
    - [Microsoft Edge](#microsoft-edge)
    - [Bruno](#bruno)
    - [Firefox opcional](#firefox-opcional)
    - [Remmina](#remmina)
    - [Flatseal](#flatseal)
    - [Extension Manager](#extension-manager)
  - [Ferramentas de terminal](#ferramentas-de-terminal)
    - [Git](#git)
    - [OpenSSH](#openssh)
    - [ZSH](#zsh)
    - [TMUX](#tmux)
    - [Tilix](#tilix)
  - [Podman rootless e Compose](#podman-rootless-e-compose)
  - [Node em container e Copilot CLI local](#node-em-container-e-copilot-cli-local)
  - [Claude Code CLI](#claude-code-cli)
  - [PowerShell](#powershell)
  - [Ansible e pywinrm](#ansible-e-pywinrm)
  - [Azure CLI](#azure-cli)
  - [Terraform](#terraform)
  - [kubectl](#kubectl)
  - [GitHub CLI](#github-cli)
  - [RTK](#rtk)
  - [1Password](#1password)
  - [uv](#uv)
  - [Oh My Posh](#oh-my-posh)
  - [Oh My Zsh](#oh-my-zsh)
  - [MesloLGM Nerd Font](#meslolgm-nerd-font)
  - [.NET 8 e .NET 10](#net-8-e-net-10)
  - [Visual Studio Code](#visual-studio-code)
  - [Validacao consolidada](#validacao-consolidada)
  - [Riscos e recuperacao](#riscos-e-recuperacao)

## Objetivo

Configurar uma estacao Ubuntu Desktop 26.04 LTS amd64 para desenvolvimento .NET,
automacao e administracao de infraestrutura. Aplicativos graficos independentes
usam Flatpak; SDKs, CLIs, shells e servicos usam o host e canais oficiais.

Os comandos manuais abaixo explicam cada item da stack de desenvolvimento. Para
uma instalacao idempotente e auditavel, use o
[guia Ansible](automacao-ansible.md).

## Requisitos

- Ubuntu Desktop 26.04 LTS amd64 com sessao GNOME.
- Usuario comum com permissao de `sudo`.
- Bash 4.4+, acesso HTTPS e pelo menos 20 GB livres.
- Reinicio de sessao permitido para mudancas de shell e fontes.

Confirme o alvo antes de alterar o sistema:

```bash
. /etc/os-release
printf 'SO=%s versao=%s arquitetura=%s\n' "$NAME" "$VERSION_ID" "$(dpkg --print-architecture)"
test "$ID" = ubuntu && test "$VERSION_ID" = 26.04
test "$(dpkg --print-architecture)" = amd64
```

## Aplicativos Flatpak

Instale a integracao e o Flathub uma unica vez:

```bash
sudo apt update
sudo apt install -y flatpak gnome-software gnome-software-plugin-flatpak
sudo flatpak remote-add --if-not-exists flathub \
  https://flathub.org/repo/flathub.flatpakrepo
flatpak remotes --system
```

### Microsoft Edge

```bash
sudo flatpak install -y flathub com.microsoft.Edge
flatpak info com.microsoft.Edge
```

O pacote no Flathub e comunitario e nao possui suporte oficial da Microsoft.
A automacao configura este Edge como navegador padrao para HTML e links HTTP e
HTTPS; o Google Chrome tambem e instalado como navegador alternativo pelo
repositorio APT oficial do Google.

### Bruno

```bash
sudo flatpak install -y flathub com.usebruno.Bruno
flatpak info com.usebruno.Bruno
```

O Bruno permanece isolado como aplicativo grafico; colecoes e secrets nao devem
ser adicionados ao repositorio desta automacao.

### Firefox opcional

```bash
sudo flatpak install -y flathub org.mozilla.firefox
flatpak info org.mozilla.firefox
```

O projeto instala Edge por padrao. Habilite Firefox somente quando os dois
navegadores forem necessarios.

### Remmina

```bash
sudo flatpak install -y flathub org.remmina.Remmina
flatpak info org.remmina.Remmina
```

O Remmina fornece clientes graficos RDP e SSH. A conexao a servidores deve ser
validada separadamente, sem armazenar credenciais no repositorio.

### Flatseal

```bash
sudo flatpak install -y flathub com.github.tchx84.Flatseal
flatpak info com.github.tchx84.Flatseal
```

### Extension Manager

```bash
sudo flatpak install -y flathub com.mattjakeman.ExtensionManager
flatpak info com.mattjakeman.ExtensionManager
```

## Ferramentas de terminal

### Git

```bash
sudo apt update
sudo apt install -y git
git --version
```

O Ansible cria `/home/lzocateli/.gitconfig`, modo `0600`, com identidade definida
no inventario, line endings Linux, branch `main`, fetch/push seguros, rebase,
`rerere` e integracao do VS Code. Um arquivo anterior e preservado uma unica vez
em `~/.gitconfig.pre-ansible`. Valide:

```bash
git config --global --get user.name
git config --global --get user.email
git config --global --get core.autocrlf
git config --global --get init.defaultBranch
git config --global --list --show-origin
```

Credenciais e tokens nao sao gravados no `.gitconfig`. Use SSH, a integracao do
1Password ou um helper de credenciais aprovado para o servico remoto.

### OpenSSH

```bash
sudo apt install -y openssh-client
ssh -V
```

O servidor `openssh-server` nao e instalado por padrao. Instale-o somente se a
estacao precisar aceitar conexoes e revise firewall, chaves e politica de acesso.

### ZSH

```bash
sudo apt install -y zsh
zsh --version
command -v zsh
```

Para definir como shell do usuario atual:

```bash
chsh -s "$(command -v zsh)"
getent passwd "$USER" | cut -d: -f7
```

Finalize a sessao e entre novamente para aplicar o shell.
O Ansible mantem `~/.zsh_history` persistente e compartilhado entre sessoes,
com `HISTSIZE` e `SAVEHIST` de 50.000 e permissoes `0600` no arquivo.
O bloco gerenciado do `.zshrc` configura `APPEND_HISTORY`, `SHARE_HISTORY`,
`EXTENDED_HISTORY`, evita duplicatas/comandos precedidos por espaco e carrega
o tema Atomic versionado no projeto. O Ansible habilita `zsh-autosuggestions`
para sugerir comandos do historico enquanto voce digita (seta para a direita
aceita) e `history-substring-search` para navegar com as setas por comandos que
contenham o trecho digitado. A conclusao normal por Tab continua disponivel.

### TMUX

```bash
sudo apt install -y tmux
tmux -V
```

### Tilix

```bash
sudo apt install -y tilix
tilix --version
```

Abra o Tilix na sessao GNOME para validar atalhos, perfil e fonte.

## Podman rootless e Compose

Instale Podman e os componentes necessarios para containers rootless e Compose:

```bash
sudo apt update
sudo apt install -y podman podman-compose uidmap slirp4netns fuse-overlayfs
```

Rootless depende de faixas subordinadas exclusivas para o usuario em
`/etc/subuid` e `/etc/subgid`. Confira antes de executar containers:

```bash
awk -F: -v user="$USER" '$1 == user { print FILENAME ":" $0 }' \
  /etc/subuid /etc/subgid
podman info --format '{{.Host.Security.Rootless}}'
podman --version
podman compose version
```

O primeiro comando deve mostrar uma faixa em cada arquivo; o segundo deve
imprimir `true`. As configuracoes geridas pelo Ansible ficam em
`~/.config/containers/containers.conf` e `storage.conf`, com rede e
armazenamento persistente sob o home. O Podman nao requer daemon de sistema nem
grupo privilegiado. `fuse-overlayfs` fica disponivel como fallback quando o
kernel nao puder montar overlay rootless nativo.

Nao configure um socket compativel com Docker: os comandos usam `podman`
diretamente e executam no usuario atual.

## Node em container e Copilot CLI local

A automacao nao instala Node.js, npm, npx ou SQLCMD no host. As funcoes `node`,
`npm`, `npx`, `ng` e `sqlcmd` usam `docker.io/lzocateli/devops:cpu-v1`, montam o
diretorio atual em `/workspace` e executam com o UID/GID do usuario:

```bash
node --version
npm --version
npx --version
ng version
sqlcmd --version
```

A imagem publica inclui go-sqlcmd v1.10.0. Para conexoes SQL, exporte as variaveis
`SQLCMDSERVER`, `SQLCMDDBNAME`, `SQLCMDUSER` e `SQLCMDPASSWORD` no ambiente do
usuario; o wrapper encaminha os nomes ao container sem registrar nem incluir os
valores nos argumentos do Podman.

A role `terminal` consulta a imagem rootless e faz `podman pull` somente se
ausente. O Docker Hub e publico: sem login, token ou dependencia do Artifactory.
As funcoes usam `--pull=never`. Altere a tag/digest em `terminal_devops_image`
para preparar outra versao; uma tag presente nao e atualizada implicitamente.

O Angular CLI e instalado do npm publico em
`~/.local/share/ubuntu-desktop/devops-home/.local/npm`, somente se `bin/ng`
estiver ausente. `terminal_angular_cli_package` aceita `@angular/cli@VERSAO`
ou tag; o padrao da referencia e `@angular/cli@latest`. Para reproducibilidade,
fixe uma versao no inventario. Alterar essa variavel nao atualiza uma instalacao
existente; planeje a atualizacao separadamente.

`lh` usa `eza --long --all --group --color=auto`; `lhr` faz busca recursiva,
por exemplo `lhr '*.yml' '*.json'`. Cores sao ativadas em TTY, sem ANSI em pipes.
O container pode escrever no workspace e no seu home privado, mas nao recebe
o socket Podman nem as credenciais do GitHub/Copilot.

As funcoes seguem o mesmo modelo modular da referencia: cada uma possui um
template proprio em `ansible/roles/terminal/templates/` (`node.sh.j2`,
`npm.sh.j2`, `npx.sh.j2`, `ng.sh.j2`, `op.sh.j2`, `lh.sh.j2` e `lhr.sh.j2`).
O Ansible instala os sete arquivos em `~/.local/lib/ubuntu-desktop/`, com modo
`0600` e validacao Bash antes de substituir. `development-shell.sh` mantem o
ambiente, a auditoria e o executor comum, e carrega as funcoes individuais em
Bash/ZSH. `op-container.sh.j2` continua sendo o wrapper executavel separado;
o autenticador Azure DevOps corporativo da referencia nao faz parte do fluxo.

Ajuda e simulacao do provisionamento, a partir da raiz:

```bash
bash scripts/bash/run-ansible.sh --help
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/example/hosts.yml \
  --limit ubuntu-workstation.example.invalid --tags terminal --dry-run --verbose
```

O inventario de exemplo nao e um host real. Para aplicar, substitua inventario
e limite por uma VM autorizada e remova `--dry-run`. Na primeira instalacao,
inclua `--tags host_tools,terminal` para instalar Podman e eza. O check mode
nao baixa imagens, instala Angular nem consulta secrets. O wrapper Ansible
registra auditoria em `artifacts/logs/`. Chamadas reais de `node`/`npm`/`npx`/`ng`
registram timestamp UTC, nivel, ID e modo em
`~/.local/share/ubuntu-desktop/artifacts/logs/`, tambem no stderr. Falha de log
impede iniciar o container; argumentos e variaveis nao sao registrados.

Validacao isolada, sem containers reais:

```bash
bats tests/bash/development-shell.bats tests/bash/op-container.bats \
  tests/bash/load-1password-env.bats
ansible-playbook -i localhost, tests/ansible/terminal-zsh.yml
```

Os testes verificam segunda aplicacao com `changed=0` e ausencia de `pull`/`run`
na simulacao com Podman substituido. Nao substituem validacao de rede, conteudo
da imagem ou GNOME em VM Ubuntu 26.04 amd64. Se a imagem estiver ausente,
reaplique a role; outros erros Podman interrompem o fluxo. Para recuperar o
shell anterior, restaure seu backup de `.profile`/`.zshrc` e reabra a sessao.
Nao apague homes privados sem backup. Descarte logs conforme a retencao
operacional definida pelo usuario, sem remover configuracoes do container.

A tag `cpu-v1` identifica a imagem DevOps que deve fornecer Node, npm e op;
o sistema host suportado pela automacao e Ubuntu 26.04.

O Copilot CLI 1.0.91 e instalado como binario standalone oficial em
`/opt/copilot-cli/1.0.91/copilot`, com link em `/usr/local/bin/copilot`. O
arquivo `copilot-linux-x64.tar.gz` e validado pelo SHA-256 publicado no release,
portanto o host nao precisa de Node.js ou npm para executar:

```bash
copilot --version
```

A autenticacao do Copilot ocorre diretamente no host por login interativo ou
pelas variaveis `COPILOT_GITHUB_TOKEN`, `GH_TOKEN` e `GITHUB_TOKEN`. O runtime
Podman nao recebe essas variaveis nem monta configuracoes do Copilot/GitHub CLI.
O socket Podman tambem nao e montado.

## Claude Code CLI

O playbook instala o Claude Code pelo repositorio APT oficial da Anthropic no
canal `stable`, validando o fingerprint da chave de assinatura antes de confiar
no repositorio. Verifique a instalacao e inicie uma sessao interativa:

```bash
claude --version
claude
```

A autenticacao ocorre interativamente no primeiro uso. O Ansible nao armazena
credenciais nem inicia sessoes. Atualizacoes sao entregues pelo APT, nao pelo
atualizador automatico do Claude Code.

## RTK

A role `host_tools` instala o pacote amd64 oficial do RTK v1.0.1 por meio do
release do GitHub, validando o SHA-256 publicado antes da instalacao. A versao
e o checksum ficam fixados nos defaults da role. O pacote e instalado no host;
a role `terminal` tambem instala os hooks globais de Claude Code e GitHub Copilot
no perfil do usuario. A configuracao usa `rtk init` oficial, preserva as
preferencias existentes e cria backup do `settings.json` do Claude quando ele e
alterado. Em check mode, somente o plano oficial `--dry-run` e consultado.

As variaveis `terminal_rtk_configure_claude` e
`terminal_rtk_configure_copilot` controlam os hooks e ficam habilitadas por
padrao; `terminal_rtk_copilot_home` permite definir outro diretorio Copilot.
O init responde nao ao prompt opcional de telemetria e nao habilita filtros
personalizados. Reinicie cada agente apos aplicar a role.

Esta e a edicao padrao, cujo engine esta sob BUSL-1.1 com grant upstream para
uso em producao; a variante `rtk-oss` e separada e nao inclui o engine.

```bash
rtk --version
rtk gain
```

Em `--check`, o download e a instalacao sao ignorados e a limitacao e informada;
nenhuma chamada mutante e feita para simular a instalacao. Para remover o pacote,
use `sudo apt remove rtk` depois de avaliar o impacto nos hooks/configuracoes
que voce tenha configurado separadamente.

## PowerShell

Configure o repositorio Microsoft compartilhado por PowerShell e .NET:

```bash
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl --fail --silent --show-error --location \
  https://packages.microsoft.com/keys/microsoft.asc \
  --output /etc/apt/keyrings/microsoft.asc
printf '%s\n' \
  'deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.asc] https://packages.microsoft.com/ubuntu/26.04/prod resolute main' |
  sudo tee /etc/apt/sources.list.d/microsoft-prod.list >/dev/null
sudo apt update
sudo apt install -y powershell
pwsh --version
pwsh -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion'
```

## Ansible e pywinrm

Instale no controller pelo `uv`, sem alterar o Python do sistema:

```bash
uv tool install --force 'ansible-core==2.19.2' --with 'pywinrm==0.5.0'
ansible-playbook --version
tool_dir="$(uv tool dir)"
"$tool_dir/ansible-core/bin/python" -c \
  'import winrm; print(winrm.__version__)'
```

Instale as collections fixadas pelo projeto:

```bash
ansible-galaxy collection install -r ansible/requirements.yml
ansible-galaxy collection list community.general
```

WinRM exige configuracao segura no servidor Windows. Nao desabilite validacao de
certificado nem armazene senha em inventario; use Ansible Vault ou provedor de
segredos aprovado.

## Azure CLI

```bash
sudo curl --fail --silent --show-error --location \
  https://packages.microsoft.com/keys/microsoft.asc \
  --output /etc/apt/keyrings/microsoft.asc
printf '%s\n' \
  'deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.asc] https://packages.microsoft.com/repos/azure-cli resolute main' |
  sudo tee /etc/apt/sources.list.d/azure-cli.list >/dev/null
sudo apt update
sudo apt install -y azure-cli
az version
```

`az version` nao autentica nem modifica recursos. Execute login apenas quando
necessario e nunca registre tokens em logs.

## Terraform

```bash
sudo curl --fail --silent --show-error --location \
  https://apt.releases.hashicorp.com/gpg \
  --output /etc/apt/keyrings/hashicorp.asc
printf '%s\n' \
  'deb [arch=amd64 signed-by=/etc/apt/keyrings/hashicorp.asc] https://apt.releases.hashicorp.com resolute main' |
  sudo tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
sudo apt update
sudo apt install -y terraform
terraform version
```

## kubectl

O canal abaixo fixa a serie menor `v1.34`. Altere conscientemente quando a
politica do cluster exigir outra versao suportada.

```bash
KUBERNETES_MINOR=v1.34
sudo curl --fail --silent --show-error --location \
  "https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR}/deb/Release.key" \
  --output /etc/apt/keyrings/kubernetes.asc
printf '%s\n' \
  "deb [signed-by=/etc/apt/keyrings/kubernetes.asc] https://pkgs.k8s.io/core:/stable:/${KUBERNETES_MINOR}/deb/ /" |
  sudo tee /etc/apt/sources.list.d/kubernetes.list >/dev/null
sudo apt update
sudo apt install -y kubectl
kubectl version --client
```

O teste nao acessa cluster nem modifica `~/.kube/config`.

## GitHub CLI

```bash
sudo curl --fail --silent --show-error --location \
  https://cli.github.com/packages/githubcli-archive-keyring.gpg \
  --output /etc/apt/keyrings/githubcli.gpg
printf '%s\n' \
  'deb [arch=amd64 signed-by=/etc/apt/keyrings/githubcli.gpg] https://cli.github.com/packages stable main' |
  sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
sudo apt update
sudo apt install -y gh
gh --version
```

## 1Password

Instale o Desktop pelo repositorio oficial; a CLI e fornecida pelo container:

```bash
sudo curl --fail --silent --show-error --location \
  https://downloads.1password.com/linux/keys/1password.asc \
  --output /etc/apt/keyrings/1password.asc
printf '%s\n' \
  'deb [arch=amd64 signed-by=/etc/apt/keyrings/1password.asc] https://downloads.1password.com/linux/debian/amd64 stable main' |
  sudo tee /etc/apt/sources.list.d/1password.list >/dev/null
sudo apt update
sudo apt install -y 1password
1password --version
op --version
```

O Ansible instala `~/.local/bin/op` e a funcao shell `op`. A configuracao fica
isolada em `~/.local/share/ubuntu-desktop/onepassword-home`, com permissoes
privadas. Somente `OP_SERVICE_ACCOUNT_TOKEN`, `OP_CONNECT_HOST`, `OP_CONNECT_TOKEN`
e `OP_SESSION_*` sao encaminhadas por nome, sem valores nos argumentos. Isso nao
habilita integracao biometrica com o Desktop do host. A CLI nativa ja instalada
nao e removida automaticamente.

```bash
op --help
op --dry-run item list
op -- --help
```

O wrapper aceita `-help`, `-h`, `-dryrun`, `--verbose` e `--` para encaminhamento
direto. Ajuda e simulacao nao precisam de Podman, rede ou token, nao criam
arquivos e nao fazem consultas. A CLI retorna seu status; uso invalido retorna
2 e Podman ausente retorna 127. Dados ficam no stdout; auditoria no stderr e
em `onepassword-home/artifacts/logs/`. Nao use `op signin` em automacao com logs.

Para incorporar exports literais de um documento `.env` ao profile Linux,
gravado com modo `0600`, use a secao
[Ambiente Linux pelo 1Password](automacao-ansible.md#ambiente-linux-pelo-1password).

## uv

Instale o binario oficial fixado sem executar script remoto:

```bash
UV_VERSION=0.8.22
mkdir -p "$HOME/.local/bin" "$HOME/.cache/ubuntu-desktop"
curl --fail --silent --show-error --location \
  "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-x86_64-unknown-linux-gnu.tar.gz" \
  --output "$HOME/.cache/ubuntu-desktop/uv.tar.gz"
tar -xzf "$HOME/.cache/ubuntu-desktop/uv.tar.gz" \
  -C "$HOME/.cache/ubuntu-desktop"
install -m 0755 "$HOME/.cache/ubuntu-desktop/uv-x86_64-unknown-linux-gnu/uv" \
  "$HOME/.local/bin/uv"
install -m 0755 "$HOME/.cache/ubuntu-desktop/uv-x86_64-unknown-linux-gnu/uvx" \
  "$HOME/.local/bin/uvx"
export PATH="$HOME/.local/bin:$PATH"
uv --version
uvx --version
```

## Oh My Posh

```bash
OH_MY_POSH_VERSION=26.23.4
sudo curl --fail --silent --show-error --location \
  "https://github.com/JanDeDobbeleer/oh-my-posh/releases/download/v${OH_MY_POSH_VERSION}/posh-linux-amd64" \
  --output /usr/local/bin/oh-my-posh
sudo chmod 0755 /usr/local/bin/oh-my-posh
oh-my-posh version
```

Para iniciar no ZSH:

```bash
eval "$(oh-my-posh init zsh --config \
  "$HOME/.config/oh-my-posh/atomic.omp.json")"
zsh -lc 'oh-my-posh version'
```

A automacao Ansible instala o tema a partir de
`ansible/roles/terminal/files/atomic.omp.json` e usa bloco gerenciado no
`.zshrc`; nao acrescente uma segunda inicializacao manual.

O JSON e baseado na referencia `ubuntu-desktop-cat`, com deteccao de Azure CLI,
Ansible e Terraform adaptada para depender somente dos arquivos da pasta.
`azure.yaml`, pipelines Azure ou arquivos Bicep ativam Azure CLI; `ansible.cfg`,
playbooks ou arquivos `*.ansible.yml` ativam Ansible; arquivos Terraform ou
Terragrunt ativam Terraform. A pasta `.azure` sozinha nao ativa indicador,
pois `~/.azure` tambem guarda configuracao global da CLI.

Os rotulos indicam contexto de projeto, nao apps abertos ou instalados.
`POSH_HAS_AZ`, `POSH_HAS_ANSIBLE` e `POSH_HAS_TERRAFORM` nao sao mais geradas
pelo runtime nem consultadas pelo tema; valores herdados nao ativam rotulos.
Os testes de renderizacao em `tests/bash/development-shell.bats` requerem
Oh My Posh e jq, e usam pastas/cache descartaveis sem executar containers.

O `.profile` e carregado antes do prompt.
`DOTNET_ROOT` e `SSL_CERT_DIR` predefinidos sao preservados; o PATH recebe apenas
entradas ausentes. O unico tema distribuido e `atomic.omp.json`, definido por
`terminal_oh_my_posh_config_file`.

## Oh My Zsh

```bash
git clone https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
test -f "$HOME/.oh-my-zsh/oh-my-zsh.sh"
```

Configure `ZSH="$HOME/.oh-my-zsh"` e carregue `oh-my-zsh.sh` no `.zshrc`. Faça
backup antes de substituir uma configuracao existente.

## MesloLGM Nerd Font

```bash
NERD_FONTS_VERSION=3.4.0
FONT_DIR="$HOME/.local/share/fonts/MesloLGM-Nerd-Font-${NERD_FONTS_VERSION}"
mkdir -p "$FONT_DIR" "$HOME/.cache/ubuntu-desktop"
curl --fail --silent --show-error --location \
  "https://github.com/ryanoasis/nerd-fonts/releases/download/v${NERD_FONTS_VERSION}/Meslo.zip" \
  --output "$HOME/.cache/ubuntu-desktop/Meslo.zip"
unzip -o "$HOME/.cache/ubuntu-desktop/Meslo.zip" -d "$FONT_DIR"
fc-cache -f "$HOME/.local/share/fonts"
fc-list : family | grep -F 'MesloLGM Nerd Font'
```

A role Ansible configura o perfil padrao do Tilix como `MesloLGM Nerd Font Mono
12`. Feche e abra uma nova sessao do Tilix para carregar a fonte; perfis
adicionais continuam independentes.

## .NET 8 e .NET 10

No Ubuntu Desktop 26.04 LTS amd64, a automacao instala os SDKs 8.0.425 e
10.0.402 no home do usuario, lado a lado em `~/.dotnet`, a partir de arquivos
oficiais Microsoft verificados por SHA-512. Nao instale SDKs pelo APT para
este fluxo. Aplique as roles `host_tools` e `terminal` conforme o
[procedimento operacional](automacao-ansible.md#sdks-net-por-usuario-e-globaljson)
e abra uma nova sessao antes de validar:

```bash
export DOTNET_ROOT="$HOME/.dotnet"
export PATH="$DOTNET_ROOT:$DOTNET_ROOT/tools:$PATH"
command -v dotnet
dotnet --list-sdks
dotnet --info
dotnet dev-certs https --trust
dotnet dev-certs https --check --trust
```

Use sempre `dotnet` para ambas as versoes e mantenha `global.json` na raiz de
cada repositorio com a versao completa do SDK. `rollForward: disable` exige a
versao exata ja instalada; `global.json` nao baixa SDKs. Confira a selecao com
`dotnet --version` dentro do projeto. Instalacoes antigas do sistema nao sao
removidas automaticamente. O .NET 8 encerra suporte em 10/11/2026. A confianca do certificado
e configurada para o usuario, nunca para `root`. A automacao tambem persiste em
Bash e ZSH:

```bash
export SSL_CERT_DIR="$HOME/.aspnet/dev-certs/trust:/usr/lib/ssl/certs"
```

Nao execute `dotnet dev-certs https --clean` como parte da instalacao; essa
operacao remove certificados existentes e fica reservada para recuperacao manual.

## Visual Studio Code

O PowerShell e instalado pela automacao a partir do release oficial Linux x64,
com versao e SHA-256 fixados, pois o repositorio Microsoft APT configurado para
Ubuntu 26.04 nao publica o pacote `powershell`. O executavel fica em
`/opt/powershell/<versao>` e e acessivel como `pwsh`.

O VS Code e instalado no host para acessar diretamente SDKs, Podman, SSH,
credenciais e arquivos locais:

```bash
sudo curl --fail --silent --show-error --location \
  https://packages.microsoft.com/keys/microsoft.asc \
  --output /etc/apt/keyrings/microsoft.asc
printf '%s\n' \
  'deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.asc] https://packages.microsoft.com/repos/code stable main' |
  sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
sudo apt update
sudo apt install -y code
code --version
```

O pacote Flatpak `com.visualstudio.code` nao e usado por padrao porque seu sandbox
limita integracao com as ferramentas do host.

O pacote `code` recebe atualizacoes pelo APT, mas o playbook nao ativa
atualizacao automatica. Para atualizar manualmente, execute `sudo apt update`
e `sudo apt install --only-upgrade code`. Atualizacao automatica pode ser
configurada com `unattended-upgrades`, permitindo explicitamente apenas a
origem/label do repositorio VS Code verificada por `apt-cache policy code` e
seus metadados `InRelease`. Nao suponha que a regra padrao de seguranca inclua
repositorios de terceiros nem permita toda a origem Microsoft de producao:
isso poderia atualizar outros pacotes dessa origem. Essa configuracao e
separada e nao e aplicada pela automacao atual.

## Validacao consolidada

Execute sem expor tokens ou dados de inventario:

```bash
flatpak info com.usebruno.Bruno && flatpak info com.microsoft.Edge
flatpak info org.remmina.Remmina
git --version && ssh -V && zsh --version && tmux -V && tilix --version
podman info --format '{{.Host.Security.Rootless}}' &&
  podman --version && podman compose version
pwsh --version && ansible-playbook --version && az version
terraform version && kubectl version --client && gh --version
op --version && uv --version && oh-my-posh version
dotnet --list-sdks && code --version
dotnet dev-certs https --check --trust
node --version && npm --version && npx --version && copilot --version
claude --version
```

Valide aplicativos graficos abrindo-os em uma sessao GNOME. Camera, audio,
captura, biometria, RDP e SSH exigem testes funcionais no hardware e ambiente
reais, fora de container.

## Riscos e recuperacao

- Remova um Flatpak com `sudo flatpak uninstall ID`; dados do usuario exigem
  revisao separada antes de usar `--delete-data`.
- Remova pacotes APT com `sudo apt remove PACOTE`; nao use `purge` sem revisar
  configuracoes que serao apagadas.
- Para reverter um repositorio, remova somente seu arquivo em
  `/etc/apt/sources.list.d/` e sua chave dedicada, depois execute `sudo apt update`.
- A role instala Podman, mas nao remove pacotes ou dados Docker existentes.
  Revise containers, imagens e volumes antes de migrar ou remover Docker.
- Restaure `.zshrc` de backup se a inicializacao do shell falhar; `zsh -f` inicia
  sem carregar a configuracao do usuario.
- Nao ha rollback automatico de dados de aplicativos, credenciais ou plugins.
