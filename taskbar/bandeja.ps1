<#
  mywiniso: icones da bandeja (ao lado do relogio) sempre visiveis e nesta ordem: Discord, Spotify, Steam,
  Radmin VPN.

    powershell -NoProfile -ExecutionPolicy Bypass -File bandeja.ps1

  O Windows 11 guarda cada icone em HKCU\Control Panel\NotifyIconSettings\<id>: IsPromoted = 1 e o "sempre
  mostrar" de Configuracoes > Barra de tarefas. A ordem da esquerda para a direita e o valor UIOrderList da
  chave pai, uma lista de ids de 8 bytes (UInt64, little-endian) na ordem da tela. Medido em 13/09/2026.

  A chave de um icone so nasce quando o programa abre pela primeira vez, entao este script nao consegue
  preparar nada antes: ele roda na etapa 26 do setup (antes de reiniciar o Explorer, que le a ordem ao subir)
  e a cada logon pela tarefa 'Startup OnLogon', e da segunda vez em diante tudo ja esta no lugar.
  Programa que ainda nao tem icone e pulado sem erro. O resto dos icones segue na ordem em que estava.
#>
param([string[]] $Ordem = @('Discord.exe', 'Spotify.exe', 'steam.exe', 'RvRvpnGui.exe'))

$k = 'HKCU:\Control Panel\NotifyIconSettings'
if (-not (Test-Path -LiteralPath $k)) { Write-Host '  bandeja: o Windows ainda nao criou NotifyIconSettings; fica para o proximo logon'; exit 0 }

$chaves = @(Get-ChildItem -LiteralPath $k -ErrorAction Ignore | Where-Object { $_.PSChildName -match '^\d+$' } | ForEach-Object {
    $p = Get-ItemProperty -LiteralPath $_.PSPath
    [pscustomobject]@{
        Id      = [UInt64]$_.PSChildName
        Caminho = $_.PSPath
        Exe     = $(if ($p.ExecutablePath) { Split-Path $p.ExecutablePath -Leaf } else { '' })
    }
})

# na ordem pedida; um programa pode ter mais de uma chave (o Discord troca de pasta a cada versao)
$nossos = @(foreach ($exe in $Ordem) { $chaves | Where-Object { $_.Exe -eq $exe } })
foreach ($c in $nossos) { Set-ItemProperty -LiteralPath $c.Caminho -Name IsPromoted -Value 1 -Type DWord }

$atual = (Get-ItemProperty -LiteralPath $k -ErrorAction Ignore).UIOrderList
$ids = @()
if ($atual) { for ($i = 0; $i -le $atual.Length - 8; $i += 8) { $ids += [BitConverter]::ToUInt64($atual, $i) } }
$frente = @($nossos | ForEach-Object { $_.Id })
$resto  = @($ids | Where-Object { $frente -notcontains $_ }) + @($chaves | ForEach-Object { $_.Id } | Where-Object { $frente -notcontains $_ -and $ids -notcontains $_ })

$bytes = New-Object System.Collections.Generic.List[byte]
foreach ($id in @($frente + $resto)) { $bytes.AddRange([BitConverter]::GetBytes([UInt64]$id)) }
Set-ItemProperty -LiteralPath $k -Name UIOrderList -Value ([byte[]]$bytes.ToArray()) -Type Binary

$faltam = @($Ordem | Where-Object { $nossos.Exe -notcontains $_ })
Write-Host ("  bandeja: {0} na frente{1}" -f (($nossos | ForEach-Object { $_.Exe } | Select-Object -Unique) -join ', '), $(if ($faltam) { " (ainda sem icone: $($faltam -join ', '))" } else { '' }))
