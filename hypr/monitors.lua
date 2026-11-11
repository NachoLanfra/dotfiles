-- Pantallas. La del portatil (eDP-1) se fija aca; cualquier otra que enchufes
-- (proyector, TV, monitor) arranca extendida a la derecha con su modo preferido.
-- Lo que elijas con hypr/scripts/pantallas.sh (duplicar, extender, solo una) queda
-- guardado en ~/.local/state/pantallas/modo y se vuelve a aplicar solo.

hl.monitor({
    output = "eDP-1",
    mode = "2880x1800@90.0",
    position = "0x0",
    scale = 2.0
})
hl.monitor({
    output = "",
    mode = "preferred",
    position = "auto",
    scale = 1
})

local pantallas = "~/.config/hypr/scripts/pantallas.sh"
-- al enchufar una pantalla: aplicar lo que elegiste la ultima vez
hl.on("monitor.added", function()
    hl.exec_cmd(pantallas .. " --guardado")
end)
-- al desenchufarla: si habias dejado "solo externa", reencender la del portatil
hl.on("monitor.removed", function()
    hl.exec_cmd(pantallas .. " --restaurar")
end)
