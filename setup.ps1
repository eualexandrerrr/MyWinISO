<#
  mywiniso: pós-instalação. Roda como administrador em qualquer Windows 11, não só no instalado pelo pendrive.

    irm https://raw.githubusercontent.com/eualexandrerrr/mywiniso/main/setup.ps1 | iex

  Senha: o primeiro-logon.ps1 recebe a senha da conta (injetada pelo pendrive.ps1 -Senha) e repassa em
  $env:MYWINISO_SENHA; aqui ela vira a senha do root do MariaDB. Sem senha, o root fica sem senha e só local.

  O console mostra cada etapa como [n/21], o que ela está fazendo e, no fim dela, OK, AVISO (erros não fatais,
  listados) ou ERRO (a etapa parou; a mensagem aparece). Nenhuma etapa derruba as seguintes. No final sai um
  resumo de todas as etapas e dos programas que falharam. Tudo vai também para ~\mywiniso-setup.log.

   1. garante que o winget funciona          12. Área de Trabalho Remota e política de senha
   2. Git e clone em ~\Projetos\mywiniso     13. energia: Desempenho Máximo, nunca suspender
   3. programas do apps.json, um a um        14. NVIDIA App (instalador silencioso)
   4. RedM na área de trabalho               15. MariaDB: serviço e root
   5. git config                             16. fonte Cascadia Mono, console e VS Code
   6. preferências do usuário                17. perfil do PowerShell
   7. Explorer em Detalhes (WinSetView)      18. barra de tarefas e tarefa de logon
   8. Windhawk: tema Translucent             19. WSL com Debian
   9. Office                                 20. Windows Update (drivers)
  10. wallpaper                              21. monitores: resolução, Hz e posição
  11. foto do perfil
  10. wallpaper
#>
param([string] $Senha = $env:MYWINISO_SENHA)

# Este arquivo é UTF-8 sem BOM: com BOM, "irm | iex" no Windows PowerShell engasga no primeiro caractere. Só que
# sem BOM o Windows PowerShell lê .ps1 pelo -File (ou por &) como ANSI e os acentos viram "Ã¡". Se o texto chegou
# aqui assim, relê o próprio arquivo como UTF-8 e roda de novo, passando a pasta e a senha por variáveis de ambiente.
# Regra para quem edita: fora de comentário, nada de Ó Ô Â Ä Ñ Ò, travessão, seta, cifrão de euro ou emoji dentro de
# strings; lidos como ANSI esses caracteres viram aspas curvas e o arquivo nem chega a rodar.
if ($PSCommandPath -and 'á'.Length -ne 1) {
    $env:MYWINISO_SENHA = $Senha
    $env:MYWINISO_RAIZ  = $PSScriptRoot
    # dot-source, não &: com & o bloco roda em escopo filho e $script:Resultado/$script:Falhas das funções ficam nulos
    . ([scriptblock]::Create([System.IO.File]::ReadAllText($PSCommandPath, [System.Text.Encoding]::UTF8)))
    exit $LASTEXITCODE
}

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
try { $Host.UI.RawUI.WindowTitle = 'mywiniso: setup' } catch { }

$Repo = 'https://github.com/eualexandrerrr/mywiniso'
$Dir  = Join-Path $env:USERPROFILE 'Projetos\mywiniso'
$Log  = Join-Path $env:USERPROFILE 'mywiniso-setup.log'
try { Start-Transcript -Path $Log -Append | Out-Null } catch { }

# ---------------------------------------------------------------------------------------------------
# Console: Etapa envolve cada bloco; Passo é uma linha do que está acontecendo; Falha registra item que
# falhou sem parar a etapa. Erro terminante = ERRO; erro não terminante que sobrou em $Error = AVISO.
# ---------------------------------------------------------------------------------------------------
$TotalEtapas = 21
$NumEtapa    = 0
$Resultado   = New-Object System.Collections.Generic.List[object]
$Falhas      = New-Object System.Collections.Generic.List[string]

function Passo([string] $m) { Write-Host "  - $m" -ForegroundColor Gray }
function Falha([string] $m) { Write-Host "  FALHOU: $m" -ForegroundColor Red; $script:Falhas.Add($m) }
function Etapa([string] $Nome, [scriptblock] $Corpo) {
    $script:NumEtapa++
    Write-Host ''
    Write-Host ("[{0}/{1}] {2}" -f $script:NumEtapa, $TotalEtapas, $Nome) -ForegroundColor Cyan
    $antes  = $Error.Count
    $sw     = [System.Diagnostics.Stopwatch]::StartNew()
    $estado = 'OK'
    $detalhe = ''
    try {
        & $Corpo
    } catch {
        $estado  = 'ERRO'
        $detalhe = $_.Exception.Message
        Write-Host "  ERRO: $detalhe" -ForegroundColor Red
    }
    $novos = $Error.Count - $antes
    if ($estado -eq 'OK' -and $novos -gt 0) {
        $estado = 'AVISO'
        $msgs = @(0..($novos - 1) | ForEach-Object { $Error[$_].Exception.Message })
        $detalhe = $msgs -join ' | '
        Write-Host "  AVISO: $novos erro(s) não fatal(is):" -ForegroundColor Yellow
        $msgs | ForEach-Object { Write-Host "    - $_" -ForegroundColor Yellow }
    }
    $sw.Stop()
    $cor = @{ OK = 'Green'; AVISO = 'Yellow'; ERRO = 'Red' }[$estado]
    Write-Host ("  {0} em {1:n0} s" -f $estado, $sw.Elapsed.TotalSeconds) -ForegroundColor $cor
    $script:Resultado.Add([pscustomobject]@{ Etapa = $Nome; Estado = $estado; Segundos = [int]$sw.Elapsed.TotalSeconds; Detalhe = $detalhe })
}
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
function Set-Reg([string] $Path, [string] $Name, $Value, [string] $Type = 'DWord') {
    # tolerante: valor protegido (TaskbarDa depois de o pacote Widgets sair, por exemplo) entra na lista de falhas
    # com nome e motivo, em vez de sujar $Error e virar um AVISO sem contexto no fim da etapa
    try {
        if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
    } catch {
        Falha ("registro {0}\{1}: {2}" -f ($Path -replace '^HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\', 'HKCU:...\'), $Name, $_.Exception.Message)
    }
}
function Baixar([string] $Url, [string] $Destino) {
    Passo "baixando $Url"
    Invoke-WebRequest -UseBasicParsing -UserAgent 'Mozilla/5.0' -Uri $Url -OutFile $Destino
    Passo ("{0:n1} MB em {1}" -f ((Get-Item -LiteralPath $Destino).Length / 1MB), $Destino)
}

$eu = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $eu.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Rode como administrador.'
}
Write-Host "mywiniso setup | $(Get-Date -Format 'dd/MM/yyyy HH:mm') | usuário $env:USERNAME | senha: $(if ($Senha) { 'sim' } else { 'não' }) | log: $Log"

# --- 1. winget -------------------------------------------------------------------------------------
# A ISO traz um App Installer velho (1.9 na 25H2) que não fala mais com a fonte msstore (certificado, 0x8a15005e)
# e faz qualquer "winget install" sem --source parar pedindo para escolher fonte. Então, além de garantir que o
# winget existe, esta etapa o troca pelo release atual do GitHub quando ele estiver mais de uma versão atrás.
function Test-Winget { [bool](Get-Command winget.exe -ErrorAction Ignore) }
function Get-WingetVersao {
    try {
        $txt = @(winget.exe --version 2>$null | Where-Object { $_ -match '\d+\.\d+' })[-1]
        [version](($txt -replace '^\s*v', '' -replace '-.*$', '').Trim())
    } catch { [version]'0.0' }
}
function Update-Winget {
    $rel   = Invoke-RestMethod -UseBasicParsing -UserAgent 'mywiniso' -TimeoutSec 30 -Uri 'https://api.github.com/repos/microsoft/winget-cli/releases/latest'
    $alvo  = [version]($rel.tag_name -replace '^v', '' -replace '-.*$', '')
    $atual = if (Test-Winget) { Get-WingetVersao } else { [version]'0.0' }
    if ($atual.Major -gt $alvo.Major -or ($atual.Major -eq $alvo.Major -and $atual.Minor -ge ($alvo.Minor - 1))) {
        Passo "winget $atual está em dia (release atual: $alvo)"
        return
    }
    Passo "winget $atual é antigo; instalando o $alvo do GitHub"
    $bundle = @($rel.assets | Where-Object { $_.name -like '*.msixbundle' })[0]
    $deps   = @($rel.assets | Where-Object { $_.name -eq 'DesktopAppInstaller_Dependencies.zip' })[0]
    if (-not $bundle -or -not $deps) { throw "release $($rel.tag_name) sem msixbundle ou sem DesktopAppInstaller_Dependencies.zip" }
    $tmp = Join-Path $env:TEMP 'mywiniso-winget'
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction Ignore
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    Baixar $bundle.browser_download_url (Join-Path $tmp $bundle.name)
    Baixar $deps.browser_download_url (Join-Path $tmp 'deps.zip')
    Expand-Archive -Path (Join-Path $tmp 'deps.zip') -DestinationPath (Join-Path $tmp 'deps') -Force
    $appx = @(Get-ChildItem -Path (Join-Path $tmp 'deps\x64') -Filter '*.appx' | Select-Object -ExpandProperty FullName)
    Passo "Add-AppxPackage $($bundle.name) com $($appx.Count) dependências: $(($appx | Split-Path -Leaf) -join ', ')"
    # -ErrorAction Stop: o erro real vira exceção aqui em vez de só AVISO; 3 tentativas porque no primeiro logon a Loja
    # e o AppReadiness podem estar mexendo no mesmo pacote
    for ($t = 1; $t -le 3; $t++) {
        try { Add-AppxPackage -Path (Join-Path $tmp $bundle.name) -DependencyPath $appx -ForceApplicationShutdown -ErrorAction Stop; break }
        catch { if ($t -eq 3) { throw }; Passo "Add-AppxPackage falhou (tentativa $t/3): $($_.Exception.Message); de novo em 20 s"; Start-Sleep -Seconds 20 }
    }
    Refresh-Path
    for ($i = 0; $i -lt 10 -and (Get-WingetVersao) -lt $alvo; $i++) { Start-Sleep -Seconds 3 }   # o alias winget.exe leva uns segundos para apontar para o novo
    $agora = Get-WingetVersao
    if ($agora -lt $alvo) { throw "instalei o $alvo mas 'winget --version' ainda responde $agora" }
    Passo "winget agora é $agora"
}
Etapa 'winget' {
    if (-not (Test-Winget)) {
        Passo 'winget não responde; registrando o App Installer'
        Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Ignore
        Refresh-Path
    }
    try { Update-Winget } catch { Falha "atualização do winget: $($_.Exception.Message)" }
    if (-not (Test-Winget)) {
        Passo 'ainda não; instalando pelo módulo Microsoft.WinGet.Client (demora uns minutos)'
        Install-PackageProvider -Name NuGet -Force -Scope AllUsers | Out-Null
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Install-Module -Name Microsoft.WinGet.Client -Force -Scope AllUsers
        Repair-WinGetPackageManager -AllUsers -Latest -Force
        Refresh-Path
    }
    if (-not (Test-Winget)) { throw 'winget não ficou disponível. Abra a Microsoft Store, atualize o "Instalador de Aplicativo" e rode de novo.' }
    Passo "winget $(Get-WingetVersao)"
    winget.exe source update --disable-interactivity | Out-Null
}

# --- 2. Git e clone ---------------------------------------------------------------------------------
# Rodando pelo irm/-File (sem apps.json ao lado): instala o Git, clona o repositório e continua pela cópia clonada.
# Se o Git não entrar, baixa o repositório como zip, para que o resto do setup não dependa dele; o Git é tentado
# de novo na etapa 3, porque está no apps.json.
$aqui = if ($PSScriptRoot) { $PSScriptRoot } elseif ($env:MYWINISO_RAIZ) { $env:MYWINISO_RAIZ } else { '' }
if (-not ($aqui -and (Test-Path -LiteralPath (Join-Path $aqui 'apps.json')))) {
    Etapa 'Git e clone do repositório' {
        if (-not (Get-Command git.exe -ErrorAction Ignore)) {
            if (Test-Winget) {
                Passo 'instalando Git (winget, fonte winget)'
                winget.exe install --id Git.Git --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
                if ($LASTEXITCODE -ne 0) { Falha ("Git.Git: winget saiu com código {0} (0x{0:X8})" -f $LASTEXITCODE) }
                Refresh-Path
            } else { Passo 'sem winget; o Git fica para a etapa 3 e o repositório vem pelo zip' }
        }
        if (Get-Command git.exe -ErrorAction Ignore) {
            if (Test-Path -LiteralPath (Join-Path $Dir '.git')) {
                Passo "git pull em $Dir"
                git.exe -C $Dir pull --ff-only
            } else {
                if (Test-Path -LiteralPath $Dir) { Passo "$Dir existe sem .git (veio do zip); trocando pelo clone"; Remove-Item -LiteralPath $Dir -Recurse -Force }
                Passo "git clone $Repo -> $Dir"
                New-Item -ItemType Directory -Path (Split-Path -Parent $Dir) -Force | Out-Null
                git.exe clone $Repo $Dir
            }
        }
        if (-not (Test-Path -LiteralPath (Join-Path $Dir 'apps.json'))) {
            Passo 'sem Git ou sem clone; baixando o repositório como zip'
            $zip = Join-Path $env:TEMP 'mywiniso-main.zip'
            $tmp = Join-Path $env:TEMP 'mywiniso-main'
            Remove-Item -LiteralPath $zip, $tmp -Recurse -Force -ErrorAction Ignore
            Baixar "$Repo/archive/refs/heads/main.zip" $zip
            Expand-Archive -Path $zip -DestinationPath $tmp -Force
            New-Item -ItemType Directory -Path (Split-Path -Parent $Dir) -Force | Out-Null
            Remove-Item -LiteralPath $Dir -Recurse -Force -ErrorAction Ignore
            if (Test-Path -LiteralPath $Dir) {
                Passo "$Dir não pôde ser apagado (pasta aberta em algum terminal ou arquivo em uso); copiando por cima"
                Copy-Item -Path (Join-Path $tmp 'mywiniso-main\*') -Destination $Dir -Recurse -Force
            } else {
                Move-Item -LiteralPath (Join-Path $tmp 'mywiniso-main') -Destination $Dir
            }
        }
        if (-not (Test-Path -LiteralPath (Join-Path $Dir 'apps.json'))) { throw "não consegui obter $Repo em $Dir" }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $Dir 'setup.ps1')) -or -not (Test-Path -LiteralPath (Join-Path $Dir 'apps.json'))) {
        Write-Host "Sem setup.ps1 e apps.json em $Dir não dá para continuar. Veja o erro acima; com internet, rode mywiniso-setup.cmd de novo." -ForegroundColor Red
        try { Stop-Transcript | Out-Null } catch { }
        exit 1
    }
    Passo "continuando pela cópia em $Dir, que tem os arquivos ao lado"
    try { Stop-Transcript | Out-Null } catch { }
    & (Join-Path $Dir 'setup.ps1') -Senha $Senha
    exit $LASTEXITCODE
}
Etapa 'Git e clone do repositório' {
    Passo "rodando de $aqui"
    if ((Get-Command git.exe -ErrorAction Ignore) -and (Test-Path -LiteralPath (Join-Path $aqui '.git'))) {
        # -q e sem 2>&1: no Windows PowerShell 5.1 cada linha de stderr redirecionada do git entraria em $Error e a etapa sairia como AVISO
        git.exe -C $aqui pull --ff-only -q
        if ($LASTEXITCODE -ne 0) { Falha "git pull em $aqui saiu com código $LASTEXITCODE" }
        Passo "commit: $(git.exe -C $aqui log -1 --format='%h %s')"
    } else { Passo 'cópia sem .git ou sem Git; nada a atualizar' }
}

# --- 3. Programas, um a um, com resultado ----------------------------------------------------------
Etapa 'Programas (apps.json)' {
    $lista = Get-Content -LiteralPath (Join-Path $aqui 'apps.json') -Raw | ConvertFrom-Json
    $pacotes = @()
    foreach ($src in $lista.Sources) {
        foreach ($p in $src.Packages) { $pacotes += [pscustomobject]@{ Id = $p.PackageIdentifier; Fonte = $src.SourceDetails.Name } }
    }
    $i = 0
    foreach ($p in $pacotes) {
        $i++
        Write-Host ("  [{0,2}/{1}] {2} ({3})" -f $i, $pacotes.Count, $p.Id, $p.Fonte) -ForegroundColor White
        winget.exe install --id $p.Id --exact --source $p.Fonte --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
        $codigo = $LASTEXITCODE
        if ($codigo -eq 0)                    { Write-Host '        OK' -ForegroundColor Green }
        elseif ($codigo -eq -1978335189)      { Write-Host '        já instalado, sem atualização' -ForegroundColor DarkGray }
        else                                  { Falha ("{0}: winget saiu com código {1} (0x{2:X8})" -f $p.Id, $codigo, $codigo) }
    }
    Refresh-Path
}

# --- 4. RedM ----------------------------------------------------------------------------------------
$desktop = [Environment]::GetFolderPath('Desktop')
Etapa 'RedM na área de trabalho' {
    Baixar 'https://runtime.fivem.net/redm/RedM.exe' (Join-Path $desktop 'RedM.exe')
    Passo 'o instalador não tem modo silencioso: abra o RedM.exe uma vez'
}

# --- 5. Git -----------------------------------------------------------------------------------------
Etapa 'git config' {
    git.exe config --global user.name  'Alexandre Rangel'
    git.exe config --global user.email 'mamutal91@gmail.com'
    git.exe config --global init.defaultBranch main
    Passo "user.name=$(git.exe config --global user.name) user.email=$(git.exe config --global user.email)"
}

# --- 6. Preferências do usuário ---------------------------------------------------------------------
Etapa 'Preferências do usuário' {
    Passo 'Explorer: extensões, Este Computador, menu de contexto clássico'
    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-Reg $adv 'HideFileExt'        0
    Set-Reg $adv 'LaunchTo'           1
    Set-Reg 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' '(Default)' '' 'String'
    Passo 'barra: ícones centralizados, só no monitor principal, sem busca, Visão de Tarefas, widgets e Copilot; "Finalizar tarefa"'
    Set-Reg $adv 'TaskbarAl'          1      # 1 = ícones centralizados
    Set-Reg $adv 'ShowTaskViewButton' 0
    Set-Reg $adv 'TaskbarDa'          0
    Set-Reg $adv 'ShowCopilotButton'  0
    Set-Reg $adv 'MMTaskbarEnabled'  0      # barra de tarefas só no monitor principal
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 0
    Set-Reg "$adv\TaskbarDeveloperSettings" 'TaskbarEndTask' 1
    Passo 'Iniciar: mais fixados, sem recomendações'
    Set-Reg $adv 'Start_Layout'              1
    Set-Reg $adv 'Start_IrisRecommendations' 0
    Passo 'tema escuro, sem transparência, sem cor de destaque'
    $pers = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    Set-Reg $pers 'AppsUseLightTheme'    0
    Set-Reg $pers 'SystemUsesLightTheme' 0
    Set-Reg $pers 'EnableTransparency'   0
    Set-Reg $pers 'ColorPrevalence'      0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\DWM' 'ColorPrevalence' 0
    Passo 'sem sugestões, apps promovidos e busca com Bing'
    Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1
    $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    foreach ($n in 'ContentDeliveryAllowed', 'FeatureManagementEnabled', 'OEMPreInstalledAppsEnabled', 'PreInstalledAppsEnabled',
                   'PreInstalledAppsEverEnabled', 'SilentInstalledAppsEnabled', 'SoftLandingEnabled', 'SubscribedContentEnabled',
                   'SubscribedContent-310093Enabled', 'SubscribedContent-338387Enabled', 'SubscribedContent-338388Enabled',
                   'SubscribedContent-338389Enabled', 'SubscribedContent-338393Enabled', 'SubscribedContent-353694Enabled',
                   'SubscribedContent-353696Enabled', 'SubscribedContent-353698Enabled', 'SystemPaneSuggestionsEnabled') {
        Set-Reg $cdm $n 0
    }
    Passo 'mouse sem aceleração'
    $mouse = 'HKCU:\Control Panel\Mouse'
    Set-Reg $mouse 'MouseSpeed'      '0' 'String'
    Set-Reg $mouse 'MouseThreshold1' '0' 'String'
    Set-Reg $mouse 'MouseThreshold2' '0' 'String'
    Passo 'teclado: repetição no máximo, cursor rápido, NumLock ligado, Print Screen livre para o Lightshot'
    $kbd = 'HKCU:\Control Panel\Keyboard'
    Set-Reg $kbd 'KeyboardDelay'             '0'  'String'
    Set-Reg $kbd 'KeyboardSpeed'             '31' 'String'
    Set-Reg $kbd 'InitialKeyboardIndicators' '2'  'String'
    Set-Reg 'Registry::HKU\.DEFAULT\Control Panel\Keyboard' 'InitialKeyboardIndicators' '2' 'String'
    Set-Reg 'HKCU:\Control Panel\Desktop' 'CursorBlinkRate' '200' 'String'
    Set-Reg $kbd 'PrintScreenKeyForSnippingEnabled' 0
    Passo 'desligar sem travar em app aberto; reabrir apps ao entrar'
    $desk = 'HKCU:\Control Panel\Desktop'
    Set-Reg $desk 'AutoEndTasks'         '1'    'String'
    Set-Reg $desk 'WaitToKillAppTimeout' '2000' 'String'
    Set-Reg $desk 'HungAppTimeout'       '1000' 'String'
    Set-Reg 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon' 'RestartApps' 1
    Passo 'atalhos de acessibilidade desligados; Game DVR desligado'
    Set-Reg 'HKCU:\Control Panel\Accessibility\StickyKeys'        'Flags' '506' 'String'
    Set-Reg 'HKCU:\Control Panel\Accessibility\ToggleKeys'        'Flags' '58'  'String'
    Set-Reg 'HKCU:\Control Panel\Accessibility\Keyboard Response' 'Flags' '122' 'String'
    Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
    Passo 'histórico Win+V ligado, ações sugeridas desligadas'
    Set-Reg 'HKCU:\Software\Microsoft\Clipboard' 'EnableClipboardHistory' 1
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SmartActionPlatform\SmartClipboard' 'Disabled' 1
    Passo 'sons do sistema desligados'
    Set-Reg 'HKCU:\AppEvents\Schemes' '(Default)' '.None' 'String'
    Get-ChildItem -Path 'HKCU:\AppEvents\Schemes\Apps\*\*' -ErrorAction Ignore |
        Where-Object PSChildName -eq '.Current' |
        ForEach-Object { Set-ItemProperty -LiteralPath $_.PSPath -Name '(Default)' -Value '' }
    Passo 'privacidade: sem experiências personalizadas, ID de anúncio, digitação, fala, localização'
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'         'TailoredExperiencesWithDiagnosticDataEnabled' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
    Set-Reg 'HKCU:\Software\Microsoft\Input\TIPC'                              'Enabled' 0
    Set-Reg 'HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' 'HasAccepted' 0
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value' 'Deny' 'String'
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value' 'Deny' 'String'
    Set-Reg 'HKLM:\SOFTWARE\Microsoft\Settings\FindMyDevice' 'LocationSyncEnabled' 0
    Passo 'apps de bloatware já instalados para este usuário (mesma lista do XML) e provider do Copilot'
    $bloat = @(
        'Clipchamp.Clipchamp', 'Microsoft.549981C3F5F10', 'Microsoft.BingNews', 'Microsoft.BingSearch', 'Microsoft.BingWeather',
        'Microsoft.Copilot', 'Microsoft.Edge.GameAssist', 'Microsoft.GamingApp', 'Microsoft.GetHelp', 'Microsoft.Getstarted',
        'Microsoft.Microsoft3DViewer', 'Microsoft.MicrosoftOfficeHub', 'Microsoft.MicrosoftSolitaireCollection',
        'Microsoft.MicrosoftStickyNotes', 'Microsoft.MixedReality.Portal', 'Microsoft.MSPaint', 'Microsoft.Office.OneNote',
        'Microsoft.OutlookForWindows', 'Microsoft.Paint', 'Microsoft.People', 'Microsoft.PowerAutomateDesktop',
        'Microsoft.ScreenSketch', 'Microsoft.SkypeApp', 'Microsoft.Todos', 'Microsoft.Wallet', 'Microsoft.Windows.DevHome',
        'Microsoft.WindowsAlarms', 'Microsoft.WindowsCamera', 'Microsoft.WindowsFeedbackHub', 'Microsoft.WindowsMaps',
        'Microsoft.WindowsSoundRecorder', 'Microsoft.Xbox.TCUI', 'Microsoft.XboxApp',
        'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay', 'Microsoft.XboxSpeechToTextOverlay', 'Microsoft.YourPhone',
        'Microsoft.ZuneMusic', 'Microsoft.ZuneVideo', 'MicrosoftCorporationII.MicrosoftFamily', 'MicrosoftCorporationII.QuickAssist',
        'MicrosoftTeams', 'MSTeams', 'microsoft.windowscommunicationsapps', 'MicrosoftWindows.Client.WebExperience',
        'Microsoft.WidgetsPlatformRuntime', 'MicrosoftWindows.CrossDevice', 'Microsoft.SecureAssessmentBrowser',
        'Microsoft.Windows.Ai.Copilot.Provider'
    )
    foreach ($app in Get-AppxPackage | Where-Object { $bloat -contains $_.Name }) {
        Passo "removendo $($app.Name)"
        Remove-AppxPackage -Package $app.PackageFullName -ErrorAction Continue
    }
    if (Get-Process -Name OneDrive -ErrorAction Ignore) {
        Passo 'OneDrive rodando: desinstalando'
        Stop-Process -Name OneDrive -Force -ErrorAction Ignore
        foreach ($exe in "$env:SystemRoot\System32\OneDriveSetup.exe", "$env:SystemRoot\SysWOW64\OneDriveSetup.exe", "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDriveSetup.exe") {
            if (Test-Path -LiteralPath $exe) { Start-Process -FilePath $exe -ArgumentList '/uninstall' -Wait }
        }
    }
    Passo 'Bloco de Notas sem o banner da Loja'
    Set-Reg 'HKCU:\Software\Microsoft\Notepad' 'ShowStoreBanner' 0
    Passo 'Modo Jogo ligado, apps em segundo plano desligados, cor de destaque puxada do wallpaper'
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1
    Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode'   1
    Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1
    Set-Reg 'HKCU:\Control Panel\Desktop' 'AutoColorization' 1
    Passo 'região Brasil; ícone do Edge fora da área de trabalho'
    Set-WinHomeLocation -GeoId 32
    Remove-Item -LiteralPath (Join-Path $desktop 'Microsoft Edge.lnk'), 'C:\Users\Public\Desktop\Microsoft Edge.lnk' -Force -ErrorAction Ignore
}

# --- 7. Explorer em Detalhes (WinSetView) ------------------------------------------------------------
# WinSetView (Les Ferch, MIT) grava em HKCU os padrões de exibição de todos os tipos de pasta e reinicia o Explorer.
# O INI é o do Alexandre (explorer\WinSetView\README.md). Roda em outro processo: o script mexe em Set-Location e
# solta dezenas de linhas do reg.exe, que vão para um log próprio em vez do console.
Etapa 'Explorer em Detalhes (WinSetView)' {
    $wsv = Join-Path $aqui 'explorer\WinSetView'
    $ini = Join-Path $wsv 'AppData\Win10.ini'
    if (-not (Test-Path -LiteralPath $ini)) { throw "não achei $ini" }
    $ps1 = Join-Path $wsv 'WinSetView.ps1'
    $logWsv = Join-Path $env:USERPROFILE 'mywiniso-winsetview.log'
    Passo 'Detalhes em todas as pastas: Nome, Caminho, Data de modificação, Tipo, Tamanho; por nome, sem agrupar; extensões visíveis; menu clássico'
    Passo "log: $logWsv"
    # Start-Process em vez de chamar direto: as dezenas de linhas do reg.exe não entram em $Error (viraria AVISO)
    # -Wait porque só com ele o objeto traz ExitCode; a cópia versionada do WinSetView não abre janela no fim,
    # então não há descendente para segurar a espera
    $p = Start-Process -FilePath 'powershell.exe' -ArgumentList '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', "`"$ps1`"", "`"$ini`"" `
        -Wait -PassThru -NoNewWindow -RedirectStandardOutput $logWsv -RedirectStandardError "$logWsv.err"
    if ($null -ne $p.ExitCode -and $p.ExitCode -ne 0) { throw "WinSetView.ps1 saiu com código $($p.ExitCode); veja $logWsv" }
    Passo 'aplicado; o Explorer foi reiniciado'
}

# --- 8. Windhawk: barra, Iniciar e central de notificações translúcidos, menus escuros, sem bordas --------
# Windhawk (winget) mais 5 mods, sem abrir a interface: desde o 1.7 os mods vêm precompilados de mods.windhawk.net e o
# motor lê HKLM\SOFTWARE\Windhawk\Engine\Mods\<id> e carrega o mod na hora, em todos os processos já injetados. Os temas
# Translucent (Undisputed00x) já vêm dentro dos Styler do m417z; só o setting "theme" precisa ser gravado. Cada mod:
# .wh.cpp em ModsSource (a interface lista por ele), a DLL em Engine\Mods\<bits>, e a chave com Include/Exclude/
# Architecture/Version/Settings; LibraryFileName por último, porque é ele que dispara a carga.
Etapa 'Windhawk: tema Translucent' {
    winget.exe install --id RamenSoftware.Windhawk --exact --source winget --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne -1978335189) { throw "winget não instalou o Windhawk (código $LASTEXITCODE)" }
    $wh = Join-Path $env:ProgramFiles 'Windhawk'
    if (-not (Test-Path -LiteralPath (Join-Path $wh 'windhawk.exe'))) { throw "não achei $wh\windhawk.exe" }
    $pd = Join-Path $env:ProgramData 'Windhawk'
    foreach ($d in 'ModsSource', 'Engine\Mods\64', 'Engine\Mods\32') { New-Item -ItemType Directory -Path (Join-Path $pd $d) -Force | Out-Null }
    # bibliotecas que a interface copiaria na primeira abertura; as DLLs precompiladas dos Styler dependem delas
    foreach ($alvo in @(@{ dir = 'x86_64-w64-mingw32'; bits = '64' }, @{ dir = 'i686-w64-mingw32'; bits = '32' })) {
        $bin = Join-Path $wh "Compiler\$($alvo.dir)\bin"
        foreach ($par in @(@('libc++.dll', 'libc++.whl'), @('libunwind.dll', 'libunwind.whl'), @('windhawk-mod-shim.dll', 'windhawk-mod-shim.dll'))) {
            $src = Join-Path $bin $par[0]; $dst = Join-Path $pd "Engine\Mods\$($alvo.bits)\$($par[1])"
            if ((Test-Path -LiteralPath $src) -and -not (Test-Path -LiteralPath $dst)) { Copy-Item -LiteralPath $src -Destination $dst -Force }
        }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $pd 'Engine\Mods\64\libc++.whl'))) {
        Falha 'não achei libc++.whl em Engine\Mods\64 (o Windhawk veio sem a pasta Compiler?); se a barra não ficar translúcida, abra o Windhawk uma vez, que ele copia essas bibliotecas'
    }
    $mods = @(
        @{ id = 'windows-11-taskbar-styler';             settings = @{ theme = 'TranslucentTaskbar'; xamlDiagnosticsHandling = 'block' } },
        @{ id = 'windows-11-start-menu-styler';          settings = @{ theme = 'TranslucentStartMenu' } },
        @{ id = 'windows-11-notification-center-styler'; settings = @{ theme = 'TranslucentShell' } },
        @{ id = 'dark-menus';                            settings = @{} },
        @{ id = 'invisible-borders';                     settings = @{} }
    )
    foreach ($m in $mods) {
        $id  = $m.id
        $src = Join-Path $pd "ModsSource\$id.wh.cpp"
        $dll = $null
        try {
            # fonte e DLL do mesmo servidor: o raw do GitHub pode anunciar uma versão que o mods.windhawk.net
            # ainda não compilou, e aí a URL da DLL daria 404
            $tmpSrc = Join-Path $env:TEMP "$id.wh.cpp"
            Baixar "https://mods.windhawk.net/mods/$id.wh.cpp" $tmpSrc
            $meta = @{}
            foreach ($l in (Get-Content -LiteralPath $tmpSrc -Encoding UTF8 -TotalCount 80)) {
                if ($l -match '^//\s*==/WindhawkMod==') { break }
                if ($l -match '^//\s*@(\w+)\s+(.+?)\s*$') { $meta[$Matches[1]] = @($meta[$Matches[1]]) + $Matches[2] }
            }
            $ver  = "$($meta['version'])".Trim()
            $arch = "$($meta['architecture'])".Trim()
            if (-not $ver) { throw "não achei @version no .wh.cpp" }
            $inc  = @($meta['include'] | Where-Object { $_ }) -join '|'
            $exc  = @($meta['exclude'] | Where-Object { $_ }) -join '|'
            $k    = "HKLM:\SOFTWARE\Windhawk\Engine\Mods\$id"
            $dllAntes = (Get-ItemProperty -LiteralPath $k -Name LibraryFileName -ErrorAction Ignore).LibraryFileName
            $verAntes = (Get-ItemProperty -LiteralPath $k -Name Version -ErrorAction Ignore).Version
            if (-not $dllAntes -or $verAntes -ne $ver) {
                $dll  = "${id}_${ver}_$(Get-Random -Minimum 100000 -Maximum 999999).dll"
                $bits = if ($arch -eq 'x86-64') { @('64') } else { @('64', '32') }
                foreach ($b in $bits) { Baixar "https://mods.windhawk.net/mods/$id/${ver}_$b.dll" (Join-Path $pd "Engine\Mods\$b\$dll") }
            } else { $dll = $dllAntes; Passo "$id $ver já registrado; só conferindo settings" }
            # a fonte só vai para ModsSource depois que a DLL existe, senão a interface lista uma versão que não roda
            Move-Item -LiteralPath $tmpSrc -Destination $src -Force
            Set-Reg $k 'Include'      $inc  'String'
            Set-Reg $k 'Exclude'      $exc  'String'
            Set-Reg $k 'Architecture' $arch 'String'
            Set-Reg $k 'Version'      $ver  'String'
            Set-Reg $k 'Disabled'     0
            foreach ($nome in $m.settings.Keys) { Set-Reg "$k\Settings" $nome $m.settings[$nome] 'String' }
            Set-Reg $k 'SettingsChangeTime' ([int]([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -band 0x7fffffff))
            Set-Reg $k 'LibraryFileName' $dll 'String'
            Passo ("{0} {1}: {2}{3}" -f $id, $ver, $(if ($m.settings.theme) { "tema $($m.settings.theme)" } else { 'ativo' }), $(if ($inc) { " em $inc" } else { '' }))
        } catch {
            # um mod que falha não leva os outros; DLL pela metade sai para não acumular lixo
            if ($dll) { Remove-Item -Path (Join-Path $pd "Engine\Mods\*\$dll") -Force -ErrorAction Ignore }
            Falha ("{0}: {1}" -f $id, $_.Exception.Message)
            continue
        }
    }
    # serviço e ícone da bandeja; o instalador silencioso pode não subir os dois na hora
    Start-Service -Name Windhawk -ErrorAction SilentlyContinue
    if (-not (Get-Process -Name windhawk -ErrorAction SilentlyContinue)) { Start-Process -FilePath (Join-Path $wh 'windhawk.exe') -ArgumentList '-tray-only' }
    Passo "serviço Windhawk: $((Get-Service -Name Windhawk -ErrorAction SilentlyContinue).Status)"
}

# --- 9. Office LTSC 2024 (Office Deployment Tool + office\Configuracao.xml) ------------------------
Etapa 'Office' {
    $odt = Join-Path $env:TEMP 'odt'
    New-Item -ItemType Directory -Path $odt -Force | Out-Null
    Baixar 'https://officecdn.microsoft.com/pr/wsus/setup.exe' (Join-Path $odt 'setup.exe')
    $cfg = Join-Path $aqui 'office\Configuracao.xml'
    Passo "setup.exe /configure $cfg (baixa uns 3 GB da Microsoft; demora)"
    $p = Start-Process -FilePath (Join-Path $odt 'setup.exe') -ArgumentList "/configure `"$cfg`"" -Wait -PassThru
    if ($p.ExitCode -ne 0) { throw "setup.exe do Office saiu com código $($p.ExitCode)" }
    Passo 'instalado'
}

# --- 10. Wallpaper nos dois monitores e na tela de bloqueio ------------------------------------------
Etapa 'Wallpaper' {
    $wallDir = Join-Path $env:SystemRoot 'Web\Wallpaper\mywiniso'     # legível pelo SYSTEM, que desenha a tela de bloqueio
    New-Item -ItemType Directory -Path $wallDir -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $aqui 'wallpaper\Jason_and_Lucia_Robbery_landscape.jpg') -Destination $wallDir -Force
    $wall = Join-Path $wallDir 'Jason_and_Lucia_Robbery_landscape.jpg'
    Passo "área de trabalho (todos os monitores): $wall"
    Set-Reg 'HKCU:\Control Panel\Desktop' 'WallPaper'      $wall 'String'
    Set-Reg 'HKCU:\Control Panel\Desktop' 'WallpaperStyle' '10'  'String'     # preencher
    Set-Reg 'HKCU:\Control Panel\Desktop' 'TileWallpaper'  '0'   'String'
    Add-Type -Namespace Win32 -Name Wallpaper -MemberDefinition '[DllImport("user32.dll", SetLastError = true)] public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);'
    if (-not [Win32.Wallpaper]::SystemParametersInfo(20, 0, $wall, 3)) { throw 'SystemParametersInfo recusou o wallpaper' }
    Passo 'tela de bloqueio (PersonalizationCSP)'
    $csp = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
    Set-Reg $csp 'LockScreenImagePath'   $wall 'String'
    Set-Reg $csp 'LockScreenImageUrl'    $wall 'String'
    Set-Reg $csp 'LockScreenImageStatus' 1
}

# --- 11. Foto do perfil da conta (perfil\avatar.png) -----------------------------------------------
# O Windows guarda a foto da conta em tamanhos fixos dentro de C:\Users\Public\AccountPictures\<SID> e
# aponta cada um no registro, por SID. Sem esses valores a tela de login e o Iniciar mostram o boneco padrão.
Etapa 'Foto do perfil' {
    $origem = Join-Path $aqui 'perfil\avatar.png'
    if (-not (Test-Path -LiteralPath $origem)) { throw "não achei $origem" }
    $sid = ([Security.Principal.NTAccount]"$env:USERDOMAIN\$env:USERNAME").Translate([Security.Principal.SecurityIdentifier]).Value
    $dir = Join-Path $env:PUBLIC "AccountPictures\$sid"
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Add-Type -AssemblyName System.Drawing
    $img = [System.Drawing.Image]::FromFile($origem)
    try {
        $tamanhos = 32, 40, 48, 96, 192, 208, 240, 424, 448, 1080
        $chave = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\$sid"
        foreach ($t in $tamanhos) {
            $arq = Join-Path $dir "Image$t.png"
            $bmp = New-Object System.Drawing.Bitmap $t, $t
            $g = [System.Drawing.Graphics]::FromImage($bmp)
            try {
                $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $g.DrawImage($img, 0, 0, $t, $t)
            } finally { $g.Dispose() }
            $bmp.Save($arq, [System.Drawing.Imaging.ImageFormat]::Png)
            $bmp.Dispose()
            Set-Reg $chave "Image$t" $arq 'String'
        }
        Passo "$($tamanhos.Count) tamanhos em $dir"
    } finally { $img.Dispose() }
    # a cópia no perfil do usuário é a que o Iniciar usa quando o registro ainda não foi lido
    $meu = Join-Path $env:APPDATA 'Microsoft\Windows\AccountPictures'
    New-Item -ItemType Directory -Path $meu -Force | Out-Null
    Copy-Item -LiteralPath $origem -Destination (Join-Path $meu 'avatar.png') -Force
    Passo 'foto da conta aplicada; aparece no Iniciar e na tela de login'
}

# --- 12. Área de Trabalho Remota (este PC como host), senha sem validade, scripts liberados ----------
Etapa 'Área de Trabalho Remota e contas' {
    Passo 'RDP ligado com autenticação de rede; regra de firewall'
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections' 0
    Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' 'UserAuthentication' 1
    Enable-NetFirewallRule -Group '@FirewallAPI.dll,-28752'   # grupo "Área de Trabalho Remota", nome neutro de idioma
    if (-not $Senha) { Passo 'AVISO: conta sem senha; o RDP não aceita login até você definir uma (net user Alexandre *)' }
    Passo 'senha sem validade, sem bloqueio de conta, scripts .ps1 liberados (RemoteSigned)'
    net.exe accounts /maxpwage:unlimited | Out-Null
    net.exe accounts /lockoutthreshold:0 | Out-Null
    try { Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force -ErrorAction Stop }
    catch {
        if ($Error.Count) { $Error.RemoveAt(0) }
        Passo "Set-ExecutionPolicy recusou ($($_.Exception.Message.Trim())); gravando no registro"
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell' 'ExecutionPolicy' 'RemoteSigned' 'String'
    }
}

# --- 13. Energia: Desempenho Máximo, nunca suspender, nunca apagar a tela, sem hibernação ----------
Etapa 'Energia' {
    # Desempenho Máximo (Ultimate Performance) vem oculto no Windows 11; /duplicatescheme cria uma cópia visível.
    # Se a cópia já existe (segunda execução), reaproveita em vez de criar outra.
    $guid = $null
    $lista = (powercfg.exe /list 2>&1) -join "`n"
    if ($lista -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})\s+\((Desempenho M.ximo|Ultimate Performance)\)') {
        $guid = $Matches[1]; Passo "plano Desempenho Máximo já existe: $guid"
    } else {
        $saida = (powercfg.exe /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1) -join "`n"
        if ($saida -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') { $guid = $Matches[1]; Passo "plano Desempenho Máximo criado: $guid" }
        else { $guid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'; Passo 'Desempenho Máximo não disponível; usando Alto desempenho' }
    }
    powercfg.exe /setactive $guid
    Passo 'nunca suspender, nunca apagar a tela, hibernação desligada'
    powercfg.exe /change standby-timeout-ac 0
    powercfg.exe /change hibernate-timeout-ac 0
    powercfg.exe /change monitor-timeout-ac 0
    powercfg.exe /hibernate off
    Passo ((powercfg.exe /getactivescheme) -join ' ')
}

# --- 14. NVIDIA App (não está no winget; instalador silencioso com /s) -----------------------------
Etapa 'NVIDIA App' {
    $url = 'https://us.download.nvidia.com/nvapp/client/11.0.9.251/NVIDIA_app_v11.0.9.251.exe'   # reserva, caso a página mude
    try {
        $html = (Invoke-WebRequest -UseBasicParsing -UserAgent 'Mozilla/5.0' -Uri 'https://www.nvidia.com/en-us/software/nvidia-app/' -TimeoutSec 30).Content
        if ($html -match 'https://[a-z.]*download\.nvidia\.com/nvapp/client/[0-9.]+/NVIDIA_app_v[0-9.]+\.exe') { $url = $Matches[0]; Passo 'URL atual lida da página da NVIDIA' }
        else { Passo 'página da NVIDIA sem link reconhecível; usando a URL de reserva' }
    } catch { Passo "página da NVIDIA inacessível ($($_.Exception.Message)); usando a URL de reserva" }
    $exe = Join-Path $env:TEMP 'NVIDIA_app.exe'
    Baixar $url $exe
    Passo 'instalando com /s (silencioso)'
    $p = Start-Process -FilePath $exe -ArgumentList '/s' -Wait -PassThru
    Remove-Item $exe -Force -ErrorAction Ignore
    if ($p.ExitCode -ne 0) { Falha "NVIDIA App: instalador saiu com código $($p.ExitCode) (sem placa NVIDIA é esperado); instale pelo nvidia.com" }
    else { Passo 'NVIDIA App instalado' }
}

# --- 15. MariaDB: serviço automático, root com a senha da conta e acesso remoto --------------------
Etapa 'MariaDB' {
    $maria = Get-ChildItem -Path 'C:\Program Files\MariaDB*' -Directory -ErrorAction Ignore | Select-Object -First 1
    if (-not $maria) { throw 'não instalado (MariaDB.Server falhou no winget?)' }
    $bin = Join-Path $maria.FullName 'bin'
    Passo "em $($maria.FullName)"
    if (-not (Get-Service -Name MariaDB -ErrorAction Ignore)) {
        Passo 'serviço MariaDB não existe; criando data dir e serviço'
        $data = Join-Path $maria.FullName 'data'
        if (Test-Path -LiteralPath $data) { Remove-Item -LiteralPath $data -Recurse -Force }
        $args = @("--datadir=$data", '--service=MariaDB')
        if ($Senha) { $args += "--password=$Senha" }
        & (Join-Path $bin 'mariadb-install-db.exe') @args
        if ($LASTEXITCODE -ne 0) { throw "mariadb-install-db saiu com código $LASTEXITCODE" }
    }
    Set-Service -Name MariaDB -StartupType Automatic
    Start-Service -Name MariaDB
    Start-Sleep -Seconds 5
    Passo "serviço: $((Get-Service -Name MariaDB).Status)"
    if ($Senha) {
        $sql = "ALTER USER 'root'@'localhost' IDENTIFIED BY '$Senha'; CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '$Senha'; GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION; FLUSH PRIVILEGES;"
        & (Join-Path $bin 'mysql.exe') -u root -e $sql 2>$null                          # root ainda sem senha
        if ($LASTEXITCODE -ne 0) { & (Join-Path $bin 'mysql.exe') -u root "-p$Senha" -e $sql }   # já configurado antes
        if ($LASTEXITCODE -ne 0) { throw 'não consegui definir a senha do root' }
        Passo 'root com senha, acesso local e remoto'
    } else {
        Passo 'sem senha: root sem senha, só local'
    }
}

# --- 16. Fonte Cascadia Mono (máquina), console e VS Code --------------------------------------------
Etapa 'Cascadia Mono, console e VS Code' {
    $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/microsoft/cascadia-code/releases/latest' -Headers @{ 'User-Agent' = 'PowerShell' }
    $asset = $rel.assets | Where-Object { $_.name -like 'CascadiaCode-*.zip' } | Select-Object -First 1
    $zip = Join-Path $env:TEMP 'CascadiaCode.zip'
    $tmp = Join-Path $env:TEMP 'CascadiaCode'
    Baixar $asset.browser_download_url $zip
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    Add-Type -AssemblyName PresentationCore
    $regFontes = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    $n = 0
    foreach ($f in Get-ChildItem -Path $tmp -Recurse -Filter 'CascadiaMono-*.ttf' | Where-Object FullName -like '*static*') {
        $dest = Join-Path $env:WINDIR "Fonts\$($f.Name)"
        Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
        try {
            $gt = [System.Windows.Media.GlyphTypeface]::new([Uri]$dest)
            $familia = $gt.Win32FamilyNames.Values | Select-Object -First 1
            $face    = $gt.Win32FaceNames.Values   | Select-Object -First 1
            $nome = if ($face -and $face -ne 'Regular') { "$familia $face" } else { $familia }
        } catch {
            # o construtor do GlyphTypeface falha em algumas fontes; o nome sai do arquivo e o erro não vira AVISO
            if ($Error.Count) { $Error.RemoveAt(0) }
            $partes  = $f.BaseName -split '-', 2
            $familia2 = $partes[0] -creplace '(?<=[a-z])(?=[A-Z])', ' '
            $face2    = if ($partes.Count -gt 1) { $partes[1] -creplace '(?<=[a-z])(?=Italic)', ' ' } else { '' }
            $nome = if ($face2 -and $face2 -ne 'Regular') { "$familia2 $face2" } else { $familia2 }
        }
        Set-ItemProperty -Path $regFontes -Name "$nome (TrueType)" -Value $f.Name -Type String
        $n++
    }
    Passo "$n arquivos de fonte instalados em C:\Windows\Fonts"
    $consoles = @('HKCU:\Console', 'HKCU:\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe', 'HKCU:\Console\Git Bash', 'HKCU:\Console\Git CMD')
    $pwsh = (Get-Command pwsh.exe -ErrorAction Ignore).Source
    if ($pwsh) { $consoles += "HKCU:\Console\$($pwsh -replace '\\', '_')" }
    foreach ($c in $consoles) {
        Set-Reg $c 'FaceName'   'Cascadia Mono' 'String'
        Set-Reg $c 'FontFamily' 54
        Set-Reg $c 'FontWeight' 400
        Set-Reg $c 'FontSize'   (19 -shl 16)
    }
    Passo "console: Cascadia Mono 19 em $($consoles.Count) perfis"
    $vsDir = Join-Path $env:APPDATA 'Code\User'
    $vsArq = Join-Path $vsDir 'settings.json'
    New-Item -ItemType Directory -Path $vsDir -Force | Out-Null
    $atual = if (Test-Path -LiteralPath $vsArq) { Get-Content -LiteralPath $vsArq -Raw | ConvertFrom-Json } else { New-Object PSObject }
    $novo  = Get-Content -LiteralPath (Join-Path $aqui 'vscode\settings.json') -Raw | ConvertFrom-Json
    foreach ($p in $novo.PSObject.Properties) { $atual | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force }
    $atual | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $vsArq -Encoding UTF8
    Passo "VS Code: $vsArq"
}

# --- 17. Perfil do PowerShell (powershell\profile.ps1) ----------------------------------------------
Etapa 'Perfil do PowerShell' {
    $docs = [Environment]::GetFolderPath('MyDocuments')
    New-Item -ItemType Directory -Path (Join-Path $docs 'PowerShell'), (Join-Path $docs 'WindowsPowerShell') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $aqui 'powershell\profile.ps1') -Destination (Join-Path $docs 'PowerShell\profile.ps1') -Force
    Set-Content -LiteralPath (Join-Path $docs 'WindowsPowerShell\profile.ps1') -Value '. "$HOME\Documents\PowerShell\profile.ps1"' -Encoding UTF8
    Passo "$docs\PowerShell\profile.ps1 (o do Windows PowerShell aponta para ele)"
}

# --- 18. Barra de tarefas (taskbar\LayoutModification.xml) e tarefa "Startup OnLogon" --------------
Etapa 'Barra de tarefas e tarefa de logon' {
    $layout = Join-Path $aqui 'taskbar\LayoutModification.xml'
    foreach ($shell in (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Shell'), 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell') {
        New-Item -ItemType Directory -Path $shell -Force | Out-Null
        Copy-Item -LiteralPath $layout -Destination (Join-Path $shell 'LayoutModification.xml') -Force
    }
    $taskband = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband'
    foreach ($n in 'Favorites', 'FavoritesResolve', 'FavoritesChanges', 'FavoritesVersion') {
        Remove-ItemProperty -Path $taskband -Name $n -ErrorAction Ignore      # força o Explorer a reler o layout
    }
    Passo 'pinos: Explorer, Firefox, Discord, VS Code, WinSCP, Chrome (aparecem quando o Explorer reiniciar)'
    # o script fica no próprio clone: o git pull atualiza a tarefa, e não depende do Google Drive estar sincronizado
    $onlogon = Join-Path $aqui 'startup\startup-onlogon.ps1'
    $acao      = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$onlogon`""
    $gatilho   = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
    $gatilho.Delay = 'PT30S'
    $config    = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName 'Startup OnLogon' -Action $acao -Trigger $gatilho -Settings $config -Principal $principal -Force | Out-Null
    Passo "tarefa 'Startup OnLogon': $onlogon, 30 s depois de entrar"
    Passo 'reiniciando o Explorer para aplicar tema, barra e wallpaper'
    Stop-Process -Name explorer -Force -ErrorAction Ignore
}

# --- 19. WSL com Debian (wsl\debian.sh configura por dentro) ---------------------------------------
Etapa 'WSL com Debian' {
    wsl.exe --status 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Passo 'WSL ainda não instalado; instalando sem distro (precisa reiniciar depois)'
        wsl.exe --install --no-distribution
        if ($LASTEXITCODE -ne 0) {
            # num Windows recém-instalado o componente entra mas o wsl.exe ainda responde com erro até reiniciar
            Falha "wsl --install saiu com código $LASTEXITCODE (normal antes do primeiro reinício)"
        }
        Passo 'reinicie e rode mywiniso-setup.cmd de novo para instalar e configurar o Debian'
    } else {
        $distros = ((wsl.exe --list --quiet 2>$null) -join "`n") -replace "`0", ''
        if ($distros -notmatch 'Debian') {
            Passo 'instalando a distro Debian'
            wsl.exe --install --distribution Debian --no-launch
            if ($LASTEXITCODE -ne 0) { throw "wsl --install -d Debian saiu com código $LASTEXITCODE" }
        } else { Passo 'Debian já instalado' }
        $aquiWsl = '/mnt/' + $aqui.Substring(0, 1).ToLower() + ($aqui.Substring(2) -replace '\\', '/')
        Passo "rodando wsl/debian.sh como root dentro do Debian"
        wsl.exe --distribution Debian --user root -- bash "$aquiWsl/wsl/debian.sh"
        if ($LASTEXITCODE -ne 0) { throw "debian.sh saiu com código $LASTEXITCODE" }
        wsl.exe --terminate Debian
        Passo 'Debian configurado: usuário alexandre, sudo sem senha, systemd'
    }
}

# --- 20. Drivers e atualizações pelo Windows Update ------------------------------------------------
Etapa 'Windows Update (drivers)' {
    Install-PackageProvider -Name NuGet -Force -Scope AllUsers | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers
    Import-Module PSWindowsUpdate
    Passo 'procurando e instalando atualizações e drivers (o driver da NVIDIA vem por aqui)'
    Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot | Out-Host
}

# --- 21. Monitores: resolução, frequência, orientação e posição (monitores\monitores.json) --------
# Depois do Windows Update de propósito: 180 Hz e 1440p só aparecem com o driver da placa instalado.
# Se rodar antes, o driver genérico recusa o modo e a etapa avisa; rodar o setup de novo resolve.
Etapa 'Monitores (resolução, Hz, posição)' {
    $mon  = Join-Path $aqui 'monitores\monitores.ps1'
    $json = Join-Path $aqui 'monitores\monitores.json'
    if (-not (Test-Path -LiteralPath $json)) { throw "não achei $json" }
    Passo 'ASUS XG27ACS em 2560x1440 a 180 Hz como principal; LG UltraGear em 1920x1080 a 144 Hz, de pé, à esquerda'
    & $mon -Arquivo $json
    if ($LASTEXITCODE -ne 0) { Falha "monitores: $LASTEXITCODE monitor(es) não ficaram como no monitores.json; confira o driver da placa e rode de novo" }
}

# --- Resumo -----------------------------------------------------------------------------------------
Write-Host ''
Write-Host '================================ RESUMO ================================' -ForegroundColor Cyan
foreach ($r in $Resultado) {
    $cor = @{ OK = 'Green'; AVISO = 'Yellow'; ERRO = 'Red' }[$r.Estado]
    Write-Host ("  {0,-6} {1,-40} {2,5} s  {3}" -f $r.Estado, $r.Etapa, $r.Segundos, $r.Detalhe) -ForegroundColor $cor
}
if ($Falhas.Count -gt 0) {
    Write-Host ''
    Write-Host "  Programas que falharam ($($Falhas.Count)):" -ForegroundColor Red
    $Falhas | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
}
$erros  = @($Resultado | Where-Object Estado -eq 'ERRO').Count
$avisos = @($Resultado | Where-Object Estado -eq 'AVISO').Count
Write-Host ''
Write-Host ("  {0} etapas: {1} OK, {2} com aviso, {3} com erro. Log: {4}" -f $Resultado.Count, ($Resultado.Count - $erros - $avisos), $avisos, $erros, $Log) -ForegroundColor $(if ($erros) { 'Red' } elseif ($avisos) { 'Yellow' } else { 'Green' })
Write-Host '  Reinicie. Depois: abra o RedM.exe da área de trabalho.' -ForegroundColor Cyan
try { Stop-Transcript | Out-Null } catch { }
exit $erros
