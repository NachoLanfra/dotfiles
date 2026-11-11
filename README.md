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
3. **Tema:** genera los archivos de colores que leen las configs.
4. **Sistema:** habilita servicios, agrega los grupos del usuario, copia la config de zram y activa el firewall.

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
