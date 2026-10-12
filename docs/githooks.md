# Git hooks do projeto

## Sumario

- [Git hooks do projeto](#git-hooks-do-projeto)
  - [Sumario](#sumario)
  - [Objetivo](#objetivo)
  - [Dependencias](#dependencias)
  - [Ativacao local](#ativacao-local)
  - [Comportamento](#comportamento)
  - [Validacao](#validacao)
  - [Seguranca e impacto](#seguranca-e-impacto)
  - [Troubleshooting](#troubleshooting)
    - [Podman ausente](#podman-ausente)
    - [Gitleaks bloqueia o commit](#gitleaks-bloqueia-o-commit)
  - [Recuperacao](#recuperacao)

## Objetivo

Bloquear commits que adicionem possiveis credenciais ou outros segredos. O hook
`.githooks/pre-commit` envia apenas o diff staged ao Gitleaks 8.30.1, seguindo o
mesmo contrato usado pelo Inventory360Api.

## Dependencias

- Git executado em Linux ou WSL.
- Podman CLI com suporte rootless configurado.
- Imagem `lzocateli/gitleaks:8.30.1` disponivel localmente ou acesso autorizado
  ao registry para o primeiro download.

Prepare a dependencia explicitamente:

```bash
podman pull lzocateli/gitleaks:8.30.1
podman image inspect lzocateli/gitleaks:8.30.1 >/dev/null
```

## Ativacao local

A partir da raiz do clone:

```bash
chmod +x .githooks/pre-commit
git config --local core.hooksPath .githooks
git config --local --get core.hooksPath
```

O resultado esperado e `.githooks`. A configuracao deve ser local ao clone; nao
defina esse caminho no `.gitconfig` global, pois isso permitiria que outros
repositorios executassem hooks versionados automaticamente.

## Comportamento

Ao executar `git commit`, o hook:

1. Confirma que `podman` existe no `PATH`; a ausencia bloqueia o commit.
2. Gera `git diff --cached --no-ext-diff --no-textconv`.
3. Envia o diff por stdin para um container efemero e read-only.
4. Executa Gitleaks com `stdin --redact` para ocultar valores encontrados.
5. Propaga o codigo de saida do Gitleaks; qualquer deteccao bloqueia o commit.

Arquivos apenas modificados no working tree, mas ainda nao adicionados ao index,
nao fazem parte da verificacao desse commit.

## Validacao

Valide sintaxe, ativacao e testes:

```bash
sh -n .githooks/pre-commit
test -x .githooks/pre-commit
test "$(git config --local --get core.hooksPath)" = .githooks
bats tests/bash/githooks.bats
```

Para uma verificacao manual segura, adicione ao index apenas um fixture sem
credenciais reais, execute o hook e depois restaure o index. Nunca crie um token
valido para testar deteccao.

O hook escreve somente no console. O Podman pode baixar a imagem quando ela nao
existir; por isso o pull deve ser realizado separadamente durante a preparacao.

## Seguranca e impacto

- O container recebe somente o patch staged pela entrada padrao.
- `--read-only` impede escrita no filesystem interno do container.
- Nenhum diretorio do host e montado no scanner.
- `--redact` reduz exposicao de valores detectados no terminal.
- A tag da imagem e fixa, mas nao equivale a um digest imutavel; atualizacoes
  devem ser revisadas antes de mudar a versao.
- O hook nao substitui varredura no pipeline nem revisao humana.

## Troubleshooting

### Podman ausente

Sintoma: `Gitleaks obrigatorio: Podman nao foi encontrado no PATH.`

```bash
command -v podman
podman info --format '{{.Host.Security.Rootless}}'
```

Instale Podman e corrija os mapeamentos subordinados do usuario antes de tentar
o commit.

### Gitleaks bloqueia o commit

Revise somente nomes e caminhos apresentados com redacao habilitada. Remova o
segredo do arquivo e do index, revogue-o caso seja real e execute novamente:

```bash
git diff --cached --name-only
git diff --cached --check
```

Nao desative a redacao nem imprima o valor para diagnosticar.

## Recuperacao

Para desativar a integracao neste clone sem remover os arquivos versionados:

```bash
git config --local --unset core.hooksPath
```

Reative somente depois de corrigir Podman, imagem ou configuracao. A desativacao
remove uma barreira de seguranca e deve ser temporaria e justificada.
