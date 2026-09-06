<div align="center">

# mywiniso

**Windows 11 · pt-BR · instalação sem perguntas**

Um pendrive que boota, acha o disco certo, formata, instala o Windows, cria a conta, instala e
configura tudo. Nada de ISO modificada: é a ISO oficial da Microsoft mais um arquivo de resposta
(`autounattend.xml`) que o instalador segue sozinho.

[![Windows 11](https://img.shields.io/badge/Windows_11-25H2-0078D4?style=flat-square&logo=windows&logoColor=white)](https://www.microsoft.com/pt-br/software-download/windows11)
[![Ventoy](https://img.shields.io/badge/Ventoy-auto__install-2E8B57?style=flat-square)](https://www.ventoy.net/en/plugin_autoinstall.html)

</div>

---

> **Apaga o disco inteiro.** O alvo é o Corsair MP700 ELITE (serial `6479A7AABAC014A3`).
> O script só particiona se achar exatamente esse disco; qualquer outro cenário aborta antes
> de gravar. Mesmo assim: backup antes.

## O que acontece ao ligar o PC com o pendrive

| Passo | Quem faz | O quê |
|:--|:--|:--|
| 1 | Ventoy | mostra a ISO; em 5 s aplica o `autounattend.xml` sozinho |
| 2 | `instala.vbs` (WinPE) | faz a fase inteira no lugar do Setup: pula TPM/CPU/RAM, procura o disco pelo serial ou modelo via WMI, apaga e cria GPT (EFI 300 MB, MSR, Windows, Recovery 1 GB), aplica a imagem `Windows 11 Pro` com o DISM, grava o boot, copia o XML completo para `C:\Windows\Panther` e reinicia pelo disco |
| 3 | Windows | primeiro boot pelo disco; o Setup novo da ISO nunca chega a instalar |
| 4 | `especializar.ps1` | nome `RRR`, fuso de São Paulo, remove bloatware, OneDrive, Copilot e telemetria, UAC sem perguntar, SmartScreen off, Iniciar vazio, perfil padrão já escuro, tweaks de jogo, identidade em Sistema > Sobre |
| 5 | OOBE | conta local `Alexandre` administradora, login automático permanente, sem conta Microsoft, teclado ABNT2 |
| 6 | `primeiro-logon.ps1` | baixa o `setup.ps1` deste repositório e roda; deixa `mywiniso-setup.cmd` na área de trabalho |
| 7 | `setup.ps1` | as 29 etapas abaixo |

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

Cada script mostra o estado real, não uma barra decorativa:

- **WinPE**: o `instala.vbs` mostra a janela do DISM aplicando a imagem; o resto vai para `X:\mywiniso\instala.log`,
  que fica copiado em `C:\Windows\Panther\mywiniso-instala.log`. Se falhar, o Bloco de Notas abre com o log.
- **specialize**: cada bloco aparece como `-> nome`, com os pacotes removidos um a um, e termina em `OK` ou `ERRO` com a mensagem.
- **primeiro logon**: uma janela de console que diz o que está fazendo (espera pela rede com contagem de tentativas,
  download do `setup.ps1`, execução) e **fica aberta até você apertar Enter**, com o resultado na tela.
- **setup.ps1**: cada etapa como `[n/29] nome`, linhas `- o que está fazendo`, cada programa do winget com `OK`,
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

A **etapa 25** é a única fora de lugar de propósito. Reiniciar o Explorer desfaz a atribuição de
wallpaper por monitor, e o Explorer reinicia na etapa 10 e no fim da 24; então o monitor em pé só recebe
a imagem dele depois disso. Até lá a etapa 8 deixa a paisagem nos dois.

| # | Etapa |
|:--|:--|
| 1 | ponto de restauração antes de mexer em qualquer coisa |
| 2 | garante que o winget funciona e, se a ISO trouxe um velho (o 1.9 não fala mais com a msstore), instala o release atual do GitHub |
| 3 | instala o Git e clona este repositório em `~\Projetos\mywiniso`; sem Git, baixa o zip e segue |
| 4 | **Claude Code (CLI)** pelo winget, antes de tudo que é longo |
| 5 | **driver de vídeo da NVIDIA**, o mais novo, baixado da própria NVIDIA pela API que a página de download usa; instalado em silêncio com `-s -clean -noreboot` |
| 6 | **monitores**: resolução, frequência, orientação e posição de cada um (`monitores/monitores.json`); tenta três vezes, porque o driver acabou de assumir |
| 7 | **preferências do usuário**: tema escuro, barra centralizada e só no monitor principal, **área de trabalho sem ícone nenhum**, **notificações desligadas**, Explorer, teclado, mouse, privacidade (tabela abaixo) |
| 8 | **wallpaper** (paisagem nos dois monitores) e tela de bloqueio |
| 9 | **foto do perfil** da conta (`perfil/avatar.png`) no Iniciar e na tela de login |
| 10 | **Explorer em Detalhes** em todas as pastas, com as colunas do Alexandre, pelo WinSetView (`explorer/WinSetView/`); reinicia o Explorer, e é aqui que tema e barra passam a valer |
| 11 | **Windhawk** com os temas Translucent do Undisputed00x na barra (escurecida), no Iniciar, na central de notificações e no Explorer, mais reordenar miniaturas da barra, menus escuros e janelas sem borda; tudo por registro, sem abrir o Windhawk. No fim reinicia o `ShellExperienceHost` e o `StartMenuExperienceHost`, senão eles ficam sem tema |
| 12 | **energia**: plano Desempenho Máximo, nunca suspende nem hiberna, tela apaga em 5 minutos |
| 13 | programas do `apps.json`, um a um, com resultado na tela: 44 do winget, e WhatsApp e Bloco de Notas da Loja. Instalador que recusa administrador (o do Spotify) vai por tarefa agendada sem elevação |
| 14 | **Lightshot**: um atalho só, `Shift+PrintScreen`, os outros dois desligados |
| 15 | **Chrome**: gerenciador de senhas desligado (fica só o Proton Pass), e Proton Pass e Enhancer for YouTube instalados por política |
| 16 | RedM na área de trabalho (o instalador não tem modo silencioso) |
| 17 | `git config` com nome e e-mail |
| 18 | Office LTSC Professional Plus 2024 pt-BR pelo Office Deployment Tool (`office/Configuracao.xml`) |
| 19 | Área de Trabalho Remota ligada, senha sem validade, sem bloqueio de conta, scripts liberados |
| 20 | NVIDIA App com instalador silencioso (a URL atual vem da página da NVIDIA) |
| 21 | MariaDB como serviço, root com a senha da conta e acesso remoto |
| 22 | fonte Cascadia Mono na máquina, no console e no terminal do VS Code |
| 23 | perfil do PowerShell (`powershell/profile.ps1`: atalhos `c` e `x`, histórico com setas, prompt curto) |
| 24 | barra de tarefas com Explorer, Discord, VS Code, WinSCP e Chrome; tarefa "Startup OnLogon" que arruma as janelas 30 s após entrar. Depois dos programas, porque os pinos precisam dos apps instalados |
| 25 | **wallpaper do monitor em pé** (`Real_Dimez_portrait.jpg`), pela `IDesktopWallpaper`; aqui porque o Explorer não reinicia mais |
| 26 | WSL com Debian: usuário `alexandre` com zsh, sudo sem senha, systemd (`wsl/debian.sh`) |
| 27 | resto dos drivers e as atualizações, pelo Windows Update (o de vídeo já veio na etapa 5) |
| 28 | Windows Terminal instalado, atualizado e como console padrão do sistema, com cinco shells em abas (`terminal/settings.json`) |
| 29 | manutenção: três tarefas de limpeza que rodam sozinhas, armazenamento reservado liberado, sem compartilhar updates com a internet, backup do registro e as tarefas de telemetria de fundo desligadas |

## Programas

`apps.json` é o formato do `winget import`; gerar um novo com `winget export -o apps.json`.

| | |
|:--|:--|
| Dia a dia | Chrome, Google Drive, Discord, WhatsApp, Spotify, Obsidian, VLC, Lightshot, Proton Pass, WinRAR, 7-Zip, Bloco de Notas |
| Jogos | Steam, Radmin VPN, OBS Studio, RedM (área de trabalho), NVIDIA App |
| Visual | Windhawk com Taskbar, Start Menu, Notification Center e File Explorer Styler (m417z) nos temas Translucent, Taskbar Thumbnail Reorder, Dark mode context menus, Invisible Window Borders |
| Dev | Git, GitHub CLI, VS Code, Claude Code, PowerShell 7, Node.js, Bun, Python 3.13, uv, cloudflared, MariaDB, HeidiSQL, WinSCP |
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
| `chrome/` | `enhancer-for-youtube.json`, o backup das configurações da extensão para importar na mão (ela guarda tudo dentro do perfil do Chrome e não tem managed storage, então não dá para injetar de fora) |
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
powershell -ExecutionPolicy Bypass -File .\pendrive.ps1 E: -Senha 123                                 # uma ISO só
powershell -ExecutionPolicy Bypass -File .\pendrive.ps1 E: Win11_pt-BR_unattend.iso -Senha 123        # mais de uma: diga qual
```

- `-Senha` vira a senha da conta `Alexandre` e do root do MariaDB **só na cópia do XML gravada no
  pendrive**; o `autounattend.xml` do repositório continua sem senha, e o repositório é público.
  Sem `-Senha` a conta fica sem senha e a Área de Trabalho Remota não aceita login.
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

## O que está assumido

| | Valor | Onde mudar |
|:--|:--|:--|
| Disco | serial `6479A7AABAC014A3` ou modelo `MP700 ELITE` | `SERIAL` e `MODELO` no `instala.vbs`, dentro do XML. Descobrir: `Get-Disk \| Select-Object FriendlyName, SerialNumber` |
| Edição | `Windows 11 Pro`, pelo nome da imagem dentro do `install.wim` | `EDICAO` no `instala.vbs`; `dism /Get-WimInfo` lista os nomes |
| Ativação | licença digital gravada na placa-mãe | |
| ISO | Windows 11 em Português (Brasil), da Microsoft | |
| Conta | `Alexandre`, administradora, senha pelo `pendrive.ps1 -Senha`, login automático permanente | `<LocalAccount>` e `<AutoLogon>` |
| PC | nome `RRR`, fuso `E. South America Standard Time`, teclado ABNT2 (`0416:00010416`) | `specialize` e `oobeSystem`; ABNT sem o 2 é `0416:00000416` |

## Debloat

Não há ferramenta de terceiro: a limpeza é feita pelo próprio instalador, no passo `specialize`, antes
de qualquer usuário existir, e a lista está legível no `especializar.ps1` dentro do XML.

| | |
|:--|:--|
| Apps removidos | Clipchamp, Cortana, Notícias, Clima, Bing Search, Copilot, Game Assist, app Xbox, Game Bar, Obter Ajuda, Dicas, Office Hub, Solitaire, Sticky Notes, Outlook, Pessoas, Power Automate, To Do, Dev Home, Alarmes, Câmera, Feedback Hub, Mapas, Gravador, Telefone, Mídia, Filmes e TV, Família, Assistência Rápida, Teams, Mail e Calendário, Skype, Carteira, OneNote, 3D Viewer, Mixed Reality, Widgets (app e runtime), Cross Device, Take a Test, **Paint e Ferramenta de Captura** (Lightshot no lugar) |
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
| Tema | escuro desde o primeiro boot, cor de destaque puxada do wallpaper; barra, Iniciar, central de notificações e Explorer translúcidos pelo Windhawk (TranslucentTaskbar, TranslucentStartMenu, TranslucentShell, Translucent Explorer11), menus escuros, janelas sem borda. A barra leva um `controlStyles` por cima do tema com `TintColor #CC101010`, senão ela fica clara demais sobre wallpaper claro |
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
irm https://raw.githubusercontent.com/eualexandrerrr/mywiniso/main/setup.ps1 | iex
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
