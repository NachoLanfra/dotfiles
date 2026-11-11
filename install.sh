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
    link mimeapps.list        "$CONFIG/mimeapps.list"
    link gitconfig            "$HOME/.gitconfig"
    link wallpapers           "$HOME/Pictures/wallpapers"

    # genera los archivos del tema (~/.config/theme) que leen las configs:
    # colores, GTK (settings.ini y ~/.gtkrc-2.0) y gsettings
    step "Generando el tema"
    "$DOTFILES/hypr/scripts/theme-switch.sh" --generate

    step "Servicios de la sesion (systemd --user)"
    local f
    for f in "$DOTFILES"/systemd/user/*.service "$DOTFILES"/systemd/user/*.service.d/*.conf; do
        link "${f#"$DOTFILES"/}" "$CONFIG/${f#"$DOTFILES"/}"
    done
    # waybar y hypridle ya traen su unidad en el paquete (las demas estan en
    # systemd/user/). Solo se habilitan, no se arrancan: arrancan solas al iniciar
    # sesion con "Hyprland (uwsm-managed)" en SDDM.
    systemctl --user daemon-reload 2>/dev/null || true
    local unit
    for unit in waybar hypridle awww-daemon theme-boot swayosd-server polkit-agent \
                cliphist-text cliphist-image power-watch fullscreen-boost; do
        if systemctl --user enable "$unit.service" >/dev/null 2>&1; then
            echo "enable  $unit.service"
        else
            echo "salta   $unit.service (no se pudo habilitar; habilitalo desde la sesion grafica)"
        fi
    done
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
                ufw.service docker.service fstrim.timer \
                reflector.timer paccache.timer cronie.service; do
        enable_service "$unit"
    done

    step "Mantenimiento (mirrors, cache de pacman, snapshots)"
    # mirrors: reflector.timer (semanal) usa esta config
    if [[ ! -d /etc/xdg/reflector ]]; then
        echo "salta   reflector (no esta instalado)"
    elif cmp -s "$DOTFILES/system/reflector.conf" /etc/xdg/reflector/reflector.conf 2>/dev/null; then
        echo "ok      /etc/xdg/reflector/reflector.conf"
    else
        sudo install -Dm644 "$DOTFILES/system/reflector.conf" /etc/xdg/reflector/reflector.conf
        echo "copia   /etc/xdg/reflector/reflector.conf"
    fi
    # timeshift: snapshots rsync en la particion de /home (si /home no es una
    # particion aparte, queda en la de /). Solo se crea si no existe, para no
    # pisar lo que cambies desde su ventana.
    if ! command -v timeshift >/dev/null; then
        echo "salta   timeshift (no esta instalado)"
    elif [[ -f /etc/timeshift/timeshift.json ]]; then
        echo "ok      /etc/timeshift/timeshift.json (ya existe)"
    else
        local uuid tmp
        uuid="$(findmnt -no UUID -T /home)"
        tmp="$(mktemp)"
        sed "s/@UUID@/$uuid/" "$DOTFILES/system/timeshift.json" > "$tmp"
        sudo install -Dm644 "$tmp" /etc/timeshift/timeshift.json
        rm -f "$tmp"
        echo "copia   /etc/timeshift/timeshift.json (snapshots en el disco $uuid)"
        echo "        primer snapshot a mano: sudo timeshift --create --comments 'inicial'"
    fi
    # avisos de cron: cron-notify manda notificaciones a tu sesion desde trabajos de
    # root, y timeshift-check (lo lanza cron cada hora) avisa al sacar un snapshot.
    # Se copian (no se enlazan) porque los ejecuta root.
    if [[ ! -d /etc/cron.d ]]; then
        echo "salta   avisos de cron (cronie no esta instalado)"
    else
        local tmpn
        tmpn="$(mktemp)"
        sed "s/@USER@/$USER/" "$DOTFILES/system/cron-notify.sh" > "$tmpn"
        if cmp -s "$tmpn" /usr/local/bin/cron-notify 2>/dev/null; then
            echo "ok      /usr/local/bin/cron-notify"
        else
            sudo install -Dm755 -o root -g root "$tmpn" /usr/local/bin/cron-notify
            echo "copia   /usr/local/bin/cron-notify"
        fi
        rm -f "$tmpn"
        if cmp -s "$DOTFILES/system/timeshift-check.sh" /usr/local/bin/timeshift-check 2>/dev/null; then
            echo "ok      /usr/local/bin/timeshift-check"
        else
            sudo install -Dm755 -o root -g root "$DOTFILES/system/timeshift-check.sh" /usr/local/bin/timeshift-check
            echo "copia   /usr/local/bin/timeshift-check"
        fi
        if cmp -s "$DOTFILES/system/timeshift-hourly.cron" /etc/cron.d/timeshift-hourly 2>/dev/null; then
            echo "ok      /etc/cron.d/timeshift-hourly"
        else
            sudo install -Dm644 -o root -g root "$DOTFILES/system/timeshift-hourly.cron" /etc/cron.d/timeshift-hourly
            echo "copia   /etc/cron.d/timeshift-hourly"
        fi
    fi
    # actualizacion semanal automatica: la lanza anacron (de cronie) desde
    # /etc/cron.daily. Se copia (no se enlaza) porque la ejecuta root.
    if [[ ! -d /etc/cron.daily ]]; then
        echo "salta   auto-update (cronie no esta instalado)"
    else
        local upd
        upd="$(mktemp)"
        sed "s/@USER@/$USER/" "$DOTFILES/system/auto-update.sh" > "$upd"
        if cmp -s "$upd" /etc/cron.daily/auto-update 2>/dev/null; then
            echo "ok      /etc/cron.daily/auto-update"
        else
            sudo install -Dm755 -o root -g root "$upd" /etc/cron.daily/auto-update
            echo "copia   /etc/cron.daily/auto-update (actualiza el sistema cada 7 dias)"
        fi
        rm -f "$upd"
    fi

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
