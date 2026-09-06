<#
  Cache de download do Windows Update, a cada 90 dias, pela tarefa "\mywiniso\Cache do Update".
  Vem do SoftwareDistributionTask do Sophia Script (farag2).

  Espera o wuauserv parar antes de apagar: apagar durante um update em andamento corrompe o download.
#>
$ErrorActionPreference = 'Continue'
$espera = 0
while ((Get-Service -Name wuauserv -ErrorAction Ignore).Status -eq 'Running' -and $espera -lt 3600) {
    Start-Sleep -Seconds 600
    $espera += 600
}
Get-ChildItem -Path "$env:SystemRoot\SoftwareDistribution\Download" -Recurse -Force -ErrorAction Ignore |
    Remove-Item -Recurse -Force -ErrorAction Ignore
