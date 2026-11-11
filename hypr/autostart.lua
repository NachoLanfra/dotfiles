hl.env("GTK_TOOLTIP_TIMEOUT", "100")

local terminal = "kitty"

hl.on("hyprland.start", function()
    hl.exec_cmd(terminal)
	hl.exec_cmd("~/.config/hypr/scripts/theme-switch.sh --boot; swayosd-server & waybar > /dev/null 2>&1 & /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 & hypridle &")
    hl.exec_cmd("sh -c 'sleep 1.5 && swayosd-client --output-volume raise && swayosd-client --output-volume lower' &")
    -- vigila el cargador: ahorro de energia al desenchufar, avisos de bateria baja
    hl.exec_cmd("~/.config/hypr/scripts/power-watch.sh &")
    -- historial del portapapeles (texto e imagenes) para SUPER+SHIFT+V
    hl.exec_cmd("wl-paste --type text --watch cliphist store &")
    hl.exec_cmd("wl-paste --type image --watch cliphist store &")
end)
