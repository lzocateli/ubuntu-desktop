# Automacao Ansible do Ubuntu Desktop

## Sumario

- [Automacao Ansible do Ubuntu Desktop](#automacao-ansible-do-ubuntu-desktop)
  - [Sumario](#sumario)
  - [Objetivo e escopo](#objetivo-e-escopo)
  - [Dependencias](#dependencias)
  - [Importacao grafica de certificados](#importacao-grafica-de-certificados)
    - [Importacao de CA por CLI](#importacao-de-ca-por-cli)
    - [Importacao pela interface grafica](#importacao-pela-interface-grafica)
    - [Onde os certificados ficam armazenados](#onde-os-certificados-ficam-armazenados)
  - [Estrutura](#estrutura)
  - [Bootstrap](#bootstrap)
  - [Inventario](#inventario)
  - [Secrets e Ansible Vault](#secrets-e-ansible-vault)
    - [Criptografar e descriptografar o Vault](#criptografar-e-descriptografar-o-vault)
  - [Configuracao Git do usuario](#configuracao-git-do-usuario)
  - [Ferramentas de desenvolvimento](#ferramentas-de-desenvolvimento)
  - [SDKs .NET por usuario e global.json](#sdks-net-por-usuario-e-globaljson)
  - [Montagem persistente de disco](#montagem-persistente-de-disco)
  - [Cliente Nextcloud](#cliente-nextcloud)
  - [Chaves SSH e NuGet](#chaves-ssh-e-nuget)
  - [Ambiente Linux pelo 1Password](#ambiente-linux-pelo-1password)
    - [Preparar o 1Password](#preparar-o-1password)
    - [Habilitar no inventario](#habilitar-no-inventario)
  - [ZSH, historico e tema Oh My Posh](#zsh-historico-e-tema-oh-my-posh)
  - [Fonte Meslo no terminal integrado do VS Code](#fonte-meslo-no-terminal-integrado-do-vs-code)
  - [Parametros e variaveis](#parametros-e-variaveis)
  - [Uso rapido](#uso-rapido)
  - [Simulacao](#simulacao)
  - [Remocao do Snap](#remocao-do-snap)
  - [Tags](#tags)
  - [Logs e saidas](#logs-e-saidas)
  - [Seguranca e impacto](#seguranca-e-impacto)
  - [Validacao](#validacao)
  - [Troubleshooting](#troubleshooting)
    - [Controller Windows nativo](#controller-windows-nativo)
    - [Chave ou repositorio APT rejeitado](#chave-ou-repositorio-apt-rejeitado)
    - [Aplicativo Flatpak nao abre](#aplicativo-flatpak-nao-abre)
    - [ZSH falha ao iniciar](#zsh-falha-ao-iniciar)
    - [Git rejeita pull divergente](#git-rejeita-pull-divergente)
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

A role `base` instala os validadores pelos repositorios Ubuntu: Bats,
ShellCheck, shfmt, ansible-lint e yamllint. Eles ficam disponiveis no PATH do
sistema, e a role verifica seus comandos `--version`. Para instalar ou simular,
use o wrapper com inventario explicito, `--limit` e `--tags base`; acrescente
`--dry-run` para simular sem instalar dependencias. As versoes acompanham o
repositorio APT configurado no alvo, nao o ambiente Python do bootstrap.

Comandos de validacao apos instalar, desde a raiz do repositorio:

```bash
bats tests/bash/
shellcheck scripts/bash/run-ansible.sh
shfmt -i 2 -ci -d scripts/bash/run-ansible.sh
ansible-lint --offline ansible/roles/host_tools/tasks/dotnet-sdk.yml
yamllint -d relaxed ansible/roles/base/
```

## Importacao grafica de certificados

A role `base` instala `seahorse` (Senhas e chaves), `gnome-keyring` e
`gnome-keyring-pkcs11` pelos repositorios oficiais do Ubuntu Desktop 26.04 LTS
amd64. O Seahorse fornece a interface grafica; o GNOME Keyring e seu modulo
PKCS#11 fornecem o backend para armazenar chaves e certificados compativeis.
A instalacao usa APT com `state: present`, respeita `--check --diff` e nao
importa certificados nem modifica a confianca em autoridades certificadoras.

Para simular somente essa instalacao e as validacoes obrigatorias:

```bash
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01 --tags base --dry-run
```

Para aplicar, use o mesmo comando sem `--dry-run`; sao necessarios rede e
privilegios de instalacao no alvo. O wrapper registra a auditoria em
`artifacts/logs/`. Pacotes ja instalados nao sao reinstalados.

Depois da aplicacao, encerre e inicie novamente a sessao GNOME do usuario e
reabra o certificado ou o aplicativo Senhas e chaves (`seahorse`). A mensagem
"nao ha importadores compativeis" pode indicar ausencia do backend PKCS#11,
mas tambem indisponibilidade do chaveiro na sessao ou incompatibilidade do
certificado; instalar os pacotes nao garante habilitar o botao Importar.

**Importante:** importar uma CA como `local-ca.crt` no chaveiro nao a torna
automaticamente confiavel para HTTPS no sistema, Firefox, Chromium ou aplicativos
Flatpak. Cada consumidor pode usar um repositorio de confianca diferente. Antes
de confiar em uma CA, confirme sua origem e impressao digital por canal seguro;
essa confianca exige uma operacao separada e explicita. Nao importe chaves
privadas para corrigir um problema de confianca em uma CA.

O teste local `tests/ansible/base-certificates.yml` verifica os pacotes e o
contrato declarativo sem instalar nada. A importacao pela interface e a segunda
aplicacao APT precisam de validacao em VM descartavel com sessao GNOME. Para
desfazer a selecao, remova os tres pacotes de `base_packages`; isso nao os
desinstala. Uma eventual remocao via APT deve ser revisada separadamente, pois
o GNOME Keyring pode atender outros aplicativos. Certificados importados
manualmente devem ser removidos no repositorio em que foram importados.

### Importacao de CA por CLI

Execute no alvo Ubuntu, nao no controller por engano. Os exemplos abaixo sao
operacoes manuais fora do playbook e nao recebem a auditoria do wrapper. Registre
data, destino e impressao digital conforme sua politica, sem registrar chaves
privadas ou senhas. Substitua o caminho de exemplo pelo certificado publico da
CA; nao use o certificado do servidor (`tls-leaf.crt`) como autoridade raiz.

Primeiro, consulte o certificado sem modificar a confianca:

```bash
CERT="$HOME/Downloads/local-ca.crt"
openssl x509 -in "$CERT" -noout -subject -issuer -dates -fingerprint -sha256
openssl x509 -in "$CERT" -noout -text
```

Confira a impressao digital por canal independente e confiavel, validade e
`Basic Constraints: CA:TRUE`. Em geral, a CA raiz sera autoassinada; apenas ter
subject igual ao issuer nao comprova legitimidade. O arquivo deve conter um
unico certificado PEM (`BEGIN CERTIFICATE`), nunca uma chave privada. Se o
original for DER, converta para outro arquivo antes de prosseguir:

```bash
openssl x509 -inform DER -in "$HOME/Downloads/local-ca.der" \
  -out "$HOME/Downloads/local-ca.crt"
```

**Impacto:** adicionar essa CA ao sistema permite que consumidores desse
repositorio aceitem certificados emitidos por ela, para todos os usuarios.
Somente depois da verificacao e da decisao explicita de confiar, execute:

```bash
sudo install -m 0644 -- "$CERT" /usr/local/share/ca-certificates/local-dev-ca.crt
sudo update-ca-certificates
openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt "$CERT"
```

Escolha um nome exclusivo; nao sobrescreva uma CA existente sem comparar a
impressao digital e preservar uma copia para recuperacao. `update-ca-certificates`
nao tem dry-run: a consulta com OpenSSL acima e apenas inspecao, nao simulacao
da atualizacao. Nao use `--fresh` como etapa habitual. Reinicie os aplicativos
que mantem o repositorio em memoria. Verificar a CA nao comprova a validade de
um servidor: ainda precisam ser verificados cadeia, nome DNS e validade.

Para remover apenas a CA adicionada neste exemplo, confirme o caminho e o
impacto nas conexoes antes de executar:

```bash
sudo rm -- /usr/local/share/ca-certificates/local-dev-ca.crt
sudo update-ca-certificates
```

Se o arquivo substituiu uma CA anterior, restaure a copia anterior em vez de
remove-lo e atualize novamente. A remocao nao elimina importacoes feitas em
outros repositorios nem encerra conexoes ja estabelecidas.

Para um aplicativo que usa NSS, `certutil` (pacote `libnss3-tools`) permite
importar no banco **ja existente e confirmado** desse aplicativo. Feche-o e
preserve uma copia protegida do perfil antes da alteracao. Nao execute como
root nem crie um banco vazio para tentar descobrir o destino:

```bash
NSS_DB="$HOME/.mozilla/firefox/SEU-PERFIL"
certutil -L -d "sql:$NSS_DB"
certutil -A -d "sql:$NSS_DB" -n 'Local Dev CA' -t 'C,,' -i "$CERT"
certutil -L -d "sql:$NSS_DB" -n 'Local Dev CA'
```

`SEU-PERFIL` e um placeholder; obtenha o diretorio real em `about:support` no
Firefox. `C,,` concede confianca como CA para TLS nesse banco, nao no Ubuntu.
Confirme que o apelido nao existe antes de importar; nao repita a operacao
cegamente. Para remover a entrada confirmada, com o aplicativo fechado, use
`certutil -D -d "sql:$NSS_DB" -n 'Local Dev CA'`. Esses comandos tambem nao
oferecem dry-run. Politicas do navegador podem controlar ou substituir a
confianca configurada pelo usuario.

### Importacao pela interface grafica

Para o visualizador GNOME da imagem:

1. Inicie uma sessao GNOME normal do usuario, sem `sudo`, com o chaveiro disponivel.
2. Abra o certificado `.crt` pelo gerenciador de arquivos ou execute
  `gcr-viewer "$HOME/Downloads/local-ca.crt"`.
3. Confira emissor, validade e impressao digital; compare com a inspecao OpenSSL
  e a origem confiavel descritas acima.
4. Se **Importar** estiver habilitado, revise o destino/token oferecido pelo
  importador antes de confirmar. Desbloqueie-o se solicitado, sem remover sua senha.
5. Confira o objeto no gerenciador do token correspondente. O Seahorse pode
  exibir objetos PKCS#11 quando esse backend e essa visualizacao estiverem
  disponiveis na versao instalada.

Se nao existir destino gravavel compativel, pare: a instalacao do Seahorse nao
garante que um certificado X.509 avulso seja importavel pela interface. Nao
confunda a importacao de chaves PGP/SSH do Seahorse com importacao de CAs TLS.
Nao remova arquivos do chaveiro nem importe uma chave privada como tentativa
de desbloquear o botao. Para confiar em uma CA no Ubuntu, use o fluxo CLI do
sistema; o visualizador GNOME nao substitui `update-ca-certificates`.

Para confiar na CA apenas no Firefox, ha um fluxo grafico proprio:

1. Abra **Configuracoes > Privacidade e seguranca > Certificados > Ver certificados**.
2. Na aba **Autoridades**, escolha **Importar** e selecione o certificado publico da CA.
3. Apos validar a origem, selecione a confianca para identificar sites e confirme.
4. Confira a entrada e sua impressao digital em **Autoridades**. Para desfazer,
  selecione somente essa CA e use **Excluir ou desconfiar**.

Os nomes dos controles podem variar por versao/idioma. Esse fluxo modifica o
perfil do Firefox, nao o chaveiro GNOME. Certificados pessoais com chave privada
(PKCS#12, `.p12`/`.pfx`) pertencem a **Seus certificados**, tem finalidade de
autenticacao do cliente e exigem tratamento e backup de secrets separados.

### Onde os certificados ficam armazenados

O arquivo original em Downloads permanece no lugar; a importacao cria uma
copia ou objeto no destino. Nao mova nem edite diretamente arquivos internos
dos bancos enquanto os aplicativos estiverem em uso.

| Metodo/destino | Armazenamento apos importacao | Alcance |
| --- | --- | --- |
| CLI, CA local do Ubuntu | Fonte em `/usr/local/share/ca-certificates/local-dev-ca.crt`; links PEM/hash em `/etc/ssl/certs/`; bundle gerado em `/etc/ssl/certs/ca-certificates.crt` | Consumidores da confianca do sistema, todos os usuarios |
| GNOME/GCR, token PKCS#11 | No token escolhido; para armazenamento local do GNOME Keyring, normalmente sob `${XDG_DATA_HOME:-$HOME/.local/share}/keyrings/`, conforme backend/versao | Usuario e aplicativos que consultam esse token; nao concede confianca global automaticamente |
| Token PKCS#11 de hardware | No dispositivo, conforme capacidade e politica do token; nao necessariamente em arquivo local | Consumidores desse token |
| Firefox, GUI ou `certutil` | `cert9.db` no diretorio do perfil mostrado em `about:support`; `key4.db` guarda material de chaves quando aplicavel | Perfil selecionado; leitura adicional da confianca do SO depende da versao/configuracao |
| Chromium/Chrome com NSS | Banco NSS escolhido pelo aplicativo; caminhos comuns incluem `~/.pki/nssdb` e `${XDG_DATA_HOME:-$HOME/.local/share}/pki/nssdb` | Depende da versao e de politicas; confirme no gerenciador de certificados antes de usar `certutil` |

O chaveiro de senhas `login.keyring` nao e um bundle de CAs: nao suponha que
certificados importados estejam nele. O backend define os arquivos e formatos;
gerencie objetos pela interface/API, nao copiando um `.crt` para `keyrings/`.
Nao edite o bundle do sistema manualmente, pois ele e regenerado.

Em Firefox Flatpak, o perfil pode estar sob `~/.var/app/org.mozilla.firefox/`;
em Snap, sob `~/snap/firefox/`. Use sempre o caminho informado pelo aplicativo,
nao o exemplo do host. Sandboxes, Java e outros runtimes podem manter bancos
proprios ou nao enxergar a confianca do host. Importar em um destino nao garante
importacao nos demais.

Referencias: [manual de update-ca-certificates](https://manpages.debian.org/trixie/ca-certificates/update-ca-certificates.8.en.html)
e ajuda local `man certutil`. Procedimentos documentados; importacoes, remocoes
e validacao grafica devem ser testadas em ambiente descartavel, nao no desktop
de trabalho sem autorizacao.

## Estrutura

| Caminho | Responsabilidade |
| --- | --- |
| `ansible/playbooks/configure-workstation.yml` | Orquestracao principal |
| `ansible/roles/preflight/` | Validacao de SO, arquitetura e usuario |
| `ansible/roles/base/` | Pacotes Ubuntu e terminal |
| `ansible/roles/flatpak_apps/` | Flathub e aplicativos graficos |
| `ansible/roles/nextcloud_client/` | Cliente Nextcloud e pasta de sincronizacao |
| `ansible/roles/host_tools/` | Repositorios, SDKs, CLIs e Podman rootless |
| `ansible/roles/terminal/` | uv, ZSH, Oh My Posh, Oh My Zsh e fonte |
| `ansible/roles/terminal/files/atomic.omp-VISION.json` | Tema Oh My Posh utilizado pelo ZSH |
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

Ao concluir, o bootstrap compara as versoes de `uv`, `ansible-core`, `pywinrm`
e da collection `community.general` com as versoes esperadas. Uma divergencia
retorna falha.

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

O nome esperado pelo wrapper e `vault.yml`; o arquivo da senha do Vault deve se
chamar `vault-password`. Se o alvo solicitar senha para `sudo`, inclua
`ansible_become_password` no `vault.yml`. Use `ansible_password` somente se a
conexao SSH autenticar por senha em vez de chave/agent. O token
`OP_SERVICE_ACCOUNT_TOKEN` do 1Password nao pertence ao Ansible Vault: mantenha-o
exportado no ambiente do controller.

### Criptografar e descriptografar o Vault

O fluxo recomendado e criar ou editar o arquivo com `ansible-vault`; assim o
conteudo salvo continua criptografado:

```bash
ansible-vault edit "$SECRETS_DIR/vault.yml" \
  --vault-password-file "$SECRETS_DIR/vault-password"
```

Para criptografar um YAML que ainda esteja em texto claro, proteja o arquivo com
permissoes restritas antes e execute:

```bash
chmod 600 "$SECRETS_DIR/vault.yml"
ansible-vault encrypt "$SECRETS_DIR/vault.yml" \
  --vault-password-file "$SECRETS_DIR/vault-password"
```

Para consultar o conteudo descriptografado sem substituir o arquivo criptografado,
use `view`. A saida contem secrets; nao a redirecione para logs, terminal
compartilhado ou historico:

```bash
ansible-vault view "$SECRETS_DIR/vault.yml" \
  --vault-password-file "$SECRETS_DIR/vault-password"
```

Se for realmente necessario obter uma copia descriptografada em disco, escreva
em um arquivo separado com `umask 077`, mantenha-o fora do repositorio e apague-o
assim que terminar:

```bash
umask 077
ansible-vault decrypt "$SECRETS_DIR/vault.yml" \
  --vault-password-file "$SECRETS_DIR/vault-password" \
  --output "$SECRETS_DIR/vault.plain.yml"
chmod 600 "$SECRETS_DIR/vault.plain.yml"
```

`vault.plain.yml` fica em texto claro. Nao substitua `vault.yml` por essa copia e
nao a use em execucoes. Para apagar a copia quando nao for mais necessaria:

```bash
rm -- "$SECRETS_DIR/vault.plain.yml"
```

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

O mesmo runtime define `DOTNET_ROOT="$HOME/.dotnet"` e prioriza `~/.dotnet` e
`~/.dotnet/tools` no PATH, sem duplicar esses prefixos ao recarregar o shell.
Tambem define `SSL_CERT_DIR` para o certificado HTTPS de desenvolvimento.
A role `host_tools` usa explicitamente o executavel do usuario; consulta e
eventual criacao/confianca do certificado ocorrem somente no modo real.

### SDKs .NET por usuario e global.json

No Ubuntu Desktop 26.04 LTS amd64, `host_tools` instala os SDKs 8.0.425 e
10.0.402 lado a lado em `{{ ubuntu_desktop_home }}/.dotnet` (por padrao,
`/home/lzocateli/.dotnet`). Os arquivos Linux x64 oficiais sao verificados por
SHA-512 antes da extracao, sem `sudo` para instalar os SDKs. O comando e sempre
`dotnet`; nao e necessario alternar para `dotnet8`. Os SDKs ficam em
`~/.dotnet/sdk/<versao>`, os runtimes em `~/.dotnet/shared/` e as ferramentas
globais em `~/.dotnet/tools/` quando instaladas pelo usuario.

Para simular a instalacao e a configuracao do shell, desde a raiz do repositorio:

```bash
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01 --tags host_tools,terminal --dry-run
```

Para aplicar, remova `--dry-run`. Essas tags tambem aplicam as demais ferramentas
e configuracoes dessas roles: revise o inventario e o plano antes da execucao.
O wrapper mantem logs em `artifacts/logs/`. A simulacao consulta a presenca dos
SDKs e informa os ausentes, mas nao baixa nem extrai arquivos e nao consulta
certificados .NET. No modo real, os temporarios exclusivos ficam em
`~/.dotnet/artifacts/` e sao removidos ao terminar, inclusive em caso de falha.
SDKs cuja instalacao ja esta presente nao sao baixados novamente.

Abra uma nova sessao apos aplicar a role `terminal` ou carregue o runtime:

```bash
. "$HOME/.local/lib/ubuntu-desktop/development-shell.sh"
command -v dotnet
dotnet --list-sdks
```

O primeiro comando de consulta deve apontar para `~/.dotnet/dotnet`, e a lista
deve mostrar ambos os SDKs em `~/.dotnet/sdk`. Reinicie tambem o VS Code para
atualizar o ambiente herdado; extensoes podem ter runtimes proprios, que nao
sao gerenciados por esta role.

Em cada repositorio de projeto, crie ou edite conscientemente um `global.json`
na raiz e versione-o junto do codigo. Exemplo de selecao exata do SDK 8:

```json
{
  "sdk": {
    "version": "8.0.425",
    "rollForward": "disable",
    "allowPrerelease": false
  }
}
```

Para um projeto .NET 10, use `"version": "10.0.402"`. Verifique executando
`dotnet --version` dentro da pasta do projeto. O resolvedor procura `global.json`
no diretorio atual e nos ancestrais; fora de uma selecao explicita, normalmente
usa o maior SDK instalado. Com `rollForward: disable`, um SDK ausente causa
falha em vez de selecionar outra versao. Para aceitar patches da mesma feature
band, escolha explicitamente `latestPatch`. `global.json` **nao instala SDKs**
e nao altera o `TargetFramework` do `.csproj`.

Para adicionar ou atualizar SDKs, ajuste `host_tools_dotnet_sdks` no inventario
com objetos `version` e `sha512` obtidos dos metadados oficiais Microsoft, ou
atualize os pares `host_tools_dotnet_sdk8_version`/`host_tools_dotnet_sdk8_sha512`
e `host_tools_dotnet_sdk10_version`/`host_tools_dotnet_sdk10_sha512` nos defaults.
Use versoes completas estaveis; nao use canais flutuantes. Instale primeiro o
SDK requerido e so entao atualize o `global.json`. O .NET 8 encerra suporte em
10/11/2026; planeje a migracao dos projetos que ainda o exigem.

**Migracao e recuperacao:** a instalacao normal nao remove .NET anterior.
As tags `dotnet` e `dotnet_env` instalam somente os SDKs do usuario e atualizam
o runtime compartilhado e seu carregamento em `.profile`, `.bashrc` e `.zshrc`,
sem reaplicar as demais ferramentas do host/terminal. O preflight continua
obrigatorio. `dotnet_env` atualiza o runtime compartilhado inteiro, que tambem
contem integracao com certificados, aliases e funcoes Node/Podman.

Para remover explicitamente o legado instalado pela versao anterior da role,
simule primeiro:

```bash
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01 --tags dotnet,dotnet_env \
  --remove-legacy-dotnet --dry-run
```

Revise a saida e interrompa builds/servicos que usam a instalacao antiga.
O escopo e fixo: dez pacotes .NET/ASP.NET 10 do APT, incluindo o SDK AOT,
`/opt/dotnet-sdk-8` e o link `/usr/local/bin/dotnet8`. A role consulta
`apt-get --simulate remove` e bloqueia remocoes de outros pacotes; tambem
recusa caminhos/links inesperados. Nao usa purge ou autoremove. O check mode
nao cria backup, nao remove arquivos/pacotes e nao baixa SDKs. Para aplicar:

```bash
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01 --tags dotnet,dotnet_env \
  --remove-legacy-dotnet --confirm-remove-legacy-dotnet
```

A remocao exige rede/privilegios administrativos apropriados ao APT e
confirmacao explicita; o wrapper nao solicita nem recebe senhas em argumentos.
Antes de remover o SDK 8 em `/opt`, a role cria um backup exclusivo em
`~/.dotnet/artifacts/legacy-sdk8-backup-*/dotnet-sdk-8.tar.gz`, com diretorio
`0700` e arquivo `0600`. O caminho fica no log do wrapper. O backup e
preservado, nao apagado pelo cleanup de downloads. A remocao ocorre antes da
nova instalacao; se um download falhar, use o backup ou execute novamente
apos resolver a causa. Instalar e remover nao e uma transacao atomica.

Para recuperar o SDK legado, confira o arquivo de backup e extraia-o com
`sudo tar -xzf CAMINHO_DO_BACKUP -C /opt`, somente se o destino nao contiver
outra instalacao que seria sobrescrita. Recrie o link, se necessario, com
`sudo ln -s /opt/dotnet-sdk-8/dotnet /usr/local/bin/dotnet8`, apos confirmar
que ele nao existe. Os pacotes APT podem ser reinstalados com
`sudo apt-get install dotnet-sdk-10.0 dotnet-sdk-aot-10.0`, conforme disponibilidade
do repositorio; isso pode instalar versoes mais novas que as removidas.

SDKs ja existentes em `~/.dotnet` nao sao apagados pela migracao, mesmo que
nao estejam na lista gerenciada: projetos podem depender deles. Para voltar
ao executavel do sistema, restaure o PATH/DOTNET_ROOT anterior em uma sessao
de teste e confira `command -v dotnet`. Nao apague `~/.dotnet` indiscriminadamente.
Retirar uma versao da lista Ansible nao a desinstala. Falhas de checksum devem
interromper a instalacao, nunca ser contornadas desabilitando a verificacao.

Valide `dotnet --list-sdks` e `dotnet --version` em projetos das duas versoes.
Os testes locais cobrem metadados, protecao do check mode e PATH Bash/ZSH;
download/extracao reais e segunda aplicacao devem ser validados em ambiente
descartavel. Nao ha migracao automatica dos `global.json` de projetos existentes.

Evidencia operacional de 14/10/2026 no host `vision`, com autorizacao explicita:
os dez pacotes APT legados, `/opt/dotnet-sdk-8` e o link `dotnet8` foram
removidos. SDKs 8.0.425 e 10.0.402 foram instalados no home, mantendo o SDK
10.0.400 preexistente. Fixtures isoladas de `global.json` selecionaram 8.0.425
e 10.0.402 corretamente. A reaplicacao de `base,dotnet,dotnet_env` com migracao
confirmada terminou com `changed=0` e `failed=0`.

O backup preservado foi
`~/.dotnet/artifacts/legacy-sdk8-backup-99yyvjf6/dotnet-sdk-8.tar.gz` (`0600`).
O log da migracao e `artifacts/logs/ansible-20261014T220149Z-1152921.log`;
logs/backup sao locais e nao devem ser versionados. Bats 1.13.0, ShellCheck
0.11.0, shfmt 3.12.0, ansible-lint 26.1.1 e yamllint 1.37.1 ficaram disponiveis.
Os 16 testes Bats focados passaram; a suite completa teve 21 sucessos e
quatro falhas por permissao de execucao do renderizador 1Password no repositorio,
nao alterado nesta migracao. ShellCheck do wrapper, shfmt no estilo existente,
ansible-lint das tasks novas/base e yamllint focado passaram.

## Montagem persistente de disco

O Ansible nao formata nem monta discos. Para configurar manualmente um volume
ext4 ja existente no Ubuntu, obtenha o UUID e confirme modelo, rotulo e
dispositivo antes de editar `/etc/fstab`:

```bash
lsblk -f
sudo mkdir -p /mnt/kingston
sudoedit /etc/fstab
```

Adicione uma unica linha usando o UUID conferido:

```fstab
UUID=<UUID-CONFERIDO> /mnt/kingston ext4 defaults,nofail 0 2
```

Valide a entrada antes de reiniciar. Se o desktop ja montou o disco via GNOME,
feche arquivos abertos e desmonte essa montagem antes de ativa-lo no novo caminho:

```bash
sudo findmnt --verify --verbose
udisksctl unmount --block-device /dev/disk/by-id/ID-DO-DISCO
sudo systemctl daemon-reload
sudo mount /mnt/kingston
findmnt --mountpoint /mnt/kingston
```

Substitua `ID-DO-DISCO` pelo link `/dev/disk/by-id` confirmado para o seu
dispositivo. A entrada fstab passa a ser usada no proximo boot; nao monte o
mesmo volume em dois caminhos ao mesmo tempo.

## Cliente Nextcloud

A role instala o pacote APT `nextcloud-desktop` no Ubuntu Desktop 26.04 LTS
amd64 e prepara `/mnt/kingston/Nextcloud` para sincronizacao com
`https://meudrive.lzoca/`. O volume precisa estar montado exatamente em
`/mnt/kingston` antes de executar a role. A automacao nao formata, monta nem
configura persistencia do disco.

A role tambem instala LibreOffice Writer (DOCX), Calc (XLSX), integracao GTK3
com GNOME e interface pt-BR pelos repositorios APT do Ubuntu. As versoes seguem
os pacotes da distribuicao; nao ha download de instalador externo. Edicao grafica
exige sessao GNOME. A instalacao requer privilegios `become` e acesso aos
repositorios; nao altera associacoes de arquivos nem documentos existentes.

O [cliente Nextcloud Desktop apenas sincroniza arquivos](https://docs.nextcloud.com/server/latest/user_manual/en/files/desktop_mobile_sync.html).
O [LibreOffice abre e salva DOCX e XLSX](https://help.libreoffice.org/latest/en-US/text/shared/guide/ms_user.html).
Abra arquivos da pasta sincronizada no Writer ou Calc; apos salvar e com o
cliente conectado, o Nextcloud sincroniza as alteracoes. Preserve o formato
DOCX/XLSX ao salvar se precisar compartilhar com usuarios do Microsoft Office.
Macros VBA e layouts complexos podem nao ser compativeis: trabalhe numa copia
e confira o resultado antes de sobrescrever documentos importantes.

A [edicao colaborativa pelo navegador](https://docs.nextcloud.com/server/latest/admin_manual/office/index.html)
e diferente: requer uma integracao Office e seu servico no servidor Nextcloud.
Instalar LibreOffice no desktop nao habilita essa funcionalidade.

Defina `nextcloud_client_install_libreoffice: false` para nao instalar nem
validar os editores. Isso nao desinstala pacotes existentes. A lista
`nextcloud_client_libreoffice_packages` pode ser sobrescrita no inventario.
Para recuperacao, use o historico/versoes do Nextcloud ou o backup do documento;
a role nao converte arquivos nem gerencia backups. Nao remova a pasta
sincronizada para desinstalar o editor.

Simule e aplique somente a role Nextcloud em um alvo autorizado:

```bash
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01 --tags nextcloud --dry-run
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01 --tags nextcloud
```

Check mode confirma o ponto de montagem com a consulta somente leitura
`findmnt`, simula a instalacao/pasta e pula a atualizacao do cache APT. A
disponibilidade do pacote na origem nao e confirmada ate a execucao real. A
simulacao nao autentica nem contacta o servidor.
Na sessao GNOME, abra Nextcloud Desktop, informe a URL acima, autentique-se e
selecione `/mnt/kingston/Nextcloud` como pasta local. Credenciais nao sao
armazenadas pela role. Verifique que o disco tem espaco suficiente e backup
antes da primeira sincronizacao; exclusoes e alteracoes sincronizadas no servidor
podem propagar-se para o disco e vice-versa.

A URL, a pasta local e o nome do pacote podem ser sobrescritos por
`nextcloud_client_server_url`, `nextcloud_client_sync_directory` e
`nextcloud_client_package`, respectivamente. O ponto de montagem permanece
fixado em `/mnt/kingston`, e a pasta deve ser sua filha direta.

Para acesso de escrita pelo usuario atual, ajuste a propriedade do diretorio
somente depois de confirmar que o volume certo esta montado:

```bash
sudo chown "$USER:$USER" /mnt/kingston
```

Esses comandos nao formatam o disco. Se `/etc/fstab` estiver incorreto, remova
ou corrija a linha antes de reiniciar. Nao monte simultaneamente o mesmo ext4
em dois caminhos; desmonte a montagem grafica existente antes de montar em
`/mnt/kingston`.

## Chaves SSH e NuGet

Na execucao real, a role `terminal` usa `op` no controller Ansible para ler o
campo `chave privada` dos itens SSH configurados no vault `Automation`. O
controller precisa ter o 1Password CLI e a variavel de ambiente
`OP_SERVICE_ACCOUNT_TOKEN` definida com acesso somente de leitura ao vault. O
token nao deve ser salvo no inventario nem passado como argumento de linha de
comando. As consultas ao 1Password e a instalacao das chaves sao omitidas em
check mode.

Os itens padrao sao `id_ed25519_proxmox`, `id_ed25519_pve_lzocateli`, `id_ed25519_hostinger_root`,
`id_ed25519_hostinger_brazildevops`, `id_ed25519_interserver_st56165` e `id_ed25519_github_lzocateli`.
O titulo de cada item deve ser exatamente o nome do arquivo indicado por
`IdentityFile`, sem o caminho. As chaves sao gravadas em `~/.ssh/`
com modo `0600`, dentro de um diretorio `0700`; respostas e diffs das tarefas
que manipulam material privado sao ocultados. O destino padrao do config e
`~/.ssh/config`; o arquivo mantido no Nextcloud serve somente como modelo.
Na conciliacao, o config local e a fonte da verdade: replique seus aliases,
destinos, usuarios e nomes de identidade em `terminal_ssh_hosts` dos inventarios
de exemplo e privado, e mantenha `terminal_ssh_key_items` alinhado a essas
identidades. A execucao normal continua gerando o bloco a partir do inventario;
ela nao importa alteracoes locais automaticamente. Nao execute a instalacao
real das chaves antes de conciliar os titulos no cofre.

Conciliacao de 15/10/2026: os fingerprints publicos foram comparados aos
derivados das chaves privadas locais, sem revelar material privado. O CLI
1Password 2.41.0 recusou `op item edit` com
`SSH Key item editing in the CLI is not yet supported`; nenhum titulo foi
alterado. Renomeie os itens existentes pelo aplicativo 1Password, preservando
IDs e chaves, antes de executar o Ansible:

| Titulo atual no Automation | Novo titulo igual ao arquivo local |
| --- | --- |
| `proxmox` | `id_ed25519_proxmox` |
| `pve-brazildevops` | `id_ed25519_pve_lzocateli` |
| `hostinger-root` | `id_ed25519_hostinger_root` |
| `hostinger-brazildevops` | `id_ed25519_hostinger_brazildevops` |
| `interserver-st56165` | `id_ed25519_interserver_st56165` |
| `github cat` | `id_ed25519_github_lzocateli` |

`id_ed25519_github_lzocateli` ja esta correto. `id_ed25519_github_lzocateli` tem
correspondencia local, mas nao e usado pelo config e nao entra no download
gerenciado. `proxmox`, `pve-brazildevops` e `hostinger-brazildevops` contem a
mesma chave publica, assim como os tres arquivos locais correspondentes;
esta conciliacao nao faz rotacao nem deduplicacao de chaves. Os itens
`cat-devops-zocatel` e `Github - brazildevops` nao correspondem a nenhuma
chave privada local e devem ser preservados, sem renomear por suposicao.
Arquivos locais sem referencia no config tambem nao sao removidos.
Para recuperar uma renomeacao incorreta, restaure o titulo anterior no aplicativo;
nao exclua nem recrie o item. A tentativa foi registrada em
`artifacts/logs/ssh-reconcile-20261015T155027Z-p5MYep.log`, sem segredos.

Validacao local: os 15 aliases e as seis identidades dos dois inventarios
conferem com a expansao do config via `ssh -G`, sem conexoes de rede. Os dois
testes de `tests/bash/terminal-config.bats`, yamllint, ShellCheck e syntax-check
com `ANSIBLE_CONFIG=ansible/ansible.cfg` passaram. O check mode das tarefas SSH
em fixture descartavel terminou sem falhas, sem consultar o cofre e sem gravar
arquivos SSH. Aplicacao real e idempotencia do download permanecem pendentes
das renomeacoes no aplicativo; o download real nao foi executado.

Na etapa seguinte de 15/10/2026, os arquivos locais foram renomeados para
`id_ed25519_pve_lzocateli` (incluindo `.pub`), `id_ed25519_hostinger_root` e
`id_ed25519_github_lzocateli`, preservando conteudo e permissoes. O config
local e os dois inventarios foram ajustados; o alias `github.com` continua
usando `id_ed25519_github_lzocateli`. Auditoria local em
`artifacts/logs/ssh-rename-20261015T160057Z-MIbz57.log`. A tabela de novos
titulos acima ja reflete esses nomes; a renomeacao no cofre continua manual.

O bloco gerenciado preserva outras entradas e configura:

A tag `ssh_permissions` pode ser usada isoladamente pelo wrapper para corrigir
somente permissoes: diretorio `.ssh` em `0700`, arquivos privados e auxiliares
em `0600`, e arquivos `.pub` em `0644`. Essa operacao nao consulta o 1Password
nem altera o conteudo, proprietario ou grupo dos arquivos.

| Alias | Destino | Usuario | Chave |
| --- | --- | --- | --- |
| `pve01` | `172.16.100.13` | `root` | `id_ed25519_proxmox` |
| `pve02` | `172.16.100.12` | `root` | `id_ed25519_proxmox` |
| `pve03` | `172.16.100.14` | `root` | `id_ed25519_proxmox` |
| `pve04` | `172.16.100.11` | `root` | `id_ed25519_proxmox` |
| `pve05` | `172.16.100.10` | `root` | `id_ed25519_proxmox` |
| `vm-nginx`, `vm-postgres`, `vm-monitor` | `172.16.10.30`, `.40`, `.50` | `lzocateli` | `id_ed25519_pve_lzocateli` |
| `unifi` | `172.16.100.1` | `root` | `id_ed25519_proxmox` |
| `truenas` | `172.16.100.20` | `truenas_admin` | `id_ed25519_proxmox` |
| `truenas-root` | `172.16.100.20` | `root` | `id_ed25519_proxmox` |
| `hostinger-root` | `187.77.231.228` | `root` | `id_ed25519_hostinger_root` |
| `hostinger-vps` | `187.77.231.228` | `brazildevops` | `id_ed25519_hostinger_brazildevops` |
| `interserver` | `storage3600.is.cc` | `st56165` | `id_ed25519_interserver_st56165` |
| `github.com` | `github.com` | `git` | `id_ed25519_github_lzocateli` |

As conexoes usam a porta 22 e nao desabilitam a verificacao de host key. A
validacao real usa `ssh -G` para confirmar a expansao de host, usuario,
identidade e porta sem abrir conexao de rede.

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

## ZSH, historico e tema Oh My Posh

A role `terminal` instala o tema versionado em
`ansible/roles/terminal/files/atomic.omp-VISION.json` em
`~/.config/oh-my-posh/atomic.omp-VISION.json` e configura o Oh My Posh para
carrega-lo no ZSH. O bloco Ansible gerenciado em `~/.zshrc` define o arquivo
`~/.zsh_history`, `HISTSIZE`/`SAVEHIST` de 50.000 e as opcoes `APPEND_HISTORY`,
`SHARE_HISTORY` e `EXTENDED_HISTORY`, alem de ignorar duplicatas, comandos
precedidos por espaco e espacos redundantes. O arquivo de historico tem modo
`0600`; um historico existente e preservado.

Simule e aplique somente as tarefas ZSH, sem reaplicar as demais configuracoes
da role terminal:

```bash
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/vision/hosts.yml \
  --limit vision --tags zsh --dry-run
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/vision/hosts.yml \
  --limit vision --tags zsh
```

A aplicacao valida o JSON v3 do tema, a inicializacao do Oh My Posh, a sintaxe
interativa e as opcoes/limites do historico. `terminal_oh_my_posh_config_file`
seleciona o arquivo da role, `terminal_oh_my_posh_config_path` define o caminho
no home e `terminal_zsh_history_size` controla os limites de memoria e gravacao.
Abra um novo terminal ou execute `exec zsh` para carregar a configuracao; o
Ansible nao encerra shells ja abertos.

## Fonte Meslo no terminal integrado do VS Code

A role `terminal` configura `terminal.integrated.fontFamily` como
`MesloLGM Nerd Font` nas preferencias globais e nos perfis existentes do VS Code,
usando a mesma fonte Nerd Font instalada para o prompt ZSH. Isso evita que uma
preferencia de perfil, como `monospace`, sobreponha a configuracao global. As
demais preferencias existentes sao preservadas. Feche e abra o terminal
integrado para carregar a fonte.

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
| `--remove-legacy-dotnet` | Nao | Inclui migracao .NET de escopo fixo, opt-in |
| `--confirm-remove-legacy-dotnet` | Real com migracao .NET | Confirma remocao do legado apos revisao |

Variaveis principais:

| Variavel | Padrao | Impacto |
| --- | --- | --- |
| `ubuntu_desktop_user` | `lzocateli` | Usuario da conexao e dono da configuracao de desktop |
| `ubuntu_desktop_home` | `/home/lzocateli` | Home validado no `getent` |
| `terminal_git_user_name` | `zocatel` no inventario | Nome de autor registrado nos commits, independente do login Linux |
| `terminal_git_user_email` | E-mail definido no inventario | E-mail registrado nos commits |
| `flatpak_apps_install_firefox` | `false` | Instala Firefox Flatpak |
| `host_tools_install_1password` | `true` | Instala Desktop e CLI |
| `host_tools_dotnet_install_dir` | `{{ ubuntu_desktop_home }}/.dotnet` | Destino por usuario, validado pela role |
| `host_tools_dotnet_sdks` | SDKs 8.0.425 e 10.0.402 com SHA-512 | Versoes instaladas lado a lado, sem remover as anteriores |
| `host_tools_configure_dotnet_dev_certificate` | `true` | Cria e confia no certificado HTTPS .NET do usuario |
| `terminal_configure_zsh` | `true` | Configura e define ZSH como shell |
| `terminal_oh_my_posh_config_file` | `atomic.omp-VISION.json` | Tema distribuido pela role terminal |
| `terminal_oh_my_posh_config_path` | `~/.config/oh-my-posh/atomic.omp-VISION.json` | Caminho do tema instalado |
| `terminal_zsh_history_size` | `50000` | Limite de historico carregado e salvo pelo ZSH |
| `terminal_vscode_terminal_font_family` | `MesloLGM Nerd Font` | Familia da fonte do terminal integrado do VS Code |
| `terminal_vscode_settings_path` | `~/.config/Code/User/settings.json` | Caminho das preferencias gerenciadas do VS Code |
| `terminal_devops_image` | `docker.io/lzocateli/devops:cpu-ubuntu24.04` | Imagem para Node, npm e npx |
| `terminal_copilot_cli_version` | `1.0.91` | Versao standalone do Copilot CLI instalada no host |
| `terminal_copilot_cli_checksum` | SHA-256 do release 1.0.91 | Integridade do tarball Linux x64 |
| `terminal_onepassword_env_enabled` | `false` | Baixa o `.env` e persiste exports no profile |
| `terminal_onepassword_env_account` | Vazio | Conta `op` opcional |
| `terminal_onepassword_env_vault` | Vazio | Nome/ID do vault do documento |
| `terminal_onepassword_env_document` | Vazio | Nome/ID do documento `.env` |
| `terminal_ssh_op_vault` | Vazio | Vault do 1Password que contem as chaves SSH |
| `terminal_ssh_key_items` | `[]` | Itens cujos campos `chave privada` serao instalados |
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
  --remove-snap --dry-run --verbose
```

Aplicacao real padrao, incluindo migracao destrutiva do Snap:

```bash
test -n "${OP_SERVICE_ACCOUNT_TOKEN:-}"
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01 \
  --tags all \
  --remove-snap --confirm-remove-snap
```

O exemplo acima presume `op` instalado no controller e acesso ao vault
configurado. Forneca o token no ambiente via gerenciador de secrets do
controller; nao o grave no shell profile, inventario, argumento de processo ou
log. Se as chaves SSH nao fizerem parte da execucao, configure
`terminal_ssh_key_items: []` e `terminal_ssh_hosts: []` no inventario privado.

Para remover o Snap, revise primeiro a simulacao da secao [Remocao do
Snap](#remocao-do-snap); a execucao real exige conjuntamente
`--remove-snap --confirm-remove-snap` e remove dados sem rollback automatico.
O wrapper limita uma execucao com `--remove-snap` somente a migracao Snap por
padrao. Inclua `--tags all` para reaplicar tambem as demais roles na mesma
execucao, como no comando padrao acima. Para uma aplicacao sem remover Snap,
omita ambos os parametros.

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

Depois de confirmar que Edge e os demais substitutos funcionam e que nao precisa
dos aplicativos nem dos dados Snap do Ubuntu, execute:

```bash
test -n "${OP_SERVICE_ACCOUNT_TOKEN:-}"
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01 \
  --remove-snap --confirm-remove-snap
```

Essa execucao remove os aplicativos e componentes listados na role, purga
`snapd`, exclui diretorios de dados e cria
`/etc/apt/preferences.d/no-snapd.pref` com prioridade `-1`. Qualquer Snap
instalado que nao esteja nessa lista faz a role parar antes de purgar `snapd`;
revise e inclua explicitamente novos itens na lista da role apos autorizacao.
Dados removidos nao possuem rollback automatico.

## Tags

| Tag | Escopo |
| --- | --- |
| `preflight` | Validacoes do alvo |
| `base` | Pacotes Ubuntu e terminal |
| `flatpak` | Flathub e aplicativos |
| `nextcloud` | Cliente Nextcloud Desktop, pasta de sincronizacao e LibreOffice Writer/Calc |
| `host_tools` | Podman rootless, SDKs e CLIs |
| `terminal` | Shell, Git, chaves SSH, fontes NuGet, uv, prompt e fonte |
| `zsh` | Tema Oh My Posh e configuracao de historico do ZSH; requer ferramentas instaladas |
| `development` | Ferramentas do host e terminal |
| `snap_migration` | Remocao opt-in do Snap |

Exemplo focado:

```bash
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01 --tags flatpak --dry-run
```

Para instalar ou simular apenas o cliente Nextcloud, substitua `flatpak` por
`nextcloud`.

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
ansible-playbook -i localhost, ../tests/ansible/nextcloud-client.yml
ansible-playbook -i localhost, ../tests/ansible/terminal-zsh.yml
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
