# Mantém o GoLiveBypass (bezumiya/GoLiveBypass): tarefa 'GoLiveBypass atualizado', 1x por semana (criada pelo setup.ps1).
# 1) Garante MTU = 1280 nas configs WireGuard. Sem isso o túnel do ProtonVPN Free deixa as imagens do Discord
#    sem enviar: texto passa (pacote pequeno) e o upload (fluxo grande) trava (27/10/2026). O app regenera
#    essas configs ao trocar de servidor, então a linha é reposta toda semana.
# 2) Instala ou atualiza o app pela release do GitHub (confere o SHA-256 do release). O app também se
#    atualiza sozinho; isto cobre a formatação nova e o app que ficou semanas sem abrir.
# Não mexe no túnel em uso: se o app estiver aberto, a atualização espera a próxima semana.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$destino = 'D:\Apps\desktop\GoLiveBypass'
$exe     = Join-Path $destino 'GoLiveBypass.exe'
$dados   = Join-Path $env:LOCALAPPDATA 'GoLiveBypass'
$log     = Join-Path $env:TEMP 'gobypass-atualizado.log'
function Log([string] $m) { Add-Content -LiteralPath $log -Encoding UTF8 -Value ('{0:dd/MM HH:mm:ss} {1}' -f (Get-Date), $m) }
trap { Log "erro: $($_.Exception.Message)"; break }

# 1) MTU
foreach ($nome in 'wireguard.conf', 'wiresock-discord.conf') {
    $arq = Join-Path $dados $nome
    if (-not (Test-Path -LiteralPath $arq)) { continue }
    $txt = [IO.File]::ReadAllText($arq)
    if ($txt -match '(?m)^\s*MTU\s*=') { Log "$nome já tem MTU"; continue }
    $novo = [regex]::Replace($txt, '(?m)^\[Interface\]\r?\n', "[Interface]`r`nMTU = 1280`r`n", 1)
    if ($novo -eq $txt) { Log "$nome sem [Interface], MTU não aplicado"; continue }
    Copy-Item -LiteralPath $arq -Destination "$arq.bak-mtu" -Force
    [IO.File]::WriteAllText($arq, $novo, (New-Object Text.UTF8Encoding $false))
    Log "${nome}: MTU = 1280 reposto (vale na próxima vez que o bypass subir o túnel)"
}

# 2) versão. Logo depois do logon a rede pode não ter subido: tenta por até 2 min
for ($i = 1; ; $i++) {
    try { $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/bezumiya/GoLiveBypass/releases/latest' -Headers @{ 'User-Agent' = 'mywiniso' } -TimeoutSec 20; break }
    catch { if ($i -ge 12) { throw }; Start-Sleep -Seconds 10 }
}
$ultima    = [version]($rel.tag_name -replace '^v', '')
$instalada = if (Test-Path -LiteralPath $exe) { [version](Get-Item -LiteralPath $exe).VersionInfo.ProductVersion } else { [version]'0.0' }
if ($ultima -le $instalada) { Log "$instalada já é a última"; return }
if (Get-Process -Name GoLiveBypass -ErrorAction Ignore) { Log "$ultima disponível, mas o bypass está aberto"; return }
$asset = $rel.assets | Where-Object { $_.name -eq "GoLiveBypass-$ultima.exe" } | Select-Object -First 1
if (-not $asset) { throw "release $ultima sem GoLiveBypass-$ultima.exe" }
$baixado = Join-Path $env:TEMP $asset.name
Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $baixado
if ($asset.digest -notmatch '^sha256:(.+)$') { Remove-Item -LiteralPath $baixado; throw 'release sem sha256' }
if ((Get-FileHash -LiteralPath $baixado -Algorithm SHA256).Hash -ne $Matches[1]) { Remove-Item -LiteralPath $baixado; throw 'hash do GoLiveBypass não confere' }
New-Item -ItemType Directory -Force -Path $destino | Out-Null
if (Test-Path -LiteralPath $exe) { Move-Item -LiteralPath $exe -Destination "$exe.old" -Force }
Move-Item -LiteralPath $baixado -Destination $exe -Force
Log "$instalada -> ${ultima}: GoLiveBypass agora em $((Get-Item -LiteralPath $exe).VersionInfo.ProductVersion)"
