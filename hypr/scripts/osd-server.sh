#!/usr/bin/env bash
# Mantiene swayosd-server siempre vivo.
# Las teclas de volumen/brillo usan swayosd-client, que no hace nada si el
# servidor no esta corriendo. Si se cae (o theme-switch.sh lo mata para
# recargar el css) este bucle lo vuelve a lanzar.
# Es seguro llamarlo varias veces: el lock evita instancias duplicadas.

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/osd-server.lock"
flock -n 9 || exit 0

while true; do
    swayosd-server
    # pausa para que DBus suelte el nombre antes de relanzar
    sleep 0.5
done
