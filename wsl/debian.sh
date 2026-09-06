#!/usr/bin/env bash
# Configuração inicial do Debian no WSL. Roda como root, chamado pelo setup.ps1:
#   wsl -d Debian -u root -- bash /mnt/c/Users/alexandre/Projetos/mywiniso/wsl/debian.sh
# Pode rodar de novo à vontade.
set -euo pipefail
usuario=alexandre
aqui=$(cd "$(dirname "$0")" && pwd)

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y upgrade
apt-get -y install sudo git curl wget ca-certificates gnupg build-essential unzip zip zsh nano

if ! id "$usuario" &>/dev/null; then
    useradd -m -s /bin/zsh "$usuario"
    passwd -d "$usuario"                       # sem senha, igual à conta do Windows
fi
usermod -aG sudo "$usuario"
echo "$usuario ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$usuario"
chmod 440 "/etc/sudoers.d/$usuario"

chsh -s /bin/zsh "$usuario"                   # zsh, igual ao Arch; o bash continua disponível

if [ ! -f "/home/$usuario/.zshrc" ]; then     # zshrc mínimo: histórico grande, completar com setas, c e x
    cat > "/home/$usuario/.zshrc" <<'ZRC'
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS SHARE_HISTORY
autoload -Uz compinit && compinit
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search; zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
alias c=clear
alias x=exit
alias ls='ls --color=auto'
PROMPT='%F{cyan}%~%f %# '
command -v starship >/dev/null && eval "$(starship init zsh)"
ZRC
    chown "$usuario:$usuario" "/home/$usuario/.zshrc"
fi

cp "$aqui/wsl.conf" /etc/wsl.conf             # usuário padrão e systemd; vale a partir do próximo start
echo "Debian pronto: usuário $usuario com zsh, sudo sem senha, systemd ligado."
