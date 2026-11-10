# Problemas conocidos

## `code .` abre la ventana en el workspace equivocado

**Síntoma:** lanzás `code .` en un workspace, cambiás a otro mientras carga y la
ventana aparece en el workspace donde estás ahora, no en el que la lanzaste.
Solo pasa cuando VS Code **ya estaba abierto**.

**Causa:** con VS Code abierto, `code` le pide la ventana nueva al proceso que ya
existe, así que Hyprland no la puede asociar con el proceso que lanzaste y la
deja en el workspace activo cuando se dibuja. `misc:initial_workspace_tracking`
solo cubre la primera ventana de una app.

**Probado (Hyprland, nov 2026):**

| Caso | `initial_workspace_tracking = 2` | `= 0` |
|---|---|---|
| Primera ventana de VS Code | ws correcto | ws correcto |
| Segunda, con VS Code ya abierto | ws equivocado | ws equivocado |

Cambiar ese valor no lo arregla. Otros usuarios reportan lo mismo, incluso con
`hyprctl dispatch exec '[workspace N silent] app'`, que también falla si la app
ya tiene una ventana abierta.

**Solución:** `hypr/scripts/ws-run.sh <comando>` anota el workspace de origen,
lanza el comando y mueve en silencio la primera ventana nueva que aparezca.

- Los binds `SUPER+E` (archivos) y `SUPER+B` (navegador) ya lo usan.
- Para `code .` alcanza con la función `code()` de `shell/bashrc` (ya enlazado a
  `~/.bashrc`; lo propio de la máquina va en `~/.bashrc.local`).

**Limitaciones:**
- Las apps lanzadas desde `hyprlauncher` (`SUPER+R`) no pasan por el wrapper.
- Mueve la primera ventana nueva de los 30 s siguientes: si abrís otra app justo
  en ese rato, podría moverla por error.
- Si cambiás de workspace en menos de ~0,2 s, el wrapper puede tomar mal el origen.
