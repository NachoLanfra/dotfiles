#!/usr/bin/env bash
# cron-notify: manda una notificacion a la sesion grafica del usuario desde un
# trabajo de cron (que corre como root y no tiene sesion propia).
#
# Uso:  cron-notify <titulo> <texto> [urgencia: low|normal|critical] [app]
#
# install.sh lo copia a /usr/local/bin/cron-notify (copia, no enlace: lo ejecuta root).
USER_NAME="@USER@"        # install.sh pone tu usuario
PATH=/usr/local/sbin:/usr/local/bin:/usr/bin

uid="$(id -u "$USER_NAME" 2>/dev/null)" || exit 0
bus="/run/user/$uid/bus"
[[ -S "$bus" ]] || exit 0     # sin sesion iniciada no hay a quien avisar
runuser -u "$USER_NAME" -- env DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" \
    notify-send -a "${4:-cron}" -u "${3:-normal}" "${1:-cron}" "${2:-}" || true
exit 0
