<div align="center">

# mywiniso

**Windows 11 · pt-BR · instalação sem perguntas**

Um pendrive que boota, acha o disco certo, formata, instala o Windows, cria a conta e
instala os programas. Nada de ISO modificada: é a ISO oficial da Microsoft mais um
arquivo de resposta (`autounattend.xml`) que o instalador segue sozinho.

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
| 2 | `disco.ps1` (WinPE) | pula TPM/CPU/RAM, procura o disco pelo serial ou modelo, apaga e cria GPT: EFI 300 MB, MSR, Windows, Recovery 1 GB |
| 3 | Setup | instala o Windows 11 Pro na partição que acabou de ser criada |
| 4 | `especializar.ps1` | nome `RRR`, fuso de São Paulo, remove bloatware, OneDrive, Copilot, widgets e telemetria, plano de energia alto desempenho |
| 5 | OOBE | conta local `alexandre`, sem senha, sem conta Microsoft, teclado ABNT2 |
| 6 | `primeiro-logon.ps1` | login automático permanente, baixa o `setup.ps1` deste repositório e roda |
| 7 | `setup.ps1` | garante o winget, clona o repo em `~\Projetos\mywiniso`, instala tudo do `apps.json`, RedM na área de trabalho, preferências, Office, wallpaper nos dois monitores e na tela de bloqueio, drivers pelo Windows Update |

Os três scripts dos passos 2, 4 e 6 vivem **dentro** do `autounattend.xml`, na seção `<Extensions>`
no fim do arquivo. Assim o pendrive precisa de um único arquivo, e o Setup ignora a seção.
O `setup.ps1` e o `apps.json` ficam fora de propósito: mudam com frequência e são baixados do GitHub
na hora, então o pendrive não envelhece quando a lista de programas muda.

## Arquivos

| | |
|:--|:--|
| `autounattend.xml` | fonte de verdade da instalação: disco, idioma, conta, bloatware, primeiro logon |
| `setup.ps1` | pós-instalação; roda em qualquer Windows 11, não só no instalado pelo pendrive |
| `apps.json` | lista do `winget import`; gerar uma nova com `winget export -o apps.json` |
| `ventoy/ventoy.json` | plugin `auto_install` do Ventoy; o `pendrive.ps1` troca o caminho da ISO |
| `office/Configuracao.xml` | Office LTSC Professional Plus 2024 pt-BR pelo Office Deployment Tool, que o `setup.ps1` baixa da Microsoft na hora |
| `wallpaper/` | imagem aplicada nos dois monitores e na tela de bloqueio |
| `pendrive.ps1` | grava o XML no pendrive sem formatar e sem tocar nas ISOs que já estão lá |

## Fazer o pendrive

O pendrive já tem a ISO do Windows 11 em Português (Brasil). O script não formata nada.
PowerShell como administrador, com o pendrive na letra `E:`, por exemplo:

```powershell
powershell -ExecutionPolicy Bypass -File .\pendrive.ps1 E:              # uma ISO só no pendrive
powershell -ExecutionPolicy Bypass -File .\pendrive.ps1 E: win11.iso    # mais de uma: diga qual
```

- **Ventoy**: copia `autounattend.xml` e `ventoy.json` para `\ventoy`. Um `ventoy.json` que já exista
  é preservado (cópia em `.bak`) e só a entrada desta ISO é trocada.
- **Windows extraído** (Rufus, Media Creation Tool): copia `autounattend.xml` para a raiz, que é onde o Setup procura.
- O script monta a ISO, confere `sources\lang.ini` e para se não tiver pt-BR.
- Pendrive novo: baixe o [Ventoy](https://www.ventoy.net), rode o `Ventoy2Disk.exe` (GPT, Secure Boot ligado),
  copie a ISO e rode o script. Isso sim apaga o pendrive.

Secure Boot: o Ventoy pede para registrar a chave dele na primeira vez (MokManager, *Enroll key from
disk*, `ENROLL_THIS_KEY_IN_MOKMANAGER.cer`). Ou desligue o Secure Boot na UEFI só para a instalação.

## O que está assumido

| | Valor | Onde mudar |
|:--|:--|:--|
| Disco | serial `AA09B5211012T9` ou modelo `MP700 ELITE` | `$Serial` e `$Modelo` no `disco.ps1`, dentro do XML. Descobrir: `Get-Disk \| Select-Object FriendlyName, SerialNumber` |
| Edição | Pro, pela chave genérica pública `VK7JG-…`, que só escolhe a edição | `<ProductKey>`; Home é `YTMG3-N6DKC-DKB77-7M9GH-8HVX7` |
| Ativação | licença digital gravada na placa-mãe; sem chave nenhuma o Setup pararia para perguntar a edição | |
| ISO | Windows 11 em Português (Brasil), da Microsoft | |
| Conta | `alexandre`, administrador, **sem senha**, login automático | `<LocalAccount>` e `<AutoLogon>`; se puser senha depois, atualize `DefaultPassword` no Winlogon ou o autologin para |
| PC | nome `RRR`, fuso `E. South America Standard Time`, teclado ABNT2 (`0416:00010416`) | `specialize` e `oobeSystem` |
| Bloatware | lista em `especializar.ps1`; ficam Loja, App Installer, Calculadora, Fotos, Bloco de Notas, Paint, Captura, Terminal | |

## Rodar o setup num Windows já instalado

PowerShell como administrador:

```powershell
irm https://raw.githubusercontent.com/eualexandrerrr/mywiniso/main/setup.ps1 | iex
```

O `primeiro-logon.ps1` deixa um `mywiniso-setup.cmd` na área de trabalho que faz exatamente isso.

## Depois de instalado

- **NVIDIA App** não está no winget; o driver vem pelo Windows Update no passo 7. Baixe o app em nvidia.com.
- **RedM.exe** fica na área de trabalho; o instalador dele não tem modo silencioso.
- **Office**: a chave do `Configuracao.xml` é a GVLK pública da Microsoft para volume, que só ativa contra um
  servidor KMS de organização. Com licença pessoal, troque o produto por `ProPlus2024Retail` ou `O365ProPlusRetail`.
- **Tela de bloqueio**: o wallpaper entra pela `PersonalizationCSP`, que trava a opção em Configurações. Para
  liberar, apague a chave `HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP`.
- **AtlasOS** é opcional: aplique o playbook por cima, se quiser os tweaks de jogo.

## Se algo der errado

| Fase | Log |
|:--|:--|
| WinPE não achou o disco | `X:\mywiniso\disco.log`; o Bloco de Notas abre sozinho com ele e nada foi apagado |
| specialize | `C:\Windows\Setup\Scripts\especializar.log` |
| primeiro logon e setup | `C:\Users\alexandre\mywiniso.log` |

Sem internet no primeiro logon, o `primeiro-logon.ps1` desiste depois de 5 minutos e o
`mywiniso-setup.cmd` da área de trabalho roda o resto quando a rede voltar.

## Referências

- [Unattend Generator (schneegans.de)](https://schneegans.de/windows/unattend-generator/): de onde vem a técnica de embutir scripts no XML e o caminho `C:\Windows\Panther\unattend.xml`
- [Ventoy auto_install](https://www.ventoy.net/en/plugin_autoinstall.html)
- [Microsoft: layout de partições UEFI/GPT](https://learn.microsoft.com/windows-hardware/manufacture/desktop/configure-uefigpt-based-hard-drive-partitions)
- [Microsoft: chaves genéricas de instalação (KMS client setup keys)](https://learn.microsoft.com/windows-server/get-started/kms-client-activation-keys)
