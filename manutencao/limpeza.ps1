<#
  Limpeza de disco, a cada 30 dias, pela tarefa "\mywiniso\Limpeza do Windows".
  Vem do CleanupTask do Sophia Script (farag2). O perfil 1337 do cleanmgr é montado pelo setup.ps1,
  que grava StateFlags1337 nos caches que devem ser tratados.

  StartComponentCleanup limpa o WinSxS. Sem /ResetBase de propósito: com ele você não consegue mais
  desinstalar nenhuma atualização já aplicada.
#>
$ErrorActionPreference = 'Continue'
Get-Process -Name cleanmgr, Dism, DismHost -ErrorAction Ignore | Stop-Process -Force -ErrorAction Ignore
Start-Process -FilePath "$env:SystemRoot\System32\Dism.exe" -ArgumentList '/Online', '/Cleanup-Image', '/StartComponentCleanup', '/NoRestart' -Wait -WindowStyle Hidden
Start-Process -FilePath "$env:SystemRoot\System32\cleanmgr.exe" -ArgumentList '/sagerun:1337' -Wait -WindowStyle Hidden
