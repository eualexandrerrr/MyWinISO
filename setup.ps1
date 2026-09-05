<#
  mywiniso: pós-instalação. Roda como administrador em qualquer Windows 11, não só no instalado pelo pendrive.

    irm https://raw.githubusercontent.com/eualexandrerrr/mywiniso/main/setup.ps1 | iex

  1. garante que o winget funciona (em instalação nova ele demora a registrar)
  2. instala o Git e clona este repositório em ~\Projetos\mywiniso, se ainda não estiver rodando de lá
  3. winget import apps.json
  4. RedM na área de trabalho, git config, preferências do usuário, drivers pelo Windows Update
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
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue   # reabre sozinho com as preferências

# --- 7. Drivers e atualizações pelo Windows Update (inclui o driver da NVIDIA) ----------------------
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
