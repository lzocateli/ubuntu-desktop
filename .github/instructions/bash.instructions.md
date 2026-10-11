---
description: "Criar, alterar ou revisar Bash: help, dry-run, seguranca, logs, ShellCheck, shfmt e testes Bats."
applyTo: "**/*.sh,**/*.bash,**/*.bats"
---

# Padrões Bash

## Estrutura e Portabilidade

- Use `#!/usr/bin/env bash`, LF, `set -euo pipefail` e `main` em executáveis Bash.
	Declare versão mínima; não execute Bash com `sh` nem aplique suas regras a POSIX sh.
- Bibliotecas sourced não executam `main` nem alteram opções globais do shell chamador.
- Separe parsing, validação, planejamento e execução em funções pequenas.
- Resolva caminhos via `BASH_SOURCE`; cite expansões e use arrays para argumentos.
	Não use `eval`, comandos compostos como strings ou parsing de `ls`.
- Não confie só em `set -e`: condicionais e pipelines têm exceções. Valide comandos
	críticos explicitamente, preserve falhas com `pipefail` e não mascare status com `tee`.

## Ajuda e Parâmetros

- `usage()` inclui objetivo, dependências, opções/defaults, códigos de saída e exemplos.
	Aceite `--help`, `-help`, `-h`, `--dry-run`, `-dryrun`, `--verbose` e terminador `--`.
- Ajuda sai com zero antes de criar log/pasta ou validar dependências/privilégios.
- Parsing por `case`; valide quantidade antes de acessar `$2`, valores ausentes,
	opções desconhecidas, combinações inválidas e entradas iniciadas com `-`.
- Use código 2 para erro de uso e não zero para erro operacional; documente exceções.
- Não invoque `sudo` automaticamente nem passe senhas em argumentos.

## Simulação e Segurança

- Toda mutação passa por gate de execução: em dry-run, mostre plano e retorne sem agir.
- Redirecionamentos, here-documents, `tee` e substitutions podem escrever; mantenha
	esses efeitos dentro do ramo real, nunca antes da verificação de simulação.
- Separe consultas read-only de mutações. Não instale dependências para consultar estado.
- Mostre argumentos escapados com `printf '%q'`, omitindo secrets; prefira `printf`
	a `echo -e`. Não habilite `set -x` onde houver dados sensíveis.
- Temporários únicos via `mktemp` em `artifacts/`, apenas no modo real; `trap` limpa
	só recursos próprios e preserva status original, inclusive após interrupções.
- Antes de remover, valide caminho não vazio, raiz esperada e escopo; não use
	`rm -rf` em entrada não validada. Não use `curl | bash` ou repositórios não confiáveis.
- Verifique `/etc/os-release` e estado atual antes de `apt-get`/`systemctl`. Não remova
	locks do gerenciador de pacotes; documente ausência de systemd/sessão gráfica.

## Logs

- Console e arquivo único em `artifacts/logs/`, timestamp UTC, nível e modo de execução.
- Erros em stderr; stdout reservado a resultados consumíveis por automação.
- Cores só em TTY e nunca no arquivo; verbose sem secrets. Falha no log impede mutações.

## Validação

Comandos-modelo; substitua `<script>` por arquivo real antes de executar:

```bash
bash -n scripts/bash/<script>.sh
shellcheck scripts/bash/<script>.sh
shfmt -d scripts/bash/<script>.sh
bats tests/bash/
```

- Bats cobre ajuda/aliases sem dependências, entradas inválidas, caminhos com espaços,
	execução fora da raiz, erros, cleanup e idempotência em fixture descartável.
- No dry-run, substitua mutadores por stubs que falham se chamados; compare estado
	antes/depois, descontando apenas o log permitido. Teste efeitos indiretos também.
- Não instale pacotes ou use `sudo` no host real para testes; informe checks indisponíveis.
