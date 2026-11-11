# dotfiles

Configuración de Arch Linux con Hyprland.

## Instalar

```bash
git clone <url-del-repo> ~/dotfiles
cd ~/dotfiles
./install.sh
```

El script pide `sudo` cuando lo necesita. No lo corras como root.

## Qué hace

1. **Paquetes:** instala lo de `packages.txt` con `pacman` y, debajo de `### AUR ###`, con `yay` (lo compila si falta).
2. **Enlaces:** enlaza las configs del repo a `~/.config` y `~`. Lo que ya existía se guarda en `~/.dotfiles-backup/<fecha>/`.
3. **Tema:** genera los archivos de colores que leen las configs, más la apariencia GTK (`settings.ini`, `~/.gtkrc-2.0` y gsettings). Todo eso sale de `hypr/scripts/theme-switch.sh` hacia `~/.config/theme`, por eso no está versionado: así el repo no cambia al elegir un tema.
4. **Servicios de la sesión:** enlaza `systemd/user/*.service` y los habilita (waybar, hypridle, swayosd, polkit, portapapeles, ahorro de energía, wallpaper). Arrancan solos con la sesión *Hyprland (uwsm-managed)* y se relanzan si se caen. Estado: `systemctl --user status waybar`; logs: `journalctl --user -u waybar`.
5. **Sistema:** habilita servicios, agrega los grupos del usuario, copia la config de zram y activa el firewall.
6. **Mantenimiento:** `reflector` elige los mirrors más rápidos (semanal), `paccache` limpia la caché de pacman (semanal) y `timeshift` saca snapshots del sistema (diario y semanal, guardados en la partición de `/home`). Para volver atrás: `sudo timeshift --list` y `sudo timeshift --restore`.
7. **Actualización automática:** `system/auto-update.sh` se instala en `/etc/cron.daily/` y lo lanza anacron (viene con cronie). Cada 7 días, con el cargador enchufado, saca un snapshot de timeshift, corre `pacman -Syu` y `flatpak update`, y avisa con una notificación. Si algo falla no actualiza y reintenta al día siguiente. El AUR no se actualiza solo (`yay -Sua`). Log: `/var/log/auto-update.log`. A mano: `sudo /etc/cron.daily/auto-update --force`.

## Opciones

| Opción | Efecto |
|---|---|
| `--no-packages` | no instala paquetes |
| `--no-links` | no enlaza configs |
| `--no-system` | no toca servicios, grupos, zram ni firewall |
| `--help` | muestra la ayuda |

Se puede correr varias veces: lo que ya está hecho se saltea.

## A mano

El script lo avisa al terminar:

- **SDDM:** `sddm/README.md`
- **GRUB:** `grub/default-grub-lines.txt` y `grub/theme/install.sh`
- Reiniciar la sesión para que tomen los grupos, zram y SDDM.

## Mantener `packages.txt`

`./packages-sync.sh` compara lo instalado con `packages.txt` y muestra las diferencias. Con `--add` agrega lo que falte.
