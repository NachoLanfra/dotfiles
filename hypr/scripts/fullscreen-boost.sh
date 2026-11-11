#!/usr/bin/env bash
# fullscreen-boost.sh: acelera la CPU unos segundos al entrar/salir de pantalla
# completa.
#
# Por que: en "power-saver" (el que pone power-watch.sh con bateria) el
# procesador sube de frecuencia muy lento. Cambiar a pantalla completa en
# YouTube es una rafaga de ~1 s de trabajo (re-layout del reproductor a
# 2880x1800) y con power-saver tardaba 1-3 s; con "performance" tarda ~0.3 s.
#
# Que hace: escucha los eventos de Hyprland; cuando una ventana entra o sale de
# pantalla completa pone el perfil "performance" y, pasados BOOST_SECS sin mas
# eventos, devuelve el perfil que habia. Si mientras tanto elegis otro perfil a
# mano (waybar), no lo pisa. El costo en bateria es de unos pocos segundos.
#
# Lo lanza hypr/autostart.lua. Una sola instancia a la vez.
set -u

export BOOST_SECS="${BOOST_SECS:-4}"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}"

exec 9>"$STATE_DIR/fullscreen-boost.lock"
flock -n 9 || exit 0

exec python3 -I - <<'EOF'
import os, select, socket, subprocess, time

secs = float(os.environ["BOOST_SECS"])
sock_path = "{}/hypr/{}/.socket2.sock".format(
    os.environ["XDG_RUNTIME_DIR"], os.environ["HYPRLAND_INSTANCE_SIGNATURE"])


# Se habla con power-profiles-daemon por D-Bus con gdbus (~10 ms). Con
# powerprofilesctl cada llamada tarda ~160 ms y el boost llegaba tarde: la
# rafaga de trabajo del navegador empieza a los pocos ms del evento.
GDBUS = ["gdbus", "call", "--system", "--dest", "net.hadess.PowerProfiles",
         "--object-path", "/net/hadess/PowerProfiles", "--method"]
IFACE = "net.hadess.PowerProfiles"


def profile():
    out = subprocess.run(
        GDBUS + ["org.freedesktop.DBus.Properties.Get", IFACE, "ActiveProfile"],
        capture_output=True, text=True).stdout
    return out.split("'")[1] if "'" in out else ""


def set_profile(name):
    subprocess.run(
        GDBUS + ["org.freedesktop.DBus.Properties.Set", IFACE, "ActiveProfile",
                 "<'%s'>" % name], capture_output=True)


s = socket.socket(socket.AF_UNIX)
s.connect(sock_path)

previous = None   # perfil a restaurar (None = no hay boost activo)
deadline = 0.0
buf = ""

while True:
    timeout = max(0.0, deadline - time.time()) if previous else None
    if select.select([s], [], [], timeout)[0]:
        data = s.recv(65536).decode(errors="ignore")
        if not data:
            break   # Hyprland se cerro
        buf += data
        *lines, buf = buf.split("\n")
        if any(l.startswith("fullscreen>>") for l in lines):
            if previous is None:
                current = profile()
                if current and current != "performance":
                    previous = current
                    set_profile("performance")
            if previous:
                deadline = time.time() + secs
    elif previous:
        if profile() == "performance":   # si lo cambiaron a mano, no tocar
            set_profile(previous)
        previous = None

if previous and profile() == "performance":
    set_profile(previous)
EOF
