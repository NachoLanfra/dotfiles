#!/usr/bin/env bash
# Abre (o cierra, si ya esta abierto) el menu de apagado, centrado en el monitor
# enfocado sea cual sea su resolucion o escala.
#
# wlogout acomoda los botones dentro de un area definida por los margenes. Esa
# area tiene que ser al menos tan grande como los botones (~944 px de ancho); si
# es mas chica, los botones se desbordan y quedan corridos hacia un lado. Por eso
# se fija el tamano del area (AREA_W x AREA_H) y se reparte el resto en margenes iguales.
AREA_W=960
AREA_H=250

pkill -x wlogout && exit 0

# tamano logico (ya dividido por la escala) del monitor enfocado
read -r w h < <(hyprctl monitors -j | jq -r '.[] | select(.focused) | "\((.width / .scale) | floor) \((.height / .scale) | floor)"')
w=${w:-1440}; h=${h:-900}

mx=$(( (w - AREA_W) / 2 )); my=$(( (h - AREA_H) / 2 ))
(( mx < 0 )) && mx=0
(( my < 0 )) && my=0

exec wlogout -b 4 --margin-left "$mx" --margin-right "$mx" --margin-top "$my" --margin-bottom "$my"
