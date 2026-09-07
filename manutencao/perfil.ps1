# Perfil no D:. Toda pasta de configuração que QUALQUER programa cria no perfil do usuário em C: vai para
# D:\Perfil, e no lugar fica uma junção: o programa continua lendo e gravando no caminho de sempre sem saber
# que está em D:. Depois da formatação, o Windows novo em C: roda isto antes de instalar qualquer coisa,
# acha as pastas em D:\Perfil e cria as junções: cada programa nasce já com as preferências de antes.
#
# Regra, e não lista: tudo que houver em cada uma destas raízes, menos o que é do próprio Windows.
#   %APPDATA%              -> D:\Perfil\Roaming\<pasta>       (menos Microsoft)
#   %LOCALAPPDATA%         -> D:\Perfil\Local\<pasta>         (menos Microsoft, Packages, Temp, Programs e caches de instalador)
#   %USERPROFILE%\AppData\LocalLow -> D:\Perfil\LocalLow\<pasta> (menos Microsoft)
#   %USERPROFILE%\.*       -> D:\Perfil\Home\.<pasta>         (.ssh, .claude, .vscode, .config, .cargo, .gradle...)
#   %USERPROFILE%\.<arquivo>  -> symlink para D:\Perfil\Home\.<arquivo>  (.claude.json, .gitconfig...)
# Por que não o AppData inteiro: Local\Microsoft guarda o estado do Explorer e o UsrClass.dat (a colmeia
# HKCU\Software\Classes), Local\Packages são os apps da Loja (ACL por pacote, quebram fora do lugar) e
# Roaming\Microsoft tem o Menu Iniciar, Recentes e as chaves DPAPI da conta. Mover isso quebra Start,
# barra e atalhos, como a documentação e os relatos confirmam. Uma junção por pasta de programa, não.
#
# Quem tem razão quando os dois lados existem: o arquivo mais novo (robocopy /XO). Na reinstalação o C: tem
# só o que o instalador acabou de criar e o D: tem o perfil de verdade; num programa novo o D: nem existe.
# Pasta em uso (programa aberto) não se move: o rename da pasta é o teste, porque o NTFS recusa renomear uma
# pasta com arquivo aberto dentro. Fica para a próxima rodada: a tarefa 'Perfil no D' roda a cada logon,
# antes dos programas de inicialização, e de hora em hora.
#
# O que NÃO volta, por desenho do Windows: o que os programas cifram com a DPAPI da conta (cookies e sessões
# do Chrome, token do Discord e do Spotify, credencial do git, hosts.yml do gh). A conta nova tem chave nova;
# esses pedem login de novo. Apps da Loja (Packages) guardam o deles em C:; o Windows Terminal vem do repositório.
param([switch] $Quieto)

$ErrorActionPreference = 'Stop'
$vol = Get-Volume -FileSystemLabel 'Files' -ErrorAction Ignore | Where-Object DriveType -eq 'Fixed' | Select-Object -First 1
if (-not $vol -or -not $vol.DriveLetter) { if (-not $Quieto) { Write-Host '  sem volume Files; perfil fica em C:' }; exit 0 }
$perfil = "$($vol.DriveLetter):\Perfil"
New-Item -ItemType Directory -Path $perfil -Force | Out-Null
$log = Join-Path $perfil 'perfil.log'
$feitos = 0; $emUso = 0
function L([string] $m, [string] $cor = 'Gray') {
    "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m" | Add-Content -LiteralPath $log -Encoding UTF8
    if (-not $Quieto) { Write-Host "  $m" -ForegroundColor $cor }
}
function Reparse($item) { $item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) }
# junção qualquer um cria; symlink de arquivo só administrador (ou Modo de Desenvolvedor). Sem isso, arquivo não se mexe.
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -or
         (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' -ErrorAction Ignore).AllowDevelopmentWithoutDevLicense -eq 1

$raizes = @(
    @{ de = $env:APPDATA;                           para = 'Roaming';  so = '*';  menos = @('Microsoft') },
    @{ de = $env:LOCALAPPDATA;                      para = 'Local';    so = '*';  menos = @('Microsoft', 'Packages', 'Temp', 'Programs', 'Comms', 'ConnectedDevicesPlatform', 'D3DSCache', 'PlaceholderTileLogoFolder', 'Publishers', 'PeerDistRepub', 'TileDataLayer', 'CrashDumps', 'ElevatedDiagnostics', 'Package Cache', 'PackageManagement', 'SquirrelTemp', 'IsolatedStorage') },
    @{ de = "$env:USERPROFILE\AppData\LocalLow";    para = 'LocalLow'; so = '*';  menos = @('Microsoft') },
    @{ de = $env:USERPROFILE;                       para = 'Home';     so = '.*'; menos = @() }
)
foreach ($r in $raizes) {
    $destinoRaiz = Join-Path $perfil $r.para
    New-Item -ItemType Directory -Path $destinoRaiz, $r.de -Force | Out-Null
    # união do que há em C: e do que sobreviveu em D:, para a junção nascer mesmo antes de o programa existir
    $nomes = @(Get-ChildItem -LiteralPath $r.de -Force -ErrorAction Ignore | Where-Object Name -like $r.so | ForEach-Object Name) +
             @(Get-ChildItem -LiteralPath $destinoRaiz -Force -ErrorAction Ignore | Where-Object Name -like $r.so | ForEach-Object Name) |
             Sort-Object -Unique
    foreach ($nome in $nomes) {
        if ($r.menos -contains $nome -or $nome -like '*.mudando' -or $nome -eq 'desktop.ini') { continue }
        $de = Join-Path $r.de $nome; $para = Join-Path $destinoRaiz $nome
        $itC = Get-Item -LiteralPath $de -Force -ErrorAction Ignore
        $itD = Get-Item -LiteralPath $para -Force -ErrorAction Ignore
        if (Reparse $itC) { continue }                                   # já é junção/symlink (nossa ou do Windows)
        $ehPasta = if ($itC) { $itC.PSIsContainer } else { $itD.PSIsContainer }
        if (-not $ehPasta -and -not $admin) { L "$($r.para)\$nome é arquivo; symlink precisa de administrador, fica para a tarefa" 'DarkGray'; continue }
        try {
            if ($itC) {
                # o rename é o teste de "em uso": o NTFS recusa renomear pasta com arquivo aberto dentro
                $tmp = "$de.mudando"
                try { Rename-Item -LiteralPath $de -NewName "$nome.mudando" -Force -ErrorAction Stop }
                # o $Error.RemoveAt tira daqui o registro que o catch acabou de apanhar: pasta em uso e
                # o caminho previsto (a NVIDIA e a de sempre), ja contado em $emUso e dito na linha acima.
                # Sem isso ele fica em $Error, e como este script roda dentro da Etapa do setup, as etapas
                # 7, 13 e 28 fechavam em AVISO com "o acesso ao caminho ... foi negado" -- barulho, nao erro.
                catch {
                    $emUso++; L "$($r.para)\$nome em uso; fica para a próxima rodada" 'DarkGray'
                    if ($Error.Count) { $Error.RemoveAt(0) }
                    continue
                }
                if ($ehPasta) {
                    New-Item -ItemType Directory -Path $para -Force | Out-Null
                    # /MOVE leva e apaga; /XO deixa no C: o que for mais velho que o de D:, e o resto some abaixo
                    robocopy $tmp $para /E /MOVE /XO /XJ /R:0 /W:0 /NFL /NDL /NJH /NJS /NP | Out-Null
                    $rc = $LASTEXITCODE
                    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction Ignore
                    if (Test-Path -LiteralPath $tmp) { L "$($r.para)\${nome}: sobrou $tmp (robocopy $rc); junção adiada" 'Yellow'; continue }
                    $como = if ($itD) { 'juntado com o que já havia em D: (mais novo vence)' } else { 'levado para D:' }
                } else {
                    if (-not $itD -or $itC.LastWriteTime -gt $itD.LastWriteTime) { Move-Item -LiteralPath $tmp -Destination $para -Force }
                    else { Remove-Item -LiteralPath $tmp -Force }
                    $como = if ($itD) { 'o mais novo ficou em D:' } else { 'levado para D:' }
                }
            } else { $como = 'voltou de D:' }
            if ($ehPasta) { New-Item -ItemType Junction -Path $de -Target $para -ErrorAction Stop | Out-Null }
            else {
                # se o symlink falhar o arquivo volta para C: (cópia): o programa não pode ficar sem ele
                try { New-Item -ItemType SymbolicLink -Path $de -Target $para -ErrorAction Stop | Out-Null }
                catch { Copy-Item -LiteralPath $para -Destination $de -Force; throw }
            }
            $feitos++
            L ("{0}\{1} -> {2}: {3}" -f $r.para, $nome, $para, $como) 'Green'
        } catch { L "$($r.para)\$nome FALHOU: $($_.Exception.Message)" 'Red' }
    }
}
L "rodada: $feitos junções feitas, $emUso em uso" $(if ($emUso) { 'Yellow' } else { 'Gray' })
