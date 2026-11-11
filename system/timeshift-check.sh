#!/usr/bin/env bash
# timeshift-check: reemplaza al "timeshift --check --scripted" que cron lanza cada
# hora, y avisa con una notificacion cuando de verdad se pone a sacar un snapshot
# (la mayoria de las horas no hace nada, y ahi no molesta).
#
# install.sh lo copia a /usr/local/bin/timeshift-check y escribe
# /etc/cron.d/timeshift-hourly para que cron lo use.
PATH=/usr/local/sbin:/usr/local/bin:/usr/bin
LOG=/var/log/timeshift-check.log

out="$(mktemp)"
trap 'rm -f "$out"' EXIT

started=0
timeshift --check --scripted 2>&1 | tee "$out" | while IFS= read -r line; do
    if (( ! started )) && [[ "$line" == *"Creating new snapshot"* ]]; then
        started=1
        cron-notify "Timeshift: sacando snapshot" "Se esta guardando una copia del sistema, puede tardar unos minutos." low timeshift
    fi
done
rc=${PIPESTATUS[0]}

# si no llego a crear nada, no hay nada que avisar ni guardar
grep -q "Creating new snapshot" "$out" || exit "$rc"

{ printf '[%s]\n' "$(date '+%F %T')"; cat "$out"; } >>"$LOG"
if (( rc == 0 )); then
    cron-notify "Timeshift: snapshot listo" "Copia del sistema guardada." low timeshift
else
    cron-notify "Timeshift: fallo el snapshot" "Detalles en $LOG" critical timeshift
fi
exit "$rc"
