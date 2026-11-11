#!/usr/bin/env bash
# auto-update: actualiza el sistema una vez por semana, sin que te tengas que acordar.
#
# Lo lanza anacron (viene con cronie) desde /etc/cron.daily: corre como mucho una
# vez por dia, solo con el cargador enchufado y entre las 3 y las 22 h; si la
# compu estaba apagada, lo hace cuando vuelve a estar prendida. Este script mira
# si pasaron INTERVAL_DAYS desde la ultima actualizacion que salio bien.
#
# Que hace, en orden:
#   1. saca un snapshot de timeshift (si falla, NO actualiza nada)
#   2. pacman -Syu  (paquetes oficiales)
#   3. flatpak update  (los de Flatpak)
#   4. avisa con una notificacion: si hay que reiniciar, si aparecieron archivos
#      .pacnew nuevos y cuantos paquetes del AUR esperan. El AUR NO se
#      actualiza solo (compila codigo de terceros y conviene mirarlo): yay -Sua
# Si algo falla, no marca la semana como hecha y reintenta al dia siguiente.
# Todo queda en /var/log/auto-update.log.
#
# install.sh lo copia a /etc/cron.daily/auto-update (copia, no enlace: lo ejecuta
# root, asi que no puede ser un archivo que tu usuario pueda cambiar).
#
# Uso manual:  sudo /etc/cron.daily/auto-update --force   (ignora los 7 dias)
set -u

USER_NAME="@USER@"        # install.sh pone tu usuario (para las notificaciones y el AUR)
INTERVAL_DAYS=7
STAMP=/var/lib/auto-update/last-success
LOG=/var/log/auto-update.log
PATH=/usr/local/sbin:/usr/local/bin:/usr/bin

force=0
[[ "${1:-}" == --force ]] && force=1

mkdir -p "$(dirname "$STAMP")"
exec 9>/run/auto-update.lock
flock -n 9 || exit 0

if (( ! force )); then
    last="$(cat "$STAMP" 2>/dev/null || echo 0)"
    (( $(date +%s) - last < INTERVAL_DAYS * 86400 )) && exit 0
fi

exec >>"$LOG" 2>&1
log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

# notify <titulo> <texto> [urgencia]: notificacion en la sesion del usuario
notify() {
    local uid bus
    uid="$(id -u "$USER_NAME" 2>/dev/null)" || return 0
    bus="/run/user/$uid/bus"
    [[ -S "$bus" ]] || return 0
    runuser -u "$USER_NAME" -- env DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
        notify-send -a auto-update -u "${3:-normal}" "$1" "$2" || true
}

fail() {
    log "ERROR: $*"
    notify "Actualizacion automatica: fallo" "$*. Detalles en /var/log/auto-update.log" critical
    exit 1
}

log "=== inicio ==="

if [[ -e /var/lib/pacman/db.lck ]]; then
    log "pacman esta ocupado; se reintenta manana"
    exit 0
fi
if ! curl -fsI --max-time 15 https://archlinux.org >/dev/null; then
    log "sin conexion; se reintenta manana"
    exit 0
fi

# 1. snapshot (tag W: lo rota timeshift junto con los semanales, no se acumulan)
if command -v timeshift >/dev/null; then
    log "snapshot de timeshift..."
    timeshift --create --comments "antes de actualizar (auto-update)" --tags W ||
        fail "No se pudo sacar el snapshot de timeshift, no se actualizo nada"
else
    log "timeshift no esta instalado: se actualiza sin snapshot"
fi

# 2. paquetes oficiales (se cuentan los .pacnew antes, para avisar solo de los nuevos)
pacnew_before="$(find /etc -name '*.pacnew' 2>/dev/null | wc -l)"
log "pacman -Syu..."
pacman -Syu --noconfirm --noprogressbar || fail "pacman -Syu fallo"

# 3. flatpak (si falla, no corta: ya se actualizo lo importante)
if command -v flatpak >/dev/null; then
    log "flatpak update..."
    flatpak update -y --noninteractive || log "AVISO: flatpak update fallo"
fi

# 4. resumen
msg=""
# si desaparecio la carpeta de modulos del kernel que esta corriendo, hay que reiniciar
[[ -d "/usr/lib/modules/$(uname -r)" ]] || msg+="Reinicia para usar el kernel nuevo. "
pacnew="$(( $(find /etc -name '*.pacnew' 2>/dev/null | wc -l) - pacnew_before ))"
(( pacnew > 0 )) && msg+="Aparecieron $pacnew archivo(s) .pacnew nuevos: revisalos con pacdiff. "
home="$(getent passwd "$USER_NAME" | cut -d: -f6)"
if command -v yay >/dev/null && [[ -n "$home" ]]; then
    aur="$(timeout 90 runuser -u "$USER_NAME" -- env HOME="$home" yay -Qua 2>/dev/null | wc -l)"
    (( aur > 0 )) && msg+="$aur paquete(s) del AUR esperan: yay -Sua. "
fi

date +%s > "$STAMP"
log "listo. ${msg:-Sin pendientes.}"
notify "Sistema actualizado" "${msg:-Todo al dia.}"
