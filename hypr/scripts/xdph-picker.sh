#!/bin/bash
# Selector de pantalla para xdg-desktop-portal-hyprland (hyprland-share-picker, zenity de respaldo).
# Imprime "[SELECTION]/screen:NOMBRE" o "[SELECTION]/window:ID" en stdout.
# Chromium/Vesktop abre ~8 sesiones del portal por cada intento de compartir;
# se recuerda la ultima eleccion unos segundos para no repetir el dialogo.
TTL=20
CACHE="${XDG_RUNTIME_DIR:-/tmp}/xdph-picker-last"
exec 9>"$CACHE.lock"
flock 9
if [ -f "$CACHE" ] && [ $(( $(date +%s) - $(stat -c %Y "$CACHE") )) -lt $TTL ]; then
    cat "$CACHE"
    exit 0
fi
# Selector nativo (abre en ~0.3s; zenity tarda ~1s). Zenity queda de respaldo.
if command -v hyprland-share-picker >/dev/null; then
    out=$(hyprland-share-picker 2>/dev/null | grep '^\[SELECTION\]')
    if [ -n "$out" ]; then
        printf '%s\n' "$out" | tee "$CACHE"
    else
        : > "$CACHE"   # cancelado
    fi
    exit 0
fi
rows=()
# Monitores: "len:nombre:x:y:w:h;"
list="$XDPH_OUTPUT_SHARING_LIST"
while [[ "$list" =~ ^([0-9]+):(.*) ]]; do
    len=${BASH_REMATCH[1]}; rest=${BASH_REMATCH[2]}
    name=${rest:0:$len}; rest=${rest:$((len+1))}
    IFS=':;' read -r x y w h rest <<< "$rest"
    rows+=("screen:$name" "Pantalla" "$name (${w}x${h})")
    list="$rest"
done
# Ventanas: "id[HC>]clase[HT>]titulo[HE>]addr[HA>]"
list="$XDPH_WINDOW_SHARING_LIST"
while [[ -n "$list" && "$list" == *"[HA>]"* ]]; do
    entry=${list%%\[HA\>\]*}; list=${list#*\[HA\>\]}
    id=${entry%%\[HC\>\]*}; entry=${entry#*\[HC\>\]}
    class=${entry%%\[HT\>\]*}; entry=${entry#*\[HT\>\]}
    title=${entry%%\[HE\>\]*}
    [[ "$id" =~ ^[0-9]+$ ]] || continue
    rows+=("window:$id" "Ventana" "$class — ${title:0:70}")
done
sel=$(zenity --list --title="Compartir pantalla" --text="Elegí qué compartir" \
      --width=700 --height=450 --hide-column=1 --print-column=1 \
      --column=id --column=Tipo --column=Nombre "${rows[@]}" 2>/dev/null)
if [ -n "$sel" ]; then
    printf '[SELECTION]/%s\n' "$sel" | tee "$CACHE"
else
    : > "$CACHE"   # cancelado: las sesiones pendientes tambien cancelan
fi
exit 0
