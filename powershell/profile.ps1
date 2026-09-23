# O único perfil do PowerShell. Vale para o PowerShell 7 e para o Windows PowerShell 5.1, em qualquer host:
# Windows Terminal, VS Code, console solto, elevado ou não. O setup.ps1 copia este arquivo para
# Documentos\PowerShell\profile.ps1 e faz o Documentos\WindowsPowerShell\profile.ps1 apontar para ele.
# Mesmo desenho do zsh do Debian (wsl/zshrc): starship com o mesmo starship.toml, histórico grande e
# compartilhado, eza, zoxide, e os atalhos c e x. Tudo que é de máquina (histórico, tema) mora em D:\Perfil\Home.
# Nada aqui pode custar tempo: o perfil roda a cada terminal aberto.

# --- ambiente ---------------------------------------------------------------------------------------------
# UTF-8 no console: sem isto o Windows PowerShell 5.1 mostra os glifos do starship como "?".
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$OutputEncoding = [Text.Encoding]::UTF8

$HomeD = 'D:\Perfil\Home'                                      # o "home" que sobrevive à formatação
$env:EDITOR = 'nano'
if (Test-Path -LiteralPath "$HomeD\.config\starship.toml") { $env:STARSHIP_CONFIG = "$HomeD\.config\starship.toml" }
foreach ($p in "$HOME\.local\bin", "$HOME\.maestro\bin") {      # engram e maestro (o setup também põe no Path do usuário)
    if ((Test-Path -LiteralPath $p) -and ($env:Path -split ';') -notcontains $p) { $env:Path = "$p;$env:Path" }
}

# --- histórico: um arquivo só, em D:, para o 5.1, o 7, o VS Code e o Windows Terminal --------------------
# Sem isto cada host guarda o seu (ConsoleHost_history.txt, Visual Studio Code Host_history.txt) em
# Roaming\Microsoft, que a formatação leva. Com o mesmo arquivo, o que foi digitado num vale em todos.
if (Get-Module PSReadLine) {
    if (Test-Path -LiteralPath $HomeD) { Set-PSReadLineOption -HistorySavePath "$HomeD\.ps_history" }
    Set-PSReadLineOption -MaximumHistoryCount 100000 -HistoryNoDuplicates -HistorySearchCursorMovesToEnd
    Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
    # sugestão em cinza a partir do histórico, como o zsh-autosuggestions; só no PSReadLine 2.1+ (o 5.1 vem com o 2.0)
    if ((Get-Module PSReadLine).Version -ge [version]'2.1') { Set-PSReadLineOption -PredictionSource History -PredictionViewStyle InlineView }
}

# --- atalhos, os mesmos do zsh -----------------------------------------------------------------------------
if (Test-Path -LiteralPath 'D:\Utils\git.sh') {
    function c { & 'C:\Program Files\Git\bin\bash.exe' 'D:\Utils\git.sh' @args }
} else { function c { Clear-Host } }
# a sessão leva o nome da pasta atual (aparece no seletor, no título do terminal e no Remote Control do celular);
# -n/--name passado na mão vence
function x {
    $nome = @()
    if (-not ($args | Where-Object { $_ -in '-n', '--name' })) { $nome = '-n', (Split-Path -Leaf $PWD.Path) }
    claude --dangerously-skip-permissions --model opus @nome @args
}
# deploy do Michigan Roleplay (DeployFiles\deploy.mjs), o mesmo do perfil antigo (repo powershell-profile)
if (Test-Path -LiteralPath 'D:\MichiganRoleplay\DeployFiles\deploy.mjs') {
    function deploy {
        Push-Location 'D:\MichiganRoleplay\DeployFiles'
        try { & node deploy.mjs @args } finally { Pop-Location }
    }
}
# ls pelo eza, com ícones e pastas primeiro. Só o ls: cat continua Get-Content, que scripts usam em pipeline.
if (Get-Command eza -ErrorAction Ignore) {
    Remove-Item Alias:ls -Force -ErrorAction Ignore
    function ls { eza --icons --group-directories-first @args }
}
# --- init do zoxide e do starship, de cache ------------------------------------------------------------------
# Rodar "starship init" e passar a saída pelo Invoke-Expression custava ~310 ms a cada terminal aberto
# (medido em 13/09/2026: 35 ms do processo, 275 ms do Invoke-Expression analisando 10 KB de script), e o
# zoxide mais 60 ms. A saída dos dois é sempre a mesma para o mesmo exe (a chave de sessão do starship é
# sorteada dentro do script, não na geração), então vai para um .ps1 em %LOCALAPPDATA% que o PowerShell
# carrega por dot-source, com a análise em cache. O arquivo se refaz sozinho quando o exe muda (caminho,
# data e tamanho no cabeçalho). Dot-source aqui no topo do perfil, e não dentro de função, senão as
# definições ficam no escopo da função. UTF-8 com BOM: o init do starship tem caractere fora do ASCII,
# e sem BOM o 5.1 lê como ANSI. Um arquivo por edição (5.1 e 7).
function Get-InitCache([string] $Nome, [string] $Exe, [string[]] $Argumentos, [string] $Config = '', [scriptblock] $Ajuste = $null) {
    $bin = (Get-Command $Exe -CommandType Application -ErrorAction Ignore | Select-Object -First 1).Source
    if (-not $bin) { return $null }
    $it   = Get-Item -LiteralPath $bin
    $cfg  = if ($Config -and (Test-Path -LiteralPath $Config)) { (Get-Item -LiteralPath $Config).LastWriteTimeUtc.Ticks } else { '' }
    $selo = "# $bin|$($it.LastWriteTimeUtc.Ticks)|$($it.Length)|$cfg"
    $arq  = Join-Path $env:LOCALAPPDATA "mywiniso-pwsh\$Nome-$($PSVersionTable.PSEdition).ps1"
    # StreamReader fechado na hora: ReadLines | Select -First 1 deixava o arquivo aberto e a gravação logo
    # abaixo falhava com "being used by another process"
    $atual = ''
    if (Test-Path -LiteralPath $arq) { $sr = New-Object IO.StreamReader $arq; try { $atual = $sr.ReadLine() } finally { $sr.Dispose() } }
    if ($atual -ne $selo) {
        $corpo = (& $bin @Argumentos | Out-String)
        if (-not $corpo) { return $null }
        if ($Ajuste) { $corpo = & $Ajuste $corpo $bin }
        New-Item -ItemType Directory -Path (Split-Path $arq) -Force | Out-Null
        # grava ao lado e troca: dois terminais abrindo juntos não leem arquivo pela metade; se outro
        # estiver segurando o cache, esta sessão usa a própria cópia e a próxima tenta de novo
        $tmp = "$arq.$PID.tmp"
        [IO.File]::WriteAllText($tmp, "$selo`r`n$corpo", (New-Object Text.UTF8Encoding $true))
        try { Move-Item -LiteralPath $tmp -Destination $arq -Force -ErrorAction Stop } catch { return $tmp }
    }
    return $arq
}
$zoxideInit = Get-InitCache 'zoxide' 'zoxide' @('init', 'powershell')
if ($zoxideInit) { . $zoxideInit }

# --- prompt: starship, com o starship.toml de D: (o mesmo do zsh) -----------------------------------------
# O init do starship ainda chamava "starship prompt --continuation" ao carregar, um processo por terminal
# (~200 ms). O texto só depende do starship.toml, que entra no selo do cache: calcula uma vez e grava pronto.
$starshipInit = Get-InitCache 'starship' 'starship' @('init', 'powershell', '--print-full-init') $env:STARSHIP_CONFIG {
    param($corpo, $bin)
    $cont = (& $bin prompt --continuation | Out-String).TrimEnd("`r", "`n").Replace("'", "''").Replace('$', '$$')
    [regex]::Replace($corpo, '(?s)Set-PSReadLineOption -ContinuationPrompt \(\s*Invoke-Native.*?"--continuation"\s*\)\s*\)', "Set-PSReadLineOption -ContinuationPrompt '$cont'")
}
if ($starshipInit) {
    . $starshipInit
    # O add_newline do starship.toml põe uma linha vazia antes de todo prompt, inclusive do primeiro, e todo
    # terminal novo abria com a primeira linha em branco. Aqui só o primeiro perde esse newline; entre um
    # comando e outro o espaço continua. É um embrulho como o do shell integration do VS Code: o starship lê
    # o $global:?, que a chamada aninhada não muda, então o símbolo vermelho de erro segue certo.
    $global:StarshipPrompt  = $function:prompt
    $global:PrimeiroPrompt  = $true
    function global:prompt {
        $p = & $global:StarshipPrompt
        if ($global:PrimeiroPrompt) { $global:PrimeiroPrompt = $false; $p = $p -replace '^\r?\n', '' }
        $p
    }
} else {
    function prompt {
        $leaf = Split-Path -Leaf $PWD
        if ([string]::IsNullOrEmpty($leaf)) { $leaf = $PWD.Path }
        Write-Host $leaf -ForegroundColor Green -NoNewline
        return '> '
    }
}
