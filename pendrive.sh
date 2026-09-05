#!/usr/bin/env bash
# Coloca o autounattend.xml no pendrive SEM formatar e SEM mexer nas ISOs que já estão lá.
#
#   sudo ./pendrive.sh /dev/sdX [nome-da-iso-no-pendrive]
#
# Dois tipos de pendrive são aceitos:
#   Ventoy               copia autounattend.xml e ventoy.json para /ventoy, apontando para a ISO do Windows
#                        que já está no pendrive (se houver mais de uma, passe o nome como 2º argumento)
#   Windows extraído     (Rufus, dd, cópia dos arquivos) copia autounattend.xml para a raiz; o Setup lê de lá
#
# Qualquer outro caso o script para e explica. Ele nunca apaga nada.
set -euo pipefail
cd "$(dirname "$0")"

dev=${1:?uso: sudo $0 /dev/sdX [iso]}
iso_pedida=${2:-}

[[ $EUID -eq 0 ]] || { echo "rode com sudo"; exit 1; }
[[ -b $dev ]] || { echo "$dev não é um dispositivo de bloco"; exit 1; }
[[ $(lsblk -dno RM "$dev") == 1 ]] || { echo "$dev não é removível; me recuso a mexer"; exit 1; }
lsblk -o NAME,SIZE,LABEL,FSTYPE,MODEL "$dev"

mapfile -t parts < <(lsblk -nrpo NAME,TYPE "$dev" | awk '$2=="part"{print $1}')
[[ ${#parts[@]} -ge 1 ]] || { echo "sem partições em $dev"; exit 1; }

mnt=$(mktemp -d)
limpar() { sync; umount "$mnt" 2>/dev/null || true; rmdir "$mnt" 2>/dev/null || true; }
trap limpar EXIT
mount "${parts[0]}" "$mnt"

# Confere se a ISO/mídia é pt-BR: o XML pede pt-BR no WinPE e, com ISO de outro idioma, o Setup para com erro.
checar_idioma() {   # $1 = caminho de sources/lang.ini
    if grep -qi 'pt-BR' "$1"; then
        echo "idioma: pt-BR ok"
    else
        echo "ERRO: a mídia não tem pt-BR (sources/lang.ini). Baixe a ISO em Português (Brasil) ou troque os 'pt-BR' do autounattend.xml."
        exit 1
    fi
}

if [[ ${#parts[@]} -ge 2 && $(blkid -s LABEL -o value "${parts[1]}" 2>/dev/null) == VTOYEFI ]]; then
    echo "pendrive Ventoy detectado"
    mapfile -t isos < <(cd "$mnt" && find . -maxdepth 3 -iname '*.iso' -printf '%P\n' | sort)
    [[ ${#isos[@]} -ge 1 ]] || { echo "nenhuma .iso no pendrive"; exit 1; }
    if [[ -n $iso_pedida ]]; then
        [[ -f "$mnt/$iso_pedida" ]] || { echo "não achei $iso_pedida no pendrive. Tem: ${isos[*]}"; exit 1; }
        iso=$iso_pedida
    elif [[ ${#isos[@]} -eq 1 ]]; then
        iso=${isos[0]}
    else
        printf 'mais de uma ISO; passe o nome como 2º argumento:\n'; printf '  %s\n' "${isos[@]}"; exit 1
    fi
    echo "ISO: /$iso"

    isomnt=$(mktemp -d)
    mount -o loop,ro "$mnt/$iso" "$isomnt"
    [[ -f "$isomnt/sources/boot.wim" ]] || { umount "$isomnt"; rmdir "$isomnt"; echo "/$iso não é uma ISO de instalação do Windows"; exit 1; }
    checar_idioma "$isomnt/sources/lang.ini"
    umount "$isomnt"; rmdir "$isomnt"

    mkdir -p "$mnt/ventoy"
    cp autounattend.xml "$mnt/ventoy/autounattend.xml"

    # ventoy.json: preserva o que já existe e só troca a entrada auto_install desta ISO
    novo=$(jq --arg img "/$iso" '.auto_install[0].image = $img' ventoy/ventoy.json)
    if [[ -f "$mnt/ventoy/ventoy.json" ]]; then
        cp "$mnt/ventoy/ventoy.json" "$mnt/ventoy/ventoy.json.bak"
        jq --argjson novo "$novo" --arg img "/$iso" \
            '.auto_install = ((.auto_install // []) | map(select(.image != $img))) + $novo.auto_install' \
            "$mnt/ventoy/ventoy.json.bak" > "$mnt/ventoy/ventoy.json"
        echo "ventoy.json existente preservado (cópia em ventoy.json.bak)"
    else
        printf '%s\n' "$novo" > "$mnt/ventoy/ventoy.json"
    fi
    echo "gravado: /ventoy/autounattend.xml e /ventoy/ventoy.json"

elif [[ -f "$mnt/sources/boot.wim" ]]; then
    echo "pendrive com o Windows extraído detectado"
    checar_idioma "$mnt/sources/lang.ini"
    cp autounattend.xml "$mnt/autounattend.xml"
    echo "gravado: /autounattend.xml (o Setup procura na raiz da mídia removível)"

else
    cat <<MSG
Não reconheci o pendrive: não é Ventoy e não tem sources/boot.wim.
Para transformar em Ventoy (isso APAGA o pendrive, tire as ISOs antes):
    paru -S ventoy-bin
    sudo ventoy -i -g -s $dev        # -g GPT, -s Secure Boot
    copie a ISO do Windows para ele e rode este script de novo
MSG
    exit 1
fi

echo "pronto. Ao dar boot: no Ventoy, escolha a ISO; o template é aplicado sozinho em 5 s."
