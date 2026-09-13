<#
  mywiniso: compila o ColarImagem e registra a tarefa de logon que o mantem rodando.

    powershell -NoProfile -ExecutionPolicy Bypass -File compilar.ps1

  Ctrl+V nos terminais: texto pela colagem do proprio terminal (instantaneo) e imagem virando Alt+V, o colar
  imagem do Claude Code. Explicacao completa no cabecalho do ColarImagem.cs. Usa o csc do .NET Framework 4.8.
  Exe em %LOCALAPPDATA%\Programs\ColarImagem; tarefa "Colar imagem" no logon, como usuario normal.
#>
$ErrorActionPreference = 'Stop'
$aqui = $PSScriptRoot
$destino = Join-Path $env:LOCALAPPDATA 'Programs\ColarImagem'
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path -LiteralPath $csc)) { throw "nao achei $csc" }

Get-Process -Name ColarImagem -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path $destino -Force | Out-Null
$exe = Join-Path $destino 'ColarImagem.exe'
$saida = & $csc /nologo /codepage:65001 /target:winexe /optimize+ /platform:anycpu "/out:$exe" `
    /r:System.dll /r:System.Windows.Forms.dll (Join-Path $aqui 'ColarImagem.cs') 2>&1
if ($LASTEXITCODE -ne 0) { throw "csc saiu com codigo ${LASTEXITCODE}: $($saida -join ' | ')" }
Write-Host "  ColarImagem compilado: $exe"

$eu = "$env:USERDOMAIN\$env:USERNAME"
$gatilho = New-ScheduledTaskTrigger -AtLogOn -User $eu
Register-ScheduledTask -TaskName 'Colar imagem' -Force `
    -Action (New-ScheduledTaskAction -Execute $exe -WorkingDirectory $destino) -Trigger $gatilho `
    -Principal (New-ScheduledTaskPrincipal -UserId $eu -LogonType Interactive -RunLevel Limited) `
    -Settings (New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero)) | Out-Null
Start-ScheduledTask -TaskName 'Colar imagem'
Write-Host "  tarefa 'Colar imagem': no logon e rodando agora"
