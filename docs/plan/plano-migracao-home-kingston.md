# Plano de migracao do home para o Kingston

## Sumario

- [Plano de migracao do home para o Kingston](#plano-de-migracao-do-home-para-o-kingston)
  - [Sumario](#sumario)
  - [Status do Plano](#status-do-plano)
  - [Objetivo e limites](#objetivo-e-limites)
  - [Evidencias](#evidencias)
  - [Arquitetura proposta](#arquitetura-proposta)
  - [Backup externo por SSH](#backup-externo-por-ssh)
  - [Confirmacao antes da aprovacao](#confirmacao-antes-da-aprovacao)
  - [Pre-condicoes](#pre-condicoes)
  - [Etapas](#etapas)
  - [Validacao e aceite](#validacao-e-aceite)
  - [Recuperacao](#recuperacao)
  - [Auditoria e pendencias](#auditoria-e-pendencias)

## Status do Plano

| Campo | Valor |
| --- | --- |
| Status geral | Bloqueado |
| Data da avaliacao e ultima atualizacao | 2026-10-14 |
| Progresso | Capacidade avaliada e pasta remota criada; 0 de 6 etapas de migracao executadas |
| Viabilidade | Viavel por capacidade e compatibilidade; execucao condicionada aos gates abaixo |
| Evidencias | Consultas locais e SSH; preflight de aprovacao encontrou bloqueios registrados abaixo |
| Proximo passo | Usuario executar consultas privilegiadas e preparar acesso independente; nao aprovar execucao ainda |

O pedido autoriza planejamento e criacao da pasta remota, nao a migracao nem
o envio dos arquivos. Nao foram alterados dados pessoais, montagens, cadastro
do usuario, pacotes ou servicos. A unica mutacao operacional foi a criacao
autorizada dos diretorios privados de backup remoto, com log local.

## Objetivo e limites

Mover dados para `/mnt/kingston/home/lzocateli`, preservando `/home/lzocateli`
por montagem bind. Alvo observado: Ubuntu Desktop 26.04.1 LTS, x86_64,
usuario UID/GID 1000/1000 com ZSH. Manter Nextcloud no caminho atual e
`ubuntu_desktop_home: /home/lzocateli`. Nao formatar ou reparticionar discos.

Pacotes de sistema permanecem na raiz; SDKs e dados instalados dentro do home
acompanham a migracao. Nao implementar scripts ou roles nesta fase: a role
`storage` esta vazia, nao integra o playbook e as montagens sao manuais.

## Evidencias

GiB arredondados, derivados de `df -B1` e `du -x -B1`:

| Item | Resultado em 2026-10-14 |
| --- | --- |
| SSD do sistema | ADATA IM2P33F3A NVMe, `/dev/nvme1n1` |
| Raiz | `/dev/nvme1n1p2`, ext4; 74,5 GiB usados, 369,0 GiB disponiveis |
| SSD de destino | KINGSTON SNVS1000G NVMe, `/dev/nvme0n1` |
| Destino | `/dev/nvme0n1p2`, ext4; 25,4 GiB usados, 843,8 GiB disponiveis |
| UUID Kingston | `cb2ee1fc-a783-4b55-a441-b648a24c0dc6` |
| Inodes livres | 61.012.291 de 61.046.784 |
| Home medido | Pelo menos 35,3 GiB; 66 erros de acesso, total nao definitivo |
| `.local` / `.vscode` / `.var` | Pelo menos 20,9 / 3,5 / 2,9 GiB |
| `.config` / `.dotnet` / `.cache` | Pelo menos 2,7 / 2,0 / 1,7 GiB |
| Nextcloud no destino | 25,4 GiB, medicao sem erros |
| Permissoes atuais | Home `0750`, Kingston `0700`, Nextcloud `0750`; UID/GID 1000/1000 |
| Home cadastrado | `/home/lzocateli`, sem montagem propria ou aninhada observada |
| Podman graphroot | `/home/lzocateli/.local/share/containers/storage` |
| Containers ativos | 11; nenhuma interrupcao realizada |

O espaco livre excede inclusive todo o espaco usado na raiz. A capacidade e
suficiente, mas a medicao completa e de tamanho aparente continua obrigatoria.

`findmnt --verify --verbose`: zero erros e cinco avisos, sendo quatro consultas
de tipo em disco sem permissao e um aviso sobre `/swap.img` como arquivo.
Isso nao comprova integridade do filesystem ou do hardware.

`smartctl` e `nvme` indisponiveis: saude fisica nao verificada. `lsblk` nao
mostrou camada LUKS; isso nao descarta criptografia por arquivo. O destino
ext4 nao garante, por si so, protecao criptografica dos segredos do home.

## Arquitetura proposta

```text
/mnt/kingston/Nextcloud         (inalterado)
/mnt/kingston/home/lzocateli    (dados fisicos)
/home/lzocateli                (bind do diretorio acima)
```

Entradas propostas para `/etc/fstab`, nao aplicadas:

```fstab
UUID=cb2ee1fc-a783-4b55-a441-b648a24c0dc6 /mnt/kingston ext4 defaults,x-gvfs-show 0 2
/mnt/kingston/home/lzocateli /home/lzocateli none bind,x-systemd.requires-mounts-for=/mnt/kingston 0 0
```

Substituir apenas a entrada existente do Kingston, retirando `nofail`, e
adicionar a bind sem duplicacao. Preservar raiz, EFI e swap. Comprovar a
dependencia e ordem de montagem em VM com o systemd do alvo.

Falha do Kingston deve impedir boot normal, sem permitir login e gravacoes
em home alternativo. Nao usar `nofail` ou automount para contornar essa falha.
Nao sera usado USB. Antes da troca, validar acesso ao console fisico e uma
rota administrativa de recuperacao pelo GRUB independente do home migrado.
O modo de emergencia pode nao oferecer login root utilizavel; nao presumir
que SSH estara disponivel se o boot falhar. Sem rota comprovada, nao migrar.

## Backup externo por SSH

Destino autorizado e criado:

```text
interserver-st56165:/home/st56165/baskups/home-lzocateli-2026-10-14/
```

O caminho inicialmente solicitado `/baskups` nao existe e o usuario remoto
nao pode criar diretorios na raiz. O usuario aprovou o destino alternativo
acima. Ambos os diretorios criados tem modo `0700`, UID/GID 1179/1181.

SSH com `BatchMode=yes`, `StrictHostKeyChecking=yes` e timeout de conexao
funcionou. Home remoto em ZFS `vz/st56165`, com aproximadamente 439 GiB livres,
opcoes `nosuid,nodev,noatime,xattr,noacl`; rsync remoto disponivel. A raiz
remota e tmpfs e nao deve ser usada como armazenamento de backup. `quota -s`
emitiu erros sobre `/dev/md0`; quota efetiva e limites do provedor continuam
pendentes. O espaco informado nao equivale a garantia de quota disponivel.

Nao copiar o home como arvore comum via rsync sem tratamento de metadados:
o destino tem `noacl` e usuario diferente, impossibilitando presumir preservacao
direta de ACLs e UIDs/GIDs subordinados. Usar arquivo GNU tar que preserve ACLs,
xattrs, IDs numericos, hard links, arquivos esparsos e symlinks, sem segui-los.
Validar as opcoes e restauracao no ensaio. Criptografar localmente esse arquivo
antes da transferencia, por exemplo com age e chave publica aprovada; manter
a chave privada de recuperacao fora do home e fora do servidor de backup.
SSH protege o transporte, nao os segredos armazenados no servidor.

Gerar o backup consistente com workloads e usuario parados. Pode ser preparado
fora de `/home/lzocateli`, no Kingston, antes de transferir o arquivo cifrado;
essa copia local so sera backup independente depois de validada no servidor.
Reservar espaco para staging e copia final, conferir checksum local/remoto do
arquivo cifrado e testar restauracao isolada com acesso administrativo.
Preparar autenticacao SSH na sessao administrativa antes de encerrar o usuario;
nao presumir disponibilidade do agente 1Password ou copiar chaves privadas.

Nenhum arquivo pessoal foi enviado. A pasta vazia nao constitui backup.

## Confirmacao antes da aprovacao

Verificacao adicional realizada em 2026-10-14, sem interromper sessoes ou workloads:

| Gate | Resultado | Acao necessaria |
| --- | --- | --- |
| Capacidade Kingston | Confirmada; aproximadamente 843,8 GiB livres | Revalidar na janela de copia |
| SSH e pasta externa | Confirmados; ZFS persistente e diretorios `0700` | Manter validacao estrita de host key |
| Capacidade externa informada | 471.053.238.272 bytes livres, aproximadamente 438,7 GiB | Confirmar quota efetiva com provedor |
| Quota ZFS | Nao confirmada; CLI informa modulos ZFS indisponiveis no ambiente remoto | Administrador/provedor consultar limites; nao carregar modulos |
| GNU tar | 1.35, com ACLs, xattrs, IDs numericos e sparse | Ensaiar arquivamento e restauracao isolados |
| Criptografia age | Indisponivel localmente | Preparar ferramenta e chave publica; guardar chave privada fora do home |
| Saude NVMe | Nao confirmada; smartctl e nvme ausentes | Preparar ferramenta e consultar saude com acesso administrativo |
| Tamanho completo do home | Bloqueado; `sudo -n` exige senha | Usuario executar medicao privilegiada no proprio terminal |
| Administracao independente | Nao preparada; somente root e lzocateli listados como contas com shell utilizavel | Preparar sessao administrativa fora do home; cadastro root nao comprova login habilitado |
| SSH de entrada no desktop | ssh.service e ssh.socket nao instalados | Usar TTY local ou preparar acesso SSH separado apos autorizacao |
| Servicos persistentes do usuario | Linger=no; duas sessoes ativas | Encerrar sessoes e workloads somente na janela autorizada |
| Recuperacao GRUB | Nao comprovada; menu hidden, timeout 0, grub.cfg sem leitura para o usuario | Validar console e rota de recuperacao antes da troca |
| Backup restauravel | Nao produzido; pasta remota vazia | Gerar backup cifrado e comprovar restauracao antes da troca |
| Ensaio de montagem e rollback | Nao realizado | Validar em VM descartavel antes de alterar o host |

Nao aprovar a execucao da migracao como pronta enquanto esses gates estiverem
pendentes. Consultas nao comprovam capacidade real de escrita remota, checksum,
restauracao ou boot. A verificacao de GRUB exige acompanhamento e possivelmente
reboot autorizado; nao foi feito reboot nesta avaliacao.

Comandos somente de leitura para o usuario executar em seu proprio terminal,
digitando eventual senha diretamente nele, nunca no chat:

```bash
sudo du -x -B1 -s /home/lzocateli
sudo du -x -B1 --apparent-size -s /home/lzocateli
sudo findmnt --verify --verbose
sudo awk '/^[[:space:]]*menuentry .*recovery/ { count++ } END { print "Entradas recovery:", count+0 }' /boot/grub/grub.cfg
```

Esses comandos nao alteram dados, mas a medicao de um home ativo pode variar e
nao comprova consistencia. Compartilhar apenas totais e diagnosticos sem dados
sensiveis. Instalar ferramentas, criar conta administrativa, alterar GRUB ou
habilitar SSH sao mudancas separadas, ainda nao autorizadas ou realizadas.

## Pre-condicoes

- Aprovacao explicita, janela de indisponibilidade e backup independente do Kingston.
- Backup restauravel, incluindo segredos e dados consistentes dos containers.
- Sessao administrativa independente em TTY ou SSH local, com home fora de `/home/lzocateli`.
- Console fisico e recuperacao GRUB testados; nao depender do SSH remoto para reparar boot local.
- Acesso administrativo preparado pelo usuario; nao autoelevar nem solicitar senhas em logs.
- Confirmar quota remota, criptografia, chave de recuperacao e teste de restauracao externa.
- `rsync` 3.4.1 observado, com ACLs e xattrs; `getfacl` disponivel.
- Obter `smartmontools` ou `nvme-cli` separadamente por fonte confiavel, se necessario.
- Medir tamanho ocupado e aparente com acesso completo; erros bloqueiam o avancamento.
- Inventariar links, montagens, servicos do usuario e volumes externos dos containers.
- Verificar criptografia e impacto de centralizar home e Nextcloud no mesmo SSD.
- Confirmar UUID e ausencia de symlinks no caminho de destino.
- Reservar tamanho completo do home mais 20% de margem, considerando crescimento futuro.
- Nunca aplicar `chown -R`: dados Podman podem ter UIDs/GIDs subordinados legitimos.

## Etapas

1. **Aprovar e preparar.** Verificar saude NVMe, tamanho completo, destino, dependencias
   e acesso administrativo independente. Identificar bancos de dados e obter
   backups consistentes das aplicacoes. Preparar backup remoto e recuperacao
   sem USB. Registrar horario UTC e versoes.
2. **Ensaiar em VM descartavel.** Reproduzir ext4, bind e systemd. Testar copia com
   ACLs, xattrs, hard links, arquivos esparsos e UIDs subordinados. Testar boot,
   destino ausente e rollback. Nao simular falha no desktop real.
3. **Congelar o home e copiar.** Em sessao administrativa independente, encerrar
   ordenadamente containers, Nextcloud e servicos; impedir reinicio automatico,
   incluindo servicos com linger, e encerrar todas as sessoes de lzocateli.
   Verificar ausencia de processos e gravacoes no home. O sistema continua
   ligado, mas o home fica inativo. Gerar, enviar e validar backup cifrado remoto
   antes da troca; copiar para Kingston somente apos verificar UUID e destino.
   Nao copiar bancos ativos. Esta fase nao pode ocorrer dentro do VS Code do usuario.
4. **Conferir e configurar.** Comparar conteudos e metadados; falhas bloqueiam a
   troca. Preservar home antigo na origem sob nome de backup sem colisao. Criar
   ponto de montagem vazio e inacessivel ao usuario quando desmontado. Salvar
   fstab original e aplicar apenas as entradas aprovadas no sistema instalado.
5. **Reiniciar e validar.** Testar boot, bind, login, aplicativos e workloads;
   manter copia antiga e backup independente ate aceitar a migracao.
6. **Liberar espaco apos aceite.** Excluir home antigo somente com nova confirmacao,
   verificacao do caminho e backup valido. Nao automatizar essa exclusao.

Perfil proposto de copia: `rsync -aHAXSx --numeric-ids`, executado com acesso
administrativo. Usar barras finais nos caminhos para copiar o conteudo do home;
preservar IDs, permissoes, timestamps, links, ACLs, xattrs e arquivos esparsos.
`-x` nao copia filesystems aninhados: trata-los separadamente conforme inventario.
Nao seguir symlinks nem usar `--delete`. Verificar caminhos e montagens pela
sessao administrativa independente antes de copiar. Nao isolar targets systemd
ou encerrar o usuario sem garantir que o canal administrativo permanecera acessivel.

Simulacao: `--dry-run --itemize-changes` com os mesmos caminhos validados;
nao comprova escrita, saude ou boot. Nao houve simulacao de copia nesta avaliacao.

## Validacao e aceite

- Backup remoto cifrado com checksum correspondente e restauracao isolada comprovada.
- Copia com home inativo completa, sem falhas de leitura/escrita ou erros ignorados.
- Comparacao final rsync em dry-run com checksum e mesmos atributos, sem diferencas
  inesperadas; identificar arquivos extras no destino sem exclui-los.
- Conferir ACLs, xattrs, IDs subordinados, links e amostras de arquivos esparsos.
- `findmnt --verify` com acesso administrativo, sem erros; esclarecer avisos.
- Em VM, conferir unidades systemd e dependencia Kingston antes da bind.
- No host, `findmnt -T /home/lzocateli` mostra Kingston com subpasta esperada,
  UUID correto e cadastro inalterado; repetir reboot para provar persistencia.
- Testar login grafico, ZSH, SSH, VS Code, .NET/certificados, Flatpak e keyring.
- Validar Podman rootless, graphroot inalterado, volumes e todos os workloads.
- Nextcloud permanece em `/mnt/kingston/Nextcloud`, sem sincronizacao inesperada.
- Repetir comparacao com ambos os lados congelados antes de liberar origem;
  nenhuma diferenca inesperada. Isso nao substitui testes dos aplicativos.

Nao reinstalar aplicativos por padrao: o caminho logico do home nao muda.

## Recuperacao

1. Usar sessao administrativa independente ou recuperacao GRUB previamente testada;
   identificar discos por UUID, nao por nome NVMe. Se o boot falhar, nao contar com SSH.
2. Se houve uso do novo home, salvar primeiro suas alteracoes em backup separado;
   o home antigo nao contem os dados criados depois da troca.
3. Com homes inativos, restaurar fstab salvo: remover bind e recuperar politica
   anterior do Kingston, preservando outras mudancas posteriores.
4. Confirmar ponto original desmontado, remover somente diretorio vazio preparado
   para bind e devolver home antigo ao caminho `/home/lzocateli`.
5. Conferir cadastro, ownership e montagens; reiniciar e validar login.

Se a copia antiga foi removida, a recuperacao depende do backup independente.
Nunca apagar novo home no rollback nem desmontar home em sessao ativa.

## Auditoria e pendencias

Consultas realizadas: `df`, `lsblk`, `findmnt`, `getent`, `uname -m`, `stat`,
`du -x -B1`, `rsync --version`, `systemctl show`, `podman info --format` e
`podman ps --format`. Estado Git limpo antes deste plano. Consultas Podman
nao iniciaram workloads, mas podem envolver estado interno normal da ferramenta.

Pendentes: SMART, tamanho completo/aparente, criptografia, backup/restauracao,
quota remota, acesso administrativo independente, recuperacao GRUB, ensaio em VM,
copia com home inativo e boot. Nenhum pacote foi instalado.

Preflight adicional: `sudo -n du` falhou por exigir senha; nao houve nova tentativa
de elevacao. Consulta remota `zfs get` falhou por indisponibilidade dos modulos
no ambiente exposto; nao foi tentado `modprobe`. Nenhum desses gates foi marcado
como concluido. Configuracao GRUB consultada sem expor hashes ou credenciais.

Consulta SSH confirmou ZFS persistente, rsync e permissoes. A criacao autorizada
da pasta remota foi verificada com `stat` e `findmnt`. Evidencia local:
`artifacts/logs/backup-dir-20261015T002041512668313-1302611.log`.
O timestamp do log e UTC, correspondente a 2026-10-14 no horario local.
Nao foram enviados dados nem interrompidos containers ou sessoes.

Execucao futura exige logs protegidos em `artifacts/logs/`, com timestamp UTC,
nivel, identificador unico e modo real/simulado. Nao registrar segredos,
conteudo pessoal ou listagens extensas de arquivos. Falha de logging deve
impedir mutacoes; exportar evidencia necessaria para fora da origem antes da
janela offline. Este plano nao e uma automacao implementada ou validada.