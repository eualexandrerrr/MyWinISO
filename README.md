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

> **Apaga o disco inteiro.** O alvo é o Corsair MP700 ELITE (serial `AA09B5211012T9`).
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
| 7 | `setup.ps1` | as 17 etapas abaixo |

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
- **setup.ps1**: cada etapa como `[n/17] nome`, linhas `- o que está fazendo`, cada programa do winget com `OK`,
  `já instalado` ou `FALHOU (código)`, e no fim de cada etapa `OK`, `AVISO` (erros não fatais, listados) ou
  `ERRO` (a etapa parou, a mensagem aparece). Uma etapa com erro não derruba as seguintes. No final, um resumo
  de todas as etapas com tempo, a lista de programas que falharam e o caminho do log.

Logs: `C:\Windows\Setup\Scripts\especializar.log`, `~\mywiniso.log` (primeiro logon) e `~\mywiniso-setup.log` (setup).

## O que o setup.ps1 faz

Roda no primeiro logon e em qualquer Windows 11 depois (`mywiniso-setup.cmd` ou o `irm` abaixo).

| # | Etapa |
|:--|:--|
| 1 | garante que o winget funciona (em instalação nova ele demora a registrar) |
| 2 | instala o Git e clona este repositório em `~\Projetos\mywiniso` |
| 3 | programas do `apps.json`, um a um, com resultado na tela: 45 do winget, e WhatsApp e Bloco de Notas da Loja |
| 4 | RedM na área de trabalho (o instalador não tem modo silencioso) |
| 5 | `git config` com nome e e-mail |
| 6 | preferências do usuário (tabela abaixo) |
| 7 | Office LTSC Professional Plus 2024 pt-BR pelo Office Deployment Tool (`office/Configuracao.xml`) |
| 8 | wallpaper nos dois monitores e na tela de bloqueio |
| 9 | Área de Trabalho Remota ligada, senha sem validade, sem bloqueio de conta, scripts liberados |
| 10 | energia: plano Desempenho Máximo, nunca suspende, nunca apaga a tela, sem hibernação |
| 11 | NVIDIA App com instalador silencioso (a URL atual vem da página da NVIDIA) |
| 12 | MariaDB como serviço, root com a senha da conta e acesso remoto |
| 13 | fonte Cascadia Mono na máquina, no console e no terminal do VS Code |
| 14 | perfil do PowerShell (`powershell/profile.ps1`: atalhos `c` e `x`, histórico com setas, prompt curto) |
| 15 | barra de tarefas com Explorer, Firefox, Discord, VS Code, WinSCP e Chrome; tarefa "Startup OnLogon" que arruma as janelas 30 s após entrar |
| 16 | WSL com Debian: usuário `alexandre`, sudo sem senha, systemd (`wsl/debian.sh`) |
| 17 | drivers e atualizações pelo Windows Update |

## Programas

`apps.json` é o formato do `winget import`; gerar um novo com `winget export -o apps.json`.

| | |
|:--|:--|
| Dia a dia | Chrome, Firefox, Google Drive, Discord, WhatsApp, Spotify, Obsidian, VLC, Lightshot, WinRAR, 7-Zip, TranslucentTB, Bloco de Notas |
| Jogos | Steam, Radmin VPN, OBS Studio, RedM (área de trabalho), NVIDIA App |
| Dev | Git, GitHub CLI, VS Code, Claude Code, PowerShell 7, Node.js, Bun, Python 3.13, uv, Docker Desktop, cloudflared, MariaDB, HeidiSQL, WinSCP |
| CLI | starship, zoxide, fzf, bat, fd, ripgrep, eza, jq, ffmpeg, rclone, JetBrainsMono Nerd Font |
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
| `wallpaper/` | imagem dos dois monitores e da tela de bloqueio |
| `powershell/profile.ps1` | perfil do PowerShell 7 |
| `taskbar/LayoutModification.xml` | pinos da barra de tarefas |
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
| Disco | serial `AA09B5211012T9` ou modelo `MP700 ELITE` | `SERIAL` e `MODELO` no `instala.vbs`, dentro do XML. Descobrir: `Get-Disk \| Select-Object FriendlyName, SerialNumber` |
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
| Perfil padrão | a conta já nasce com tema escuro, barra à esquerda sem busca, extensões visíveis, sem OneDrive: a primeira tela não aparece clara |
| Jogo (o que Atlas e Revi fazem) | agendamento de GPU por hardware, sem power throttling, **VBS e isolamento de núcleo desligados** (uns FPS a mais, menos proteção; ligue de volta em Segurança do Windows se quiser), MMCSS com prioridade para jogos, serviço de telemetria parado, Modo Jogo, apps em segundo plano desligados |
| Identidade | Sistema > Sobre mostra fabricante `mywiniso`, modelo `RRR`, dono `Alexandre`, link para este repositório |

O `setup.ps1` aplica a mesma lista aos apps já instalados para o usuário, então num Windows que não veio do pendrive a limpeza também acontece.
Quer mais? Adicione o nome do pacote na lista `$bloat` (`Get-AppxProvisionedPackage -Online | Select DisplayName` mostra os nomes).

## Configurações do usuário

Aplicadas pelo `setup.ps1`, então valem em qualquer Windows onde ele rodar.

| Área | O que fica |
|:--|:--|
| Explorer | extensões visíveis, abre em Este Computador, menu de contexto clássico |
| Barra e Iniciar | ícones à esquerda, sem busca, Visão de Tarefas, widgets e Copilot; Iniciar com mais fixados e sem recomendações; "Finalizar tarefa" no botão direito; pinos fixos |
| Tema | escuro desde o primeiro boot, sem transparência, cor de destaque puxada do wallpaper |
| Desligar | apps travados são encerrados sozinhos (`AutoEndTasks`), sem "este aplicativo está impedindo o desligamento" |
| Entrar | reabre os apps que estavam abertos (`RestartApps`), NumLock ligado, tarefa de logon arruma as janelas |
| Teclado | repetição no máximo, cursor piscando rápido, Print Screen não abre a Ferramenta de Captura (fica para o Lightshot), atalhos de Teclas de Aderência, Alternância e Filtragem desligados |
| Mouse | sem aceleração |
| Jogos | Game DVR desligado |
| Área de transferência | histórico Win+V ligado, ações sugeridas desligadas |
| Privacidade | sem experiências personalizadas, ID de anúncio, dados de digitação, fala online, localização, Encontrar meu dispositivo |
| Região | Brasil, pt-BR |
| Sons | esquema "Sem sons" |
| Energia | Desempenho Máximo, nunca suspende, nunca apaga a tela, sem hibernação |
| RDP | ligado como host com autenticação de rede; precisa da senha da conta |
| WSL | Debian com usuário `alexandre`, sudo sem senha, systemd; precisa de um reinício na primeira vez |

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
