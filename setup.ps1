<#
  mywiniso: pós-instalação. Roda como administrador em qualquer Windows 11, não só no instalado pelo pendrive.

    irm https://raw.githubusercontent.com/eualexandrerrr/mywiniso/main/setup.ps1 | iex

  Senha: o primeiro-logon.ps1 recebe a senha da conta (injetada pelo pendrive.ps1 -Senha) e repassa em
  $env:MYWINISO_SENHA; aqui ela vira a senha do root do MariaDB. Sem senha, o root fica sem senha e só local.

   1. garante que o winget funciona           9. Área de Trabalho Remota e política de senha
   2. Git e clone em ~\Projetos\mywiniso     10. energia: Desempenho Máximo, nunca suspender
   3. winget import apps.json                11. NVIDIA App (instalador silencioso)
   4. RedM na área de trabalho               12. MariaDB: serviço e root
   5. git config                             13. fonte Cascadia Mono, console e VS Code
   6. preferências do usuário                14. perfil do PowerShell
   7. Office                                 15. barra de tarefas e tarefa de logon
   8. wallpaper                              16. WSL com Debian
                                             17. Windows Update (drivers)
#>
param([string] $Senha = $env:MYWINISO_SENHA)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'
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
    & (Join-Path $Dir 'setup.ps1') -Senha $Senha       # roda a cópia clonada, que tem os arquivos ao lado
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
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 0   # sem busca na barra
Set-Reg 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' '(Default)' '' 'String'   # menu de contexto clássico
$pers = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
Set-Reg $pers 'AppsUseLightTheme'   0
Set-Reg $pers 'SystemUsesLightTheme' 0
Set-Reg $pers 'EnableTransparency'  0
Set-Reg $pers 'ColorPrevalence'     0
Set-Reg 'HKCU:\Software\Microsoft\Windows\DWM' 'ColorPrevalence' 0
Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1     # busca sem Bing
$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
foreach ($n in 'ContentDeliveryAllowed', 'FeatureManagementEnabled', 'OEMPreInstalledAppsEnabled', 'PreInstalledAppsEnabled',
               'PreInstalledAppsEverEnabled', 'SilentInstalledAppsEnabled', 'SoftLandingEnabled', 'SubscribedContentEnabled',
               'SubscribedContent-310093Enabled', 'SubscribedContent-338387Enabled', 'SubscribedContent-338388Enabled',
               'SubscribedContent-338389Enabled', 'SubscribedContent-338393Enabled', 'SubscribedContent-353694Enabled',
               'SubscribedContent-353696Enabled', 'SubscribedContent-353698Enabled', 'SystemPaneSuggestionsEnabled') {
    Set-Reg $cdm $n 0
}
# Mouse sem "aprimorar precisão do ponteiro" (aceleração), para jogo
$mouse = 'HKCU:\Control Panel\Mouse'
Set-Reg $mouse 'MouseSpeed'      '0' 'String'
Set-Reg $mouse 'MouseThreshold1' '0' 'String'
Set-Reg $mouse 'MouseThreshold2' '0' 'String'
# Teclado: repetição no máximo, cursor piscando rápido, NumLock ligado ao entrar (sessão e tela de login)
$kbd = 'HKCU:\Control Panel\Keyboard'
Set-Reg $kbd 'KeyboardDelay'             '0'  'String'
Set-Reg $kbd 'KeyboardSpeed'             '31' 'String'
Set-Reg $kbd 'InitialKeyboardIndicators' '2'  'String'
Set-Reg 'Registry::HKU\.DEFAULT\Control Panel\Keyboard' 'InitialKeyboardIndicators' '2' 'String'
Set-Reg 'HKCU:\Control Panel\Desktop' 'CursorBlinkRate' '200' 'String'
# Print Screen não abre a Ferramenta de Captura: a tecla fica livre para o Lightshot
Set-Reg $kbd 'PrintScreenKeyForSnippingEnabled' 0
# Desligar e reiniciar sem travar em "este aplicativo está impedindo o desligamento"
$desk = 'HKCU:\Control Panel\Desktop'
Set-Reg $desk 'AutoEndTasks'         '1'    'String'
Set-Reg $desk 'WaitToKillAppTimeout' '2000' 'String'
Set-Reg $desk 'HungAppTimeout'       '1000' 'String'
Set-Reg "$adv\TaskbarDeveloperSettings" 'TaskbarEndTask' 1              # "Finalizar tarefa" no botão direito da barra
# Reabrir os apps que estavam abertos ao entrar de novo (Contas > Opções de entrada)
Set-Reg 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon' 'RestartApps' 1
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
Set-Reg $adv 'Start_Layout'              1
Set-Reg $adv 'Start_IrisRecommendations' 0
Set-Reg $adv 'ShowCopilotButton'         0
# Sons do sistema desligados (esquema "Sem sons")
Set-Reg 'HKCU:\AppEvents\Schemes' '(Default)' '.None' 'String'
Get-ChildItem -Path 'HKCU:\AppEvents\Schemes\Apps\*\*' -ErrorAction SilentlyContinue |
    Where-Object PSChildName -eq '.Current' |
    ForEach-Object { Set-ItemProperty -LiteralPath $_.PSPath -Name '(Default)' -Value '' }
# Privacidade: sem experiências personalizadas, ID de anúncio, dados de digitação, fala online, localização
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy'         'TailoredExperiencesWithDiagnosticDataEnabled' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0
Set-Reg 'HKCU:\Software\Microsoft\Input\TIPC'                              'Enabled' 0
Set-Reg 'HKCU:\Software\Microsoft\Speech_OneCore\Settings\OnlineSpeechPrivacy' 'HasAccepted' 0
Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value' 'Deny' 'String'
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location' 'Value' 'Deny' 'String'
Set-Reg 'HKLM:\SOFTWARE\Microsoft\Settings\FindMyDevice' 'LocationSyncEnabled' 0
# Região Brasil; ícone do Edge fora da área de trabalho
Set-WinHomeLocation -GeoId 32
Remove-Item -LiteralPath (Join-Path $desktop 'Microsoft Edge.lnk'), 'C:\Users\Public\Desktop\Microsoft Edge.lnk' -Force -ErrorAction SilentlyContinue

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

# --- 9. Área de Trabalho Remota (este PC como host), senha sem validade, scripts liberados ----------
# RDP só aceita conta com senha: use o pendrive.ps1 -Senha, ou net user Alexandre * depois.
Info 'Área de Trabalho Remota e contas'
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server' 'fDenyTSConnections' 0
Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp' 'UserAuthentication' 1
Enable-NetFirewallRule -Group '@FirewallAPI.dll,-28752' -ErrorAction SilentlyContinue   # grupo "Área de Trabalho Remota", nome neutro de idioma
net.exe accounts /maxpwage:unlimited | Out-Null
net.exe accounts /lockoutthreshold:0 | Out-Null
Set-ExecutionPolicy -Scope LocalMachine -ExecutionPolicy RemoteSigned -Force

# --- 10. Energia: Desempenho Máximo, nunca suspender, nunca apagar a tela, sem hibernação ----------
Info 'Energia'
$guid = $null
$saida = powercfg.exe /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>&1 | Out-String    # Ultimate Performance (oculto)
if ($saida -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') { $guid = $Matches[1] }
if (-not $guid) { $guid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c' }                              # Alto desempenho
powercfg.exe /setactive $guid | Out-Null
powercfg.exe /change standby-timeout-ac 0
powercfg.exe /change hibernate-timeout-ac 0
powercfg.exe /change monitor-timeout-ac 0
powercfg.exe /hibernate off

# --- 11. NVIDIA App (não está no winget; instalador silencioso com /s) -----------------------------
Info 'NVIDIA App'
try {
    $url = 'https://us.download.nvidia.com/nvapp/client/11.0.9.251/NVIDIA_app_v11.0.9.251.exe'   # reserva, caso a página mude
    try {
        $html = (Invoke-WebRequest -UseBasicParsing -UserAgent 'Mozilla/5.0' -Uri 'https://www.nvidia.com/en-us/software/nvidia-app/' -TimeoutSec 30).Content
        if ($html -match 'https://[a-z.]*download\.nvidia\.com/nvapp/client/[0-9.]+/NVIDIA_app_v[0-9.]+\.exe') { $url = $Matches[0] }
    } catch { }
    $exe = Join-Path $env:TEMP 'NVIDIA_app.exe'
    Invoke-WebRequest -UseBasicParsing -UserAgent 'Mozilla/5.0' -Uri $url -OutFile $exe
    $p = Start-Process -FilePath $exe -ArgumentList '/s' -Wait -PassThru
    if ($p.ExitCode -ne 0) { Write-Warning "NVIDIA App saiu com código $($p.ExitCode); instale pelo nvidia.com se não abrir." }
    Remove-Item $exe -Force -ErrorAction SilentlyContinue
} catch { Write-Warning "NVIDIA App: $_" }

# --- 12. MariaDB: serviço automático, root com a senha da conta e acesso remoto --------------------
Info 'MariaDB'
try {
    $maria = Get-ChildItem -Path 'C:\Program Files\MariaDB*' -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $maria) { throw 'não instalado (winget MariaDB.Server)' }
    $bin = Join-Path $maria.FullName 'bin'
    if (-not (Get-Service -Name MariaDB -ErrorAction SilentlyContinue)) {
        $data = Join-Path $maria.FullName 'data'
        if (Test-Path -LiteralPath $data) { Remove-Item -LiteralPath $data -Recurse -Force }
        $args = @("--datadir=$data", '--service=MariaDB')
        if ($Senha) { $args += "--password=$Senha" }
        & (Join-Path $bin 'mariadb-install-db.exe') @args | Out-Null
    }
    Set-Service -Name MariaDB -StartupType Automatic
    Start-Service -Name MariaDB -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 5
    if ($Senha) {
        $sql = "ALTER USER 'root'@'localhost' IDENTIFIED BY '$Senha'; CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY '$Senha'; GRANT ALL PRIVILEGES ON *.* TO 'root'@'%' WITH GRANT OPTION; FLUSH PRIVILEGES;"
        & (Join-Path $bin 'mysql.exe') -u root -e $sql 2>$null                          # root ainda sem senha
        if ($LASTEXITCODE -ne 0) { & (Join-Path $bin 'mysql.exe') -u root "-p$Senha" -e $sql }   # já configurado antes
    }
} catch { Write-Warning "MariaDB: $_" }

# --- 13. Fonte Cascadia Mono (máquina), console e VS Code --------------------------------------------
Info 'Cascadia Mono, console e VS Code'
try {
    $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/microsoft/cascadia-code/releases/latest' -Headers @{ 'User-Agent' = 'PowerShell' }
    $asset = $rel.assets | Where-Object { $_.name -like 'CascadiaCode-*.zip' } | Select-Object -First 1
    $zip = Join-Path $env:TEMP 'CascadiaCode.zip'
    $tmp = Join-Path $env:TEMP 'CascadiaCode'
    Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $zip
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Recurse -Force }
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    Add-Type -AssemblyName PresentationCore
    $regFontes = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    foreach ($f in Get-ChildItem -Path $tmp -Recurse -Filter 'CascadiaMono-*.ttf' | Where-Object FullName -like '*static*') {
        $dest = Join-Path $env:WINDIR "Fonts\$($f.Name)"
        Copy-Item -LiteralPath $f.FullName -Destination $dest -Force
        try {
            $gt = [System.Windows.Media.GlyphTypeface]::new([Uri]$dest)
            $familia = $gt.Win32FamilyNames.Values | Select-Object -First 1
            $face    = $gt.Win32FaceNames.Values   | Select-Object -First 1
            $nome = if ($face -and $face -ne 'Regular') { "$familia $face" } else { $familia }
        } catch { $nome = $f.BaseName -replace '-', ' ' }
        Set-ItemProperty -Path $regFontes -Name "$nome (TrueType)" -Value $f.Name -Type String
    }
} catch { Write-Warning "Cascadia Mono: $_" }
$consoles = @('HKCU:\Console', 'HKCU:\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe', 'HKCU:\Console\Git Bash', 'HKCU:\Console\Git CMD')
$pwsh = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
if ($pwsh) { $consoles += "HKCU:\Console\$($pwsh -replace '\\', '_')" }
foreach ($c in $consoles) {
    Set-Reg $c 'FaceName'   'Cascadia Mono' 'String'
    Set-Reg $c 'FontFamily' 54
    Set-Reg $c 'FontWeight' 400
    Set-Reg $c 'FontSize'   (19 -shl 16)
}
try {
    $vsDir = Join-Path $env:APPDATA 'Code\User'
    $vsArq = Join-Path $vsDir 'settings.json'
    New-Item -ItemType Directory -Path $vsDir -Force | Out-Null
    $atual = if (Test-Path -LiteralPath $vsArq) { Get-Content -LiteralPath $vsArq -Raw | ConvertFrom-Json } else { New-Object PSObject }
    $novo  = Get-Content -LiteralPath (Join-Path $aqui 'vscode\settings.json') -Raw | ConvertFrom-Json
    foreach ($p in $novo.PSObject.Properties) { $atual | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force }
    $atual | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $vsArq -Encoding UTF8
} catch { Write-Warning "VS Code settings: $_" }

# --- 14. Perfil do PowerShell (powershell\profile.ps1) ----------------------------------------------
Info 'Perfil do PowerShell'
$docs = [Environment]::GetFolderPath('MyDocuments')
New-Item -ItemType Directory -Path (Join-Path $docs 'PowerShell'), (Join-Path $docs 'WindowsPowerShell') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $aqui 'powershell\profile.ps1') -Destination (Join-Path $docs 'PowerShell\profile.ps1') -Force
Set-Content -LiteralPath (Join-Path $docs 'WindowsPowerShell\profile.ps1') -Value '. "$HOME\Documents\PowerShell\profile.ps1"' -Encoding UTF8

# --- 15. Barra de tarefas (taskbar\LayoutModification.xml) e tarefa "Startup OnLogon" --------------
Info 'Barra de tarefas e tarefa de logon'
$layout = Join-Path $aqui 'taskbar\LayoutModification.xml'
foreach ($shell in (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Shell'), 'C:\Users\Default\AppData\Local\Microsoft\Windows\Shell') {
    New-Item -ItemType Directory -Path $shell -Force | Out-Null
    Copy-Item -LiteralPath $layout -Destination (Join-Path $shell 'LayoutModification.xml') -Force
}
$taskband = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Taskband'
foreach ($n in 'Favorites', 'FavoritesResolve', 'FavoritesChanges', 'FavoritesVersion') {
    Remove-ItemProperty -Path $taskband -Name $n -ErrorAction SilentlyContinue      # força o Explorer a reler o layout
}
try {
    $utils = Join-Path $env:USERPROFILE 'Meu Drive\Utils'
    New-Item -ItemType Directory -Path $utils -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $aqui 'startup\startup-onlogon.ps1') -Destination (Join-Path $utils 'startup-onlogon.ps1') -Force
    $acao      = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$utils\startup-onlogon.ps1`""
    $gatilho   = New-ScheduledTaskTrigger -AtLogOn -User "$env:USERDOMAIN\$env:USERNAME"
    $gatilho.Delay = 'PT30S'
    $config    = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([TimeSpan]::Zero) -StartWhenAvailable
    $principal = New-ScheduledTaskPrincipal -UserId "$env:USERDOMAIN\$env:USERNAME" -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName 'Startup OnLogon' -Action $acao -Trigger $gatilho -Settings $config -Principal $principal -Force | Out-Null
} catch { Write-Warning "Tarefa Startup OnLogon: $_" }
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue   # reabre sozinho com tema, barra e wallpaper

# --- 16. WSL com Debian (wsl\debian.sh configura por dentro) ---------------------------------------
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

# --- 17. Drivers e atualizações pelo Windows Update ------------------------------------------------
Info 'Windows Update (drivers)'
try {
    Install-PackageProvider -Name NuGet -Force -Scope AllUsers | Out-Null
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
    Install-Module -Name PSWindowsUpdate -Force -Scope AllUsers
    Import-Module PSWindowsUpdate
    Get-WindowsUpdate -AcceptAll -Install -IgnoreReboot | Out-Host
} catch { Write-Warning "Windows Update: $_" }

Info 'Pronto. Reinicie. Depois: abra o RedM.exe da área de trabalho.'
exit 0
