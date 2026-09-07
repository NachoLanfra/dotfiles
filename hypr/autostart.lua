hl.env("GTK_TOOLTIP_TIMEOUT", "100")

local terminal = "kitty"

hl.on("hyprland.start", function()
    hl.exec_cmd(terminal)
	hl.exec_cmd("nm-applet & swayosd-server & waybar > /dev/null 2>&1 & swaybg -i /home/hyprlandnacho/Pictures/wallpaper.jpg -m fill & /usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 & hypridle &")
    hl.exec_cmd("sh -c 'sleep 1.5 && swayosd-client --output-volume raise && swayosd-client --output-volume lower' &")
end)
