<div align="center">

# MyWinISO

**Windows 11 · pt-BR · instalação sem perguntas**

Um pendrive que boota, acha o disco certo, formata, instala o Windows, cria a conta, instala e
configura tudo. Nada de ISO modificada: é a ISO oficial da Microsoft mais um arquivo de resposta
(`autounattend.xml`) que o instalador segue sozinho.

[![Windows 11](https://img.shields.io/badge/Windows_11-26H2-0078D4?style=flat-square&logo=windows&logoColor=white)](https://www.microsoft.com/pt-br/software-download/windows11)
[![Ventoy](https://img.shields.io/badge/Ventoy-auto__install-2E8B57?style=flat-square)](https://www.ventoy.net/en/plugin_autoinstall.html)

</div>

---

> **Apaga o Windows, não os seus arquivos.** O alvo é o Corsair MP700 ELITE (serial `6479A7AABAC014A3`).
> Na primeira instalação o disco inteiro é apagado e nasce a partição **Alexandre** (D:) no fim dele; em toda
> reinstalação só as quatro partições do Windows (EFI, MSR, Windows, Recovery) são apagadas e recriadas no
> mesmo espaço, e a partição Alexandre não é tocada. O C: se chama Win11. Veja "Disco" abaixo.
> O script só particiona se achar exatamente esse disco; qualquer outro cenário aborta antes
> de gravar. Mesmo assim: backup antes.

## O que acontece ao ligar o PC com o pendrive

| Passo | Quem faz | O quê |
|:--|:--|:--|
| 1 | Ventoy | mostra a ISO; em 5 s aplica o `autounattend.xml` sozinho |
| 2 | `instala.vbs` (WinPE) | faz a fase inteira no lugar do Setup: pula TPM/CPU/RAM, procura o disco pelo serial ou modelo via WMI, particiona (EFI 300 MB, MSR, Windows 120 GB, Recovery 1 GB e a partição Alexandre com o resto; numa reinstalação recria só as quatro primeiras e deixa a Alexandre em paz), aplica a imagem `Windows 11 Pro` com o DISM, grava o boot, copia o XML completo para `C:\Windows\Panther` e reinicia pelo disco |
| 3 | Windows | primeiro boot pelo disco; o Setup novo da ISO nunca chega a instalar |
| 4 | `especializar.ps1` | nome `RRR`, fuso de São Paulo, remove bloatware, OneDrive, Copilot e telemetria, UAC sem perguntar, SmartScreen off, Iniciar vazio, perfil padrão já escuro, tweaks de jogo, identidade em Sistema > Sobre |
| 5 | OOBE | conta local `Alexandre` administradora, login automático permanente, sem conta Microsoft, teclado ABNT2 |
| 6 | `primeiro-logon.ps1` | baixa o `setup.ps1` deste repositório e roda; deixa `mywiniso-setup.cmd` na área de trabalho |
| 7 | `setup.ps1` | as 28 etapas abaixo |

Os três scripts dos passos 2, 4 e 6 vivem **dentro** do `autounattend.xml`, na seção `<Extensions>`
no fim do arquivo. Assim o pendrive precisa de um único arquivo, e o Setup ignora a seção. No WinPE,
que não tem PowerShell, um extrator em VBScript gravado por `echo` (cada `<Path>` tem no máximo 255
caracteres, em qualquer passo; o motor de unattend rejeita o arquivo inteiro se um passar) lê o XML pelo MSXML e
solta o `instala.vbs`; nos passos seguintes o PowerShell já existe.

Por que o `instala.vbs` substitui o Setup: o Setup novo do Windows 11 (24H2 em diante) reescreve o arquivo
de resposta para os passos seguintes com só o que ele entende (conta local e bypass) e descarta o resto:
some a seção `<Extensions>`, o `specialize` e o `oobeSystem`, e o OOBE volta a perguntar país e teclado.
Descoberto no teste em VM; é o mesmo motivo do modo "script no lugar do setup.exe" do gerador schneegans.
O `setup.ps1` e o resto ficam fora de propósito: mudam com frequência e são baixados do GitHub
na hora, então o pendrive não envelhece quando a lista de programas muda.

## O que aparece na tela

Cada script mostra o estado real, não uma barra decorativa. E nada pode parecer travado: no `specialize` e no
`setup.ps1` uma thread à parte escreve `... bloco atual | N s | HH:MM:SS` **a cada 10 segundos de silêncio**,
então uma remoção de pacote ou um winget baixando 600 MB continua dando sinal de vida. No WinPE, onde não há
thread, toda linha sai com a hora e cada comando fecha com o tempo que levou e o código de saída; comando que
roda em janela escondida avisa antes que a tela vai ficar parada. Quer dizer: se a hora parou de andar, aí sim
travou de verdade.

- **WinPE**: o `instala.vbs` mostra a janela do DISM aplicando a imagem; o resto vai para `X:\mywiniso\instala.log`,
  que fica copiado em `C:\Windows\Panther\mywiniso-instala.log`. Se falhar, o Bloco de Notas abre com o log.
- **specialize**: cada bloco aparece como `-> nome`, com a hora, os pacotes removidos um a um, e termina em
  `OK (N s)` ou `ERRO` com a mensagem.
- **primeiro logon**: uma janela de console que diz o que está fazendo (espera pela rede com contagem de tentativas,
  download do `setup.ps1`, execução) e **fica aberta até você apertar Enter**, com o resultado na tela. O download
  mostra a resposta do GitHub: código HTTP, servidor, tamanho, `ETag` (que no `raw.githubusercontent` é o sha do
  blob) e a data de modificação, mais o tamanho e as linhas do arquivo gravado — prova de que veio de lá agora.
- **downloads em geral**: cada um diz de que host vem, o código HTTP, o tamanho anunciado e o progresso a cada 10%
  com a velocidade. Os `git clone` vão com `--progress` e, no fim, o commit em que o clone ficou.
- **setup.ps1**: cada etapa como `[n/28] nome`, linhas `- o que está fazendo`, cada programa do winget com `OK`,
  `já instalado` ou `FALHOU (código)`, e no fim de cada etapa `OK`, `AVISO` (erros não fatais, listados) ou
  `ERRO` (a etapa parou, a mensagem aparece). Uma etapa com erro não derruba as seguintes. No final, um resumo
  de todas as etapas com tempo, a lista de programas que falharam e o caminho do log.

Logs: `C:\Windows\Setup\Scripts\especializar.log`, `~\mywiniso.log` (primeiro logon) e `~\mywiniso-setup.log` (setup).

## O que o setup.ps1 faz

Roda no primeiro logon e em qualquer Windows 11 depois (`mywiniso-setup.cmd` ou o `irm` abaixo).

O **Claude Code entra na etapa 4**, antes de tudo que é longo: com ele na mão dá para consertar o que
der errado nas etapas seguintes sem esperar o resto. Depois, as etapas **5 a 12** são as que mudam o que
se vê. Tudo isso vem de propósito antes dos programas (etapa 13, que sozinha leva uns treze minutos): em
uns cinco minutos a máquina já está com o driver da placa, nos 2560x1440 a 180 Hz, no tema escuro, com o
wallpaper e a barra no lugar, e o resto se instala por baixo.

A etapa 8 termina **esperando o Explorer gravar o `TranscodedImageCache_00N`** no registro. Sem essa
espera, o reinício do Explorer na etapa 10 desfaz a atribuição de wallpaper por monitor e o monitor em pé
perde a imagem dele; com ela, sobrevive. Medido nesta máquina, não suposto.

| # | Etapa |
|:--|:--|
| 1 | ponto de restauração antes de mexer em qualquer coisa |
| 2 | garante que o winget funciona e, se a ISO trouxe um velho (o 1.9 não fala mais com a msstore), instala o release atual do GitHub |
| 3 | instala o Git e clona este repositório em `~\Projetos\MyWinISO`; sem Git, baixa o zip e segue |
| 4 | **Claude Code (CLI)** pelo winget, antes de tudo que é longo |
| 5 | **driver de vídeo da NVIDIA**, o mais novo, baixado da própria NVIDIA pela API que a página de download usa; instalado em silêncio com `-s -clean -noreboot` |
| 6 | **monitores**: resolução, frequência, orientação e posição de cada um (`monitores/monitores.json`); tenta três vezes, porque o driver acabou de assumir |
| 7 | **preferências do usuário**: tema escuro, barra centralizada e só no monitor principal, **área de trabalho sem ícone nenhum**, **notificações desligadas**, **Downloads em D:** quando a partição Alexandre (D:) existe, Explorer, teclado, mouse, privacidade (tabela abaixo) |
| 8 | **wallpaper, um por monitor**: paisagem na ASUS, `Real_Dimez_portrait.jpg` na LG em pé, pela `IDesktopWallpaper`; mais a tela de bloqueio. Termina esperando o Explorer persistir a escolha (veja acima) |
| 9 | **foto do perfil** da conta (`perfil/avatar.png`) no Iniciar e na tela de login |
| 10 | **Explorer em Detalhes** em todas as pastas, com as colunas do Alexandre, pelo WinSetView (`explorer/WinSetView/`); reinicia o Explorer, e é aqui que tema e barra passam a valer |
| 11 | **Windhawk** com um tema só, o Translucent do Undisputed00x, em tudo: barra (escurecida), Iniciar, central de notificações, **Explorer e Configurações** (pelo par `translucent-windows` + File Explorer Styler, com o mesmo tint escuro da barra; o styler sozinho dava um cinza lavado), mais reordenar miniaturas da barra, menus escuros e janelas sem borda; tudo por registro, sem abrir o Windhawk. No fim reinicia o `ShellExperienceHost` e o `StartMenuExperienceHost`, senão eles ficam sem tema |
| 12 | **energia e memória**: plano Desempenho Máximo, nunca suspende nem hiberna, tela apaga em 5 minutos; pagefile fixo pelo tamanho da RAM (metade, entre 4 e 16 GB) no C: e compressão de memória desligada |
| 13 | programas do `apps.json`, um a um, com resultado na tela: 44 do winget, e WhatsApp e Bloco de Notas da Loja. Instalador que recusa administrador (o do Spotify) vai por tarefa agendada sem elevação |
| 14 | **Lightshot**: um atalho só, `Shift+PrintScreen`, os outros dois desligados |
| 15 | **Chrome e Discord**: gerenciador de senhas do Chrome desligado (fica só o Proton Pass), Proton Pass e Enhancer for YouTube instalados por política; e o Discord recebe o **Vencord do fork `eualexandrerrr/Vencord`** (plugin `goLiveBypass` e o que mais estiver em `src/userplugins`), clonado em `~\Projetos\Vencord`, buildado com pnpm e injetado com `pnpm inject`. As configurações do Vencord (`%APPDATA%\Vencord`) moram em D: pela etapa 7 |
| 16 | **Jogos**: RedM em `D:\Jogos\RedM` (ou `%LOCALAPPDATA%\RedM` sem a partição Dados) com atalho no menu Iniciar, que é o que a barra fixa; e a biblioteca do Steam semeada em `D:\Jogos\Steam`, que depois de uma formatação volta inteira sem baixar nada. O bootstrapper não tem modo silencioso (só entende `-ctracpkm`), então o primeiro clique ainda baixa o jogo numa janela própria |
| 17 | `git config` com nome e e-mail |
| 18 | Office LTSC Professional Plus 2024 pt-BR pelo Office Deployment Tool (`office/Configuracao.xml`) |
| 19 | Área de Trabalho Remota ligada, senha sem validade, sem bloqueio de conta, scripts liberados |
| 20 | NVIDIA App com instalador silencioso (a URL atual vem da página da NVIDIA) |
| 21 | MariaDB como serviço com os bancos em `D:\Perfil\MariaDB\data` (sobrevivem à formatação; na reinstalação o serviço é registrado em cima deles), root com a senha da conta e acesso remoto; HeidiSQL em modo portátil com as sessões em `D:\Perfil\HeidiSQL` |
| 22 | fonte Cascadia Mono na máquina, no console e no terminal do VS Code |
| 23 | perfil do PowerShell (`powershell/profile.ps1`: atalhos `c` e `x`, histórico com setas, prompt curto) |
| 24 | barra de tarefas, nesta ordem: **Explorer, Chrome, RedM, Discord, VS Code**; tarefa "Startup OnLogon" que arruma as janelas 30 s após entrar. Depois dos programas, porque os pinos precisam dos atalhos existindo (o do VS Code fica em `%AppData%`, porque o winget o instala por usuário) |
| 25 | WSL com Debian: usuário `alexandre` com zsh, sudo sem senha, systemd (`wsl/debian.sh`). Com a partição Dados o disco do Debian fica em `D:\WSL\Debian` e, na reinstalação, volta como estava sem rodar nada |
| 26 | resto dos drivers e as atualizações, pelo Windows Update (o de vídeo já veio na etapa 5); e a **ativação** pela licença digital gravada no hardware (`slmgr /ato` e o estado no resumo) — sem chave e sem ativador, porque esta máquina já tem a licença do Pro vinculada |
| 27 | Windows Terminal instalado, atualizado e como console padrão do sistema, com cinco shells em abas (`terminal/settings.json`) |
| 28 | manutenção: três tarefas de limpeza que rodam sozinhas, a tarefa **Standby list** (o que o Intelligent Standby List Cleaner faz: a cada minuto, se a RAM livre caiu abaixo de um quarto e a standby list passou de 1 GB, esvazia a standby list pela mesma chamada do ISLC, `manutencao/standby.ps1`), a tarefa **Perfil no D** (`manutencao/perfil.ps1`, veja "Perfil dos programas"), armazenamento reservado liberado, sem compartilhar updates com a internet, backup do registro e as tarefas de telemetria de fundo desligadas |

## Programas

`apps.json` é o formato do `winget import`; gerar um novo com `winget export -o apps.json`.

| | |
|:--|:--|
| Dia a dia | Chrome, Google Drive, Discord, WhatsApp, Spotify, Obsidian, Lightshot, Proton Pass, WinRAR, 7-Zip, Bloco de Notas |
| Jogos | Steam, Radmin VPN, OBS Studio, RedM (área de trabalho), NVIDIA App |
| Visual | Windhawk com Taskbar, Start Menu, Notification Center e File Explorer Styler (m417z) nos temas Translucent, Translucent Windows (Undisputed00x), Taskbar Thumbnail Reorder, Dark mode context menus, Invisible Window Borders |
| Dev | Git, GitHub CLI, VS Code, Claude Code, PowerShell 7, Node.js, Bun, Python 3.13, uv, cloudflared, MariaDB, HeidiSQL |
| CLI | Windows Terminal, starship, zoxide, fzf, bat, fd, ripgrep, eza, jq, ffmpeg, rclone, JetBrainsMono Nerd Font |
| Android | Temurin JDK 17, Android Studio, Platform Tools, scrcpy |
| Office | Word, Excel, PowerPoint (sem Access, Outlook, OneNote, Publisher, Lync, OneDrive) |

Insync e Maestro não existem no winget; Google Drive oficial entra no lugar do Insync.

## Arquivos

| | |
|:--|:--|
| `autounattend.xml` | fonte de verdade da instalação: disco, idioma, conta, bloatware, primeiro logon |
| `setup.ps1` | pós-instalação; roda em qualquer Windows 11 |
| `apps.json` | lista do `winget import` |
| `pendrive.ps1` | grava o XML no pendrive sem formatar e sem tocar nas ISOs que já estão lá |
| `ventoy/ventoy.json` | plugin `auto_install` do Ventoy; o `pendrive.ps1` troca o caminho da ISO |
| `office/Configuracao.xml` | Office pelo Office Deployment Tool, que o `setup.ps1` baixa da Microsoft na hora |
| `wallpaper/` | a paisagem dos dois monitores e da tela de bloqueio, e a imagem em retrato do monitor em pé |
| `powershell/profile.ps1` | perfil do PowerShell 7 |
| `taskbar/LayoutModification.xml` | pinos da barra de tarefas |
| `explorer/WinSetView/` | WinSetView (Les Ferch, MIT) com o modo de exibição do Explorer em `AppData/Win10.ini`; ver o README da pasta |
| `manutencao/` | os três scripts que as tarefas de limpeza rodam: limpeza de disco, cache do Update e temporários |
| `monitores/` | `monitores.json` com resolução, Hz, orientação e posição de cada monitor, e o `monitores.ps1` que aplica |
| `terminal/settings.json` | perfis do Windows Terminal: PowerShell 7 (padrão), Windows PowerShell, Prompt de Comando, Debian com zsh e Git Bash |
| `perfil/avatar.png` | foto da conta, redimensionada pelo setup para os tamanhos que o Windows usa |
| `startup/startup-onlogon.ps1` | tarefa de logon: maximiza o Discord, posiciona duas janelas do Chrome no monitor vertical, backup do histórico do terminal |
| `vscode/settings.json` | o que o `setup.ps1` mescla no `settings.json` do VS Code |
| `wsl/debian.sh`, `wsl/wsl.conf` | configuração do Debian no WSL |

## Fazer o pendrive

O pendrive já é Ventoy e já tem a ISO do Windows 11 em Português (Brasil). O script não formata
nada e não mexe nas ISOs. PowerShell como administrador, com o pendrive na letra `E:`:

```powershell
powershell -ExecutionPolicy Bypass -File .\pendrive.ps1 E:                                            # uma ISO só
powershell -ExecutionPolicy Bypass -File .\pendrive.ps1 E: Win11_pt-BR_unattend.iso                   # mais de uma: diga qual
```

- **A senha é perguntada no instalador**, no WinPE, antes de qualquer coisa ser apagada: o `instala.vbs`
  pede duas vezes, compara, e grava só na cópia do arquivo de resposta que vai para o disco
  (`C:\Windows\Panther\unattend.xml`, que o `primeiro-logon.ps1` apaga no fim). O pendrive nunca
  carrega a senha, e o repositório é público. Ela vai para a conta `Alexandre`, o login automático e o
  root do MariaDB. Em branco = conta sem senha (a Área de Trabalho Remota não aceita login).
- `-Senha` ainda existe para instalação sem ninguém na frente da máquina, mas aí a senha fica em texto
  no pendrive, que é justamente o que a pergunta no WinPE evita. Prefira não usar.
- **Ventoy**: copia `autounattend.xml` e `ventoy.json` para `\ventoy`. Um `ventoy.json` que já exista
  é preservado (cópia em `.bak`); só a entrada desta ISO é trocada, ela vira a padrão do menu e o menu
  secundário do Ventoy ("Boot in normal mode", que não tem timeout) é desligado, então o boot vai direto
  para a instalação sem apertar nada.
- **Windows extraído** (Rufus, Media Creation Tool): copia `autounattend.xml` para a raiz, que é onde o Setup procura.
- O script monta a ISO, confere `sources\lang.ini` e para se não tiver pt-BR.
- A ISO que já está no pendrive traz um `autounattend.xml` antigo embutido. Ele não atrapalha: o Windows
  procura primeiro o arquivo que o Ventoy injeta. Escolher "Boot without template" no menu do Ventoy
  usa o antigo, que serve de plano B.
- Pendrive novo: baixe o [Ventoy](https://www.ventoy.net), rode o `Ventoy2Disk.exe` (GPT, Secure Boot ligado),
  copie a ISO e rode o script. Isso sim apaga o pendrive.

**Ordem de boot**: dê boot no pendrive pelo menu de boot da placa (F8, F11 ou F12, conforme a placa), sem
mudar a ordem permanente da UEFI. Depois de copiar os arquivos o Windows reinicia, e se o pendrive continuar
como primeiro da ordem ele boota de novo e o Setup pergunta se quer "continuar a atualização"; nesse caso,
tire o pendrive e deixe reiniciar. Do primeiro reinício em diante nada mais é lido do pendrive.

Secure Boot: o Ventoy pede para registrar a chave dele na primeira vez (MokManager, *Enroll key from
disk*, `ENROLL_THIS_KEY_IN_MOKMANAGER.cer`). Ou desligue o Secure Boot na UEFI só para a instalação.

## O que vai no pendrive

| Entrada do menu | Arquivo | Para quê |
|:--|:--|:--|
| **Windows 11 26H2 pt-BR** | `Win11_26H2_pt-BR.iso` | a ISO deste repositório: montada do UUP dump (build 26300, Pro, com as atualizações), limpa, sem nada embutido. Em 5 s o Ventoy aplica o `autounattend.xml` e a instalação corre sozinha |
| **Arch Linux** | `myarch-2026.09.05-x86_64.iso` | o [MyArchISO](https://github.com/eualexandrerrr/MyArchISO) |
| **Hiren's BootCD PE** | `HBCD_PE_x64.iso` | socorro quando o Windows não sobe: senha esquecida, disco, partição, backup, antivírus, um Windows PE inteiro com ferramentas |
| **ChromeOS Flex** | `ChromeOS_Flex.img` | um sistema vivo com navegador para quando tudo mais falhar. Suporte experimental no Ventoy: o `.bin` do Google renomeado para `.img`, só o modo normal (sem Verified Boot), e a opção de instalar pode não aparecer; para instalar o Flex de verdade, grave-o num pendrive próprio |

O menu usa o tema `ventoy/theme/MyWinISO` (fundo do Alexandre, fontes e ícones do
[grub2-themes](https://github.com/vinceliuice/grub2-themes), roxo `#6B69D6` como o accent do
Windows), com um ícone por entrada (`menu_class`) e 10 s de timeout com o Windows como padrão. O
`ventoy.json` inteiro é o que o `pendrive.ps1` preserva: ele só garante o `auto_install` e as três
opções de `control` dele.

## O que está assumido

| | Valor | Onde mudar |
|:--|:--|:--|
| Disco | serial `6479A7AABAC014A3` ou modelo `MP700 ELITE`; Windows com 120 GB (`WINDOWS_MB`; o C: é descartável, a máquina é formatada a cada três meses) e o resto vira a partição `Dados` (`DADOS`), que nunca é apagada | `SERIAL` e `MODELO` no `instala.vbs`, dentro do XML. Descobrir: `Get-Disk \| Select-Object FriendlyName, SerialNumber` |
| Edição | `Windows 11 Pro`, pelo nome da imagem dentro do `install.wim` | `EDICAO` no `instala.vbs`; `dism /Get-WimInfo` lista os nomes |
| Ativação | licença digital gravada na placa-mãe | |
| ISO | Windows 11 em Português (Brasil), da Microsoft | |
| Conta | `Alexandre`, administradora, senha perguntada no WinPE pelo `instala.vbs`, login automático permanente | `<LocalAccount>` e `<AutoLogon>` |
| PC | nome `RRR`, fuso `E. South America Standard Time`, teclado ABNT2 (`0416:00010416`) | `specialize` e `oobeSystem`; ABNT sem o 2 é `0416:00000416` |

## Debloat

Não há ferramenta de terceiro: a limpeza é feita pelo próprio instalador, no passo `specialize`, antes
de qualquer usuário existir, e a lista está legível no `especializar.ps1` dentro do XML.

| | |
|:--|:--|
| Apps removidos | Clipchamp, Cortana, Notícias, Clima, Bing Search, Copilot, Game Assist, app Xbox, Game Bar, Obter Ajuda, Dicas, Office Hub, Solitaire, Sticky Notes, Outlook, Pessoas, Power Automate, To Do, Dev Home, Alarmes, Câmera, Feedback Hub, Mapas, Gravador, Telefone, Família, Assistência Rápida, Teams, Mail e Calendário, Skype, Carteira, OneNote, 3D Viewer, Mixed Reality, Widgets (app e runtime), Cross Device, Take a Test, **Paint e Ferramenta de Captura** (Lightshot no lugar) |
| Capacidades removidas | Internet Explorer, WordPad, Fax e Scanner, Windows Media Player legado, Steps Recorder, Math Input, Handwriting, Speech e TTS, Hello Face, OneSync, OpenSSH Client (o Git traz o dele), PowerShell ISE |
| Recursos removidos | PowerShell 2.0, cliente de Área de Trabalho Remota (`mstsc`), Recall, Captura |
| Ficam | Loja e App Installer (o winget depende deles), Bloco de Notas (sem o banner da Loja), Calculadora, Fotos, Terminal, Xbox Identity Provider, MediaPlayback (jogos e apps usam para vídeo) |
| Também sai | OneDrive (desinstalado e proibido de voltar por política), agendamento pós-OOBE do Outlook, Dev Home e Teams, ícone do Edge, sons do sistema |
| Políticas | telemetria no mínimo, sem sugestões e apps promovidos, sem Copilot (app, provider, política e barra lateral do Edge), sem widgets, sem ID de anúncio, Edge sem tela inicial e sem startup boost, Edge desinstalável, busca sem Bing, Iniciar sem nada fixado |
| Fica de fora de propósito | o Edge em si: o Windows usa o WebView2 dele em várias telas e o Windows Update o traz de volta; ele fica desinstalável para você decidir |
| Segurança que atrapalha | UAC sem perguntar (o LUA fica ligado, senão apps da Loja não abrem), Smart App Control e SmartScreen desligados, ícone da Segurança do Windows escondido |
| Sistema | inicialização rápida desligada, caminhos longos, som de inicialização desligado, senha sem validade, sem bloqueio de conta |
| Perfil padrão | a conta já nasce com tema escuro, barra centralizada e só no monitor principal, sem busca, extensões visíveis, teclado rápido, sem OneDrive: a primeira tela não aparece clara |
| Jogo (o que Atlas e Revi fazem) | agendamento de GPU por hardware, sem power throttling, **VBS e isolamento de núcleo desligados** (uns FPS a mais, menos proteção; ligue de volta em Segurança do Windows se quiser), MMCSS com prioridade para jogos, serviço de telemetria parado, Modo Jogo, apps em segundo plano desligados |
| Identidade | Sistema > Sobre mostra fabricante `mywiniso`, modelo `RRR`, dono `Alexandre`, link para este repositório |

O `setup.ps1` aplica a mesma lista aos apps já instalados para o usuário, então num Windows que não veio do pendrive a limpeza também acontece.
Quer mais? Adicione o nome do pacote na lista `$bloat` (`Get-AppxProvisionedPackage -Online | Select DisplayName` mostra os nomes).

## Configurações do usuário

Aplicadas pelo `setup.ps1`, então valem em qualquer Windows onde ele rodar.

| Área | O que fica |
|:--|:--|
| Explorer | extensões visíveis, abre em Este Computador, menu de contexto clássico; Detalhes em todas as pastas com Nome, Caminho, Data de modificação, Tipo e Tamanho (WinSetView) |
| Barra e Iniciar | ícones centralizados e só no monitor principal (a LG de pé fica sem barra), sem busca, Visão de Tarefas, widgets e Copilot; Iniciar com mais fixados e sem recomendações; "Finalizar tarefa" no botão direito; pinos fixos |
| Tema | escuro desde o primeiro boot, cor de destaque fixa `#6B69D6` (o "Roxo-sombreado-escuro" da paleta do Windows; a automática tirava um roxo sujo do wallpaper); barra, Iniciar, central de notificações, Explorer e Configurações translúcidos e escuros pelo Windhawk (TranslucentTaskbar, TranslucentStartMenu, TranslucentShell, Translucent Explorer11 e o mod Translucent Windows com `acrylicblur` no tint `#CC101010`, o mesmo da barra), menus escuros, janelas sem borda. A barra leva um `controlStyles` por cima do tema com `TintColor #CC101010`, senão ela fica clara demais sobre wallpaper claro |
| Disco | duas partições que importam: `C:` com o Windows e os programas (120 GB; formatado a cada três meses, então não precisa de mais) e `D:` **Dados** com o resto. Em D: mora tudo que não se quer refazer a cada formatação: os jogos (`D:\Jogos`: biblioteca do Steam e RedM), o Debian do WSL (`D:\WSL\Debian\ext4.vhdx`, que volta inteiro por `wsl --import-in-place`), o Android SDK e os emuladores (`D:\Android`, por `ANDROID_HOME`/`ANDROID_AVD_HOME`) e a pasta Downloads, redirecionada pelo caminho oficial (`SHSetKnownFolderPath`) -- Documentos, Imagens, Vídeos e Músicas ficam no C: mesmo. Projetos em D: é o Alexandre quem cria; este clone segue em `~\Projetos`. A instalação nunca toca em D:: o `instala.vbs` só apaga as partições do Windows, confere a numeração pelo próprio diskpart (o WMI não lista a MSR), recusa qualquer layout que não reconheça e para antes do DISM se Dados sumir |
| Perfil dos programas | `D:\Perfil`, por **regra e não por lista** (`manutencao/perfil.ps1`): toda pasta que qualquer programa cria em `%APPDATA%`, `%LOCALAPPDATA%`, `LocalLow` e nos `~\.dotfolders` vai para `D:\Perfil\Roaming`, `Local`, `LocalLow` e `Home`, e no lugar fica uma junção; arquivo solto do perfil (`~\.claude.json`, `~\.gitconfig`) vai por symlink. Fica em C: só o que é do Windows: `Microsoft`, `Packages` (apps da Loja), `Temp`, `Programs`. Roda na etapa 7 (antes de instalar qualquer programa, para a junção já existir quando o instalador gravar), no fim dos Programas, no fim do setup, e pela tarefa **Perfil no D** a cada logon e de hora em hora, para programa instalado depois: pasta em uso (programa aberto) fica para a próxima rodada, porque o NTFS recusa renomear pasta com arquivo aberto, e o rename é o teste. Quando os dois lados existem, o arquivo mais novo vence. Fora do AppData: `Steam\config` + `Steam\userdata` em `D:\Jogos\Steam\_perfil`, os bancos do MariaDB em `D:\Perfil\MariaDB\data` (na reinstalação o serviço é registrado em cima deles) e as sessões do HeidiSQL em `D:\Perfil\HeidiSQL` (modo portátil por symlink). Mover `C:\Users` inteiro (`ProfilesDirectory`) ou o `AppData\Local` inteiro não: quebra apps da Loja, Start e barra, e a Microsoft só admite em teste. O que a DPAPI da conta cifra não volta, por desenho do Windows: cookies e sessões do Chrome, token do Discord e do Spotify, credencial do git pedem login de novo (as senhas estão no Proton Pass) |
| Explorer, nomes | pastas com o nome real (`Program Files`, `Users`, `Public`), tirando o `LocalizedResourceName` do `desktop.ini` de cada uma; caminho completo na barra de título. A barra de endereço do Windows 11 só mostra a trilha (clicar nela mostra o caminho literal); não há ajuste para deixá-la literal |
| Menus e MMC | menu de contexto clássico, escuro e sem a borda clara (`TranslucentFlyoutsFix` do dark-menus). O Agendador de Tarefas, o Visualizador de Eventos e o resto do `mmc.exe` ficam no tema claro original: o Windows não tem tema escuro para MMC, e o Translucent Windows os deixava meio brancos; a regra de processo os tira do mod |
| Memória | pagefile fixo (início = máximo) de metade da RAM no C:, entre 4 e 16 GB; compressão de memória desligada; tarefa `Standby list` a cada minuto (veja a etapa 28) |
| Área de trabalho | **sem ícone nenhum** (`HideIcons`). Os arquivos continuam lá, o `RedM.exe` inclusive; para chegar neles, Win+E e ir na pasta Área de Trabalho |
| Notificações | os avisos que aparecem no canto ficam **desligados**. A central de notificações em si continua de pé, de propósito: no Windows 11 o calendário mora dentro dela, e clicar no relógio abre esse painel. A política `DisableNotificationCenter` levaria o calendário junto, então ela fica de fora |
| Print Screen | `Shift+PrintScreen` chama o Lightshot para selecionar área, e é o único atalho dele ligado; os de "salvar tela toda" e "enviar tela toda" ficam desligados |
| Senhas | o gerenciador do Chrome é desligado por política (`PasswordManagerEnabled=0`): não salva, não preenche e não sugere senha. Fica só o Proton Pass, no Windows e como extensão |
| Desligar | apps travados são encerrados sozinhos (`AutoEndTasks`), sem "este aplicativo está impedindo o desligamento" |
| Entrar | reabre os apps que estavam abertos (`RestartApps`), NumLock ligado, tarefa de logon arruma as janelas |
| Teclado | só o layout ABNT2, sem nenhum em inglês; repetição no máximo aplicada na hora, cursor piscando rápido, Print Screen não abre a Ferramenta de Captura (fica para o Lightshot), atalhos de Teclas de Aderência, Alternância e Filtragem desligados |
| Mouse | sem aceleração |
| Jogos | Game DVR desligado; bibliotecas do Visual C++ e do .NET, que jogos exigem |
| Área de transferência | histórico Win+V ligado, ações sugeridas desligadas |
| Privacidade | sem experiências personalizadas, ID de anúncio, dados de digitação, fala online, localização, Encontrar meu dispositivo |
| Região | Brasil, pt-BR |
| Sons | esquema "Sem sons" |
| Do Sophia Script | o que faltava do preset do farag2, cruzado função por função: relatório de erros e feedback off, AutoPlay off, Acesso Rápido sem recentes/frequentes, diálogo de cópia detalhado, conflitos de merge visíveis, Edge sem criar atalho, sem animação do primeiro logon, atalhos sem o sufixo "- Atalho", sites sem ler a lista de idiomas, BSoD com os parâmetros, F1 sem abrir o Edge, Painel de Controle em ícones grandes, Iniciar sem "mais usados"/"adicionados recentemente"/avisos de conta, sem "procurar na Loja", sem destaques da busca, sem impressora padrão automática, sem anúncio do OneDrive, placa de rede sem economia de energia, Microsoft Update junto do Windows Update. Fora de propósito: DNS over HTTPS (troca o DNS do roteador) e os itens de segurança (sandbox do Defender, PUA, proteção de rede) |
| Energia | Desempenho Máximo, nunca suspende nem hiberna; a tela apaga depois de 5 minutos parada |
| RDP | ligado como host com autenticação de rede; precisa da senha da conta |
| WSL | Debian com usuário `alexandre` usando zsh, sudo sem senha, systemd; precisa de um reinício na primeira vez |
| Terminal | Windows Terminal é o console padrão do sistema; tudo abre nele em abas. PowerShell 7 é o padrão, e o menu tem Windows PowerShell, Prompt de Comando, Debian com zsh e Git Bash |
| Monitores | ASUS XG27ACS em 2560x1440 a 180 Hz como principal; LG UltraGear em 1920x1080 a 144 Hz, de pé, à esquerda e 262 px acima. Casados pelo nome do EDID, então trocar de porta não embaralha |
| Conta | foto do perfil do `perfil/avatar.png` no Iniciar e na tela de login |

## Rodar o setup num Windows já instalado

PowerShell como administrador:

```powershell
$env:MYWINISO_SENHA = '123'    # opcional: vira a senha do root do MariaDB
irm https://raw.githubusercontent.com/eualexandrerrr/MyWinISO/main/setup.ps1 | iex
```

## Depois de instalado

- **RedM.exe** fica na área de trabalho; abra uma vez para instalar.
- **WSL**: na primeira execução o Windows precisa reiniciar; rode `mywiniso-setup.cmd` de novo e o Debian entra.
- **MariaDB**: root com a senha da conta, acesso local e remoto. Sem senha, root sem senha e só local.
- **Office**: a chave do `Configuracao.xml` é a GVLK pública da Microsoft para volume, que só ativa contra um
  servidor KMS de organização. Com licença pessoal, troque o produto por `ProPlus2024Retail` ou `O365ProPlusRetail`.
- **Tela de bloqueio**: o wallpaper entra pela `PersonalizationCSP`, que trava a opção em Configurações. Para
  liberar, apague a chave `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP`.
- **Senha depois**: `net user Alexandre *` troca; o login automático continua (o Windows guarda a senha do autologon).
- **AtlasOS e ReviOS** não entram: dependem do AME Wizard, que é gráfico, e o playbook brigaria com esta limpeza. O que eles fazem de relevante para jogo já está na tabela de Debloat.

## Se algo der errado

| Fase | Log |
|:--|:--|
| WinPE | `X:\mywiniso\instala.log` e `dism.log`; o Bloco de Notas abre sozinho com o log se algo falhar. Antes do diskpart nada foi apagado. Erro `0x80070002` logo no início é comando do `windowsPE` não encontrado |
| specialize | `C:\Windows\Setup\Scripts\especializar.log` |
| primeiro logon e setup | `C:\Users\Alexandre\mywiniso.log` |

Sem internet no primeiro logon, o `primeiro-logon.ps1` desiste depois de 5 minutos e o
`mywiniso-setup.cmd` da área de trabalho roda o resto quando a rede voltar.

## Referências

- [Unattend Generator (schneegans.de)](https://schneegans.de/windows/unattend-generator/): de onde vem a técnica de embutir scripts no XML e o caminho `C:\Windows\Panther\unattend.xml`
- [Ventoy auto_install](https://www.ventoy.net/en/plugin_autoinstall.html)
- [Microsoft: ordem de busca do arquivo de resposta](https://learn.microsoft.com/windows-hardware/manufacture/desktop/windows-setup-automation-overview)
- [Microsoft: layout de partições UEFI/GPT](https://learn.microsoft.com/windows-hardware/manufacture/desktop/configure-uefigpt-based-hard-drive-partitions)
- [Microsoft: chaves genéricas de instalação (KMS client setup keys)](https://learn.microsoft.com/windows-server/get-started/kms-client-activation-keys)
- [Sophia Script for Windows (farag2)](https://github.com/farag2/Sophia-Script-for-Windows): de onde vêm as três tarefas de limpeza, o ponto de restauração antes de mexer, o armazenamento reservado liberado, as tarefas de telemetria de fundo e o contorno do driver UCPD para gravar `TaskbarDa`. É a referência mais cuidadosa da categoria: quase não faz "otimização" e desfaz a dos outros
