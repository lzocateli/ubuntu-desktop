# Aplicativos cobertos pelo Ansible

## Sumario

- [Aplicativos cobertos pelo Ansible](#aplicativos-cobertos-pelo-ansible)
  - [Sumario](#sumario)
  - [Escopo](#escopo)
  - [Cliente Nextcloud Desktop](#cliente-nextcloud-desktop)
  - [Aplicativos Flatpak](#aplicativos-flatpak)
    - [Leitura em voz alta no Edge](#leitura-em-voz-alta-no-edge)
  - [Ferramentas do host](#ferramentas-do-host)
    - [OBS Studio](#obs-studio)
    - [Atualizacoes do Visual Studio Code](#atualizacoes-do-visual-studio-code)
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

Por padrao, a mesma role instala `libreoffice-writer`, `libreoffice-calc`,
`libreoffice-gtk3` e `libreoffice-l10n-pt-br` via APT para editar DOCX e XLSX
localmente, com integracao GNOME e interface em portugues. Desabilite com
`nextcloud_client_install_libreoffice: false` (nao remove instalacoes existentes).
Writer e Calc editam os arquivos; Nextcloud Desktop sincroniza as alteracoes.
Isso nao configura edicao colaborativa no navegador nem servicos Office no
servidor. Confira formatos complexos e macros antes de sobrescrever originais.

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
| Microsoft Edge | `com.microsoft.Edge` | Instalacao de sistema pelo Flathub; padrao para HTML e links HTTP/HTTPS; permissao do socket de fala local, sem garantia de leitura nativa | Instalado |
| Firefox | `org.mozilla.firefox` | Instalacao de sistema pelo Flathub | Opcional |
| Remmina | `org.remmina.Remmina` | Instalacao de sistema pelo Flathub | Instalado |
| Flatseal | `com.github.tchx84.Flatseal` | Instalacao de sistema pelo Flathub | Instalado |
| Extension Manager | `com.mattjakeman.ExtensionManager` | Instalacao de sistema pelo Flathub | Instalado |
| WhatsApp (ZapZap) | `com.rtosta.zapzap` | Cliente nao oficial do WhatsApp Web pelo Flathub | Instalado |
| Telegram Desktop | `org.telegram.desktop` | Instalacao de sistema pelo Flathub | Instalado |

Firefox e habilitado com `flatpak_apps_install_firefox: true`. Login, RDP e
extensoes GNOME exigem validacao manual na sessao grafica.

### Leitura em voz alta no Edge

**Limite de suporte:** instalar o Speech Dispatcher e liberar seu socket nao
habilita o botao **Ler em voz alta** do Edge nem do leitor imersivo. A
[documentacao oficial da politica ReadAloudEnabled](https://learn.microsoft.com/en-us/deployedge/microsoft-edge-browser-policies/readaloudenabled)
lista Windows, macOS, Android e iOS, mas nao Linux. Nao ha garantia documentada
de que essa politica habilite o recurso no Ubuntu. Trocar Flatpak por DEB ou
adicionar flags experimentais nao e uma correcao comprovada para esse botao.

A role `host_tools` instala `speech-dispatcher` e
`speech-dispatcher-espeak-ng`; o socket de usuario e ativado sob demanda pelo
systemd da sessao. A role `flatpak_apps` concede ao Edge somente o caminho
`xdg-run/speech-dispatcher` do usuario, necessario para o aplicativo Flatpak
acessar esse sintetizador. Nenhum acesso geral ao barramento D-Bus e concedido.

A configuracao e individual do usuario e pode ser conferida com:

```bash
systemctl --user status speech-dispatcher.socket
spd-say --language=pt-BR --wait 'Teste de leitura em voz alta.'
flatpak override --user --show com.microsoft.Edge
```

O teste com `spd-say` reproduz audio na sessao grafica e deve ser executado
manualmente pelo usuario. Ele valida a fala do host, nao a disponibilidade de
vozes no navegador ou do botao no leitor imersivo. A automacao valida somente
a permissao do socket; nao realiza um teste de audio nem configura flags de
sintese de voz do Chromium.

Para ler paginas no Edge Linux, uma alternativa e uma extensao como
[Read Aloud: A Text to Speech Voice Reader](https://chromewebstore.google.com/detail/read-aloud-a-text-to-speec/hdhinadidafjejdhmfkjgnolgimiaplp).
Essa alternativa nao foi validada por esta automacao e nao adiciona o botao
nativo ao leitor imersivo. Antes de instalar, revise publicador, permissoes de
acesso ao conteudo e politica de privacidade. Vozes em nuvem podem enviar o
texto a terceiros; disponibilidade, autenticacao e custos dependem do provedor.
Use a extensao na pagina original, nao presuma acesso ao endereco interno
`read://`. Nenhuma extensao e instalada, forcada ou autorizada pela role.

A tag `edge_speech` mantem compatibilidade e apenas configura essa permissao
local. Em `--check --diff`, consulta as permissoes e informa mudancas pendentes
sem executar `flatpak override --filesystem`. Reinicie o Edge manualmente
apos uma alteracao de permissao; isso nao garante a aparicao do recurso nativo.

WhatsApp e acessado pelo ZapZap, nao por um aplicativo oficial da Meta para Linux.
Abra `flatpak run com.rtosta.zapzap` na sessao grafica e vincule o dispositivo
pelo celular. Para Telegram, abra `flatpak run org.telegram.desktop` e autentique
sua conta. A automacao nao gerencia credenciais nem mensagens.

Spotify e KeePassXC foram excluidos do escopo. A automacao garante que seus
Flatpaks estejam ausentes, inclusive em maquinas configuradas por uma versao
anterior do projeto; dados de usuario nao sao apagados automaticamente.

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
| GNOME Sushi | Pacote `gnome-sushi` via APT | Previa do arquivo selecionado no Arquivos ao pressionar Espaco |
| Google Chrome | Repositorio Google assinado para APT | `google-chrome --version` |
| WireGuard VPN | Metapacote `wireguard` do Ubuntu e NetworkManager (`network-manager`, `network-manager-gnome`) | Pacotes via `dpkg-query` e CLI com `wg --version` |
| Speech Dispatcher | `speech-dispatcher` e `speech-dispatcher-espeak-ng` | Pacotes via `dpkg-query`; socket de usuario ativado sob demanda |
| OBS Studio | `obs-studio` pelo APT do Ubuntu | Instalacao do pacote; perfis e cenas configurados pelo usuario |
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
| 1Password CLI | Funcao e wrapper `~/.local/bin/op` usam imagem DevOps publica via Podman; sem pacote CLI nativo | `op --version` |
| Visual Studio Code | Pacote `code` pelo repositorio Microsoft no host | `code --version`; atualizacao pelo APT |
| .NET SDK 8 | Arquivo oficial Microsoft fixado por versao e SHA-512 em `~/.dotnet` | `~/.dotnet/dotnet --list-sdks` |
| .NET SDK 10 | Arquivo oficial Microsoft fixado por versao e SHA-512 no mesmo `~/.dotnet` | `dotnet --version` no projeto com `global.json` |
| Certificado HTTPS .NET | `openssl`, `libnss3-tools` e trust por usuario | `dotnet dev-certs https --check --trust` |

### OBS Studio

A role `host_tools` instala `obs-studio` pelo APT do Ubuntu. O Ansible nao grava
um perfil inicial: o assistente nativo do OBS precisa da sessao grafica e escolhe
FPS e encoder a partir do hardware, da rede e do uso informado (streaming ou
gravacao). Apos instalar, abra **Ferramentas > Assistente de configuracao
automatica** e aplique o resultado. Em **Configuracoes > Audio**, confira a taxa
de 48 kHz, o modo stereo e selecione os dispositivos conectados para audio do
desktop e microfone. Os dispositivos e nomes variam por host; o padrao do OBS e
usar os dispositivos de audio default do sistema. Nao coloque credenciais de
transmissao no Ansible.

`/mnt/kingston/Nextcloud/OBS` e uma biblioteca de midia sincronizada, nao uma
pasta de configuracao do OBS: a estrutura atual contem `videos`, `musicas`,
`efeitos` e `Animated-Lower-Thirds`, sem perfis ou colecoes de cenas. Mantenha
esses arquivos no Nextcloud e adicione-os como fontes nas cenas do OBS usando
os caminhos nesse diretorio. Nao copie essa arvore para o repositorio Ansible.

Trazer perfis/cenas para o Ansible so faria sentido depois de separar e revisar
arquivos portaveis. Perfis podem conter chaves de stream em `service.json`, e
cenas podem guardar caminhos absolutos, nomes de dispositivos e configuracoes
especificas do host. Se futuramente forem versionados, remova secrets, use
caminhos deliberadamente portaveis e mantenha os assets grandes no Nextcloud.

Para instalar somente o OBS na estacao `vision`, simule e depois aplique a tag
dedicada:

```bash
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/vision/hosts.yml \
  --limit vision --tags obs_studio --dry-run
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/vision/hosts.yml \
  --limit vision --tags obs_studio
```

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

No Ubuntu 26.04, a role instala os SDKs 8.0.425 e 10.0.402 dos arquivos oficiais
Linux x64 com SHA-512 verificado, lado a lado em `~/.dotnet`, pertencente ao
usuario do desktop. Nao instala SDK pelo APT nem cria um comando `dotnet8`.
A role `terminal` prioriza `~/.dotnet` no PATH e define `DOTNET_ROOT`.
Selecione a versao de cada projeto com `global.json`; veja o
[procedimento operacional](automacao-ansible.md#sdks-net-por-usuario-e-globaljson).
Atualize versao e hash juntos nos defaults ou na lista `host_tools_dotnet_sdks`.
Instalacoes antigas do sistema nao sao removidas automaticamente. O .NET 8
encerra suporte em 10/11/2026; mantenha-o somente enquanto houver projetos que
precisem dele.

### Atualizacoes do Visual Studio Code

O pacote `code` vem do repositorio APT oficial da Microsoft configurado pela
role `host_tools`. As atualizacoes publicadas nesse repositorio chegam pelo
APT; o playbook instala o pacote e configura a origem, mas **nao habilita por
si so atualizacao automatica**. Atualize manualmente com:

```bash
sudo apt update
sudo apt install --only-upgrade code
```

O Atualizador de Programas do Ubuntu tambem pode oferecer atualizacoes desse
repositorio junto das demais atualizacoes APT. Para atualizacao automatica sem
interacao, configure `unattended-upgrades` e inclua explicitamente a origem do
repositorio do VS Code, usando os campos `Origin`/`Label` realmente publicados
no `InRelease` e exibidos por `apt-cache policy code`. Nao presuma que a regra
padrao de atualizacoes de seguranca inclua repositorios de terceiros e nao
habilite todo o repositorio Microsoft de producao apenas para atualizar o VS
Code; isso pode autorizar atualizacao automatica de outros pacotes Microsoft.

A configuracao de `unattended-upgrades`, a origem APT permitida e a politica de
reinicializacao sao deliberadamente separadas da instalacao atual do VS Code.
Antes de ativa-las, revise quais pacotes serao autorizados e teste a simulacao
do `unattended-upgrades` para confirmar que apenas as origens desejadas estao
incluidas.

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
| Oh My Posh | Binario em `/usr/local/bin` e tema customizado da referencia em `~/.config/oh-my-posh/atomic.omp.json` | `oh-my-posh version`; inicializacao ZSH valida |
| Oh My Zsh | Clone fixado por variavel e plugin Git; historico persistente compartilhado com 50.000 linhas | Arquivo principal e opcoes de historico validados; `~/.zsh_history` modo `0600` |
| Git do usuario | Role independente `git_config`: template, backup, identidade preservada e helper Azure DevOps opt-in | Valores essenciais via `git config --file`; testes isolados de PAT e idempotencia |
| MesloLGM Nerd Font | Fonte no perfil do usuario e atualização do cache | Familia presente em `fc-list` |
| Ambiente 1Password | Ansible baixa o `.env` e grava exports em `~/.profile` | Sintaxe do profile e testes com stub |
| Chaves SSH | `op` em container no alvo le o vault e a role grava config e chaves com permissoes restritas | `ssh -G` valida host, usuario, identidade e porta |
| Fontes NuGet | `~/.nuget/NuGet/NuGet.Config` define nuget.org e nugettest depois da instalacao do .NET | `dotnet nuget list source` |
| Node, npm, npx e ng | Funcoes na imagem publica `docker.io/lzocateli/devops:cpu-v1`; Angular persistente via npm publico | Funcoes carregadas em Bash e ZSH |
| SQLCMD | go-sqlcmd v1.10.0 na imagem publica; funcao Bash/ZSH executa via Podman e encaminha variaveis `SQLCMD*` sem valores nos argumentos | A role executa `sqlcmd --version` dentro da imagem |
| lh e lhr | eza com cores automaticas e busca recursiva por padroes | Testes isolados em Bash e ZSH |
| Copilot CLI | Binario Linux x64 oficial fixado e verificado por SHA-256 | `copilot --version` no host |

O ambiente 1Password e opt-in e exige `terminal_onepassword_env_enabled: true`,
vault e documento. Consulte o [guia operacional](automacao-ansible.md#ambiente-linux-pelo-1password).
As chaves SSH usam `op` preparado no alvo e `OP_SERVICE_ACCOUNT_TOKEN` fornecido
pelo ambiente do controller; veja
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
