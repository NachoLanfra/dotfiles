hl.env("GTK_TOOLTIP_TIMEOUT", "100")

local terminal = "kitty"

-- Waybar, hypridle, swayosd, el agente de polkit, el historial del portapapeles,
-- power-watch, fullscreen-boost y el wallpaper/tema ya no se lanzan desde aca:
-- son servicios de systemd --user (systemd/user/*.service en el repo), que
-- arrancan con la sesion y se relanzan solos si se caen.
-- Estado: systemctl --user status waybar   Logs: journalctl --user -u waybar
hl.on("hyprland.start", function()
    hl.exec_cmd(terminal)
    -- precarga el servidor del cartel de volumen para que la primera tecla no tarde
    -- (+0: muestra el volumen actual sin cambiarlo)
    hl.exec_cmd("sh -c 'sleep 1.5 && swayosd-client --output-volume +0' &")
end)
