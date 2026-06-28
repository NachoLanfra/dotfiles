hl.env("GTK_TOOLTIP_TIMEOUT", "100")

local terminal = "kitty"

hl.on("hyprland.start", function()
    hl.exec_cmd(terminal)
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("swayosd-server & waybar > /dev/null 2>&1 & swaybg -i /home/nachohyperland/Pictures/wallpaper.jpg -m fill & /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &")
end)
