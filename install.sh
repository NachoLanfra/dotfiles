#!/usr/bin/env bash
# Instala los paquetes de packages.txt y enlaza las configs a ~/.config.
# Uso: ./install.sh [--no-packages] [--no-links]
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

do_packages=1
do_links=1
for arg in "$@"; do
    case "$arg" in
        --no-packages) do_packages=0 ;;
        --no-links) do_links=0 ;;
        *) echo "Argumento desconocido: $arg" >&2; exit 1 ;;
    esac
done

install_packages() {
    local pacman_pkgs=() aur_pkgs=() section=pacman line pkg
    while IFS= read -r line; do
        [[ "$line" == "### AUR ###" ]] && { section=aur; continue; }
        pkg="${line%%#*}"
        pkg="${pkg//[[:space:]]/}"
        [[ -z "$pkg" ]] && continue
        if [[ $section == aur ]]; then aur_pkgs+=("$pkg"); else pacman_pkgs+=("$pkg"); fi
    done < "$DOTFILES/packages.txt"

    echo ">> Instalando ${#pacman_pkgs[@]} paquetes oficiales"
    sudo pacman -S --needed "${pacman_pkgs[@]}"

    if ! command -v yay >/dev/null; then
        echo ">> yay no está instalado: instalalo a mano (https://aur.archlinux.org/packages/yay) y volvé a correr con --no-links" >&2
        return 1
    fi
    echo ">> Instalando ${#aur_pkgs[@]} paquetes del AUR"
    yay -S --needed "${aur_pkgs[@]}"
}

# link <origen en el repo> <destino>
link() {
    local src="$DOTFILES/$1" dst="$2"
    if [[ -L "$dst" && "$(readlink -f "$dst")" == "$(readlink -f "$src")" ]]; then
        echo "ok      $dst"
        return
    fi
    if [[ -e "$dst" || -L "$dst" ]]; then
        mkdir -p "$BACKUP"
        mv "$dst" "$BACKUP/$(basename "$dst")"
        echo "backup  $dst -> $BACKUP/"
    fi
    mkdir -p "$(dirname "$dst")"
    ln -s "$src" "$dst"
    echo "link    $dst -> $src"
}

make_links() {
    link hypr                 "$CONFIG/hypr"
    link waybar               "$CONFIG/waybar"
    link kitty                "$CONFIG/kitty"
    link fastfetch            "$CONFIG/fastfetch"
    link wlogout              "$CONFIG/wlogout"
    link shell/starship.toml  "$CONFIG/starship.toml"
    link shell/bashrc         "$HOME/.bashrc"
    link micro/settings.json  "$CONFIG/micro/settings.json"
    link micro/bindings.json  "$CONFIG/micro/bindings.json"
    link gtk-3.0/settings.ini "$CONFIG/gtk-3.0/settings.ini"
    link gtk-4.0/settings.ini "$CONFIG/gtk-4.0/settings.ini"
    link mimeapps.list        "$CONFIG/mimeapps.list"
    link gitconfig            "$HOME/.gitconfig"
    link wallpapers           "$HOME/Pictures/wallpapers"
}

[[ $do_packages == 1 ]] && install_packages
[[ $do_links == 1 ]] && make_links
# genera los archivos del tema (~/.config/theme) que leen las configs
"$DOTFILES/hypr/scripts/theme-switch.sh" --generate

cat <<'EOF'

Pasos manuales (requieren root, no los hace el script):
  - SDDM:  ver sddm/README.md (tema sugar-light + sddm.conf)
  - GRUB:  ver grub/default-grub-lines.txt y grub/theme/install.sh
  - Lo propio de cada maquina va en ~/.bashrc.local (se carga desde shell/bashrc)
EOF
