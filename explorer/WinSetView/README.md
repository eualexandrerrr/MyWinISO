# WinSetView

Cópia do [WinSetView](https://github.com/LesFerch/WinSetView) (Les Ferch, MIT), só o que o script precisa:
`WinSetView.ps1` e `AppParts\`. O `AppData\Win10.ini` é o modo de exibição do Alexandre: Detalhes em todas as
pastas, colunas Nome, Caminho da pasta, Data de modificação, Tipo e Tamanho, ordenado por nome, sem agrupar,
extensões visíveis, menu de contexto clássico.

O `setup.ps1` aplica com `WinSetView.ps1 AppData\Win10.ini`. Para mudar: abra o `WinSetView.exe` do original
apontando para esta pasta (ele lê e grava `AppData\Win10.ini`), ou edite o INI, e faça commit.
Os backups que o script grava em `AppData\Backup\` ficam fora do git.
