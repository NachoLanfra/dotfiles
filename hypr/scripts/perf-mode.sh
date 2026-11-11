#!/usr/bin/env bash
# perf-mode.sh: modo rendimiento (SUPER+F10). Apaga animaciones, blur y sombras
# para ahorrar bateria y ganar fluidez; al volver a apretarlo restaura todo.
#
# Es distinto del modulo de perfil de energia de la waybar: ese cambia el
# comportamiento del procesador, esto cambia los efectos visuales. Se pueden
# usar juntos.
set -u

STATE="${XDG_RUNTIME_DIR:-/tmp}/perf-mode"   # se borra solo al cerrar sesion

if [[ -f "$STATE" ]]; then
    rm -f "$STATE"
    # recargar la config devuelve todo lo que apagamos
    hyprctl reload >/dev/null 2>&1
    notify-send -u low -t 1800 "Modo rendimiento: apagado" "Efectos visuales restaurados"
else
    touch "$STATE"
    hyprctl eval 'hl.config({ animations = { enabled = false }, decoration = { blur = { enabled = false }, shadow = { enabled = false } } })' >/dev/null 2>&1
    notify-send -u low -t 1800 "Modo rendimiento: activado" "Sin animaciones, blur ni sombras"
fi
