<#
  Arquivos temporários e pastas de sobra de instalação, a cada 60 dias, pela tarefa
  "\mywiniso\Arquivos temporários". Vem do TempTask do Sophia Script (farag2).

  %SystemDrive%\Recovery só entra se tiver ReAgentOld.xml, que é a guarda do Sophia: sem ela você
  apaga o ambiente de recuperação do Windows.
#>
$ErrorActionPreference = 'Continue'

Get-ChildItem -Path $env:TEMP -Recurse -Force -ErrorAction Ignore |
    Where-Object { $_.CreationTime -lt (Get-Date).AddDays(-1) } |
    Remove-Item -Recurse -Force -ErrorAction Ignore

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
