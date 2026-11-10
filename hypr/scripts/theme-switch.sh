#!/usr/bin/env bash
# theme-switch: cambia el tema de todo el escritorio (SUPER+T).
#
# Uso: theme-switch.sh [--menu | --next | --boot | --generate | --list | <tema>]
#   --menu      abre un selector flotante para elegir el tema
#   --next      pasa al tema siguiente
#   --boot      al iniciar sesion: genera los archivos y pone el wallpaper
#   --generate  solo genera los archivos (sin recargar nada; lo usa install.sh)
#   <tema>      aplica ese tema (nombre de un archivo en hypr/themes/)
#
# Las paletas viven en hypr/themes/<tema>.sh. Los archivos generados van a
# ~/.config/theme/ y las configs del repo los leen desde ahi.
# Wallpaper por tema: ~/Pictures/wallpapers/<tema>.{jpg,jpeg,png,webp};
# si falta el de un tema, se usa el de gruvbox.

set -u

SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
THEMES_DIR="$(cd "$(dirname "$SELF")/../themes" && pwd)"
OUT="${XDG_CONFIG_HOME:-$HOME/.config}/theme"
STATE="$OUT/current"
DEFAULT_THEME=gruvbox

list_themes() { for f in "$THEMES_DIR"/*.sh; do basename "${f%.sh}"; done; }
current_theme() { cat "$STATE" 2>/dev/null || echo "$DEFAULT_THEME"; }

load_theme() {
    local f="$THEMES_DIR/$1.sh"
    [[ -f "$f" ]] || { echo "tema desconocido: $1" >&2; return 1; }
    # shellcheck disable=SC1090
    source "$f"
    local v
    for v in BG BG1 BG2 BG3 FG FG_BRIGHT MUTED RED GREEN YELLOW BLUE PURPLE AQUA ORANGE \
             ACCENT ACCENT2 ON_ACCENT WARNING CRITICAL SEL_BG SEL_FG \
             C0 C1 C2 C3 C4 C5 C6 C7 C8 C9 C10 C11 C12 C13 C14 C15; do
        [[ -n "${!v:-}" ]] || { echo "falta $v en $1.sh" >&2; return 1; }
    done
}

# escribe $1 con el contenido de stdin, de forma atomica
put() { cat > "$OUT/$1.tmp" && mv "$OUT/$1.tmp" "$OUT/$1"; }

generate() {
    local name="$1"
    load_theme "$name" || return 1
    mkdir -p "$OUT" "${XDG_CONFIG_HOME:-$HOME/.config}/dunst"

    put kitty.conf <<EOF
# Generado por theme-switch.sh ($name). No editar.
background            #$BG
foreground            #$FG
selection_background  #$SEL_BG
selection_foreground  #$SEL_FG
cursor                #$FG
cursor_text_color     #$BG
color0  #$C0
color1  #$C1
color2  #$C2
color3  #$C3
color4  #$C4
color5  #$C5
color6  #$C6
color7  #$C7
color8  #$C8
color9  #$C9
color10 #$C10
color11 #$C11
color12 #$C12
color13 #$C13
color14 #$C14
color15 #$C15
EOF

    local defs
    defs="/* Generado por theme-switch.sh ($name). No editar. */
@define-color bg       #$BG;
@define-color bg1      #$BG1;
@define-color bg2      #$BG2;
@define-color bg3      #$BG3;
@define-color fg       #$FG;
@define-color fgbright #$FG_BRIGHT;
@define-color inactive #$MUTED;
@define-color red      #$RED;
@define-color green    #$GREEN;
@define-color yellow   #$YELLOW;
@define-color blue     #$BLUE;
@define-color purple   #$PURPLE;
@define-color aqua     #$AQUA;
@define-color orange   #$ORANGE;
@define-color accent   #$ACCENT;
@define-color accent2  #$ACCENT2;
@define-color onaccent #$ON_ACCENT;
@define-color warning  #$WARNING;
@define-color critical #$CRITICAL;
@define-color module-bg @bg1;"
    printf '%s\n' "$defs" | put waybar.css
    printf '%s\n' "$defs" | put wlogout.css

    put hyprtoolkit.conf <<EOF
# Generado por theme-switch.sh ($name). No editar.
background = 0xFF$BG1
base = 0xFF$BG2
text = 0xFF$FG
alternate_base = 0xFF$BG3
bright_text = 0xFF$FG_BRIGHT
accent = 0xFF$ACCENT
accent_secondary = 0xFF$ACCENT2
EOF

    put hyprlock.conf <<EOF
# Generado por theme-switch.sh ($name). No editar.
\$lock_text  = rgba(${FG}ff)
\$lock_outer = rgba(${FG}80)
\$lock_inner = rgba(${BG}b3)
\$lock_font  = rgb($FG)
\$lock_check = rgb($ACCENT)
\$lock_fail  = rgb($CRITICAL)
EOF

    put hypr.lua <<EOF
-- Generado por theme-switch.sh ($name). No editar.
return {
    active_border   = "rgba(${ACCENT}ee)",
    inactive_border = "rgba(${BG2}aa)",
    shadow          = 0xee$BG,
}
EOF

    put dunst.conf <<EOF
# Generado por theme-switch.sh ($name). No editar.
[global]
    frame_color = "#$ACCENT"
    separator_color = frame
    highlight = "#$ACCENT"

[urgency_low]
    background = "#$BG1"
    foreground = "#$FG"
    frame_color = "#$BG3"

[urgency_normal]
    background = "#$BG1"
    foreground = "#$FG"
    frame_color = "#$ACCENT"

[urgency_critical]
    background = "#$BG1"
    foreground = "#$FG"
    frame_color = "#$CRITICAL"
EOF
    # dunst solo lee dunstrc.d junto al dunstrc que carga (el de /etc), asi que
    # armamos ~/.config/dunst/dunstrc = config estandar + colores del tema
    { cat /etc/dunst/dunstrc 2>/dev/null; echo; cat "$OUT/dunst.conf"; } \
        > "${XDG_CONFIG_HOME:-$HOME/.config}/dunst/dunstrc"

    # waycal (calendario de la waybar) trae sus colores dentro del binario. Se lo
    # lanza con XDG_CONFIG_HOME=$OUT/xdg para que GTK4 cargue este gtk.css encima.
    mkdir -p "$OUT/xdg/gtk-4.0"
    ln -sf "${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0/settings.ini" "$OUT/xdg/gtk-4.0/settings.ini"
    put xdg/gtk-4.0/gtk.css <<EOF
/* Generado por theme-switch.sh ($name). No editar. */
.waycal-root { background-color: #$BG1; border: 2px solid #$BG2; color: #$FG; }
.waycal-root:focus-visible { border: 2px solid #$ACCENT; }
.waycal-weekday { color: #$ACCENT; }
.waycal-day { color: #$FG; }
.waycal-day.dim { color: #$MUTED; opacity: 1; }
.waycal-day.today { background-color: #$ACCENT; color: #$ON_ACCENT; }
.waycal-root.rounded { background-color: alpha(#$BG1, 0.96); border: 2px solid transparent; }
.waycal-header { color: #$FG; }
.waycal-footer { color: #$MUTED; border-top: 2px solid #$BG2; }
EOF

    # Tema GTK: apps GTK3 leen settings.ini; las GTK4/libadwaita, los enlaces de gtk-4.0
    if [[ -n "${GTK_THEME:-}" && -d "/usr/share/themes/$GTK_THEME" ]]; then
        local cfg="${XDG_CONFIG_HOME:-$HOME/.config}" f
        for f in "$cfg/gtk-3.0/settings.ini" "$cfg/gtk-4.0/settings.ini"; do
            [[ -f "$f" ]] && sed -i "s/^gtk-theme-name=.*/gtk-theme-name=$GTK_THEME/" "$f"
        done
        if [[ -d "$cfg/gtk-4.0" && -d "/usr/share/themes/$GTK_THEME/gtk-4.0" ]]; then
            for f in gtk.css gtk-dark.css assets; do
                [[ -e "/usr/share/themes/$GTK_THEME/gtk-4.0/$f" ]] && ln -sfn "/usr/share/themes/$GTK_THEME/gtk-4.0/$f" "$cfg/gtk-4.0/$f"
            done
        fi
    fi

    echo "$name" | put current
}

wallpaper_for() {
    local ext f
    for ext in jpg jpeg png webp; do
        f="$HOME/Pictures/wallpapers/$1.$ext"
        [[ -f "$f" ]] && { echo "$f"; return; }
    done
    echo "$HOME/Pictures/wallpapers/gruvbox.jpg"
}

set_wallpaper() {
    local wp old new
    wp="$(wallpaper_for "$1")"
    [[ -f "$wp" ]] || return 0
    old="$(pgrep -x swaybg || true)"
    # si ya esta puesto este wallpaper, no hacer nada (evita parpadeo)
    if [[ -n "$old" ]] && tr '\0' ' ' < "/proc/${old%%$'\n'*}/cmdline" 2>/dev/null | grep -qF -- "-i $wp "; then
        return 0
    fi
    # stdin de /dev/null: si no, swaybg hereda la terminal del selector y la
    # ventana de kitty no se cierra al terminar
    setsid -f swaybg -i "$wp" -m fill </dev/null >/dev/null 2>&1
    sleep 0.7
    # cierra solo los swaybg anteriores; el nuevo es el ultimo en arrancar
    for new in $old; do kill "$new" 2>/dev/null; done
}

reload_live() {
    pkill -USR1 -x kitty 2>/dev/null
    pkill -USR2 -x waybar 2>/dev/null
    dunstctl reload >/dev/null 2>&1
    [[ -n "${GTK_THEME:-}" ]] && gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" 2>/dev/null
    hyprctl eval "hl.config({ general = { col = { active_border = \"rgba(${ACCENT}ee)\", inactive_border = \"rgba(${BG2}aa)\" } }, decoration = { shadow = { color = 0xee$BG } } })" >/dev/null 2>&1
}

apply() {
    generate "$1" || return 1
    set_wallpaper "$1"
    reload_live
    notify-send -u low -t 1800 "Tema: $THEME_LABEL" >/dev/null 2>&1
}

next_theme() {
    local cur t found=0 first=""
    cur="$(current_theme)"
    for t in $(list_themes); do
        [[ -z "$first" ]] && first="$t"
        if [[ $found == 1 ]]; then echo "$t"; return; fi
        [[ "$t" == "$cur" ]] && found=1
    done
    echo "$first"
}

# --menu: abre el selector en una ventanita flotante (clase theme-float);
# una segunda pulsacion la cierra.
menu() {
    local pid
    pid="$(hyprctl clients -j | jq -r '.[] | select(.class == "theme-float") | .pid' | head -n1)"
    if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null; return 0; fi
    setsid -f kitty --class theme-float --title Temas -o background_opacity=0.96 "$SELF" --pick >/dev/null 2>&1
}

# --pick: el selector en si (corre dentro de la ventana de kitty).
pick() {
    local themes=() labels=() accents=() swatches=() cur t i sel=0 key rest
    local label a b c d e f
    cur="$(current_theme)"
    for t in $(list_themes); do
        IFS='|' read -r label a b c d e f < <(source "$THEMES_DIR/$t.sh"; echo "$THEME_LABEL|$ACCENT|$RED|$GREEN|$YELLOW|$BLUE|$PURPLE")
        themes+=("$t"); labels+=("$label"); accents+=("$a"); swatches+=("$b $c $d $e $f")
        [[ "$t" == "$cur" ]] && sel=$(( ${#themes[@]} - 1 ))
    done
    local n=${#themes[@]}
    rgb() { printf '%d;%d;%d' "0x${1:0:2}" "0x${1:2:2}" "0x${1:4:2}"; }

    draw() {
        local i h line
        printf '\e[H\e[2J\n  \e[1mElegir tema\e[0m\n\n'
        for ((i = 0; i < n; i++)); do
            line=""
            for h in ${swatches[i]}; do line+=$(printf '\e[38;2;%sm●\e[0m  ' "$(rgb "$h")"); done
            if (( i == sel )); then
                printf '  \e[38;2;%sm❯ \e[1m%-13s\e[0m %s' "$(rgb "${accents[i]}")" "${labels[i]}" "$line"
            else
                printf '    %-13s %s' "${labels[i]}" "$line"
            fi
            [[ "${themes[i]}" == "$cur" ]] && printf '\e[2m (actual)\e[0m'
            printf '\n'
        done
        printf '\n  \e[2m↑↓ mover · Enter elegir · Esc salir\e[0m\n'
    }

    printf '\e[?25l'
    trap 'printf "\e[?25h"' EXIT
    draw
    while IFS= read -rsn1 key; do
        if [[ "$key" == $'\e' ]]; then
            read -rsn2 -t 0.05 rest
            case "$rest" in
                '[A') (( sel = (sel + n - 1) % n )) ;;
                '[B') (( sel = (sel + 1) % n )) ;;
                '')   return 0 ;;
            esac
        else
            case "$key" in
                k) (( sel = (sel + n - 1) % n )) ;;
                j) (( sel = (sel + 1) % n )) ;;
                q) return 0 ;;
                '') [[ "${themes[sel]}" != "$cur" ]] && apply "${themes[sel]}"; return 0 ;;
            esac
        fi
        draw
    done
}

case "${1:-}" in
    --menu)     menu ;;
    --pick)     pick ;;
    --next)     apply "$(next_theme)" ;;
    --boot)     generate "$(current_theme)" && set_wallpaper "$(current_theme)" ;;
    --generate) generate "$(current_theme)" ;;
    --list)     list_themes ;;
    "")         echo "uso: ${0##*/} [--menu|--next|--boot|--generate|--list|<tema>]" >&2; exit 1 ;;
    *)          apply "$1" ;;
esac
