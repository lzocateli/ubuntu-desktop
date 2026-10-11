# Aplicativos cobertos pelo Ansible

## Sumario

- [Escopo](#escopo)
- [Aplicativos Flatpak](#aplicativos-flatpak)
- [Ferramentas do host](#ferramentas-do-host)
- [Terminal e shell](#terminal-e-shell)
- [Dependencias do controller](#dependencias-do-controller)
- [Limites da validacao](#limites-da-validacao)

## Escopo

Esta e a relacao canonica das ferramentas instaladas, configuradas e validadas
pela automacao. O alvo suportado e Ubuntu Desktop 24.04 LTS amd64. Todas as
validacoes pos-instalacao rodam no modo real; em check mode, o Ansible apresenta
o plano sem exigir que binarios ainda nao instalados existam.

O usuario da estacao e `zocatel`, com home `/home/zocatel` e acesso pelo grupo
`sudo`. Pacotes, repositorios, Flatpaks de sistema e servicos exigem elevacao;
configuracoes pessoais, shell, fontes e `~/.profile` pertencem a `zocatel`.

## Aplicativos Flatpak

Todos usam o remote `flathub` em escopo de sistema. A automacao valida o binario
Flatpak, o remote e cada aplicativo com `flatpak info`.

| Aplicativo | ID | Configuracao minima | Estado padrao |
| --- | --- | --- | --- |
| Bruno | `com.usebruno.Bruno` | Instalacao de sistema pelo Flathub | Instalado |
| Microsoft Edge | `com.microsoft.Edge` | Instalacao de sistema pelo Flathub | Instalado |
| Firefox | `org.mozilla.firefox` | Instalacao de sistema pelo Flathub | Opcional |
| Remmina | `org.remmina.Remmina` | Instalacao de sistema pelo Flathub | Instalado |
| Flatseal | `com.github.tchx84.Flatseal` | Instalacao de sistema pelo Flathub | Instalado |
| Extension Manager | `com.mattjakeman.ExtensionManager` | Instalacao de sistema pelo Flathub | Instalado |

Firefox e habilitado com `flatpak_apps_install_firefox: true`. Login, RDP e
extensoes GNOME exigem validacao manual na sessao grafica.

OBS Studio, Spotify e KeePassXC foram excluidos do escopo. A automacao garante
que seus Flatpaks estejam ausentes, inclusive em maquinas configuradas por uma
versao anterior do projeto; dados de usuario nao sao apagados automaticamente.

## Ferramentas do host

Pacotes APT sao conferidos com `dpkg-query`; CLIs possuem validacao de versao ou
estado. Repositorios externos usam HTTPS, Deb822, keyrings e `signed-by`.

| Ferramenta | Instalacao/configuracao minima | Validacao Ansible |
| --- | --- | --- |
| Git | Pacote Ubuntu e `~/.gitconfig` Linux gerenciado para `zocatel` | Versao, sintaxe, identidade, LF e branch inicial |
| OpenSSH Client | Pacote Ubuntu | `ssh -V` |
| ZSH | Pacote Ubuntu e shell padrao opcional | `zsh --version` |
| TMUX | Pacote Ubuntu | `tmux -V` |
| Tilix | Pacote Ubuntu | `tilix --version` |
| Docker Engine | Repositorio oficial; daemon iniciado e habilitado | Versao, Compose, `is-active`, `is-enabled` |
| Docker Buildx | Plugin oficial | `docker buildx version` |
| Docker Compose | Plugin oficial | `docker compose version` |
| PowerShell | Repositorio Microsoft | `pwsh --version` |
| Azure CLI | Repositorio Microsoft | `az version` |
| Terraform | Repositorio HashiCorp | `terraform version` |
| kubectl | Repositorio Kubernetes `v1.34` por padrao | `kubectl version --client` |
| GitHub CLI | Repositorio oficial | `gh --version` |
| 1Password Desktop | Repositorio oficial | `1password --version` |
| 1Password CLI | Repositorio oficial | `op --version` |
| Visual Studio Code | Repositorio Microsoft no host | `code --version` |
| .NET SDK 8 | Repositorio Microsoft | Presenca da major 8 em `dotnet --list-sdks` |
| .NET SDK 10 | Repositorio Microsoft | Presenca da major 10 em `dotnet --list-sdks` |
| Certificado HTTPS .NET | `openssl`, `libnss3-tools` e trust por usuario | `dotnet dev-certs https --check --trust` |

O acesso sem `sudo` ao Docker e opcional. Quando
`host_tools_add_user_to_docker_group: true`, a automacao adiciona e valida o
usuario no grupo `docker`; uma nova sessao e necessaria para renovar os grupos.

## Terminal e shell

| Ferramenta | Instalacao/configuracao minima | Validacao Ansible |
| --- | --- | --- |
| uv | Versao fixa em `/opt/uv`, links em `/usr/local/bin` | `uv --version` |
| uvx | Instalado junto com uv | `uvx --version` |
| Oh My Posh | Binario em `/usr/local/bin` e inicializacao no ZSH | `oh-my-posh version` |
| Oh My Zsh | Clone fixado por variavel e plugin Git | Arquivo principal presente |
| Git do usuario | VS Code, fluxo de branches, diff/merge, rebase e `rerere` | Valores essenciais via `git config --file` |
| MesloLGM Nerd Font | Fonte no perfil do usuario e atualização do cache | Familia presente em `fc-list` |
| Ambiente 1Password | Ansible baixa o `.env` e grava exports em `~/.profile` | Sintaxe do profile e testes com stub |
| Node, npm e npx | Funcoes que executam na imagem `lzocateli/devops:cpu-ubuntu24.04` | Funcoes carregadas em Bash e ZSH |
| Copilot CLI | Binario Linux x64 oficial fixado e verificado por SHA-256 | `copilot --version` no host |

O ambiente 1Password e opt-in e exige `terminal_onepassword_env_enabled: true`,
vault e documento. Consulte o [guia operacional](automacao-ansible.md#ambiente-linux-pelo-1password).
Node e npm nao sao instalados no host. Seus wrappers usam um home isolado e nao
montam o socket Docker. O Copilot CLI e instalado localmente sem depender de
Node/npm; autenticacao e configuracao permanecem no perfil normal do usuario.

## Dependencias do controller

Estas ferramentas executam no controller Linux/WSL e nao sao aplicativos do
desktop alvo. O [bootstrap](../scripts/bash/bootstrap-ansible.sh) instala e
valida `uv`, `ansible-core` 2.19.2, `pywinrm` 0.5.0 e a collection
`community.general` 11.3.0.

## Limites da validacao

- Comandos e metadados comprovam instalacao, nao login em servicos externos.
- Aplicativos graficos precisam ser abertos em uma sessao GNOME real.
- Remmina e Docker precisam de testes funcionais conforme hardware e rede.
- O Ansible precisa acessar o documento como o usuario durante a aplicacao real.
- Check mode remoto, primeira aplicacao e segunda aplicacao com `changed=0`
  permanecem obrigatorios em VM descartavel autorizada.
