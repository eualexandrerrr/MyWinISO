<#
  Retomada depois de um reinício que o próprio Windows pediu durante a instalação.

  Quem cria a tarefa 'mywiniso-retomar' é o setup.ps1, no fim de uma rodada que terminou com reinício
  pendente. No logon seguinte a tarefa chama este script, elevado, e ele roda o setup de novo.

  Rodar de novo é o que "continuar de onde parou" quer dizer aqui: toda etapa do setup é idempotente, e
  numa máquina já configurada a rodada inteira leva menos de dois minutos -- os 45 programas saem em uns
  20 s dizendo "já instalado". O que ficou pela metade (o Debian do WSL, um instalador que só termina
  depois do reinício) é justamente o que anda desta vez. Reiniciar no meio das etapas seria pior: exigiria
  guardar em disco em que ponto parou, e esse estado é mais fácil de errar do que de acertar.

  A senha não ganha cópia nova em disco. Ela sai do primeiro-logon.ps1, onde o pendrive.ps1 já a gravou,
  e vai direto para a variável de ambiente deste processo.
#>
$ErrorActionPreference = 'Continue'
try { $Host.UI.RawUI.WindowTitle = 'mywiniso: retomando depois do reinício' } catch { }

$aqui  = Split-Path -Parent $PSScriptRoot        # manutencao\ -> raiz do clone
$setup = Join-Path $aqui 'setup.ps1'
if (-not (Test-Path -LiteralPath $setup)) {
    Write-Host "não achei $setup. Rode o mywiniso-setup.cmd da área de trabalho." -ForegroundColor Red
    Start-Sleep -Seconds 30
    exit 1
}

$primeiro = 'C:\Windows\Setup\Scripts\primeiro-logon.ps1'
if (Test-Path -LiteralPath $primeiro) {
    $m = [regex]::Match([IO.File]::ReadAllText($primeiro), "\`$Senha\s*=\s*'([^']*)'")
    if ($m.Success -and $m.Groups[1].Value) {
        $env:MYWINISO_SENHA = $m.Groups[1].Value
        Write-Host 'senha recuperada do primeiro-logon.ps1' -ForegroundColor DarkGray
    } else {
        Write-Host 'primeiro-logon.ps1 sem senha gravada; o setup roda sem ela' -ForegroundColor DarkGray
    }
}

Write-Host ("retomando o setup depois do reinício | {0}" -f (Get-Date -Format 'dd/MM/yyyy HH:mm')) -ForegroundColor Cyan
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $setup
exit $LASTEXITCODE
