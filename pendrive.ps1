<#
  Coloca o autounattend.xml no pendrive SEM formatar e SEM mexer nas ISOs que já estão lá.

    powershell -ExecutionPolicy Bypass -File .\pendrive.ps1 E: -Senha 123          # letra do pendrive
    powershell -ExecutionPolicy Bypass -File .\pendrive.ps1 E: win11.iso -Senha 123 # mais de uma ISO: diga qual

  -Senha vira a senha da conta Alexandre (e do root do MariaDB) só na cópia do XML gravada no pendrive;
  o autounattend.xml do repositório continua sem senha. Sem -Senha a conta fica sem senha e o RDP não entra.

  Dois tipos de pendrive são aceitos:
    Ventoy             copia autounattend.xml e ventoy.json para \ventoy, apontando para a ISO do Windows
                       que já está no pendrive
    Windows extraído   (Rufus, Media Creation Tool) copia autounattend.xml para a raiz; o Setup lê de lá

  Qualquer outro caso o script para e explica. Ele nunca apaga nada.
#>
param(
    [Parameter(Mandatory = $true)] [string] $Letra,
    [string] $Iso,
    [string] $Senha
)
$ErrorActionPreference = 'Stop'

# Confere se a mídia é pt-BR: o XML pede pt-BR no WinPE e, com ISO de outro idioma, o Setup para com erro.
function Test-Idioma([string] $LangIni) {
    if (-not (Test-Path -LiteralPath $LangIni)) { throw "não achei $LangIni" }
    if (-not (Select-String -Path $LangIni -Pattern 'pt-BR' -Quiet)) {
        throw "a mídia não tem pt-BR (sources\lang.ini). Baixe a ISO em Português (Brasil) ou troque os 'pt-BR' do autounattend.xml."
    }
    Write-Host 'idioma: pt-BR ok'
}

# Preenche a senha nos dois <Value></Value> (conta e autologon) e no $Senha do primeiro-logon.ps1.
function Set-SenhaXml([string] $Texto, [string] $Senha) {
    if (-not $Senha) { return $Texto }
    $xml = [System.Security.SecurityElement]::Escape($Senha)
    $ps  = $Senha.Replace("'", "''")
    $Texto = $Texto.Replace('<Value></Value>', "<Value>$xml</Value>")
    $Texto = $Texto.Replace("`$Senha = ''", "`$Senha = '$ps'")
    return $Texto
}

# ventoy.json: preserva o que já existe no pendrive, troca só a entrada auto_install desta ISO e deixa
# esta ISO como entrada padrão do menu (VTOY_DEFAULT_IMAGE), assim o boot vai direto sem apertar nada.
function Merge-VentoyJson([string] $ModeloJson, [string] $Existente, [string] $Imagem) {
    $novo = $ModeloJson | ConvertFrom-Json
    $novo.auto_install[0].image = $Imagem
    $atual = if ($Existente) { $Existente | ConvertFrom-Json } else { $novo }
    $lista = @($atual.auto_install | Where-Object { $_ -and $_.image -ne $Imagem }) + @($novo.auto_install)
    if ($atual.PSObject.Properties['auto_install']) { $atual.auto_install = $lista }
    else { $atual | Add-Member -NotePropertyName 'auto_install' -NotePropertyValue $lista }
    $controle = @($atual.control | Where-Object { $_ -and -not $_.PSObject.Properties['VTOY_DEFAULT_IMAGE'] }) + @([pscustomobject]@{ VTOY_DEFAULT_IMAGE = $Imagem })
    if ($atual.PSObject.Properties['control']) { $atual.control = $controle }
    else { $atual | Add-Member -NotePropertyName 'control' -NotePropertyValue $controle }
    return ($atual | ConvertTo-Json -Depth 10)
}

$l = $Letra.Trim().TrimEnd('\').TrimEnd(':').ToUpper()
if ($l.Length -ne 1) { throw "letra inválida: $Letra" }
$raiz = "${l}:\"
if (-not (Test-Path -LiteralPath $raiz)) { throw "$raiz não existe" }

$part = Get-Partition -DriveLetter $l
$disco = Get-Disk -Number $part.DiskNumber
if ($disco.BusType -ne 'USB') { throw "$raiz não é USB ($($disco.BusType)); me recuso a mexer" }
Write-Host ("pendrive: {0}, {1} GB" -f $disco.FriendlyName, [math]::Round($disco.Size / 1GB))

$xmlTexto = Set-SenhaXml (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'autounattend.xml') -Raw) $Senha
$modelo = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'ventoy\ventoy.json') -Raw
if (-not $Senha) { Write-Warning 'sem -Senha: a conta fica sem senha e a Área de Trabalho Remota não aceita login.' }

$ehVentoy = [bool](Get-Partition -DiskNumber $disco.Number |
    ForEach-Object { Get-Volume -Partition $_ -ErrorAction SilentlyContinue } |
    Where-Object FileSystemLabel -eq 'VTOYEFI')

if ($ehVentoy) {
    Write-Host 'pendrive Ventoy detectado'
    $isos = @(Get-ChildItem -LiteralPath $raiz -Recurse -Depth 2 -Filter '*.iso' -File |
        ForEach-Object { $_.FullName.Substring($raiz.Length) })
    if ($isos.Count -eq 0) { throw 'nenhuma .iso no pendrive' }
    if ($Iso) {
        if (-not (Test-Path -LiteralPath (Join-Path $raiz $Iso))) { throw "não achei $Iso no pendrive. Tem: $($isos -join ', ')" }
        $isoRel = $Iso
    } elseif ($isos.Count -eq 1) {
        $isoRel = $isos[0]
    } else {
        throw "mais de uma ISO; passe o nome como 2º argumento:`n  " + ($isos -join "`n  ")
    }
    $isoPath = Join-Path $raiz $isoRel
    $imagem = '/' + ($isoRel -replace '\\', '/')
    Write-Host "ISO: $imagem"

    $img = Mount-DiskImage -ImagePath $isoPath -PassThru
    try {
        $li = ($img | Get-Volume).DriveLetter
        if (-not (Test-Path -LiteralPath "${li}:\sources\boot.wim")) { throw "$imagem não é uma ISO de instalação do Windows" }
        Test-Idioma "${li}:\sources\lang.ini"
    } finally {
        Dismount-DiskImage -ImagePath $isoPath | Out-Null
    }

    New-Item -ItemType Directory -Path "$raiz\ventoy" -Force | Out-Null
    [System.IO.File]::WriteAllText("$raiz\ventoy\autounattend.xml", $xmlTexto, [System.Text.UTF8Encoding]::new($false))
    $destino = "$raiz\ventoy\ventoy.json"
    $existente = $null
    if (Test-Path -LiteralPath $destino) {
        Copy-Item -LiteralPath $destino -Destination "$destino.bak" -Force
        $existente = Get-Content -LiteralPath $destino -Raw
        Write-Host 'ventoy.json existente preservado (cópia em ventoy.json.bak)'
    }
    $json = Merge-VentoyJson $modelo $existente $imagem
    [System.IO.File]::WriteAllText($destino, $json, [System.Text.UTF8Encoding]::new($false))   # sem BOM: o Ventoy não aceita
    Write-Host 'gravado: \ventoy\autounattend.xml e \ventoy\ventoy.json'

} elseif (Test-Path -LiteralPath "$raiz\sources\boot.wim") {
    Write-Host 'pendrive com o Windows extraído detectado'
    Test-Idioma "$raiz\sources\lang.ini"
    [System.IO.File]::WriteAllText("$raiz\autounattend.xml", $xmlTexto, [System.Text.UTF8Encoding]::new($false))
    Write-Host 'gravado: \autounattend.xml (o Setup procura na raiz da mídia removível)'

} else {
    throw @"
Não reconheci o pendrive: não é Ventoy e não tem sources\boot.wim.
Para transformar em Ventoy (isso APAGA o pendrive, tire as ISOs antes):
  baixe em https://www.ventoy.net, rode Ventoy2Disk.exe (GPT, Secure Boot ligado),
  copie a ISO do Windows para ele e rode este script de novo.
"@
}

Write-Host 'pronto. Ao dar boot: no Ventoy, escolha a ISO; o template é aplicado sozinho em 5 s.'
