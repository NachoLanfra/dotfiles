#!/usr/bin/env bash
# Muestra la cancion actual solo mientras se reproduce (ignora Discord).
# Reemplaza al modulo mpris de waybar, que crasheaba al abrir Spotify.
IGNORE="vesktop,discord,Discord,WebCord"

while true; do
    playerctl --ignore-player "$IGNORE" --follow metadata \
        --format $'{{status}}\t{{markup_escape(artist)}} - {{markup_escape(title)}}' 2>/dev/null |
    while IFS=$'\t' read -r status text; do
        if [[ "$status" == "Playing" ]]; then
            text=${text//\\/\\\\}
            text=${text//\"/\\\"}
            printf '{"text":"%s","class":"playing"}\n' "$text"
        else
            printf '{"text":""}\n'
        fi
    done
    sleep 2
done
