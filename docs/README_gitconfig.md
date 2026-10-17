# Configuracao Git gerenciada

## Sumario

- [Configuracao Git gerenciada](#configuracao-git-gerenciada)
  - [Sumario](#sumario)
  - [Objetivo](#objetivo)
  - [Arquivo e propriedade](#arquivo-e-propriedade)
  - [Identidade](#identidade)
  - [Comportamento principal](#comportamento-principal)
  - [Commits e branches](#commits-e-branches)
  - [Fetch pull push e rebase](#fetch-pull-push-e-rebase)
  - [Reutilizacao de conflitos](#reutilizacao-de-conflitos)
  - [Diff com VS Code](#diff-com-vs-code)
  - [Merge com VS Code](#merge-com-vs-code)
  - [Ordenacao ajuda e colunas](#ordenacao-ajuda-e-colunas)
  - [Credenciais](#credenciais)
  - [Aplicacao e validacao](#aplicacao-e-validacao)
  - [Riscos e recuperacao](#riscos-e-recuperacao)

## Objetivo

Explicar cada parametro do `.gitconfig` criado pela role Ansible `git_config` no
Ubuntu Desktop 26.04 LTS. O estado foi definido para o usuario `lzocateli`, com
line endings Linux, operacoes explicitas e integracao com Visual Studio Code.

O template de origem e
[`ansible/roles/git_config/templates/gitconfig.j2`](../ansible/roles/git_config/templates/gitconfig.j2).

A estrutura segue a referencia: defaults, tasks, template e arquivo do
credential helper em uma role independente. O controller requer Ansible
conforme o [guia operacional](automacao-ansible.md); no alvo, Git e Bash 4.4+.
Nao depende de rede ou sessao grafica para configurar o Git. VS Code so e
necessario ao usar os comandos de editor, diff ou merge.

## Arquivo e propriedade

O Ansible cria `/home/lzocateli/.gitconfig` com proprietario e grupo `lzocateli` e
modo `0600`. O proprio Git valida a sintaxe antes da substituicao. Se ja existir
um arquivo, uma copia unica e preservada em `~/.gitconfig.pre-ansible`.

O comentario inicial informa que o arquivo e gerenciado. Alteracoes manuais sao
substituidas na proxima aplicacao; mudancas permanentes devem ser feitas nas
variaveis do inventario ou no template.

## Identidade

| Parametro | Valor | Significado |
| --- | --- | --- |
| `user.name` | `git_config_user_name` | Nome gravado como autor e committer dos novos commits. |
| `user.email` | `git_config_user_email` | E-mail gravado como autor e committer dos novos commits. |

O filtro Jinja `to_json` gera uma string corretamente escapada no arquivo. A
identidade nao autentica o usuario no servidor Git e nao deve conter tokens.

Por compatibilidade, os defaults usam `terminal_git_user_name` e
`terminal_git_user_email` quando essas variaveis legadas existem no inventario.
Os nomes novos tem precedencia. Se nome e email efetivos estiverem vazios,
a role preserva a identidade do `.gitconfig` atual. Configure ambos juntos;
um perfil novo pode ficar sem identidade ate ela ser informada explicitamente.
`git_config_group` assume o grupo com o mesmo nome de `ubuntu_desktop_user`.

## Comportamento principal

| Parametro | Valor | Significado |
| --- | --- | --- |
| `core.editor` | `code --wait` | Abre o VS Code para mensagens de commit e aguarda o fechamento do editor. |
| `core.autocrlf` | `input` | Converte CRLF para LF ao adicionar arquivos, sem converter LF para CRLF no checkout. |
| `core.eol` | `lf` | Usa LF quando o Git precisa normalizar o fim de linha no working tree. |
| `core.safecrlf` | `warn` | Avisa quando a conversao de fim de linha pode nao ser reversivel. |
| `core.filemode` | `true` | Rastreia alteracoes no bit executavel, comportamento apropriado no Linux. |
| `core.ignorecase` | `false` | Trata nomes com caixa diferente como caminhos distintos. |
| `core.quotepath` | `false` | Exibe caracteres nao ASCII nos caminhos em vez de sequencias octais. |
| `sequence.editor` | `code --wait` | Usa o VS Code para editar a lista de um rebase interativo. |

`core.autocrlf=input` nao substitui regras `.gitattributes` do repositorio. Para
arquivos com requisitos especificos, o `.gitattributes` continua sendo a fonte
mais precisa.

## Commits e branches

| Parametro | Valor | Significado |
| --- | --- | --- |
| `init.defaultBranch` | `main` | Define `main` como branch inicial de novos repositorios. |
| `commit.verbose` | `true` | Inclui o diff no editor da mensagem de commit; o diff nao entra na mensagem final. |

## Fetch pull push e rebase

| Parametro | Valor | Significado |
| --- | --- | --- |
| `fetch.prune` | `true` | Remove referencias remotas locais que deixaram de existir no remoto. |
| `fetch.pruneTags` | `true` | Remove tags locais ausentes no remoto durante fetch com prune. |
| `pull.ff` | `only` | Permite `git pull` apenas quando for possivel fazer fast-forward. |
| `push.default` | `simple` | Envia a branch atual para a branch upstream de mesmo nome. |
| `push.autoSetupRemote` | `true` | Configura automaticamente o upstream no primeiro push de uma branch. |
| `push.followTags` | `true` | Envia tambem tags anotadas alcancaveis pelos commits enviados. |
| `rebase.autoStash` | `true` | Guarda e restaura alteracoes locais automaticamente durante rebase. |
| `rebase.updateRefs` | `true` | Atualiza outras branches locais que apontavam para commits reescritos. |

`pull.ff=only` evita merges implicitos. Quando os historicos divergirem, revise o
estado e escolha explicitamente `git rebase` ou `git merge`.

`fetch.pruneTags=true` pode remover uma tag somente local. Publique tags que
precisam ser preservadas ou desabilite esse parametro no template.

## Reutilizacao de conflitos

| Parametro | Valor | Significado |
| --- | --- | --- |
| `rerere.enabled` | `true` | Registra como um conflito foi resolvido para reutilizar a solucao depois. |
| `rerere.autoupdate` | `true` | Atualiza o index automaticamente quando uma resolucao gravada e reaplicada. |

Antes de concluir merge ou rebase, revise resolucoes reaplicadas com `git diff
--staged`.

## Diff com VS Code

| Parametro | Valor | Significado |
| --- | --- | --- |
| `diff.tool` | `vscode` | Define o bloco `difftool.vscode` como ferramenta padrao. |
| `diff.algorithm` | `histogram` | Usa o algoritmo histogram, geralmente mais legivel em codigo-fonte. |
| `diff.colorMoved` | `zebra` | Destaca linhas movidas e alterna cores entre blocos adjacentes. |
| `diff.mnemonicPrefix` | `true` | Usa prefixos contextuais, como working tree e index, no lugar de `a/` e `b/`. |
| `difftool.prompt` | `false` | Nao solicita confirmacao antes de abrir cada comparacao. |
| `difftool.vscode.cmd` | `code --wait --diff "$LOCAL" "$REMOTE"` | Abre os dois lados no comparador do VS Code e aguarda seu fechamento. |

`$LOCAL` e `$REMOTE` sao arquivos temporarios fornecidos pelo `git difftool`.
Aspas protegem caminhos que contenham espacos.

## Merge com VS Code

| Parametro | Valor | Significado |
| --- | --- | --- |
| `merge.tool` | `vscode` | Define o bloco `mergetool.vscode` como ferramenta padrao. |
| `merge.conflictStyle` | `zdiff3` | Mostra os dois lados e a base comum, omitindo trechos repetidos nas bordas. |
| `mergetool.prompt` | `false` | Nao solicita confirmacao antes de abrir cada conflito. |
| `mergetool.keepBackup` | `false` | Remove o arquivo `.orig` depois que a ferramenta termina. |
| `mergetool.vscode.cmd` | `code --wait --merge "$REMOTE" "$LOCAL" "$BASE" "$MERGED"` | Abre o Merge Editor do VS Code com remoto, local, base e resultado. |
| `mergetool.vscode.trustExitCode` | `true` | Confia no status de saida do VS Code para considerar a ferramenta concluida. |

As variaveis `$REMOTE`, `$LOCAL`, `$BASE` e `$MERGED` sao fornecidas pelo Git.
Como backups `.orig` ficam desabilitados, confirme o resultado com `git diff`
antes de concluir o merge.

## Ordenacao ajuda e colunas

| Parametro | Valor | Significado |
| --- | --- | --- |
| `branch.sort` | `-committerdate` | Lista primeiro as branches com commits mais recentes. |
| `tag.sort` | `version:refname` | Ordena tags como versoes, por exemplo `v2.9` antes de `v2.10`. |
| `column.ui` | `auto` | Usa colunas automaticamente quando o terminal e a saida permitem. |
| `help.autocorrect` | `0` | Sugere alternativas sem executar uma correcao automaticamente, como na referencia. |

## Credenciais

| Parametro | Valor | Significado |
| --- | --- | --- |
| `credential.useHttpPath` | `true` | Inclui o caminho da URL na chave usada para localizar uma credencial HTTPS. |

Esse comportamento permite credenciais diferentes para organizacoes ou caminhos
no mesmo host, mas pode criar entradas repetidas quando todos os repositorios
usam o mesmo token.

Por padrao, nenhum `credential.helper`, token ou senha e gravado. A integracao
Azure DevOps da referencia esta disponivel como opt-in, sem identidade ou
organizacao corporativa predefinida:

```yaml
git_config_azure_devops_pat_enabled: true
git_config_azure_devops_organization: example-org
git_config_azure_devops_username: example-user
```

O helper e instalado em
`~/.local/lib/ubuntu-desktop/git-credential-azure-devops.sh`, modo `0700`.
Ele so fornece `AZURE_DEVOPS_EXT_PAT` para HTTPS em `dev.azure.com` e para o
caminho da organizacao configurada. O PAT vem do ambiente do processo Git:
nao e consultado nem persistido pelo Ansible. Os blocos em `.profile`,
`.bashrc` e `.zshrc` contem somente `export AZURE_DEVOPS_EXT_PAT`, sem valor,
preservando atribuicoes pessoais fora desses blocos.

No escopo autorizado, helpers anteriores sao zerados e a falta de PAT encerra
a autenticacao sem tentar credenciais antigas. Outros hosts/organizacoes nao
recebem o token deste helper. `store` e `erase` nao gravam nem apagam dados.
O helper nao faz rede ou mutacoes, nao cria logs em arquivo e reserva stdout
ao protocolo de credenciais Git; erros e `--verbose` usam stderr sem valores.
Retorna 0 em sucesso, 1 para PAT ausente/invalido e 2 para erro de uso.
Nao imprima `git credential fill` nem habilite `set -x` com credenciais reais.

Ajuda e simulacao do helper, sem PAT:

```bash
bash ansible/roles/git_config/files/git-credential-azure-devops.sh --help
printf 'protocol=https\nhost=dev.azure.com\npath=example-org/projeto/_git/repo\n\n' |
  bash ansible/roles/git_config/files/git-credential-azure-devops.sh \
    --organization example-org --username example-user get --dry-run
```

Aliases: `-help`, `-h` e `-dryrun`. Opcoes `--organization` e `--username`
sao obrigatorias para operacoes; `--` encerra opcoes. Ajuda nao le stdin nem
requer parametros. A simulacao valida o escopo sem emitir credenciais.
Desabilitar `git_config_azure_devops_pat_enabled` remove helper, escopo Git e
blocos gerenciados, sem apagar valores pessoais. Use SSH ou um helper aprovado
para outros fluxos; integracao biometrica 1Password exige configuracao propria
e nao e fornecida pela CLI em container.

## Aplicacao e validacao

Simule e aplique somente em um alvo autorizado:

```bash
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01 --tags git_config --dry-run --verbose
bash scripts/bash/run-ansible.sh \
  --inventory ansible/inventories/private/lab/hosts.yml \
  --limit workstation01 --tags git_config
```

Valide sem exibir segredos:

```bash
stat -c '%U:%G %a %n' "$HOME/.gitconfig"
git config --global --get user.name
git config --global --get user.email
git config --global --get core.autocrlf
git config --global --get init.defaultBranch
git config --global --name-only --list
```

`--tags terminal` e `--tags development` tambem incluem a role para manter
compatibilidade com comandos anteriores. A role `terminal` nao escreve mais
no `.gitconfig`.

Check mode consulta estado/identidade e planeja a configuracao sem alterar
perfis ou helpers; diffs do `.gitconfig`, backup e perfis sao ocultados para
nao expor conteudo preexistente sensivel. Validacao com `git config --file`
roda antes da substituicao e apos a aplicacao real. Logs auditaveis ficam em
`artifacts/logs/` pelo wrapper, sem PAT; nenhum privilegio root e necessario
para a role Git. O preflight do playbook continua validando o usuario-alvo.

Testes isolados, sem rede ou alteracao do Git real:

```bash
bats tests/bash/git-config.bats
shellcheck ansible/roles/git_config/files/git-credential-azure-devops.sh
shfmt -i 2 -ci -d ansible/roles/git_config/files/git-credential-azure-devops.sh
```

Os testes usam perfis temporarios, caminhos com espacos e PAT ficticio; cobrem
`changed=0` na reaplicacao, simulacao sem escritas, limites de organizacao e
ausencia de fallback inseguro. Credenciais reais nao foram testadas aqui.

## Riscos e recuperacao

- O template substitui alteracoes manuais na proxima aplicacao.
- `fetch.pruneTags=true` pode excluir tags somente locais.
- `pull.ff=only` interrompe pulls divergentes para exigir uma decisao explicita.
- `mergetool.keepBackup=false` nao preserva arquivos `.orig`.
- A identidade fica visivel no historico de commits publicados.

Para restaurar temporariamente a configuracao anterior:

```bash
install -m 0600 "$HOME/.gitconfig.pre-ansible" "$HOME/.gitconfig"
git config --global --get core.autocrlf
```

A proxima aplicacao restaura o template. Para uma mudanca permanente, ajuste
`git_config_user_name`, `git_config_user_email` ou o template e valide em
uma VM descartavel antes de aplicar na estacao de trabalho.
