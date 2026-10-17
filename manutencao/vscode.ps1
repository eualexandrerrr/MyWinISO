# Atualiza o VS Code no logon, antes de ele abrir (tarefa 'VS Code atualizado', criada pelo setup.ps1).
# Pergunta a versão à API de atualização do próprio VS Code, e não ao winget: o manifesto 1.142.0 do winget
# apontava para o instalador da 1.141.2, e o "winget upgrade" reinstalava a 1.141.2 a cada boot, com ~45 s de
# disco e janelas "Instalador" no logon (17/10/2026). Só baixa e instala quando a versão é mesmo mais nova.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'    # com a barra de progresso o Invoke-WebRequest do 5.1 levava minutos
$exe = Join-Path $env:LOCALAPPDATA 'Programs\Microsoft VS Code\Code.exe'
$log = Join-Path $env:TEMP 'vscode-atualizado.log'
function Log([string] $m) { Add-Content -LiteralPath $log -Encoding UTF8 -Value ('{0:dd/MM HH:mm:ss} {1}' -f (Get-Date), $m) }
trap { Log "erro: $($_.Exception.Message)"; break }
# logo depois do logon a rede ainda pode não ter subido: tenta por até 2 min
for ($i = 1; ; $i++) {
    try { $api = Invoke-RestMethod -Uri 'https://update.code.visualstudio.com/api/update/win32-x64-user/stable/latest' -TimeoutSec 20; break }
    catch { if ($i -ge 12) { throw }; Start-Sleep -Seconds 10 }
}
$instalada = if (Test-Path -LiteralPath $exe) { [version](Get-Item -LiteralPath $exe).VersionInfo.ProductVersion } else { [version]'0.0' }
if ([version]$api.productVersion -le $instalada) { Log "$instalada já é a última"; return }
if (Get-Process -Name Code -ErrorAction Ignore) { Log "$($api.productVersion) disponível, mas o VS Code está aberto"; return }    # aberto: fica para o próximo logon
$setup = Join-Path $env:TEMP "VSCodeUserSetup-x64-$($api.productVersion).exe"
Invoke-WebRequest -UseBasicParsing -Uri $api.url -OutFile $setup
if ((Get-FileHash -LiteralPath $setup -Algorithm SHA256).Hash -ne $api.sha256hash) { Remove-Item -LiteralPath $setup; throw 'hash do instalador não confere' }
Start-Process -FilePath $setup -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/MERGETASKS=!runcode' -Wait
Remove-Item -LiteralPath $setup -ErrorAction Ignore
Log "$instalada -> $($api.productVersion): VS Code agora em $((Get-Item -LiteralPath $exe).VersionInfo.ProductVersion)"
