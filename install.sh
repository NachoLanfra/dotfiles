#!/usr/bin/env bash
# install.sh: deja una instalacion de Arch igual a este repo.
#
# Uso: ./install.sh [--no-packages] [--no-links] [--no-system]
#   --no-packages  no instala paquetes (pacman + AUR)
#   --no-links     no enlaza las configs
#   --no-system    no toca el sistema (servicios, grupos, zram, firewall)
#
# Es seguro correrlo varias veces: lo que ya esta hecho se salta, y lo que
# reemplaza se guarda antes en ~/.dotfiles-backup/<fecha>/.
set -euo pipefail

DOTFILES="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
BACKUP="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"

do_packages=1
do_links=1
do_system=1
for arg in "$@"; do
    case "$arg" in
        --no-packages) do_packages=0 ;;
        --no-links) do_links=0 ;;
        --no-system) do_system=0 ;;
        -h|--help) sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Argumento desconocido: $arg (probá --help)" >&2; exit 1 ;;
    esac
done

step() { printf '\n\e[1;34m>>\e[0m \e[1m%s\e[0m\n' "$*"; }

if [[ $EUID -eq 0 ]]; then
    echo "No lo corras como root: usa sudo solo donde hace falta." >&2
    exit 1
fi
command -v pacman >/dev/null || { echo "Esto es para Arch Linux (no encuentro pacman)." >&2; exit 1; }

# ---------------------------------------------------------------- paquetes

# yay no esta en los repos oficiales: se compila desde el AUR
install_yay() {
    command -v yay >/dev/null && return 0
    step "Instalando yay desde el AUR"
    sudo pacman -S --needed --noconfirm git base-devel
    local tmp
    tmp="$(mktemp -d)"
    git clone https://aur.archlinux.org/yay.git "$tmp/yay"
    (cd "$tmp/yay" && makepkg -si --noconfirm)
    rm -rf "$tmp"
}

install_packages() {
    local pacman_pkgs=() aur_pkgs=() section=pacman line pkg
    while IFS= read -r line; do
        [[ "$line" == "### AUR ###" ]] && { section=aur; continue; }
        pkg="${line%%#*}"
        pkg="${pkg//[[:space:]]/}"
        [[ -z "$pkg" ]] && continue
        if [[ $section == aur ]]; then aur_pkgs+=("$pkg"); else pacman_pkgs+=("$pkg"); fi
    done < "$DOTFILES/packages.txt"

    step "Paquetes oficiales (${#pacman_pkgs[@]})"
    sudo pacman -S --needed "${pacman_pkgs[@]}"

    # yay figura en la lista del AUR; si ya esta, se saltea solo con --needed
    install_yay
    step "Paquetes del AUR (${#aur_pkgs[@]})"
    yay -S --needed "${aur_pkgs[@]}"
}

# ------------------------------------------------------------------ enlaces

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
    step "Enlazando configs"
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

    # genera los archivos del tema (~/.config/theme) que leen las configs
    step "Generando el tema"
    "$DOTFILES/hypr/scripts/theme-switch.sh" --generate
}

# ------------------------------------------------------------------ sistema

# enable_service <unidad>: habilita (sin arrancar) si existe y no esta habilitada
enable_service() {
    local unit="$1"
    if ! systemctl cat "$unit" >/dev/null 2>&1; then
        echo "salta   $unit (no esta instalado)"
    elif systemctl is-enabled --quiet "$unit" 2>/dev/null; then
        echo "ok      $unit"
    else
        sudo systemctl enable "$unit" && echo "enable  $unit"
    fi
}

configure_system() {
    step "Servicios"
    # solo se habilitan (sin --now): arrancar sddm cerraria la sesion actual
    local unit
    for unit in NetworkManager.service bluetooth.service sddm.service \
                power-profiles-daemon.service swayosd-libinput-backend.service \
                ufw.service docker.service fstrim.timer; do
        enable_service "$unit"
    done

    step "Grupos de $USER"
    local g
    for g in video docker; do
        if ! getent group "$g" >/dev/null; then
            echo "salta   $g (el grupo no existe)"
        elif id -nG "$USER" | tr ' ' '\n' | grep -qx "$g"; then
            echo "ok      $g"
        else
            sudo usermod -aG "$g" "$USER" && echo "grupo   $g (se aplica al volver a iniciar sesion)"
        fi
    done

    step "zram (swap comprimido en RAM)"
    if cmp -s "$DOTFILES/system/zram-generator.conf" /etc/systemd/zram-generator.conf 2>/dev/null; then
        echo "ok      /etc/systemd/zram-generator.conf"
    else
        sudo install -Dm644 "$DOTFILES/system/zram-generator.conf" /etc/systemd/zram-generator.conf
        echo "copia   /etc/systemd/zram-generator.conf (activo desde el proximo arranque)"
    fi

    step "Firewall (ufw)"
    if command -v ufw >/dev/null; then
        if sudo ufw status | grep -q "Status: active"; then
            echo "ok      ufw ya esta activo"
        else
            sudo ufw default deny incoming
            sudo ufw default allow outgoing
            sudo ufw --force enable
        fi
    else
        echo "salta   ufw no esta instalado"
    fi
}

[[ $do_packages == 1 ]] && install_packages
[[ $do_links == 1 ]] && make_links
[[ $do_system == 1 ]] && configure_system

cat <<'FIN'

Listo. Quedan pasos a mano:
  - SDDM:  sddm/README.md (tema sugar-light + sddm.conf + parche de Main.qml)
  - GRUB:  grub/default-grub-lines.txt y grub/theme/install.sh
  - Cosas que no estan en pacman ni en el AUR:
      uv (Python):       curl -LsSf https://astral.sh/uv/install.sh | sh
      Claude Code:       https://claude.com/claude-code
      JetBrains:         JetBrains Toolbox
  - Lo propio de cada maquina (por ejemplo el PATH de uv) va en ~/.bashrc.local,
    que shell/bashrc carga si existe.
  - Reinicia la sesion (o la maquina) para que tomen los grupos, zram y sddm.
FIN
