<#
  mywiniso: pós-instalação. Roda como administrador em qualquer Windows 11, não só no instalado pelo pendrive.

    irm https://raw.githubusercontent.com/eualexandrerrr/mywiniso/main/setup.ps1 | iex

  1. garante que o winget funciona (em instalação nova ele demora a registrar)
  2. instala o Git e clona este repositório em ~\Projetos\mywiniso, se ainda não estiver rodando de lá
  3. winget import apps.json
  4. RedM na área de trabalho, git config, preferências e energia, Office, wallpaper, RDP, WSL com Debian,
     drivers pelo Windows Update
#>

$ErrorActionPreference = 'Continue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Repo = 'https://github.com/eualexandrerrr/mywiniso'
$Dir  = Join-Path $env:USERPROFILE 'Projetos\mywiniso'

function Info([string] $m) { Write-Host "`n== $m" -ForegroundColor Cyan }
function Refresh-Path {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}
function Set-Reg([string] $Path, [string] $Name, $Value, [string] $Type = 'DWord') {
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
    Set-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -Type $Type -Force
}

$eu = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $eu.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Rode como administrador.'
}

# --- 1. winget -------------------------------------------------------------------------------------
Info 'winget'
function Test-Winget { [bool](Get-Command winget.exe -ErrorAction SilentlyContinue) }
if (-not (Test-Winget)) {
    Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction SilentlyContinue
    Refresh-Path
}
if (-not (Test-Winget)) {
    Install-PackageProvider -Name NuGet -Force -Scope AllUsers | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module -Name Microsoft.WinGet.Client -Force -Scope AllUsers
    Repair-WinGetPackageManager -AllUsers -Latest -Force
    Refresh-Path
}
if (-not (Test-Winget)) { throw 'winget não ficou disponível. Abra a Microsoft Store, atualize o "Instalador de Aplicativo" e rode de novo.' }
winget.exe source update --disable-interactivity | Out-Null

# --- 2. Git e clone ---------------------------------------------------------------------------------
$aqui = if ($PSScriptRoot) { $PSScriptRoot } else { '' }
if (-not ($aqui -and (Test-Path -LiteralPath (Join-Path $aqui 'apps.json')))) {
    Info 'Git e clone do repositório'
    if (-not (Get-Command git.exe -ErrorAction SilentlyContinue)) {
        winget.exe install --id Git.Git -e --silent --accept-package-agreements --accept-source-agreements --disable-interactivity
        Refresh-Path
    }
    if (Test-Path -LiteralPath $Dir) {
        git.exe -C $Dir pull --ff-only
    } else {
        New-Item -ItemType Directory -Path (Split-Path -Parent $Dir) -Force | Out-Null
        git.exe clone $Repo $Dir
    }
    if (-not (Test-Path -LiteralPath (Join-Path $Dir 'apps.json'))) { throw "Não consegui clonar $Repo em $Dir." }
    & (Join-Path $Dir 'setup.ps1')       # roda a cópia clonada, que tem o apps.json ao lado
    exit $LASTEXITCODE
}

# --- 3. Programas -----------------------------------------------------------------------------------
Info 'Programas (winget import apps.json)'
winget.exe import -i (Join-Path $aqui 'apps.json') --accept-package-agreements --accept-source-agreements --ignore-unavailable --disable-interactivity
Refresh-Path

# --- 4. RedM ----------------------------------------------------------------------------------------
# O instalador não tem modo silencioso: fica na área de trabalho para abrir uma vez.
Info 'RedM'
$desktop = [Environment]::GetFolderPath('Desktop')
try {
    Invoke-WebRequest -UseBasicParsing -Uri 'https://runtime.fivem.net/redm/RedM.exe' -OutFile (Join-Path $desktop 'RedM.exe')
} catch { Write-Warning "RedM: $_" }

# --- 5. Git -----------------------------------------------------------------------------------------
Info 'git config'
git.exe config --global user.name  'Alexandre Rangel'
git.exe config --global user.email 'mamutal91@gmail.com'
git.exe config --global init.defaultBranch main

# --- 6. Preferências do usuário ---------------------------------------------------------------------
Info 'Preferências'
$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
Set-Reg $adv 'HideFileExt'        0     # extensões visíveis
Set-Reg $adv 'TaskbarAl'          0     # ícones da barra à esquerda
Set-Reg $adv 'ShowTaskViewButton' 0
Set-Reg $adv 'TaskbarDa'          0     # sem botão de widgets
Set-Reg $adv 'LaunchTo'           1     # Explorer abre em "Este Computador"
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 1   # só o ícone da busca
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'AppsUseLightTheme'   0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize' 'SystemUsesLightTheme' 0
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1     # busca sem Bing
$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
foreach ($n in 'SilentInstalledAppsEnabled', 'SystemPaneSuggestionsEnabled', 'SoftLandingEnabled',
               'PreInstalledAppsEnabled', 'OemPreInstalledAppsEnabled',
               'SubscribedContent-338388Enabled', 'SubscribedContent-338389Enabled', 'SubscribedContent-310093Enabled') {
    Set-Reg $cdm $n 0
}
# Mouse sem "aprimorar precisão do ponteiro" (aceleração), para jogo
$mouse = 'HKCU:\Control Panel\Mouse'
Set-Reg $mouse 'MouseSpeed'      '0' 'String'
Set-Reg $mouse 'MouseThreshold1' '0' 'String'
Set-Reg $mouse 'MouseThreshold2' '0' 'String'
# Desligar e reiniciar sem travar em "este aplicativo está impedindo o desligamento"
$desk = 'HKCU:\Control Panel\Desktop'
Set-Reg $desk 'AutoEndTasks'         '1'    'String'
Set-Reg $desk 'WaitToKillAppTimeout' '2000' 'String'
Set-Reg $desk 'HungAppTimeout'       '1000' 'String'
Set-Reg "$adv\TaskbarDeveloperSettings" 'TaskbarEndTask' 1              # "Finalizar tarefa" no botão direito da barra
# Reabrir os apps que estavam abertos ao entrar de novo (Contas > Opções de entrada)
Set-Reg 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon' 'RestartApps' 1
# Print Screen não abre a Ferramenta de Captura: a tecla fica livre para o Lightshot
Set-Reg 'HKCU:\Control Panel\Keyboard' 'PrintScreenKeyForSnippingEnabled' 0
# Atalhos de acessibilidade desligados (Shift 5x, Shift por 8 s, NumLock por 5 s): atrapalham no jogo
Set-Reg 'HKCU:\Control Panel\Accessibility\StickyKeys'        'Flags' '506' 'String'
Set-Reg 'HKCU:\Control Panel\Accessibility\ToggleKeys'        'Flags' '58'  'String'
Set-Reg 'HKCU:\Control Panel\Accessibility\Keyboard Response' 'Flags' '122' 'String'
# Game DVR (gravação em segundo plano) desligado
Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0
# Histórico da área de transferência (Win+V) ligado, "ações sugeridas" desligadas
Set-Reg 'HKCU:\Software\Microsoft\Clipboard' 'EnableClipboardHistory' 1
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\SmartActionPlatform\SmartClipboard' 'Disabled' 1
# Menu Iniciar com mais fixados e sem recomendações; sem botão do Copilot
Set-Reg $adv 'Start_Layout'             1
Set-Reg $adv 'Start_IrisRecommendations' 0
Set-Reg $adv 'ShowCopilotButton'        0
# NumLock ligado ao entrar (na sessão e na tela de login)
Set-Reg 'HKCU:\Control Panel\Keyboard'                    'InitialKeyboardIndicators' '2' 'String'
Set-Reg 'Registry::HKU\.DEFAULT\Control Panel\Keyboard'  'InitialKeyboardIndicators' '2' 'String'
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue   # reabre sozinho com as preferências

# Energia: nunca suspender, nunca apagar a tela, sem hibernação
powercfg.exe /change standby-timeout-ac 0
powercfg.exe /change hibernate-timeout-ac 0
powercfg.exe /change monitor-timeout-ac 0
powercfg.exe /hibernate off

# --- 7. Office LTSC 2024 (Office Deployment Tool + office\Configuracao.xml) ------------------------
Info 'Office'
try {
    $odt = Join-Path $env:TEMP 'odt'
    New-Item -ItemType Directory -Path $odt -Force | Out-Null
    Invoke-WebRequest -UseBasicParsing -Uri 'https://officecdn.microsoft.com/pr/wsus/setup.exe' -OutFile (Join-Path $odt 'setup.exe')
    $cfg = Join-Path $aqui 'office\Configuracao.xml'
    $p = Start-Process -FilePath (Join-Path $odt 'setup.exe') -ArgumentList "/configure `"$cfg`"" -Wait -PassThru
    if ($p.ExitCode -ne 0) { Write-Warning "Office: setup.exe saiu com código $($p.ExitCode)" }
} catch { Write-Warning "Office: $_" }

# --- 8. Wallpaper nos dois monitores e na tela de bloqueio ------------------------------------------
Info 'Wallpaper'
$wallDir = Join-Path $env:SystemRoot 'Web\Wallpaper\mywiniso'     # legível pelo SYSTEM, que desenha a tela de bloqueio
New-Item -ItemType Directory -Path $wallDir -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $aqui 'wallpaper\Jason_and_Lucia_Robbery_landscape.jpg') -Destination $wallDir -Force
$wall = Join-Path $wallDir 'Jason_and_Lucia_Robbery_landscape.jpg'
Set-Reg 'HKCU:\Control Panel\Desktop' 'WallPaper'      $wall 'String'
Set-Reg 'HKCU:\Control Panel\Desktop' 'WallpaperStyle' '10'  'String'     # preencher
Set-Reg 'HKCU:\Control Panel\Desktop' 'TileWallpaper'  '0'   'String'
Add-Type -Namespace Win32 -Name Wallpaper -MemberDefinition '[DllImport("user32.dll", SetLastError = true)] public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);'
[Win32.Wallpaper]::SystemParametersInfo(20, 0, $wall, 3) | Out-Null    # SPI_SETDESKWALLPAPER: vale para todos os monitores
$csp = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\PersonalizationCSP'
Set-Reg $csp 'LockScreenImagePath'   $wall 'String'
Set-Reg $csp 'LockScreenImageUrl'    $wall 'String'
Set-Reg $csp 'LockScreenImageStatus' 1

# --- 9. Área de Trabalho Remota (este PC como host) ------------------------------------------------
# Só aceita conta com senha: a do autounattend não tem. Para usar: net user alexandre *  (e atualizar
# DefaultPassword no Winlogon, senão o login automático para).
Info 'Área de Trabalho Remota'
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections' 0
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' 'UserAuthentication' 1
Enable-NetFirewallRule -Group '@FirewallAPI.dll,-28752' -ErrorAction SilentlyContinue   # grupo "Área de Trabalho Remota", nome neutro de idioma

# --- 10. WSL com Debian (wsl\debian.sh configura por dentro) ---------------------------------------
# Em máquina nova, o WSL precisa de um reinício antes de aceitar distro. O script detecta e avisa;
# rodar de novo depois do reinício termina o serviço.
Info 'WSL e Debian'
try {
    wsl.exe --status 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        wsl.exe --install --no-distribution
        Write-Warning 'WSL instalado: precisa reiniciar. Depois rode mywiniso-setup.cmd de novo para instalar e configurar o Debian.'
    } else {
        $distros = ((wsl.exe --list --quiet 2>$null) -join "`n") -replace "`0", ''
        if ($distros -notmatch 'Debian') { wsl.exe --install --distribution Debian --no-launch }
        $aquiWsl = '/mnt/' + $aqui.Substring(0, 1).ToLower() + ($aqui.Substring(2) -replace '\\', '/')
        wsl.exe --distribution Debian --user root -- bash "$aquiWsl/wsl/debian.sh"
        wsl.exe --terminate Debian
    }
} catch { Write-Warning "WSL: $_" }

# --- 11. Drivers e atualizações pelo Windows Update (inclui o driver da NVIDIA) ---------------------
Info 'Windows Update (drivers)'

try {
    Install-PackageProvider -Name NuGet -Force -Scope AllUsers | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers
    Import-Module PSWindowsUpdate
    Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot | Out-Host
} catch { Write-Warning "Windows Update: $_" }

Info 'Pronto. Reinicie. Depois: abra o RedM.exe da área de trabalho e instale o NVIDIA App (não está no winget).'
exit 0
