# Aplicativos cobertos pelo Ansible

## Sumario

- [Escopo](#escopo)
- [Cliente Nextcloud Desktop](#cliente-nextcloud-desktop)
- [Aplicativos Flatpak](#aplicativos-flatpak)
- [Ferramentas do host](#ferramentas-do-host)
- [Terminal e shell](#terminal-e-shell)
- [Dependencias do controller](#dependencias-do-controller)
- [Limites da validacao](#limites-da-validacao)

## Escopo

Esta e a relacao canonica das ferramentas instaladas, configuradas e validadas
pela automacao. O alvo suportado e Ubuntu Desktop 26.04 LTS amd64. Todas as
validacoes pos-instalacao rodam no modo real; em check mode, o Ansible apresenta
o plano sem exigir que binarios ainda nao instalados existam.

O usuario da estacao e `lzocateli`, com home `/home/lzocateli` e acesso pelo grupo
`sudo`. Pacotes, repositorios, Flatpaks de sistema e servicos exigem elevacao;
configuracoes pessoais, shell, fontes e `~/.profile` pertencem a `lzocateli`.

## Cliente Nextcloud Desktop

| Aplicativo | Pacote | Servidor | Pasta local | Estado padrao |
| --- | --- | --- | --- | --- |
| Nextcloud Desktop | `nextcloud-desktop` (APT) | `https://meudrive.lzoca/` | `/mnt/kingston/Nextcloud` | Instalado |

A role exige que `/mnt/kingston` ja seja um ponto de montagem e cria a pasta de
sincronizacao com proprietario `lzocateli`, grupo primario do usuario e modo
`0750`. Ela nao formata, monta nem altera `/etc/fstab`, e falha se a pasta
configurada for um link simbolico ou um arquivo. O cliente inicia sem conta
autenticada: abra **Nextcloud Desktop**, informe o servidor acima e conclua o
login no assistente. Selecione `/mnt/kingston/Nextcloud` como pasta local; nao
grave senha de app ou token no inventario.

## Aplicativos Flatpak

Todos usam o remote `flathub` em escopo de sistema. A automacao valida o binario
Flatpak, o remote e cada aplicativo com `flatpak info`.

| Aplicativo | ID | Configuracao minima | Estado padrao |
| --- | --- | --- | --- |
| Bruno | `com.usebruno.Bruno` | Instalacao de sistema pelo Flathub | Instalado |
| Microsoft Edge | `com.microsoft.Edge` | Instalacao de sistema pelo Flathub; padrao para HTML e links HTTP/HTTPS | Instalado |
| Firefox | `org.mozilla.firefox` | Instalacao de sistema pelo Flathub | Opcional |
| Remmina | `org.remmina.Remmina` | Instalacao de sistema pelo Flathub | Instalado |
| Flatseal | `com.github.tchx84.Flatseal` | Instalacao de sistema pelo Flathub | Instalado |
| Extension Manager | `com.mattjakeman.ExtensionManager` | Instalacao de sistema pelo Flathub | Instalado |
| WhatsApp (ZapZap) | `com.rtosta.zapzap` | Cliente nao oficial do WhatsApp Web pelo Flathub | Instalado |
| Telegram Desktop | `org.telegram.desktop` | Instalacao de sistema pelo Flathub | Instalado |

Firefox e habilitado com `flatpak_apps_install_firefox: true`. Login, RDP e
extensoes GNOME exigem validacao manual na sessao grafica.

WhatsApp e acessado pelo ZapZap, nao por um aplicativo oficial da Meta para Linux.
Abra `flatpak run com.rtosta.zapzap` na sessao grafica e vincule o dispositivo
pelo celular. Para Telegram, abra `flatpak run org.telegram.desktop` e autentique
sua conta. A automacao nao gerencia credenciais nem mensagens.

OBS Studio, Spotify e KeePassXC foram excluidos do escopo. A automacao garante
que seus Flatpaks estejam ausentes, inclusive em maquinas configuradas por uma
versao anterior do projeto; dados de usuario nao sao apagados automaticamente.

## Ferramentas do host

Pacotes APT sao conferidos com `dpkg-query`; CLIs possuem validacao de versao ou
estado. Repositorios externos usam HTTPS, Deb822, keyrings e `signed-by`. O Edge
Flatpak e o navegador padrao do usuario para arquivos HTML e os esquemas HTTP e
HTTPS; a preferencia e configurada em `~/.config/mimeapps.list` e validada com
`xdg-mime`.

Os repositorios Microsoft usam keyrings separados conforme a assinatura de cada
feed: `microsoft.asc` para Azure CLI e VS Code, e `microsoft-2025.asc` para o
feed de producao do Ubuntu 26.04. O SHA-256 da chave de 2025 e fixado nos
defaults da role.

| Ferramenta | Instalacao/configuracao minima | Validacao Ansible |
| --- | --- | --- |
| Git | Pacote Ubuntu e `~/.gitconfig` Linux gerenciado para `lzocateli` | Versao, sintaxe, identidade, LF e branch inicial |
| OpenSSH Client | Pacote Ubuntu | `ssh -V` |
| ZSH | Pacote Ubuntu e shell padrao opcional | `zsh --version` |
| TMUX | Pacote Ubuntu | `tmux -V` |
| Tilix | Pacote Ubuntu | `tilix --version` |
| Google Chrome | Repositorio Google assinado para APT | `google-chrome --version` |
| WireGuard VPN | Metapacote `wireguard` do Ubuntu e NetworkManager (`network-manager`, `network-manager-gnome`) | Pacotes via `dpkg-query` e CLI com `wg --version` |
| Mullvad Desktop | Repositorio oficial Mullvad | Executavel `/opt/Mullvad VPN/mullvad-vpn` |
| Mullvad CLI | Incluida no pacote oficial `mullvad-vpn` | `mullvad --help` |
| Podman | Pacotes Ubuntu para runtime rootless; sem daemon de sistema | `podman --version`, `podman info` com `Rootless=true` |
| Podman Compose | Provider Compose executado pelo usuario | `podman compose version` |
| PowerShell | Release oficial Microsoft, fixado por versao e SHA-256 em `/opt/powershell` | `pwsh --version` |
| Azure CLI | Repositorio Microsoft | `az version` |
| Terraform | Repositorio HashiCorp | `terraform version` |
| kubectl | Repositorio Kubernetes `v1.34` por padrao | `kubectl version --client` |
| GitHub CLI | Repositorio oficial | `gh --version` |
| Claude Code CLI | Repositorio APT oficial Anthropic, canal `stable` e chave validada por fingerprint | `claude --version` |
| 1Password Desktop | Repositorio oficial | `1password --version` |
| 1Password CLI | Repositorio oficial | `op --version` |
| Visual Studio Code | Repositorio Microsoft no host | `code --version` |
| .NET SDK 8 | Arquivo oficial Microsoft fixado por versao e SHA-512 em `/opt/dotnet-sdk-8` | `dotnet8 --list-sdks` |
| .NET SDK 10 | Repositorio Ubuntu | Presenca da major 10 em `dotnet --list-sdks` |
| Certificado HTTPS .NET | `openssl`, `libnss3-tools` e trust por usuario | `dotnet dev-certs https --check --trust` |

O Podman e executado sem `sudo` e sem daemon root. A role gerencia
`~/.config/containers/containers.conf` e `storage.conf`, mantendo redes e
armazenamento de containers no home do usuario. O usuario precisa de faixas
subordinadas configuradas em `/etc/subuid` e `/etc/subgid`.

O metapacote WireGuard instala as ferramentas `wg`/`wg-quick`; o NetworkManager
oferece suporte nativo a WireGuard e a configuracao grafica fica disponivel nas
Configuracoes de Rede do GNOME. Nenhum tunel ou chave e criado pela automacao.
O pacote Mullvad fornece aplicativo grafico e `mullvad` CLI, mas a role nao
informa numero de conta, inicia sessao nem conecta a VPN. A instalacao do Chrome
e do Mullvad adiciona repositorios APT oficiais dedicados.

No Ubuntu 26.04, o APT fornece o .NET SDK 10, mas nao publica o SDK 8. A role
instala a versao 8.0.425 do arquivo oficial Linux x64 com SHA-512 verificado,
isolada em `/opt/dotnet-sdk-8` e acessivel pelo comando `dotnet8`; o comando
`dotnet` continua usando o SDK 10 do Ubuntu. Atualize a versao e o hash juntos
em `ansible/roles/host_tools/defaults/main.yml`. O .NET 8 encerra suporte em
10/11/2026; mantenha-o somente enquanto houver projetos que precisem dele.

O repositorio Microsoft APT configurado para Ubuntu 26.04 nao publica o pacote
PowerShell. A role instala o tarball oficial Linux x64 do PowerShell 7.6.6 com
SHA-256 verificado em `/opt/powershell/7.6.6` e cria `/usr/local/bin/pwsh`.
Atualize a versao e o hash juntos nos defaults da role.

Claude Code e instalado pelo repositorio APT oficial da Anthropic no canal
`stable`. Antes de habilitar o repositorio, a role valida o fingerprint da chave
de assinatura oficial. Atualizacoes do pacote chegam pelo fluxo normal do APT;
a automacao nao autentica nem inicia sessoes do Claude Code.

## Terminal e shell

| Ferramenta | Instalacao/configuracao minima | Validacao Ansible |
| --- | --- | --- |
| uv | Versao fixa em `/opt/uv`, links em `/usr/local/bin` | `uv --version` |
| uvx | Instalado junto com uv | `uvx --version` |
| Oh My Posh | Binario em `/usr/local/bin` e tema Atomic do projeto em `~/.config/oh-my-posh/atomic.omp-VISION.json` | `oh-my-posh version`; inicializacao ZSH valida |
| Oh My Zsh | Clone fixado por variavel e plugin Git; historico persistente compartilhado com 50.000 linhas | Arquivo principal e opcoes de historico validados; `~/.zsh_history` modo `0600` |
| Git do usuario | VS Code, fluxo de branches, diff/merge, rebase e `rerere` | Valores essenciais via `git config --file` |
| MesloLGM Nerd Font | Fonte no perfil do usuario e atualização do cache | Familia presente em `fc-list` |
| Ambiente 1Password | Ansible baixa o `.env` e grava exports em `~/.profile` | Sintaxe do profile e testes com stub |
| Chaves SSH | `op` no controller le os itens do vault e a role grava `~/.ssh/config` e as chaves com permissoes restritas | `ssh -G` valida host, usuario, identidade e porta |
| Fontes NuGet | `~/.nuget/NuGet/NuGet.Config` define nuget.org e nugettest depois da instalacao do .NET | `dotnet nuget list source` |
| Node, npm e npx | Funcoes que executam na imagem `docker.io/lzocateli/devops:cpu-ubuntu24.04` via Podman rootless | Funcoes carregadas em Bash e ZSH |
| Copilot CLI | Binario Linux x64 oficial fixado e verificado por SHA-256 | `copilot --version` no host |

O ambiente 1Password e opt-in e exige `terminal_onepassword_env_enabled: true`,
vault e documento. Consulte o [guia operacional](automacao-ansible.md#ambiente-linux-pelo-1password).
As chaves SSH exigem `op` e `OP_SERVICE_ACCOUNT_TOKEN` no controller; veja
[chaves SSH e NuGet](automacao-ansible.md#chaves-ssh-e-nuget) para o mapeamento
dos itens, aliases e limites do check mode.
Node e npm nao sao instalados no host. Seus wrappers usam um home isolado e nao
montam o socket Podman. O Copilot CLI e instalado localmente sem depender de
Node/npm; autenticacao e configuracao permanecem no perfil normal do usuario.

Os comandos `lh` (`ls -lha`) e `lhr` (busca recursiva de arquivos) sao definidos na integracao
compartilhada `~/.local/lib/ubuntu-desktop/development-shell.sh`, carregada por
`~/.profile`, `~/.bashrc` e `~/.zshrc`. Sem argumentos, `lh` lista a pasta atual
com arquivos ocultos e tamanhos legiveis; `lhr` lista todos os arquivos regulares
a partir da pasta atual, incluindo arquivos ocultos, sem seguir links simbolicos.
Com argumentos, `lhr` filtra pelo nome do arquivo com um ou mais padroes,
combinados por OU, e mostra os resultados com `ls -lha`. Sem correspondencias,
nao imprime resultados e retorna zero; falhas de acesso retornam erro.
No ZSH, use `lhr *.yml *.json`: o alias usa `noglob` somente nesse comando.
No Bash, use `lhr '*.yml' '*.json'` para evitar a expansao antecipada pelo shell.
Os padroes correspondem ao nome, nao ao caminho completo; `lh` continua aceitando
caminhos adicionais. Abra um novo terminal ou execute
`. "$HOME/.local/lib/ubuntu-desktop/development-shell.sh"` para carregar os aliases
na sessao atual. Eles apenas listam arquivos e nao exigem privilegios nem Podman.

## Dependencias do controller

Estas ferramentas executam no controller Linux/WSL e nao sao aplicativos do
desktop alvo. O [bootstrap](../scripts/bash/bootstrap-ansible.sh) instala e
valida `uv`, `ansible-core` 2.19.2, `pywinrm` 0.5.0 e a collection
`community.general` 11.3.0. O bootstrap compara as versoes esperadas.

## Limites da validacao

- Comandos e metadados comprovam instalacao, nao login em servicos externos.
- Aplicativos graficos precisam ser abertos em uma sessao GNOME real.
- Remmina e Podman precisam de testes funcionais conforme hardware e rede.
- Montagens persistentes de discos sao configuradas fora do Ansible, diretamente no alvo.
- O Ansible precisa acessar o documento como o usuario durante a aplicacao real.
- Check mode remoto, primeira aplicacao e segunda aplicacao com `changed=0`
  permanecem obrigatorios em VM descartavel autorizada.
