---
description: "Criar, alterar ou revisar PowerShell: Help, DryRun, WhatIf, ShouldProcess, logs, Pester e PSScriptAnalyzer."
applyTo: "**/*.ps1,**/*.psm1,**/*.psd1"
---

# Padrões PowerShell

## Estrutura e Compatibilidade

- Prefira PowerShell 7; documente versão mínima e SO. Suporte 5.1 somente se exigido
	e testado; não presuma registry, IIS ou cmdlets Windows no Ubuntu.
- Executáveis usam `[CmdletBinding(SupportsShouldProcess = $true)]` e `param(...)`.
	Exponha `[switch]$Help` e `[switch]$DryRun`; não redeclare `-WhatIf`, `-Confirm`
	ou `-Verbose`, que são parâmetros comuns habilitados por CmdletBinding.
- Comment-based help: `.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`, `.NOTES`
	com dependências, versões e riscos; suporte `Get-Help` e `-Help`.
- Ajuda retorna zero antes de logs/pré-requisitos. Evite `Mandatory` ou validadores
	que impeçam ajuda sem entradas; valide parâmetros operacionais após o gate de ajuda.
- Use `Set-StrictMode -Version Latest`, erros terminantes e `try/catch/finally`.
	Módulos não mudam preferências globais nem usam `exit` para encerrar o chamador.
- Caminhos via `$PSScriptRoot`, `Join-Path`, `-LiteralPath`; dados via APIs estruturadas.
	Não use `Invoke-Expression`; funções públicas com verbos aprovados e parâmetros tipados.

## WhatIf e DryRun

- `-DryRun` ativa `$WhatIfPreference = $true` apenas no escopo local, sem desativar
	um `-WhatIf` recebido; ambos devem impedir mutações.
- Toda mutação, incluindo programas nativos/remoting, fica dentro de
	`if ($PSCmdlet.ShouldProcess($alvo, $acao)) { ... }` no escopo com ShouldProcess.
- Preparação de arquivos também é mutação: não a execute antes do gate. Auxiliares
	recebem/propagam modo e protegem suas próprias mutações.
- Exemplo de gate local, não template completo:

```powershell
if ($DryRun) { $WhatIfPreference = $true }
if ($PSCmdlet.ShouldProcess($TargetPath, 'Atualizar configuracao')) {
		Set-Content -LiteralPath $TargetPath -Value $DesiredContent
}
```

- Apenas logger pode escrever em `artifacts/` no dry-run; documente essa exceção.
	Não gere exports, backups ou temporários gerenciados na simulação.
- Use `ConfirmImpact = 'High'` em ações destrutivas; não suprima confirmação por padrão.
	Não altere execution policy ou autoeleve privilégios para facilitar execução.
- Wrappers Ansible têm rota read-only que chama `--check --diff` na simulação,
	em vez de simplesmente bloquear a chamada ao engine sem apresentar plano.

## Erros e Logs

- Verifique `$LASTEXITCODE` imediatamente após cada nativo. `try/catch` sozinho
	não detecta todos os códigos não zero em todas as versões suportadas.
- Ao capturar stderr (`2>&1`), diferencie saída de `ErrorRecord`; preserve/restaure
	preferências locais em `finally` e valide exit code sem engolir falhas.
- Logs em console e arquivo UTF-8 único em `artifacts/logs/`, timestamp UTC e nível.
	Preserve objetos no success stream; verbose/debug sem secrets ou dump de parâmetros.
- Não use transcript indiscriminado com credenciais. Falha de logging impede mutações.
- Executáveis retornam não zero ao falhar; funções/módulos lançam erros terminantes.
	Cleanup em `finally` restrito aos temporários desta execução.

## Validação

- Valide AST com `System.Management.Automation.Language.Parser`, sem erros.
- Execute `Invoke-ScriptAnalyzer -Path <arquivo> -Severity Warning,Error` e
	`Invoke-Pester -Path <suite> -CI`, substituindo placeholders por caminhos reais.
- Pester cobre `-Help`, `Get-Help`, `-DryRun`, `-WhatIf`, entradas inválidas, falha
	nativa, idempotência, paths com espaços e execução fora da raiz.
- Mocke mutações e afirme zero invocações na simulação; teste remoting/subprocessos.
	Não teste no host real nem instale módulos automaticamente; informe lacunas.
- Usar códigos de saída consistentes em caso de erro.
