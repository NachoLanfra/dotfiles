#!/usr/bin/env bash
# power-watch.sh: se queda mirando el cargador y la bateria.
#
#  - Al desenchufar: perfil de energia "power-saver" y brillo a 50% como maximo
#    (guarda el brillo anterior).
#  - Al enchufar: perfil "balanced" y devuelve el brillo guardado.
#  - Avisa cuando la bateria baja de 20% y de 10% (una vez por bajada).
#
# Solo actua cuando cambia el estado del cargador (y una vez al iniciar), asi que
# si despues elegis otro perfil a mano desde la waybar, no te lo pisa.
# Lo lanza hypr/autostart.lua. Una sola instancia a la vez.
#
# Para probarlo sin tocar nada: DRY=1 PS_DIR=<carpeta falsa> power-watch.sh
set -u

PS="${PS_DIR:-/sys/class/power_supply}"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}"
BRIGHT_FILE="$STATE_DIR/power-watch-brightness"
INTERVAL="${INTERVAL:-5}"
SAVER_BRIGHTNESS=50

exec 9>"$STATE_DIR/power-watch.lock"
flock -n 9 || exit 0

run() { if [[ -n "${DRY:-}" ]]; then echo "[dry] $*"; else "$@"; fi; }

ac_file="$(ls "$PS"/A*/online "$PS"/AC*/online 2>/dev/null | head -n1)"
bat_dir="$(ls -d "$PS"/BAT* 2>/dev/null | head -n1)"
[[ -n "$ac_file" && -n "$bat_dir" ]] || exit 0   # no es una laptop

brightness_percent() { brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%'; }

on_unplug() {
    run powerprofilesctl set power-saver
    local cur
    cur="$(brightness_percent)"
    if [[ -n "$cur" && "$cur" -gt $SAVER_BRIGHTNESS ]]; then
        echo "$cur" > "$BRIGHT_FILE"
        run brightnessctl -q set "${SAVER_BRIGHTNESS}%"
    fi
    run notify-send -u low -t 2500 "Con bateria" "Modo ahorro de energia"
}

on_plug() {
    run powerprofilesctl set balanced
    if [[ -f "$BRIGHT_FILE" ]]; then
        run brightnessctl -q set "$(cat "$BRIGHT_FILE")%"
        rm -f "$BRIGHT_FILE"
    fi
    run notify-send -u low -t 2500 "Cargando" "Perfil equilibrado"
}

prev=""
warned20=0
warned10=0
while true; do
    ac="$(cat "$ac_file" 2>/dev/null || echo 0)"
    if [[ "$ac" != "$prev" ]]; then
        if [[ "$ac" == "1" ]]; then on_plug; else on_unplug; fi
        prev="$ac"
    fi

    cap="$(cat "$bat_dir/capacity" 2>/dev/null || echo 100)"
    if [[ "$ac" == "1" ]]; then
        warned20=0; warned10=0
    else
        if (( cap <= 10 && warned10 == 0 )); then
            run notify-send -u critical "Bateria muy baja: ${cap}%" "Enchufá el cargador"
            warned10=1; warned20=1
        elif (( cap <= 20 && warned20 == 0 )); then
            run notify-send -u normal "Bateria baja: ${cap}%"
            warned20=1
        fi
    fi
    sleep "$INTERVAL" 9>&-   # sin heredar el bloqueo: matar el script lo libera
done
