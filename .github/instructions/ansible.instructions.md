---
description: "Criar, alterar ou revisar Ansible: playbooks, roles, inventarios, idempotencia, check mode, diff, Vault, ansible-lint e Molecule."
applyTo: "ansible/**,**/*.ansible.yml,**/*.ansible.yaml"
---

# Padroes Ansible

## Estrutura e Dependencias

- Playbooks em `ansible/playbooks/`, roles em `ansible/roles/`, inventarios por
  ambiente em `ansible/inventories/`, dependencias em `ansible/requirements.yml`.
  Crie apenas pastas utilizadas; fixe versoes testadas de collections/roles.
- Documente ansible-core, Python no controller/hosts e Ubuntu suportados. Controller
  roda em Linux/WSL, nao em Windows nativo. Use `uv` para ambientes Python quando aplicavel.
- YAML com dois espacos, tasks descritivas, FQCN (`ansible.builtin.apt`, por exemplo).
- Defaults sobrescreviveis em `defaults/main.yml`, variaveis prefixadas por role;
  valide entradas com `assert` e SO/facts antes de alterar hosts.
- Exija inventario explicito e `--limit` no wrapper para execucoes reais; nao use
  localhost/hosts reais por omissao. Documente tags e alvos.
- `become` so onde necessario; nunca senhas em argumentos/inventarios. Secrets via
  Vault/provedor aprovado, fora do Git, com `no_log: true` e `diff: false` nas tasks sensiveis.

## Ajuda e Simulacao

- Playbooks nao sao CLIs: `ansible-playbook --help` explica o engine, nao o projeto.
  Entrypoints operacionais precisam de wrapper fino Bash/PowerShell com ajuda
  especifica, dependencias, parametros e exemplos reais/simulados.
- Wrapper traduz dry-run/WhatIf para `--check --diff`, mantendo inventario, limite
  e tags; a rota simulada chama check mode em vez de bloquear o engine sem plano.
- Check mode nao garante simulacao de todos os modulos. Nao use `check_mode: false`
  em tasks mutadoras. Consultas indispensaveis com essa opcao exigem comprovacao de
  somente leitura e `changed_when: false`.
- Para modulo sem check mode, pule mutacoes com `when: not ansible_check_mode` e
  apresente limitacao ou interrompa explicando. Nunca anuncie simulacao completa
  de tasks puladas. Trate resultados registrados indefinidos quando tasks nao rodam.
- Diff pode revelar secrets: `diff: false` e `no_log: true` onde necessario.
  Revise lookups/plugins/scripts que podem agir no controller mesmo em check mode.

## Idempotencia e Operacao

- Prefira modulos declarativos a `shell`/`command`, estado desejado explicito e
  handlers para reiniciar servicos somente quando houver mudanca.
- Comandos inevitaveis usam `argv`, `creates`/`removes`, `changed_when` e
  `failed_when` baseados no estado real; nao mascare alteracoes com resultado falso.
- Nao use `state: latest` sem motivo nem `ignore_errors: true` para esconder falhas.
  `block/rescue/always` exige recuperacao real e preservacao do resultado de falha.
- Templates validam configuracao antes de substituir; ownership/modes explicitos
  e citados (`'0644'`). SSH/rede/firewall exigem acesso alternativo e rollback.
- Controle concorrencia com `serial`/`throttle` quando houver risco de indisponibilidade.
  Nao desabilite host-key checking nem reinicie todos os hosts indiscriminadamente.
- Logs no console e no controller em `artifacts/logs/`, unicos por execucao. Configure
  `ANSIBLE_LOG_PATH` absoluto, proteja permissoes e evite vazamento de secrets.

## Validacao

Comandos-modelo: substitua caminhos/alvos pelo ambiente descartavel real.

```bash
yamllint ansible/
ansible-lint ansible/
ansible-playbook -i <inventario-teste> <playbook> --syntax-check
ansible-playbook -i <inventario-teste> <playbook> --list-hosts --list-tasks
ansible-playbook -i <inventario-teste> <playbook> --limit <alvo-teste> --check --diff
```

- Teste ausencia de mutacoes no check mode e primeira/segunda aplicacao: segunda
  deve ter `changed=0`, salvo excecao justificada. Molecule para roles.
- Containers nao provam systemd/desktop; use VM descartavel quando necessario.
  Check mode pode acessar hosts e exigir privilegios: nao teste em hosts reais sem autorizacao.
- Teste wrappers, limites, entradas invalidas, secrets e tasks nao simulaveis;
  informe ferramentas/SSH/ambientes indisponiveis e verificacoes nao executadas.