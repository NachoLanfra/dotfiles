#!/usr/bin/env bash
# keybinds.sh: lista de atajos de teclado (SUPER+F1).
# Se arma leyendo hypr/binds.lua, asi que no hay que mantener ninguna lista
# aparte: la convencion de comentarios esta explicada al principio de ese archivo.
#
# Uso: keybinds.sh [--menu | --pick | --dump]
#   --menu   (por defecto) abre/cierra la ventana flotante
#   --pick   la lista en si (corre dentro de la ventana)
#   --dump   imprime la lista como texto plano
#
# En la lista: escribi para filtrar, ↑/↓ para moverte, Esc o Enter para cerrar.

set -u
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
BINDS="$(cd "$(dirname "$SELF")/.." && pwd)/binds.lua"

# ---- lectura de binds.lua --------------------------------------------------

SECS=(); KEYS=(); DESCS=()

# "SUPER + SHIFT + left" -> "SUPER + SHIFT + ←"
pretty_key() {
    local k="$1" out="" part
    local IFS='+'
    local -a parts
    read -ra parts <<< "$k"
    for part in "${parts[@]}"; do
        part="${part#"${part%%[![:space:]]*}"}"; part="${part%"${part##*[![:space:]]}"}"
        case "$part" in
            left) part="←" ;; right) part="→" ;; up) part="↑" ;; down) part="↓" ;;
            mouse_down) part="rueda ↓" ;; mouse_up) part="rueda ↑" ;;
            mouse:272) part="clic izquierdo" ;; mouse:273) part="clic derecho" ;;
            XF86*) part="${part#XF86}" ;;
        esac
        out+="${out:+ + }$part"
    done
    printf '%s' "$out"
}

parse() {
    local line sec="" blank=0 rest idx keyexpr desc k
    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ -z "${line//[[:space:]]/}" ]]; then blank=1; continue; fi

        if [[ "$line" == --@* ]]; then               # atajo escrito a mano
            rest="${line#--@}"; rest="${rest# }"
            SECS+=("$sec"); KEYS+=("${rest%% | *}"); DESCS+=("${rest#* | }")
            blank=0; continue
        fi
        if [[ "$line" == --* ]]; then                # titulo de seccion
            if (( blank )); then sec="${line#--}"; sec="${sec# }"; fi
            blank=0; continue
        fi
        blank=0

        [[ "$line" == hl.bind\(* ]] || continue
        rest="${line#hl.bind(}"
        [[ "$rest" == *'.. key,'* ]] && continue     # los de bucles van con --@
        [[ "$rest" == *'",'* ]] || continue
        keyexpr="${rest%%\",*}"                      # todo hasta la comilla que cierra la tecla
        desc=""
        if [[ "$line" =~ ^.*[[:space:]]--[[:space:]]+(.*)$ ]]; then desc="${BASH_REMATCH[1]}"; fi
        k="${keyexpr//mainMod .. \"/SUPER}"; k="${k//\"/}"
        SECS+=("$sec"); KEYS+=("$(pretty_key "$k")"); DESCS+=("${desc:-(sin descripcion)}")
    done < "$BINDS"
}

# ---- salidas ---------------------------------------------------------------

dump() {
    parse
    local i last="__none__"
    for ((i = 0; i < ${#KEYS[@]}; i++)); do
        if [[ "${SECS[i]}" != "$last" ]]; then printf '\n%s\n' "${SECS[i]}"; last="${SECS[i]}"; fi
        printf '  %s%*s %s\n' "${KEYS[i]}" $(( 32 - ${#KEYS[i]} )) "" "${DESCS[i]}"
    done
}

menu() {
    local pid
    pid="$(hyprctl clients -j | jq -r '.[] | select(.class == "keybinds-float") | .pid' | head -n1)"
    if [[ -n "$pid" ]]; then kill "$pid" 2>/dev/null; return 0; fi
    setsid -f kitty --class keybinds-float --title Atajos -o background_opacity=0.96 "$SELF" --pick >/dev/null 2>&1
}

pick() {
    parse
    local query="" top=0 key rest
    local -a rows=()   # cada fila: "H|titulo" o "E|tecla|descripcion"

    filter() {
        rows=()
        local q="${query,,}" i last="__none__" hay
        for ((i = 0; i < ${#KEYS[@]}; i++)); do
            hay="${SECS[i],,} ${KEYS[i],,} ${DESCS[i],,}"
            [[ -n "$q" && "$hay" != *"$q"* ]] && continue
            if [[ "${SECS[i]}" != "$last" ]]; then rows+=("H|${SECS[i]}"); last="${SECS[i]}"; fi
            rows+=("E|${KEYS[i]}|${DESCS[i]}")
        done
        top=0
    }

    draw() {
        local budget w n i row type a b cost used=0
        budget=$(( $(tput lines) - 5 )); w=$(tput cols); n=${#rows[@]}
        (( top >= n )) && top=$(( n > 0 ? n - 1 : 0 )); (( top < 0 )) && top=0
        printf '\e[H\e[2J'
        printf '  \e[1mAtajos\e[0m\n  \e[2m>\e[0m %s\e[7m \e[0m\n' "$query"
        for ((i = top; i < n; i++)); do
            row="${rows[i]}"; type="${row%%|*}"; row="${row#*|}"
            if [[ "$type" == H ]]; then cost=2; else cost=1; fi     # un titulo ocupa linea en blanco + texto
            (( used + cost > budget )) && break
            used=$(( used + cost ))
            if [[ "$type" == H ]]; then
                printf '\n  \e[1;33m%s\e[0m\n' "$row"
            else
                a="${row%%|*}"; b="${row#*|}"
                printf '    \e[36m%s\e[0m%*s %s\n' "$a" $(( 30 - ${#a} )) "" "${b:0:w-38}"
            fi
        done
        (( n == 0 )) && printf '\n    \e[2m(sin resultados)\e[0m\n'
        printf '\e[%d;1H  \e[2m↑↓ mover · escribi para filtrar · Esc cerrar\e[0m' "$(tput lines)"
    }

    printf '\e[?25l'
    trap 'printf "\e[?25h"' EXIT
    filter; draw
    while IFS= read -rsn1 key; do
        if [[ "$key" == $'\e' ]]; then
            read -rsn2 -t 0.05 rest
            case "$rest" in
                '[A') (( top > 0 )) && (( top-- )) ;;
                '[B') (( top++ )) ;;
                '')   return 0 ;;
            esac
        else
            case "$key" in
                '')       return 0 ;;
                $'\x7f')  query="${query%?}"; filter ;;
                *)        [[ "$key" =~ [[:print:]] ]] && { query+="$key"; filter; } ;;
            esac
        fi
        draw
    done
}

case "${1:---menu}" in
    --menu) menu ;;
    --pick) pick ;;
    --dump) dump ;;
    *)      echo "uso: ${0##*/} [--menu|--pick|--dump]" >&2; exit 1 ;;
esac
