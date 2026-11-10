#!/usr/bin/env bash
# packages-sync.sh: compara lo que tenes instalado con packages.txt.
#
# Uso: ./packages-sync.sh          muestra las diferencias (no cambia nada)
#      ./packages-sync.sh --add    agrega a packages.txt lo instalado que falte
#                                  (oficiales antes de "### AUR ###", AUR al final)
#
# Para lo que falta en el archivo mira solo lo instalado a proposito (pacman -Qqe).
# Lo que esta en el archivo pero ya no instalado solo se informa: borralo a mano
# si fue a proposito.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FILE="$DOTFILES/packages.txt"
MARK="### AUR ###"

# nombres del archivo (sin comentarios ni espacios), uno por linea, ordenados
listed() { sed 's/#.*//; s/[[:space:]]//g' "$FILE" | grep -v '^$' | grep -v '^###' | sort -u; }

native_missing=$(comm -23 <(pacman -Qqen | sort) <(listed))
aur_missing=$(comm -23 <(pacman -Qqem | sort) <(listed))
gone=$(comm -13 <(pacman -Qq | sort) <(listed))

show() { [[ -n "$2" ]] && { echo "$1"; sed 's/^/  /' <<<"$2"; }; return 0; }
show "Instalados y faltan en packages.txt (oficiales):" "$native_missing"
show "Instalados y faltan en packages.txt (AUR):" "$aur_missing"
show "En packages.txt pero que ya no estan instalados:" "$gone"

if [[ -z "$native_missing$aur_missing$gone" ]]; then
    echo "packages.txt esta al dia."
    exit 0
fi

if [[ "${1:-}" == "--add" ]]; then
    [[ -z "$native_missing$aur_missing" ]] && { echo "Nada para agregar."; exit 0; }
    tmp="$(mktemp)"
    awk -v native="$native_missing" -v mark="$MARK" '
        $0 == mark && native != "" { print "# Sin clasificar (agregados por packages-sync.sh)"; print native; print "" }
        { print }' "$FILE" > "$tmp"
    [[ -n "$aur_missing" ]] && printf '%s\n' "$aur_missing" >> "$tmp"
    mv "$tmp" "$FILE"
    echo "Agregado. Revisa 'git diff packages.txt' y acomodalos en su categoria."
elif [[ -n "$native_missing$aur_missing" ]]; then
    echo; echo "Para agregarlos: ./packages-sync.sh --add"
fi
