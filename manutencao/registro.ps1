<#
  Configuracao que vive SO no registro, salva em D: e devolvida depois de formatar.

    powershell -NoProfile -ExecutionPolicy Bypass -File registro.ps1            # exporta para D:
    powershell -NoProfile -ExecutionPolicy Bypass -File registro.ps1 -Importar  # devolve de D:

  Por que este script existe: o perfil.ps1 leva PASTA para D:, e resolve quase tudo. Mas alguns
  programas nao guardam nada em pasta, so no registro, e esses se perdiam a cada formatacao:

    Radmin VPN   a rede criada e a identidade da maquina (HKLM) mais a janela (HKCU)
    WinRAR       associacoes, colunas, favoritos
    Lightshot    os atalhos, inclusive o Shift+PrintScreen que a etapa 15 grava

  Windhawk NAO entra de proposito: a etapa 11 do setup reconstroi as chaves dele do zero, com
  versao e DLL do dia. Reimportar um estado velho apontaria para DLL que nao existe mais.

  Formato .reg e nao .xml: o reg.exe importa sem nenhuma dependencia, e o arquivo e legivel.
  HKLM exige elevacao, tanto para exportar quanto para importar; HKCU nao.
#>
param(
    [switch] $Importar,
    [switch] $Quieto
)

$ErrorActionPreference = 'Stop'

# a mesma regra do perfil.ps1: acha o volume pelo rotulo, nao pela letra
$vol = Get-Volume -FileSystemLabel 'Files' -ErrorAction Ignore | Where-Object DriveType -eq 'Fixed' | Select-Object -First 1
if (-not $vol -or -not $vol.DriveLetter) {
    if (-not $Quieto) { Write-Host '  sem volume Files; nada a fazer' }
    exit 0
}
$destino = "$($vol.DriveLetter):\Perfil\Registro"
New-Item -ItemType Directory -Path $destino -Force | Out-Null
$log = Join-Path $destino 'registro.log'

function L([string] $m, [string] $cor = 'Gray') {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" | Add-Content -LiteralPath $log -Encoding UTF8
    if (-not $Quieto) { Write-Host "  $m" -ForegroundColor $cor }
}

# nome do arquivo  =  chave do registro
$chaves = [ordered]@{
    'radmin-hkcu'    = 'HKCU\Software\Famatech'
    'radmin-hklm'    = 'HKLM\SOFTWARE\WOW6432Node\Famatech'
    'winrar'         = 'HKCU\Software\WinRAR'
    'lightshot'      = 'HKCU\Software\Skillbrains'
    '7zip'           = 'HKCU\Software\7-Zip'
    'steam-hkcu'     = 'HKCU\Software\Valve\Steam'
    'fivem'          = 'HKCU\Software\CitizenFX'
}

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$feitos = 0; $pulados = 0

foreach ($nome in $chaves.Keys) {
    $chave = $chaves[$nome]
    $arq   = Join-Path $destino "$nome.reg"

    if ($chave.StartsWith('HKLM') -and -not $admin) {
        L "$nome : HKLM precisa de administrador; pulado" 'DarkGray'; $pulados++; continue
    }

    if ($Importar) {
        if (-not (Test-Path -LiteralPath $arq)) { L "$nome : sem $arq; nada a devolver" 'DarkGray'; $pulados++; continue }
        $saida = cmd.exe /c "reg.exe import `"$arq`" 2>&1"
        if ($LASTEXITCODE -eq 0) { L "$nome : devolvido de $arq" 'Green'; $feitos++ }
        else { L "$nome : reg import falhou -> $saida" 'Red' }
    }
    else {
        # reg.exe query e o teste barato de existencia: query numa chave ausente devolve != 0
        cmd.exe /c "reg.exe query `"$chave`" >nul 2>&1" | Out-Null
        if ($LASTEXITCODE -ne 0) { L "$nome : $chave nao existe ainda; pulado" 'DarkGray'; $pulados++; continue }
        $saida = cmd.exe /c "reg.exe export `"$chave`" `"$arq`" /y 2>&1"
        if ($LASTEXITCODE -eq 0) {
            $kb = [math]::Round((Get-Item -LiteralPath $arq).Length / 1KB, 1)
            L "$nome : $chave -> $arq ($kb KB)" 'Green'; $feitos++
        }
        else { L "$nome : reg export falhou -> $saida" 'Red' }
    }
}

L ("rodada: {0} {1}, {2} pulado(s)" -f $feitos, $(if ($Importar) { 'devolvido(s)' } else { 'exportado(s)' }), $pulados)
