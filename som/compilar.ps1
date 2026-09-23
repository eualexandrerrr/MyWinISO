<#
  mywiniso: compila o SomTelas e registra a tarefa de logon que o mantem rodando.

    powershell -NoProfile -ExecutionPolicy Bypass -File compilar.ps1

  Som mudo enquanto os monitores estao apagados (inatividade ou botao Telas do RicePanel), e de volta quando
  acendem. Explicacao no cabecalho do SomTelas.cs. Usa o csc do .NET Framework 4.8.
  Exe em %LOCALAPPDATA%\Programs\SomTelas; tarefa "Som mudo com a tela apagada" no logon, como usuario normal.
#>
$ErrorActionPreference = 'Stop'
$aqui = $PSScriptRoot
$destino = Join-Path $env:LOCALAPPDATA 'Programs\SomTelas'
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $csc)) { throw "nao achei $csc" }

Get-Process -Name SomTelas -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $destino -Force | Out-Null
$exe = Join-Path $destino 'SomTelas.exe'
$saida = & $csc /nologo /codepage:65001 /target:winexe /optimize+ /platform:anycpu "/out:$exe" `
    /r:System.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll (Join-Path $aqui 'SomTelas.cs') 2>&1
if ($LASTEXITCODE -ne 0) { throw "csc saiu com codigo ${LASTEXITCODE}: $($saida -join ' | ')" }
Write-Host "  SomTelas compilado: $exe"

$eu = "$env:USERDOMAIN\$env:USERNAME"
$gatilho = New-ScheduledTaskTrigger -AtLogOn -User $eu
Register-ScheduledTask -TaskName 'Som mudo com a tela apagada' -Force `
    -Action (New-ScheduledTaskAction -Execute $exe -WorkingDirectory $destino) -Trigger $gatilho `
    -Principal (New-ScheduledTaskPrincipal -UserId $eu -LogonType Interactive -RunLevel Limited) `
    -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero)) | Out-Null
Start-ScheduledTask -TaskName 'Som mudo com a tela apagada'
Write-Host "  tarefa 'Som mudo com a tela apagada': no logon e rodando agora"
