# Perfil do PowerShell 7 (~\Documents\PowerShell\profile.ps1). O setup.ps1 copia para lá.
function c { & 'C:\Program Files\Git\bin\bash.exe' 'C:\Users\Alexandre\Meu Drive\Utils\git.sh' @args }
function x { claude --dangerously-skip-permissions @args }

Set-PSReadLineOption -HistorySearchCursorMovesToEnd
Set-PSReadLineKeyHandler -Key UpArrow   -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

function prompt {
    $leaf = Split-Path -Leaf $PWD
    if ([string]::IsNullOrEmpty($leaf)) { $leaf = $PWD.Path }
    Write-Host $leaf -ForegroundColor Green -NoNewline
    return "> "
}
