<#
  Arquivos temporários e pastas de sobra de instalação, toda semana, pela tarefa
  "\mywiniso\Arquivos temporários". Vem do TempTask do Sophia Script (farag2).

  %SystemDrive%\Recovery só entra se tiver ReAgentOld.xml, que é a guarda do Sophia: sem ela você
  apaga o ambiente de recuperação do Windows.
#>
$ErrorActionPreference = 'Continue'

# Em 14/11/2026 o %TEMP% tinha 20 GB (15 GB em %TEMP%\claude, com arquivos de 14/10) mesmo com esta tarefa
# rodando toda semana com resultado 0. A causa não ficou clara; o log abaixo mostra na próxima execução
# quanto havia, quanto sobrou e quantos erros, em vez de engolir tudo calado.
$log = Join-Path $env:LOCALAPPDATA 'mywiniso-temporarios.log'
function Tamanho { [math]::Round((Get-ChildItem -LiteralPath $env:TEMP -Recurse -Force -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum / 1GB, 2) }
$antes = Tamanho
$erros = @()
Get-ChildItem -Path $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable +erros |
    Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-1) } |
    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue -ErrorVariable +erros
$depois = Tamanho
$linha = '{0:yyyy-MM-dd HH:mm} | PS {1} | {2} | antes {3} GB | depois {4} GB | {5} erros' -f (Get-Date), $PSVersionTable.PSVersion, $env:TEMP, $antes, $depois, $erros.Count
Add-Content -LiteralPath $log -Value $linha
$erros | Select-Object -First 5 | ForEach-Object { Add-Content -LiteralPath $log -Value "    $($_.Exception.Message)" }

$pastas = @(
    "$env:SystemDrive\`$WinREAgent"
    "$env:SystemDrive\`$SysReset"
    "$env:SystemDrive\`$Windows.~WS"
    "$env:SystemDrive\`$GetCurrent"
    "$env:SystemDrive\ESD"
    "$env:SystemDrive\Intel"
    "$env:SystemDrive\PerfLogs"
    "$env:SystemRoot\ServiceProfiles\NetworkService\AppData\Local\Temp"
    "$env:LOCALAPPDATA\CrashDumps"
)
if (Get-ChildItem -Path "$env:SystemDrive\Recovery" -Force -ErrorAction Ignore | Where-Object Name -eq 'ReAgentOld.xml') {
    $pastas += "$env:SystemDrive\Recovery"
}
foreach ($p in $pastas) { Remove-Item -Path $p -Recurse -Force -ErrorAction Ignore }

Get-ChildItem -Path "$env:SystemRoot\System32\config\systemprofile\AppData\Local\tw-*.tmp" -Force -ErrorAction Ignore |
    Remove-Item -Force -ErrorAction Ignore
