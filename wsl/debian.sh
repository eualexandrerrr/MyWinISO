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
    useradd -m -s /bin/bash "$usuario"
    passwd -d "$usuario"                       # sem senha, igual à conta do Windows
fi
usermod -aG sudo "$usuario"
echo "$usuario ALL=(ALL) NOPASSWD: ALL" > "/etc/sudoers.d/$usuario"
chmod 440 "/etc/sudoers.d/$usuario"

cp "$aqui/wsl.conf" /etc/wsl.conf             # usuário padrão e systemd; vale a partir do próximo start
echo "Debian pronto: usuário $usuario, sudo sem senha, systemd ligado."
