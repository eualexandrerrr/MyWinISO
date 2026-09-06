#!/usr/bin/env bash
# Configuração do Debian no WSL. Roda como root, chamado pelo setup.ps1 a cada rodada:
#   wsl -d Debian -u root -- bash /mnt/c/Users/alexandre/Projetos/mywiniso/wsl/debian.sh
# Idempotente: pode rodar de novo à vontade. Sempre reaplica o wsl/zshrc, que é o único .zshrc.
set -euo pipefail
usuario=alexandre
aqui=$(cd "$(dirname "$0")" && pwd)

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get -y upgrade
apt-get -y install sudo git curl wget ca-certificates gnupg build-essential unzip zip nano \
    zsh zsh-autosuggestions zsh-syntax-highlighting fzf eza bat zoxide

if ! id "$usuario" &>/dev/null; then
    useradd -m -s /bin/zsh "$usuario"
    passwd -d "$usuario"                       # sem senha, igual à conta do Windows
fi
usermod -aG sudo "$usuario"
echo "$usuario ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$usuario"
chmod 440 "/etc/sudoers.d/$usuario"

chsh -s /bin/zsh "$usuario"                   # zsh, igual ao Arch; o bash continua disponível

# starship: o mesmo prompt do PowerShell, pelo mesmo starship.toml de D: (o zshrc aponta STARSHIP_CONFIG).
# Não está no apt do Debian; o instalador oficial põe o binário em /usr/local/bin.
if ! command -v starship >/dev/null 2>&1; then
    curl -sS https://starship.rs/install.sh | sh -s -- -y >/dev/null
fi

# o único .zshrc: o do repo, sempre por cima (o de antes não é versionado em lugar nenhum)
install -o "$usuario" -g "$usuario" -m 644 "$aqui/zshrc" "/home/$usuario/.zshrc"

cp "$aqui/wsl.conf" /etc/wsl.conf             # usuário padrão e systemd; vale a partir do próximo start
echo "Debian pronto: usuário $usuario com zsh + starship, sudo sem senha, systemd ligado."
