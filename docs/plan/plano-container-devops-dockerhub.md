# Plano DevOps Docker Hub

## Status do Plano

- Status: Concluído
- Data: 2026-10-17
- Escopo aprovado: imagem publica Docker Hub `lzocateli`, funcoes, tema da
  referencia, preservacao de `.profile` e Desktop 1Password com CLI em container.
- Limite inicial: sem mutacoes no desktop real. Aplicacao no `vision`
  posteriormente autorizada pelo usuario, em 2026-10-17.

## Progresso

- Download idempotente, Angular persistente e wrapper `op` rootless implementados.
- Funcoes `node`, `npm`, `npx`, `ng`, `op`, `lh` e `lhr` coloridas implementadas.
- JSON estruturalmente identico a referencia; tema VISION preservado.
- Preservacao de variaveis, PATH sem duplicatas e auditoria sem argumentos.
- Testes isolados: 19 de runtime/container e seis do renderizador passaram.
- Segunda aplicacao na fixture: `changed=0`; check mode sem `pull`/`run`.

## Evidencias e Proximo Passo

- `bats tests/bash/development-shell.bats tests/bash/op-container.bats` passou.
- `bats tests/bash/load-1password-env.bats` passou.
- `ansible-playbook -i localhost, tests/ansible/terminal-zsh.yml` passou.
- Comparacao `jq -S` do JSON com a referencia sem diferencas.
- Sintaxe do playbook validada com `ANSIBLE_CONFIG=ansible/ansible.cfg`.
- Blocos reais do profile validados em dash, Bash e ZSH, sem duplicar PATH.
- Bash/ZSH `-n`, ShellCheck e shfmt dos scripts renderizados passaram.
- Nos testes com comandos shell literais, SC2016 foi excluido por expansao
  intencional no subprocesso; nenhuma supressao nos scripts de producao.
- `yamllint` passou nos YAMLs novos e no recorte alterado sem legado WireGuard.
- `ansible-lint --offline` passou em 11 arquivos com exclusao explicita do
  WireGuard legado. A verificacao incluindo os arquivos legados apontou linha
  longa preexistente em `host_tools/tasks/main.yml`, ordem de chaves e ausencia
  de newline preexistentes em `wireguard.yml`; nao corrigidas neste escopo.
- Assertions Bats negativas verificam status explicitamente; check mode compara
  estado da fixture antes/depois; logs nao contem o token ficticio.
- Validacao inicial isolada sem download real, secrets ou aplicacao no host.

## Aplicacao Autorizada no Vision

- Data: 2026-10-17. Escopo: `host_tools,terminal`, inventario privado `vision`,
  limite `vision`, wrapper com auditoria e credenciais externas via Vault.
- Primeira tentativa parou porque `cpu-ubuntu24.04` nao continha a CLI `op`.
  Nenhuma falha foi ignorada; o usuario indicou `lzocateli/devops:cpu-v1`.
- Padrao alterado para `docker.io/lzocateli/devops:cpu-v1`; sete testes focados
  de imagem/container e yamllint passaram antes da reaplicacao.
- Aplicacao real com cpu-v1: `ok=137 changed=13 unreachable=0 failed=0`.
- Reaplicacao real: `ok=136 changed=2 unreachable=0 failed=0`. As duas mudancas
  sao exclusivamente criacao e remocao do temporario de importacao WireGuard,
  comportamento preexistente; nao houve alteracao nas configuracoes convergidas.
- Validados CLI 1Password em container, SDKs 8/10 no perfil do usuario,
  funcoes em Bash/ZSH e inicializacao interativa do tema Oh My Posh.
- Logs locais ignorados pelo Git:
  `artifacts/logs/ansible-20261017T163252Z-3684981.log` e
  `artifacts/logs/ansible-20261017T163604Z-3697997.log`.
- Sem migracao destrutiva .NET/Snap nem remocao automatica da CLI nativa.
- Proximo passo: abrir nova sessao do terminal para carregar profile e prompt;
  confirmar aparencia no terminal grafico, nao validada visualmente aqui.

## Modularizacao dos Templates

- Data: 2026-10-17. Solicitacao posterior: adotar o mesmo modo de templates
  individuais do projeto de referencia, mantendo Docker Hub e npm publicos.
- Funcoes extraidas para `node.sh.j2`, `npm.sh.j2`, `npx.sh.j2`, `ng.sh.j2`,
  `op.sh.j2`, `lh.sh.j2` e `lhr.sh.j2`; instaladas por loop Ansible com modo
  `0600` e `bash -n` antes da substituicao.
- Runtime central mantem ambiente/executor/auditoria e carrega os arquivos,
  removendo as variaveis auxiliares apos a importacao.
- Mantidos cores e padroes sem glob local no ZSH, migracao de aliases antigos,
  execucao de op por wrapper, imagem `cpu-v1` e preservacao do ambiente.
- Os 13 testes focados de funcoes em Bash/ZSH passaram.
- Os sete testes do wrapper/container tambem passaram: 20 testes focados no total.
- Sintaxe do playbook, yamllint, ansible-lint focado, Bash/ZSH `-n`, ShellCheck
  e shfmt dos sete templates e do runtime renderizado passaram. No carregador,
  SC1090 foi excluido por importar caminhos dinamicos do home; os arquivos
  importados foram verificados individualmente. SC2016 permanece excluido
  somente nos testes por expansao intencional no subprocesso.
- Validacao inicial isolada; a aplicacao posterior da modularizacao esta
  registrada em Efetivacao Git e Funcoes abaixo.

## Role Git Independente

- Data: 2026-10-17. Solicitacao posterior: portar a estrutura de `git_config`
  da referencia para o destino, sem copiar identidade ou organizacao corporativa.
- Criados defaults, tasks, template e helper Bash. Mantida compatibilidade com
  variaveis `terminal_git_*`; identidade existente preservada quando vazias.
- `.gitconfig` e gerenciado somente pela nova role, incluida antes de terminal
  com tags `git_config`, `terminal` e `development`; backup unico preservado.
- Helper PAT opt-in, restrito a HTTPS/host/organizacao; valor nunca persistido;
  falta de PAT nao permite fallback para credenciais antigas nesse escopo.
- Corrigida a remocao de blocos em profiles inexistentes quando desabilitado.
- Onze testes isolados passaram, incluindo idempotencia, check mode e seguranca.
- Sintaxe do playbook, lint Ansible focado, ShellCheck e shfmt passaram;
  selecao `--list-tasks --tags git_config` validada sem conectar a hosts.
- Validacao inicial sem reaplicacao no desktop; a efetivacao posterior foi
  explicitamente autorizada e esta registrada abaixo.

## Efetivacao Git e Funcoes

- Data: 2026-10-17. Usuario autorizou aplicar as ultimas alteracoes no `vision`.
- Wrapper com inventario privado `vision`, limite `vision` e tags
  `git_config,dotnet_env`; nenhuma migracao destrutiva ou instalacao global.
- Simulacao: `ok=22 changed=3 unreachable=0 failed=0`.
- Aplicacao: `ok=24 changed=3 unreachable=0 failed=0`; atualizado `.gitconfig`,
  instalados os sete arquivos individuais e atualizado o carregador central.
- Reaplicacao: `ok=23 changed=0 unreachable=0 failed=0`; idempotencia comprovada.
- Perfis instalados passaram em `bash -n`/`zsh -n`; as sete funcoes carregam
  em Bash/ZSH sem executar containers. No ZSH, `lhr` usa o alias `noglob`.
- Helper PAT permaneceu desabilitado conforme default; nenhum token persistido.
- Logs: `artifacts/logs/ansible-20261017T165652Z-3767777.log` e
  `artifacts/logs/ansible-20261017T165721Z-3769904.log`.
- Proximo passo: abrir uma nova sessao de terminal para carregar as funcoes
  modulares nos processos interativos existentes.

## Indicadores por Contexto da Pasta

- Data: 2026-10-17. Usuario autorizou corrigir os indicadores sempre visiveis
  e aplicar o ajuste no `vision`.
- Azure CLI, Ansible e Terraform agora dependem apenas dos padroes de arquivos
  de projeto. Removida a ativacao por `POSH_HAS_*` no JSON e a geracao dessas
  variaveis no runtime; valores antigos herdados sao ignorados pelo tema.
- `.azure` isolada nao conta como projeto, evitando falso positivo no home.
- Preservadas as demais edicoes do tema e as funcoes/variaveis do usuario.
- Dezesseis testes Bash/ZSH passaram, incluindo renderizacao real do Oh My
  Posh em pastas/cache temporarios. Pasta vazia, mesmo com flags antigas true,
  nao exibe os rotulos; azure.yaml, ansible.cfg e main.tf ativam apenas seu
  respectivo indicador. A fixture nao executa containers.
- ShellCheck, shfmt, JSON e teste Ansible de profile/ZSH passaram.
- Aplicacao com tags `zsh,dotnet_env`: `ok=23 changed=2 failed=0`.
- Reaplicacao: `ok=23 changed=0 failed=0`; runtime instalado validado em Bash/ZSH
  e JSON instalado identico ao versionado.
- Logs: `artifacts/logs/ansible-20261017T173624Z-3866781.log` e
  `artifacts/logs/ansible-20261017T173701Z-3869021.log`.
- Proximo passo: abrir nova sessao do terminal para conferir o prompt no uso
  grafico; indicadores representam arquivos do projeto, nao apps em execucao.
