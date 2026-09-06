SDDM theme: sugar-light (MarianArlt)
Repo: https://github.com/MarianArlt/sddm-sugar-light
Instalado en: /usr/share/sddm/themes/sugar-light

Cambios sobre el default:
- theme.conf: ThemeColor="#ebdbb2", AccentColor="#d79921", PanelColor="#1d2021" (paleta Gruvbox)
- Main.qml parcheado a mano: se agregó `palette.window: config.PanelColor` (línea ~36)
  para que el panel izquierdo tome color oscuro, ya que el tema no lo soporta por default.
  NOTA: este parche se pierde si se reinstala/actualiza el paquete con yay — hay que
  volver a aplicarlo.
