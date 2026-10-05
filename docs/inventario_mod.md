# Inventario de funciones del mod de Eloria (lo que Gon usa ahora)

Fecha: 2026-10-05. Revisión de solo lectura del repositorio `eloria-analisis`.
Objetivo: decidir qué pasar a la app nueva y comprobar que cada pieza funciona.

## 0. Cómo leer este documento

**Cadena de generación**, que conviene tener clara antes de nada:

```
cavebots/Expedition/*.json + tools/recorrido_venomfen_v3.txt
        │  tools/gen_expeditions.py
        ▼
eloria_expeditions.lua            (script de EloriaBot: lógica de expedición + 12 rutas)
        │  tools/gen_expeditions_mod.py  (+ trozos copiados de "Eloria HUD.lua")
        ▼
mods_zalo/expediciones/expediciones.lua   (EL MOD: lo que se carga con Ctrl+T)
        │  al cargarse, carga también
        ▼
mods_zalo/datos/zalo_datos.lua    (recolector de datos)
```

- **Fuente de verdad del mod**: `tools/gen_expeditions_mod.py`. Lo he comprobado: regenerado en una copia aparte, sale **idéntico** al `expediciones.lua` del repositorio (salvo los finales de línea). El `.lua` está al día.
- **¿`eloria_expeditions.lua` está obsoleto?** No del todo. **Como script de EloriaBot (pegado en EloriaBot > Scripting) sí está obsoleto**: la cabecera del mod dice que hay que quitarlo de ahí, y el mod hace lo mismo. **Pero sigue siendo necesario como archivo intermedio**: `gen_expeditions_mod.py` lo lee (línea 13) y mete su cuerpo tal cual dentro del mod. Coincide exactamente con la plantilla de `tools/gen_expeditions.py`, con 12 rutas. No hay que borrarlo. Sus comentarios sí están anticuados (ver F01 y F05).
- **`gen_expeditions.py` no se puede ejecutar desde el repo**: necesita `cavebots/Expedition/*.json`, que no está en el repo, y `tools/recorrido_venomfen_v3.txt`, que está en `.gitignore`. Además usa `BASE + '\\' + fname`, así que solo funciona en Windows.
- **Referencias**: `archivo:línea`. Para la lógica de expedición doy la línea de la plantilla en `tools/gen_expeditions.py` (la fuente) y la del mod generado. Para el resto del mod doy la del generador (`gen_expeditions_mod.py`) y la del `.lua` generado (`expediciones.lua`).
- **Etiquetas en "Cómo comprobarlo"**: **[seguro]** solo lee o mira. **[ACTÚA]** hace que el personaje haga algo (andar, usar objetos, hablar, gastar oro…).
- **Consola Ctrl+T**: cada línea se ejecuta por separado. Las variables `local` no pasan de una línea a la siguiente, así que todas las comprobaciones son de una sola línea.
- **Rutas de archivo**: `/mods_zalo/...` es relativo a la carpeta de escritura del cliente (`%APPDATA%\Eloria Client\EloriaClient\`).
- **Ojo**: el estado de la expedición (`ST`) y el objeto `EXP` son `local` en el mod. **No se pueden leer desde la consola** con `print(EXP.estado)`. Lo único global es `ExpMod` (que es `EXP`) y las tablas `ExpMod*` (lista completa en la sección 11). Para leer el paso actual uso los textos del panel: `ExpMod.box:getChildByIndex(n):getText()`.
  - Hijos 1 a 5 del panel, en orden: 1 = título `[ON]/[OFF]`, 2 = "Paso …" (oculto en el mod, pero tiene el texto), 3 = "Mapa: …", 4 = "Oleada: …", 5 = "Estado: …".

---

## 1. Expediciones: secuencia, rutas y movimiento

### F01. ON/OFF de expediciones y reanudación
- **Qué hace**: enciende o apaga la máquina de estados de la expedición. Al encender, apaga el cavebot de EloriaBot y las demás automatizaciones del mod, y retoma la secuencia desde donde esté el personaje (sala, safe spot o NPC).
- **Dónde**:
  - `toggle()`: `tools/gen_expeditions.py:431` → `expediciones.lua:687`.
  - Callback del título con `onlyOne("exp")`: `gen_expeditions_mod.py:978` → `expediciones.lua:1606`.
  - Bucle principal `Timer("eloria-expeditions", …, 50 ms)`: `gen_expeditions.py:447` → `expediciones.lua:703`.
- **Disparo**: botón de la UI (click en el título del panel) o comando de consola `ExpMod.toggle()`. Después, un temporizador de 50 ms.
- **Qué toca**: **actúa**. Apaga el cavebot de EloriaBot con `modules.game_helper.cavebot.toggle(false)` y pone en marcha todo lo de F02 a F11.
- **Ajustes**: `CFG` en `gen_expeditions.py:123` / `expediciones.lua:260`.
- **Archivos**: ninguno.
- **Pendientes y bugs**:
  - La cabecera del mod (`gen_expeditions_mod.py:88`) dice "El cavebot de EloriaBot hay que apagarlo a mano (el mod no puede tocarlo)". **Es falso hoy**: `Engine.enableCaveBot` (`expediciones.lua:143`) sí lo apaga.
  - El comentario "REANUDAR" de `eloria_expeditions.lua` dice que el vigilante repite el cristal cada 10 s. En el mod es cada 60 s o cuando cambia.
- **Cómo comprobarlo**:
  - **[seguro]** Mira el título: `print(ExpMod.box:getChildByIndex(1):getText())` → `[OFF] Eloria Expeditions`.
  - **[ACTÚA]** Al darle a ON el personaje sale andando hacia el NPC. Prueba solo en un sitio controlado. Con ON, `getChildByIndex(2)` debe pasar a "Paso 1/8 Ir al NPC…".

### F02. Diálogo con el NPC (hi → expeditions) y reintentos
- **Qué hace**: va a la casilla del NPC (`NPC_POS`), dice `hi` y, 1,2 s después, `expeditions`. Si en 20 s no entra en la sala, repite. Tras 3 intentos se para con un error.
- **Dónde**:
  - Etapas `npc`, `hi` y `empezar`: `gen_expeditions.py:476-519` → `expediciones.lua:732-776`.
  - Casillas prohibidas junto al NPC: `AVOID` en `gen_expeditions.py:151`.
- **Disparo**: el temporizador de 50 ms de F01, en las etapas npc, hi y empezar.
- **Qué toca**: **actúa**. Anda (map click) y **habla** (`g_game.talk`).
- **Ajustes**: `NPC_POS {15840,19514,7}`, `WORD_GAP_MS=1200`, `START_WAIT_MS=20000`, `START_TRIES=3`, `AVOID` (3 casillas).
- **Archivos**: ninguno.
- **Pendientes y bugs**: el mensaje de error todavía dice "vigilante Ctrl+T?", pero el vigilante ya va dentro del mod (F03).
- **Cómo comprobarlo**:
  - **[seguro]** Comprueba que estás en la casilla: `print(g_game.getLocalPlayer():getPosition().x, g_game.getLocalPlayer():getPosition().y)` debe dar 15840 19514.
  - **[ACTÚA]** Con ON, en la consola del juego aparecen `hi` y `expeditions` en Default. Si falla, `getChildByIndex(5)` muestra "Estado: no empieza, reintento n/3".

### F03. Vigilante del panel de expediciones (elegir mapa, pagar, Begin)
- **Qué hace**: cuando se abre la ventana `expeditionWindow` con las expediciones en ON, pulsa la tarjeta del mapa que toca. Después comprueba que "selected" sea ese mapa y pulsa **Begin**. Si sale "not enough", cambia el modo de pago y prueba otra vez.
- **Dónde**:
  - `vigPick`, `vigGo`, `vigBegin` y `vigSwapPay`: `gen_expeditions_mod.py:346-374` → `expediciones.lua:974-1002`.
  - Bucle de 500 ms: `gen_expeditions_mod.py:377` → `expediciones.lua:1005`.
- **Disparo**: temporizador de 500 ms que mira si la ventana está visible. Actúa una vez por cada apertura y solo con `ST.stage ~= "off"` y Auto-EXP apagado.
- **Qué toca**: **actúa**. Pulsa botones de la UI del juego: elegir mapa, cambiar modo de pago y Begin, que **gasta el coste de la expedición**.
- **Ajustes**: lista `VL = {"venomfen","prismheart","cinderfall"}`. Esperas de 1000 ms y 400 ms, y 500 ms para el cambio de pago.
- **Archivos**: ninguno.
- **Pendientes y bugs**: si el mapa elegido no coincide, solo imprime "destino mal, NO Begin" y no lo vuelve a intentar hasta que se cierre y se abra otra vez la ventana.
- **Cómo comprobarlo**:
  - **[seguro]** Con expediciones en **OFF**, abre a mano el panel del NPC. No debe pasar nada (prueba negativa).
  - **[ACTÚA]** Con ON, la consola imprime `[Vigilante] Begin en venomfen, siguiente: prismheart`.

### F04. Bucle de mapas Auto / Single
- **Qué hace**: en **Auto** hace los mapas en bucle Venomfen → Prismheart → Cinderfall. En **Single** repite solo el mapa marcado. Al hacer click en un mapa se elige.
- **Dónde**:
  - `MAPS` (gemas 63663/63664/63662): `gen_expeditions_mod.py:428` → `expediciones.lua:1056`.
  - Botones: `gen_expeditions_mod.py:489-491` → `expediciones.lua:1117-1119`.
  - `paintMaps`: `gen_expeditions_mod.py:877` → `expediciones.lua:1505`.
- **Disparo**: botones de la UI (Auto, Single y click en un mapa).
- **Qué toca**: solo estado interno (`VI`, `ExpModSel`). Lo usa F03.
- **Ajustes**: `ExpModSel` (0 = Auto, 1 a 3 = Single con ese mapa). Se conserva al recargar.
- **Archivos**: ninguno. Se pierde al cerrar el cliente.
- **Cómo comprobarlo**: **[seguro]** `print(ExpModSel)` antes y después de pulsar Auto o Single. El mapa siguiente aparece con "> " en amarillo y el de Single con "* " en verde.

### F05. Posición y fase del cristal (enganche XTAL)
- **Qué hace**: sustituye `modules.game_eternum_crystals.setExpeditionCrystalSite`. Cada vez que el cliente recibe el sitio del cristal (unos 2 s), le pasa a la lógica de expedición un mensaje interno `XTAL x y z fase cleared token`. Solo lo hace si ha cambiado o cada 60 s. La lógica lo lee en su manejador de texto.
- **Dónde**:
  - `hookCrystal`: `gen_expeditions_mod.py:396-416` → `expediciones.lua:1024-1044`.
  - Lectura del mensaje: `gen_expeditions.py:680` → `expediciones.lua:936`.
- **Disparo**: enganche a una función del módulo del cliente. Un temporizador de 2 s reintenta el enganche hasta que el módulo exista.
- **Qué toca**: solo lee. Se desactiva con Auto-EXP en ON.
- **Ajustes**: ninguno.
- **Archivos**: ninguno.
- **Pendientes y bugs**:
  - Depende de un módulo propio de Eloria (`game_eternum_crystals`). Si lo renombran, no llega el cristal y la expedición se queda en "4/8 Leer ubicación del cristal".
  - `ExpMod.stop()` restaura la función original (`expediciones.lua:3324`).
- **Cómo comprobarlo**:
  - **[seguro]** `print(modules.game_eternum_crystals and modules.game_eternum_crystals._osetExpeditionCrystalSite ~= nil)` → `true` = enganchado.
  - **[seguro]** Dentro de una sala, `print(ExpMod.box:getChildByIndex(4):getText())` debe dar "Oleada: cristal dormido" o "Oleada n/3".

### F06. Elegir la ruta según el cristal
- **Qué hace**: busca en `ROUTES` (12 rutas, 4 por mapa) la ruta cuyo cristal esté a 3 casillas o menos. Si no hay ninguna, usa la del mismo mapa con el cristal más cercano y avisa. Empieza por el nodo más cercano al personaje, así que también sirve para retomar.
- **Dónde**:
  - Tabla cristal → ruta: `gen_expeditions.py:9-22`.
  - `ROUTES` generado: `expediciones.lua:298`.
  - `pickRoute` y `nearestNode`: `gen_expeditions.py:402-425` → `expediciones.lua:658-681`.
  - Etapa `xtal`: `gen_expeditions.py:522` → `expediciones.lua:778`.
- **Disparo**: temporizador de 50 ms, etapa `xtal`.
- **Qué toca**: solo estado interno.
- **Ajustes**: `MATCH_TILES=3`, `INSTANCE_Z=0`, `XTAL_WARN_MS=10000`. `MANDATORY` está vacío. El tramo grabado (`REC`) solo existe para Venomfen.
- **Archivos**: ninguno.
- **Pendientes y bugs**:
  - Las rutas salen de JSON del cavebot que no están en el repo (ver la sección 0).
  - El nombre "Prismaheart" está mal escrito en los archivos de origen. No afecta al funcionamiento.
- **Cómo comprobarlo**: **[seguro]** en una sala con la expedición en ON, `print(ExpMod.box:getChildByIndex(3):getText())` → "Mapa: Venomfen Hollows". Si sale "Estado: cristal x,y sin ruta en la tabla", falta una ruta.

### F07. Movimiento: map click, flechas y anti-atasco
- **Qué hace**:
  - Fuera de Venomfen anda con map click. El camino se calcula con `g_map.findPath`, que permite pisar campos (fire field), y se manda con `g_game.autoWalk`. Si falla, usa el autowalk normal.
  - En Venomfen y en los nodos `a=true` (tramo grabado) anda **con flechas** (`g_game.walk`), con una búsqueda en anchura propia (radio 10) que respeta `AVOID` y `BLOCK_IDS`.
  - Si lleva 8 s sin moverse, salta al nodo siguiente.
- **Dónde**:
  - `Map.goTo`: `gen_expeditions_mod.py:228` → `expediciones.lua:155`.
  - `firstStep`, `useArrows` y `walkTo`: `gen_expeditions.py:292-356` → `expediciones.lua:548-612`.
  - Etapas `ruta` y `cristal_ir`: `gen_expeditions.py:555-585` → `expediciones.lua:811-843`.
- **Disparo**: temporizador de 50 ms.
- **Qué toca**: **actúa**: **anda**.
- **Ajustes**: `NODE_DIST=5`, `STUCK_MS=8000`, `CLICK_RETRY_MS=1000`, `BLOCK_IDS={10228}`, `ARROW_MAPS={Venomfen Hollows}`. `TICK_MS=50` está en `gen_expeditions.py:166`.
- **Archivos**: ninguno.
- **Pendientes y bugs**:
  - `Map.isTileWalkable` del mod no usa el parámetro "ignoreMagicField": solo mira `tile:isWalkable(ignoreMobs)`.
  - `Map.getAllPositionsWithTopItemId` mira todos los objetos de la casilla, no solo el de arriba.
- **Cómo comprobarlo**:
  - **[seguro]** Calcula un camino sin andar: `print(#(g_map.findPath(g_game.getLocalPlayer():getPosition(), {x=15840,y=19514,z=7}, 5000, 5) or {}))`, cerca del NPC. Debe dar más de 0.
  - **[ACTÚA]** Con ON, en una sala, el texto de `getChildByIndex(2)` debe avanzar ("nodo n/N"). "Estado: atascado, salto al nodo…" indica un atasco.

### F08. Cristal y oleadas (click, binding, re-click)
- **Qué hace**:
  - A 1 casilla del cristal, lo usa.
  - Espera la oleada. Con "the binding is exposed" vuelve a hacer click.
  - Si la fase no cambia en 4 s, repite el click.
  - Con "corrupted crystal destroyed" pasa a la salida.
- **Dónde**:
  - Etapas `cristal_usar` y `oleada`: `gen_expeditions.py:588-631` → `expediciones.lua:844-889`.
  - Textos: `gen_expeditions.py:688-690` → `expediciones.lua:944-946`.
- **Disparo**: temporizador de 50 ms, más el evento `onTextMessage` (vía `Game.registerEvent(TEXT_MESSAGE)`, que en el mod es `connect(g_game,{onTextMessage})`).
- **Qué toca**: **actúa**: **usa** el cristal (`g_game.use`).
- **Ajustes**: `CLICK_CHECK_MS=4000`. Un uso cada 500 ms como mucho.
- **Archivos**: ninguno.
- **Cómo comprobarlo**: **[ACTÚA]** en sala, `getChildByIndex(4)` pasa de "Oleada 1/3" a "2/3" y luego a "cristal destruido". Un aviso "el cristal no reaccionó (faltan kills?)" indica un re-click.

### F09. Barrido sur/norte contra monstruos a distancia (kite)
- **Qué hace**: si hay monstruos a 10 casillas o menos del cristal, ninguno pegado y el más cercano a más de 2 casillas durante 2 s, el personaje baja 5 casillas al sur del cristal y luego sube 5 al norte para atraerlos.
- **Dónde**:
  - `waveMonsters` y `freeNear`: `gen_expeditions.py:360-394` → `expediciones.lua:616-650`.
  - Etapa `kite`: `gen_expeditions.py:634-658` → `expediciones.lua:890-916`.
- **Disparo**: temporizador de 50 ms, desde la etapa `oleada`.
- **Qué toca**: **actúa**: **anda**.
- **Ajustes**: `KITE_ON=true`, `KITE_SQM=5`, `KITE_RADIUS=10`, `KITE_DIST=2`, `KITE_WAIT_MS=2000`, `KITE_LEG_MS=6000`.
- **Archivos**: ninguno.
- **Pendientes y bugs**: el comentario de `waveMonsters` dice "cache 200 ms", pero el código usa 500 ms.
- **Cómo comprobarlo**: **[ACTÚA]** en una oleada con monstruos de distancia, `getChildByIndex(2)` muestra "7/8 Barrido sur/norte".

### F10. Ventana "Expedition complete" → Yes
- **Qué hace**: cuando sale la ventana "Expedition complete", pulsa **Yes**. Para ello busca el botón dentro de la propia ventana y le hace click, porque el cliente deja la ventana abierta si solo se manda la respuesta.
- **Dónde**:
  - Manejador: `gen_expeditions.py:694` → `expediciones.lua:950`.
  - `Game.modalWindowAnswer`: `gen_expeditions_mod.py:286` → `expediciones.lua:213`.
  - Captura de título y botones en `Game.registerEvent`: `expediciones.lua:244-250`.
- **Disparo**: evento `g_game.onModalDialog`, solo con las expediciones en ON.
- **Qué toca**: **actúa**: contesta la ventana, lo que saca al personaje de la sala.
- **Ajustes**: ninguno.
- **Archivos**: ninguno.
- **Pendientes y bugs**: el código lo llama "respaldo del vigilante", pero el antiguo vigilante de consola ya no existe (F41). **Hoy es la única vía**.
- **Cómo comprobarlo**: **[ACTÚA]** al romper el cristal, la ventana se cierra sola y el personaje aparece en el safe spot (14439,19568,7).

### F11. Vuelta (safe spot → TP → NPC) y recuperación tras una muerte
- **Qué hace**:
  - Tras el Yes, va desde el safe spot al TP y de ahí al NPC.
  - Si en mitad de la expedición se encuentra fuera de la sala (muerte, por ejemplo), vuelve a empezar por el NPC.
  - Si lleva 30 s en la sala con el cristal roto y nadie ha contestado, avisa.
- **Dónde**:
  - Etapas `salida` y `vuelta`: `gen_expeditions.py:661-676` → `expediciones.lua:917-933`.
  - Detección de "fuera de la sala": `gen_expeditions.py:469` → `expediciones.lua:725`.
- **Disparo**: temporizador de 50 ms.
- **Qué toca**: **actúa**: **anda**.
- **Ajustes**: `SAFE_SPOT {14439,19568,7}`, `TP_TILE {14439,19562,7}`.
- **Archivos**: ninguno.
- **Cómo comprobarlo**: **[ACTÚA]** `getChildByIndex(2)` muestra "8/8 Vuelta: TP -> NPC" y después "1/8 Ir al NPC".

### F12. Auto-EXP (expedición para cazar con el cavebot)
- **Qué hace**: usa el mismo camino y la misma conversación con el NPC que F02. En el panel de expediciones baja ciclos hasta el nivel elegido, pulsa la etapa (Echo Reaper o Echo Monolith) y Venomfen, lo comprueba todo, paga y pulsa Begin. Dentro de la sala carga y enciende la caza "Eternum Monoliths" del cavebot de EloriaBot. Si sale de la sala (muerte), apaga el cavebot y vuelve al NPC.
- **Dónde**:
  - Bloque: `gen_expeditions_mod.py:1242-1395` → `expediciones.lua:2400-2553`.
  - `run` (panel): `gen_expeditions_mod.py:1333` → `expediciones.lua:2491`.
  - Bucle de 500 ms: `gen_expeditions_mod.py:1372` → `expediciones.lua:2530`.
- **Disparo**: botón "Auto-EXP" de la UI y los combos Lv y etapa. Luego, un temporizador de 500 ms.
- **Qué toca**: **actúa**. Anda, habla con el NPC y pulsa la UI (`modules.game_expedition.previousCycle()`, etapa, mapa, pago, Begin). Además **enciende y apaga el cavebot de EloriaBot** y le carga una ruta.
- **Ajustes**:
  - `AX_MAP="venomfen"`, `LVS={1,10,20,30,40,50}`, `STAGES`, `AX_HUNT` (las dos etapas → "Eternum Monoliths").
  - Por personaje, en `ExpModAXCfg[nombre] = {lv, stage}`. Por defecto Lv 30 para Nika y Lv 1 para el resto.
- **Archivos**: ninguno.
- **Pendientes y bugs**:
  - Con Auto-EXP en ON no se pasa el cristal (F05).
  - En la **primera** carga del cliente, si `ExpModAX.on` venía de antes, `huntCtl` se llama antes de que exista `ExpModHuntCtl` e imprime "sin control del cavebot".
  - Al recargar se usa la función `ExpModHuntCtl` de la carga anterior. Funciona, pero apunta a widgets ya destruidos (solo cambia `h.msg`).
- **Cómo comprobarlo**:
  - **[seguro]** `print(ExpModAX.on)` y `local c=ExpModAXCfg[g_game.getLocalPlayer():getName()] print(c and c.lv, c and c.stage)`.
  - **[ACTÚA]** La consola muestra `[Auto-EXP] ON: Lv 30 | Echo Reaper | Venomfen`, luego `[Auto-EXP] Begin (...)` y `[Auto-EXP] cavebot Eternum Monoliths : cargada: Monoliths`.

---

## 2. Pociones y buffs

### F13. Temporizador de buffs (pociones activas)
- **Qué hace**:
  - Lee los mensajes "You have activated X. It will last for N minutes/hours/seconds" en mensajes de texto y en el chat.
  - Muestra hasta 10 filas con icono y tiempo restante: verde si quedan más de 5 min, amarillo si quedan 5 min o menos, rojo "YA" al acabar.
  - Solo descuenta tiempo estando online. Lo guarda por personaje.
- **Dónde**:
  - Bloque: `gen_expeditions_mod.py:586-670` y bucle de pintado en `:769` → `expediciones.lua:1214-1299` y `1397`.
  - `BUFF_IDS`: `expediciones.lua:1218`.
- **Disparo**: eventos `g_game.onTextMessage` y `g_game.onTalk`, más un temporizador de 1 s.
- **Qué toca**: solo lee.
- **Ajustes**: `BUFF_IDS` (20 pociones). Colores y umbral de 300 s.
- **Archivos**:
  - `/mods_zalo/buffs_<pj>.txt` (formato `pj|buff|segundos`, cada 30 s).
  - `/mods_zalo/diag_buffs_<pj>.txt` (los últimos 20 mensajes con "activated").
  - Lee también el antiguo `/mods_zalo/buffs.txt` como respaldo.
- **Pendientes y bugs**:
  - El recolector (F29) solo reconoce "minutes", con mayúsculas exactas. Las pociones en horas no le llegan a la app.
  - El mod busca en minúsculas y acepta hours y seconds.
- **Cómo comprobarlo**: **[seguro]**
  - `for k,v in pairs(ExpModBuffs[g_game.getLocalPlayer():getName()] or {}) do print(k,v) end`.
  - El archivo `buffs_<pj>.txt` cambia cada 30 s.
  - Tras tomar una poción a mano, aparece la fila en el panel.

### F14. Auto-pociones (amplification y resilience)
- **Qué hace**: mientras "caza", usa las pociones que no estén activas, de una en una y con 2 s entre usos:
  - las base;
  - la amplification del personaje;
  - las resilience de los elementos que suponen al menos un 2 % del daño recibido en los últimos 300 s (F17).
  - Si una poción no se confirma, reintenta a los 30 s. Tras 3 fallos espera 10 min.
- **Dónde**:
  - Configuración: `gen_expeditions_mod.py:673-698` → `expediciones.lua:1301-1326`.
  - Bucle: `gen_expeditions_mod.py:740-766` → `expediciones.lua:1368-1394`.
- **Disparo**: temporizador de 1 s.
- **Qué toca**: **actúa**: **usa objetos** (`g_game.useInventoryItem(id)`), es decir, **gasta pociones**.
- **Ajustes**:
  - `POTS_BASE = {physical resilience, charm upgrade, strike enhancement}`.
  - `POTS_DMG` por personaje: Nika → fire, Trafalgar Law → ice, Zoro → physical, Nefertari → physical.
  - `POTS_RES` (códigos de elemento 0 a 6), `RES_WINDOW=300`, `RES_MIN=0.02`.
  - `AUTO_HUNTS` (5 cazas). "Cazando" significa: Auto-EXP en fase cazar, **o** una de esas cazas con el cavebot encendido, **o** algún monstruo en pantalla en los últimos 60 s.
- **Archivos**: indirectamente `buffs_<pj>.txt` (F13) y `res_<pj>.txt` (F17).
- **Pendientes y bugs**:
  - `Nefertari = physical` está marcado como "SIN CONFIRMAR".
  - "Physical resilience" aparece dos veces (en la base y en `POTS_RES[0]`). No hace daño.
  - **No hay botón para apagarlo**: está siempre activo mientras el mod esté cargado. Cualquier monstruo en pantalla (también en la ciudad o en un entrenamiento) hace que gaste pociones.
  - No comprueba cuántas pociones quedan.
- **Cómo comprobarlo**:
  - **[seguro]** La consola imprime `[Pociones] activas (bichos en pantalla)` o `(Auto-EXP)` cuando cambia el motivo.
  - **[ACTÚA]** El uso real se ve como una fila nueva en el panel y en `buffs_<pj>.txt`.
  - Para probar sin gastar no hay interruptor: **ojo**, basta con ver un monstruo para que empiece a tomarlas.

---

## 3. Registro de XP

### F15. XP Gain / RAW/h / XP/h en el panel
- **Qué hace**:
  - "XP Gain" es la experiencia ganada desde el server save (04:00) o desde el último [Reset].
  - "RAW/h" (experiencia base, sumada muerte a muerte) y "XP/h" (experiencia final) se calculan por hora de **tiempo cazando**. El reloj solo avanza si ha habido experiencia en los últimos 120 s.
- **Dónde**: `gen_expeditions_mod.py:510-574` → `expediciones.lua:1138-1202`. Evento en `:1173`, bucle de 1 s en `:1180`.
- **Disparo**: evento `g_game.onUpdateExperience(raw, final)`, temporizador de 1 s y botón [Reset].
- **Qué toca**: solo lee.
- **Ajustes**: `SERVER_SAVE_HOUR=4`, `ACTIVE_S=120`.
- **Archivos**: ninguno. Vive en `ExpModDaily`, en memoria, por personaje. Se pierde al cerrar el cliente.
- **Pendientes y bugs**: `onUpdateExperience` con dos valores (raw y final) parece ser propio de Eloria. Si deja de llegar, RAW/h se queda a 0.
- **Cómo comprobarlo**: **[seguro]** `local d=ExpModDaily[g_game.getLocalPlayer():getName()] print(d.day,d.baseXp,d.raw,d.active)`. Tras matar algo, `d.raw` debe subir.

### F16. `xp_logger.lua` (registro antiguo de XP)
- **Qué hace**: cada 30 s añade una línea `seg,raw_acum,final_acum,kills,nivel,epoch` y reescribe el archivo entero.
- **Dónde**: `mods_zalo/xp_logger.lua:2-10`.
- **Disparo**: carga manual (línea en Ctrl+T, o `tools/cargar_xp_logger.ahk`), luego `g_game.onUpdateExperience` y un temporizador de 30 s.
- **Qué toca**: solo lee.
- **Ajustes**: ninguno.
- **Archivos**: `/xp_<MMDD_HHMM>.txt`, en la **raíz** de la carpeta de escritura, no en `mods_zalo`.
- **Pendientes y bugs**:
  - El comentario dice `/xp_exped.txt`, pero no es ese nombre.
  - La lista crece sin límite en memoria y se reescribe completa.
  - **Lo sustituye el recolector (F29)**. `analisis/eloria.py` solo lo importa como "logs antiguos (Nika)".
- **Cómo comprobarlo**: **[seguro]** al cargarlo imprime `[XP] grabando en /xp_....txt`. `print(ZX.f, ZX.k, ZX.r)` muestra el archivo y lo acumulado. El archivo crece cada 30 s.

---

## 4. Seguimiento de daño

### F17. Daño recibido por elemento (para elegir resilience)
- **Qué hace**: suma el daño recibido por elemento en tramos de 10 s y calcula el reparto de los últimos 300 s. Así decide F14 qué resilience tomar.
- **Dónde**:
  - Evento: `gen_expeditions_mod.py:706` → `expediciones.lua:1334`.
  - `resPots`: `gen_expeditions_mod.py:713` → `expediciones.lua:1341`.
- **Disparo**: evento `g_game.onImpactTracker(tipo, cantidad, elemento)` (tipo 2 = recibido) y un temporizador de 1 s.
- **Qué toca**: solo lee.
- **Ajustes**: `RES_WINDOW`, `RES_MIN`, códigos de elemento (0 physical, 1 fire, 2 earth, 3 energy, 4 ice, 5 holy, 6 death; 8 drowning se ignora).
- **Archivos**: `/mods_zalo/res_<pj>.txt` cada 30 s, con el porcentaje por elemento.
- **Pendientes y bugs**:
  - Los códigos de elemento se comprobaron en un solo sitio (Echo Reaper).
  - `ExpModResDiag` es global y lo comparten todos los personajes.
- **Cómo comprobarlo**: **[seguro]** recibe algo de daño y mira que `res_<pj>.txt` se actualice (cada 30 s, con la hora, "mitigable N" y los porcentajes).

### F18. Registro de monstruos (de distancia o pegados)
- **Qué hace**: apunta cada monstruo visto (nombre sin "[nivel]" y los niveles vistos). Cuando un monstruo te golpea, mira si estaba a 2 casillas o más (distancia) o pegado.
- **Dónde**: `gen_expeditions_mod.py:804-871` → `expediciones.lua:1432-1499`.
- **Disparo**: temporizador de 2 s (espectadores), evento `g_game.onImpactTracker` y guardado cada 30 s.
- **Qué toca**: solo lee.
- **Ajustes**: ninguno. Lo usa `tools/gen_ranged_list.py` (F44).
- **Archivos**: `/mods_zalo/monstruos_vistos.txt` (`nombre|niveles|golpes_lejos|golpes_pegado`).
- **Pendientes y bugs**:
  - Si hay dos monstruos con el mismo nombre, cuenta el más cercano, lo que es una aproximación.
  - El archivo es compartido entre clientes: el último que guarda pisa a los demás.
- **Cómo comprobarlo**: **[seguro]** `local n=0 for _ in pairs(ExpModSeen) do n=n+1 end print(n)`. `monstruos_vistos.txt` debe cambiar unos 30 s después de ver bichos nuevos.

### F19. Analizador de sesión de Slandish (DMG, DPS, XP/h)
- **Qué hace**:
  - Suma el daño hecho según los mensajes y calcula DPS en 10 s, pico, golpe máximo, XP/h y niveles por hora.
  - "Profit/Loot/Supplies" no tiene API.
- **Dónde**: `Eloria HUD.lua:51-110` (`sampleStats`, `damageMessage`) y `:900-913` (panel).
- **Disparo**: solo en `Eloria HUD.lua` como script de EloriaBot: `Game.Events.TEXT_MESSAGE` y un temporizador de 100 ms.
- **Qué toca**: solo lee.
- **Ajustes**: ninguno.
- **Archivos**: ninguno.
- **Pendientes y bugs**: **es código muerto en el mod**. Se copia dentro de `HX` (`expediciones.lua:1853-1902`), pero nadie llama a `sampleStats`, `damageMessage` ni `E.resetSession`.
- **Cómo comprobarlo**: solo si `Eloria HUD.lua` está cargado en EloriaBot: sección "SESSION ANALYZER" del HUD de Slandish. En el mod no hay nada que comprobar.

---

## 5. HUD e interfaz

### F20. Panel del mod (ExpMod)
- **Qué hace**: panel arrastrable de 200 px. Arriba tiene las filas de estado (título, Mapa, Oleada, Estado) y debajo Mapas, Auto/Single/Forge/EXP/Auto-EXP, XP, buffs y secciones. Tras arrastrar, no cuenta como click.
- **Dónde**:
  - `box`, `dragHandle`, `HUD` y `hudObj`: `gen_expeditions_mod.py:147-209` → `expediciones.lua:74-136`.
  - Cambios de texto del mod (`MOD_UI`): `gen_expeditions_mod.py:29-43`.
  - `hudStep:hide()`: `expediciones.lua:961`.
- **Disparo**: al cargar el mod. Se maneja con el ratón.
- **Qué toca**: solo la UI.
- **Ajustes**: `ExpModPos` (posición; se conserva al recargar, pero no al cerrar el cliente).
- **Archivos**: ninguno.
- **Pendientes y bugs**: la fila "Paso" está oculta, pero se sigue actualizando. Es la mejor forma de leer la etapa (sección 0).
- **Cómo comprobarlo**: **[seguro]** `print(ExpMod.box:getId(), ExpMod.box:isVisible())` → `expModPanel true`.

### F21. Pantallas (principal, EXP, Forge) y secciones desplegables
- **Qué hace**:
  - Los botones EXP y Forge cambian de pantalla; "Volver" regresa a la principal.
  - Las secciones Bosses, Pesca, Bosstiary y Mining se abren o cierran al pulsar su cabecera.
  - Muestra en verde la caza del cavebot que esté en marcha.
- **Dónde**:
  - `section`: `gen_expeditions_mod.py:891` → `expediciones.lua:1519`.
  - `showPage`: `gen_expeditions_mod.py:2143` → `expediciones.lua:3301`.
- **Disparo**: botones de la UI.
- **Qué toca**: solo la UI.
- **Ajustes**: `ExpModOpen` (qué secciones están abiertas).
- **Archivos**: ninguno.
- **Pendientes y bugs**: `EXP.onMain` oculta las filas de buffs fuera de la pantalla principal.
- **Cómo comprobarlo**: **[seguro]** pulsa EXP y Volver. `print(ExpModOpen.boss)` cambia al pulsar "Bosses".

### F22. Mostrar u ocultar el panel al entrar y salir, y vigilante de recarga
- **Qué hace**:
  - El panel solo se ve dentro del juego.
  - Cada 3 s, si estás conectado y no existe `expModPanel` (el cliente ha reiniciado la interfaz, por ejemplo tras morir), recarga el mod. Lo hace como mucho una vez cada 15 s.
- **Dónde**:
  - `ExpModWD`: `gen_expeditions_mod.py:102-112` → `expediciones.lua:29-39`.
  - `showBox`: `gen_expeditions_mod.py:419-422` → `expediciones.lua:1047-1050`.
- **Disparo**: temporizador de 3 s y eventos `g_game.onGameStart` / `onGameEnd`.
- **Qué toca**: solo la UI. Recarga el mod, que a su vez recarga el recolector.
- **Ajustes**: 3 s y 15 s, fijos en el código.
- **Archivos**: ninguno.
- **Pendientes y bugs**:
  - Solo se quita con `ExpMod.stop()` sin argumentos.
  - Si el mod falla al cargar, reintenta cada 15 s e imprime el error cada vez.
- **Cómo comprobarlo**: **[seguro]**
  - `print(ExpModWD ~= nil, ExpModWDAt)`.
  - Si destruyes el panel a mano con `ExpMod.box:destroy()`, a los 3 a 15 s la consola imprime `[ExpMod] la interfaz se ha reiniciado: recargo el mod`.

### F23. `Eloria HUD.lua` (HUD de Slandish, script de EloriaBot)
- **Qué hace**: script completo para una ranura de EloriaBot. Incluye Boss Run, Dungeon Runner, Bosstiary, Mining, pesca (6 modos) y el analizador de sesión. Los textos están en polaco.
- **Dónde**: `Eloria HUD.lua:1-992`. `E.tick` en `:927` y `Timer.new` en `:991`.
- **Disparo**: botones de su HUD y un temporizador de 100 ms.
- **Qué toca**: **actúa** (según el módulo encendido).
- **Ajustes**: `CONFIG` en `:7`, `dungeonConfig` en `:252`, `BOSSTIARY_ENTRIES` en `:533`.
- **Archivos**: ninguno.
- **Pendientes y bugs**:
  - **Parece sustituido por el mod**: el mod copia Bosstiary y Mining y reescribe Boss Run y la pesca.
  - El generador lo **lee** para hacer el mod, así que no hay que borrarlo.
  - **Duda**: no consta si Gon aún lo tiene cargado en EloriaBot. Si fuera así, tendría dos automatizaciones compitiendo.
- **Cómo comprobarlo**: **[seguro]** en EloriaBot > Scripting, mira si hay una ranura con "Eloria HUD by Slandish". En la consola de EloriaBot saldría `Eloria ZeroBot HUD 4.5 GD7: gotowy`.

---

## 6. Cargadores (AHK y consola)

### F24. Carga manual del mod y `ExpMod.stop()`
- **Qué hace**:
  - Al cargar: apaga la copia anterior (`ExpMod.stop(true)`), crea el panel, carga el recolector, conecta los eventos e imprime `[ExpMod] cargado (12 rutas)…`.
  - `ExpMod.stop()` quita los temporizadores, los eventos, el enganche del cristal y el panel.
- **Dónde**:
  - Línea de carga: `gen_expeditions_mod.py:81`.
  - `EXP.stop`: `gen_expeditions_mod.py:2161` → `expediciones.lua:3319`.
- **Disparo**: comando de consola.
- **Qué toca**: deja de andar (`stopAutoWalk`). **No apaga el cavebot de EloriaBot ni el recolector.**
- **Ajustes**: ninguno.
- **Archivos**: ninguno.
- **Pendientes y bugs**: `ExpMod.stop()` **no para `ZaloDatos`**, que sigue grabando. Para pararlo, `ZaloDatos.stop()`.
- **Cómo comprobarlo**: **[seguro]** pega la línea de carga. Deben salir `[Datos] recolector v1 grabando en /mods_zalo/datos/registros/` y `[ExpMod] cargado (12 rutas)…`.

### F25. `CargarMod.ahk` (tecla RePag)
- **Qué hace**: con la ventana "Eloria" delante, RePag copia la línea de carga, abre Ctrl+T, la pega, pulsa Enter, cierra la consola y te devuelve el portapapeles.
- **Dónde**: `CargarMod.ahk:26-44`.
- **Disparo**: tecla de acceso rápido (PgUp).
- **Qué toca**: envía teclas al cliente.
- **Ajustes**: `LINEA` y las esperas.
- **Archivos**: ninguno.
- **Pendientes y bugs**: **riesgo**: si la consola ya estaba abierta, Ctrl+T la **cierra** y la línea se pega en el **chat del juego**. Con Enter, **el personaje la dice en voz alta**.
- **Cómo comprobarlo**: **[seguro, con la consola cerrada]** sale el aviso "CargarMod: cargando el mod..." junto al ratón y, en Ctrl+T, `[ExpMod] cargado`.

### F26. `tools/vigia_clientes.ahk` (carga automática por cliente)
- **Qué hace**: cada 5 s mira las ventanas `Eloria - <Nombre>`. Por cada proceso nuevo, o cada cambio de personaje, espera 20 s y a que lleves 3 s sin tocar el teclado ni el ratón, y entonces carga el mod igual que F25. Lo hace una vez por proceso y personaje.
- **Dónde**: `tools/vigia_clientes.ahk:57-96`.
- **Disparo**: temporizador de AHK de 5 s. Se arranca con Windows.
- **Qué toca**: envía teclas al cliente y cambia la ventana activa.
- **Ajustes**: `ESPERA_MS=20000` y el tiempo de inactividad de 3000 ms.
- **Archivos**: `tools/vigia.log`.
- **Pendientes y bugs**:
  - El mismo riesgo de la consola abierta que F25.
  - Si la ventana tiene título de personaje pero el personaje aún no ha entrado, el mod se carga igualmente y el panel se ocultará hasta que entre (F22).
- **Cómo comprobarlo**: **[seguro]** `tools\vigia.log` debe tener "vigia arrancado" y "cargado el mod en <pj> (pid N)". También aparece un TrayTip "Mod cargado en <pj>".

### F27. `tools/cargar_mod_nika.ahk`
- **Qué hace**: carga el mod una sola vez en la ventana exacta "Eloria - Nika" y vuelve a la ventana anterior. Códigos de salida: 2 = no existe la ventana, 3 = no se ha podido activar.
- **Dónde**: `tools/cargar_mod_nika.ahk:1-28`.
- **Disparo**: ejecución manual o desde otra herramienta (probablemente para uso remoto).
- **Qué toca**: envía teclas al cliente.
- **Ajustes**: el nombre de la ventana está fijo ("Nika").
- **Archivos**: ninguno.
- **Pendientes y bugs**:
  - Hace lo mismo que F26 pero solo para Nika. Es redundante.
  - Mismo riesgo de la consola abierta.
- **Cómo comprobarlo**: **[seguro]** ejecútalo y mira el código de salida (0 = ok) y `[ExpMod] cargado` en la consola de Nika.

### F28. `tools/cargar_xp_logger.ahk`
- **Qué hace**: igual que F27, pero carga `xp_logger.lua` (F16) en "Eloria - Nika".
- **Dónde**: `tools/cargar_xp_logger.ahk:1-28`.
- **Disparo**: ejecución manual.
- **Qué toca**: envía teclas al cliente.
- **Ajustes**: el nombre de la ventana está fijo.
- **Archivos**: indirectamente `/xp_*.txt`.
- **Pendientes y bugs**: **obsoleto** junto con F16.
- **Cómo comprobarlo**: **[seguro]** `print(ZX and ZX.f)` en la consola de Nika.

---

## 7. Recolector de datos

### F29. `mods_zalo/datos/zalo_datos.lua`
- **Qué hace**: solo lee el juego. Cada 30 s escribe un evento `tick` en JSON Lines con:
  - nivel, experiencia, raw, xp y kills del intervalo;
  - posición, % de vida y maná, stamina, si está en zona protegida (pz), ping;
  - daño recibido por elemento (`din`) y por origen (`src`), daño hecho (`dout`, sin confirmar), tipos de impacto (`imp`);
  - monstruos en pantalla (`mobs`).

  También emite `login`, `logout`, `death` (vida a 0), `buff`, `aviso` (World Boost o "You are dead") y `carga`. Cada 10 min abre un archivo nuevo.
- **Dónde**:
  - `tick`: `zalo_datos.lua:195`.
  - Eventos: `:129-170`.
  - Reconexión de eventos cada 60 s (`wire`): `:173`.
  - Arranque: `:249-256`.
  - Lo carga el mod en `gen_expeditions_mod.py:116` (`expediciones.lua:43`).
- **Disparo**:
  - Eventos `g_game`: `onUpdateExperience`, `onImpactTracker`, `onTextMessage`, `onGameStart` y `onGameEnd`.
  - Temporizadores: 30 s (tick), 1 s (muerte) y 60 s (reconexión).
- **Qué toca**: solo lee.
- **Ajustes**: `TICK_MS=30000`, `CHUNK_S=600`, `DIR`.
- **Archivos**: `/mods_zalo/datos/registros/<pj>_<AAAAMMDD_HHMMSS>.jsonl` (la cabecera dice `_HHMM`, pero el código añade también los segundos).
- **Pendientes y bugs**:
  - El evento `buff` solo reconoce "minutes" (ver F13).
  - "tipo 1 = daño hecho" está sin confirmar.
  - `ExpMod.stop()` no lo para.
  - Un archivo cada 10 min hace que se acumulen muchos archivos pequeños.
- **Cómo comprobarlo**: **[seguro]**
  - `print(ZaloDatos.file, #ZaloDatos.lines, ZaloDatos.acc.kills)`.
  - El `.jsonl` actual crece una línea cada 30 s.
  - `python analisis\eloria.py sesiones` las importa.

---

## 8. Otras automatizaciones del mod

### F30. Una automatización a la vez (`onlyOne`)
- **Qué hace**: al encender expediciones, Boss Run, Bosstiary, Mining, Auto-EXP o una caza del cavebot, apaga las demás y el cavebot de EloriaBot (excepto si lo que se enciende es una caza).
- **Dónde**: `gen_expeditions_mod.py:1223` → `expediciones.lua:2381`.
- **Disparo**: lo llaman los botones de la UI.
- **Qué toca**: **actúa**: apaga el cavebot de EloriaBot y para el movimiento.
- **Ajustes**: ninguno.
- **Archivos**: ninguno.
- **Pendientes y bugs**: la pesca, la forja, el auto sliver y las auto-pociones **no** entran en la exclusión.
- **Cómo comprobarlo**: **[ACTÚA]** enciende Mining y luego expediciones. `[OFF] Mining` debe volver a OFF.

### F31. Boss Run (estatua 46087)
- **Qué hace**:
  1. Va a la estatua del lobby (31595,17406,5).
  2. Llama a `bossSequenceStart(categoría, nº bosses)` de EloriaBot (`modules.game_helper._Helper.ScriptingActions`). Si no lo acepta, usa la estatua para abrir el panel.
  3. Espera el teleport, da 4 pasos al norte, pelea y, al volver al lobby, pasa a la siguiente categoría.
  4. Cuando ha hecho las 3 categorías, pausa 60 s.
- **Dónde**: `gen_expeditions_mod.py:946-1060` → `expediciones.lua:1574-1688`.
- **Disparo**: botón de la UI (sección Bosses) y un temporizador de 250 ms.
- **Qué toca**: **actúa**: anda, usa la estatua y lanza la secuencia de bosses.
- **Ajustes**: `ExpModBossCat` (EASY, MEDIUM o HARD) y `ExpModBossWave` (1, 3 o 5).
- **Archivos**: ninguno.
- **Pendientes y bugs**:
  - Depende de una función interna de EloriaBot.
  - `BOSS.errShown` no se reinicia, así que el error se imprime una sola vez por carga.
  - La pelea la hace otro (EloriaBot o el jugador).
- **Cómo comprobarlo**: **[seguro]** `print(type(modules.game_helper._Helper.ScriptingActions.bossSequenceStart))` → `function`. **[ACTÚA]** encenderlo en el lobby.

### F32. Bosstiary (123 bosses × 5 salas)
- **Qué hace**:
  1. Va a la entrada de cada boss de la lista.
  2. Contesta la ventana de salas eligiendo la "room N".
  3. Espera el teleport, mira si hay monstruos (la pelea), sale por el objeto 22761 y pasa a la sala o al boss siguiente.
- **Dónde**:
  - Código de Slandish dentro de `HX`: `BOSSTIARY_ENTRIES`, `bosstiaryTick` y `bosstiaryModal` en `expediciones.lua:2042`, `2168` y `2151` (origen `Eloria HUD.lua:533-709`).
  - UI: `gen_expeditions_mod.py:1182` → `expediciones.lua:2340`.
  - Bucle de 100 ms: `gen_expeditions_mod.py:1399` → `expediciones.lua:2557`.
- **Disparo**: botón de la UI, temporizador de 100 ms y evento `g_game.onModalDialog`.
- **Qué toca**: **actúa**: anda, usa objetos y contesta ventanas.
- **Ajustes**: `BOSSTIARY_ENTRIES` (coordenadas y nombres). El progreso va en `ExpModBT` (index, room, cycles).
- **Archivos**: ninguno. El progreso se pierde al cerrar el cliente.
- **Pendientes y bugs**:
  - La pelea la hace otro.
  - `E.status` lo comparten Bosstiary y Mining.
- **Cómo comprobarlo**: **[seguro]** `print(ExpModBT.index, ExpModBT.room, ExpModBT.stage, ExpModBT.cycles)`. **[ACTÚA]** encenderlo.

### F33. Mining (pico 19249)
- **Qué hace**: busca rocas (19303, 19304, 19311), usa el pico hasta 5 veces por roca y explora el piso cuando no ve más. Lee "depleted", "exhausted" y "cannot mine here".
- **Dónde**:
  - `mineTick` y `E.onText`: `expediciones.lua:2257` y `2320` (origen `Eloria HUD.lua:748-820`).
  - UI: `gen_expeditions_mod.py:1195` → `expediciones.lua:2353`.
- **Disparo**: botón de la UI, temporizador de 100 ms y evento `g_game.onTextMessage`.
- **Qué toca**: **actúa**: anda con flechas y usa el pico en el suelo.
- **Ajustes**: los ids están fijos en el código.
- **Archivos**: ninguno.
- **Cómo comprobarlo**: **[seguro]** `print(g_game.getLocalPlayer():getItemsCount(19249))` (si es 0, sale "Mining: sin pico 19249"). **[ACTÚA]** encenderlo.

### F34. Pesca (caña 3483)
- **Qué hace**: con los modos activos (Fish, Shimmer, Sandfish, Old Nasty, Rainbow, Northern), usa la caña sobre el agua más cercana del tipo de cada modo. Un uso cada 700 ms como mucho. Puede ir a la vez que el resto.
- **Dónde**: `gen_expeditions_mod.py:1066-1113` → `expediciones.lua:1694-1741`.
- **Disparo**: botones de la UI (sección Pesca) y un temporizador de 700 ms.
- **Qué toca**: **actúa**: usa objetos.
- **Ajustes**: `FISH` (ids de agua) y `ExpModFish` (modos encendidos).
- **Archivos**: ninguno.
- **Pendientes y bugs**:
  - Los iconos de Shimmer y Sandfish valen `fish=0` ("sin confirmar").
  - Old Nasty y Shimmer usan el mismo id de agua, igual que Rainbow y Northern.
- **Cómo comprobarlo**: **[seguro]** `print(g_game.getLocalPlayer():getItemsCount(3483))`. **[ACTÚA]** activar un modo junto al agua; "usos: N" sube.

### F35. Cazas EXP (cargar una ruta del cavebot de EloriaBot)
- **Qué hace**: en la pantalla EXP, al hacer click en una caza se carga su ruta en el cavebot de EloriaBot (`selectCategory` + campo `sessionName` + `loadSession`) y se enciende. Otro click la apaga. Muestra el estado y el waypoint actual.
- **Dónde**:
  - `HUNTS`: `gen_expeditions_mod.py:1672` → `expediciones.lua:2830`.
  - `ebLoadRoute`: `gen_expeditions_mod.py:1698` → `expediciones.lua:2856`.
  - `ExpModHuntCtl`: `gen_expeditions_mod.py:1732` → `expediciones.lua:2890`.
- **Disparo**: botones de la UI y un temporizador de 1 s para el estado.
- **Qué toca**: **actúa**: **enciende y apaga el cavebot de EloriaBot** y le carga rutas.
- **Ajustes**: `HUNTS`, con 8 cazas: EchoMonolith, Echo Reaper 2, Echo Reaper 2 LINEAL, FateDemon, Fate Warden, EchoTide, Eternum Monoliths y EchoMonolith 2.
- **Archivos**: ninguno.
- **Pendientes y bugs**:
  - Necesita haber abierto **una vez** la ventana del cavebot de EloriaBot (`helperWindow`). Si no, sale "abre una vez el cavebot de EloriaBot".
  - Depende de funciones internas de EloriaBot.
- **Cómo comprobarlo**: **[seguro]** `local C=modules.game_helper.cavebot print(C.isEnabled(), C.getStatus(), C.getCurrentIndex())` y `print(ExpModHunt)`.

### F36. Forja: auto-fusión
- **Qué hace**: fusiona el objeto que sueltes en el hueco.
  - **Sin objetivo**: guarda 1 de cada tier y fusiona el excedente cuando hay 3 o más.
  - **Con "Tier objetivo"**: fusiona por parejas hasta conseguir 1 objeto más en ese tier, teniendo en cuenta el "Tier inicial" del arma.
  - Pausa aleatoria de 1,8 a 3,2 s. Se para sola cuando termina, si le falta material o si 2 fusiones seguidas no cambian nada.
- **Dónde**:
  - Bloque: `gen_expeditions_mod.py:1435-1661` → `expediciones.lua:2593-2819`.
  - `sendForgeFusion`: `expediciones.lua:2812`.
  - UI de la pantalla Forge: `gen_expeditions_mod.py:1768-1843`.
- **Disparo**: botón de la UI ([ON] Auto-fusion), arrastrar un objeto al hueco y un temporizador de 500 ms.
- **Qué toca**: **actúa**: `g_game.sendForgeFusion(...)`. **Gasta oro, dust y objetos.**
- **Ajustes**: `ExpModForge` (`conv`, `sliver`, `item`, `start`, `target`).
- **Archivos**: `/mods_zalo/diag_inventario.txt`, una vez al soltar un objeto.
- **Pendientes y bugs**:
  - `FORGE_SLIVERS` devuelve `nil`: **el coste en slivers está sin confirmar** y sale "Needed: ?".
  - Si `getInventoryCount` no existe o devuelve 0, solo cuenta lo que hay en las mochilas abiertas.
- **Cómo comprobarlo**: **[seguro]** suelta un objeto en el hueco **sin** pulsar ON. Deben salir "ID n", "Items: x / Needed: y" y "(contando: inventario)", y se escribe `diag_inventario.txt`. **[ACTÚA]** con ON.

### F37. Auto sliver
- **Qué hace**: con la casilla marcada, usa el objeto sliver 37109 cada segundo. Igual que el temporizador "sliver" de EloriaBot.
- **Dónde**: `gen_expeditions_mod.py:1623-1626` → `expediciones.lua:2781-2784`.
- **Disparo**: casilla de la UI y un temporizador de 1 s.
- **Qué toca**: **actúa**: usa objetos.
- **Ajustes**: `ExpModForge.sliver`, `SLIVER_ID=37109`, `SLIVER_MS=1000`.
- **Archivos**: ninguno.
- **Pendientes y bugs**: no mira si tienes slivers, así que lo usa aunque no tengas ninguno.
- **Cómo comprobarlo**: **[seguro]** `print(ExpModForge.sliver)`. **[ACTÚA]** al marcarlo, el número de "Auto sliver (37109: n)" baja.

### F38. Compra en la tienda de la forja
- **Qué hace**:
  - "[ Hablar con el NPC (hi) ]" dice `hi`.
  - Lo que escribes en "Item:" se copia al buscador de la tienda (`strengthForgeWindow`).
  - [Comprar] busca la tarjeta con ese nombre exacto y pulsa "Buy 1" y luego "Yes" en "Confirm Purchase", N veces. Prueba 3 formas de pulsar el botón.
- **Dónde**:
  - Bloque: `gen_expeditions_mod.py:1852-2129` → `expediciones.lua:3010-3287`.
  - Bucle: `gen_expeditions_mod.py:2080` → `expediciones.lua:3238`.
- **Disparo**: botones de la UI y un temporizador de 20 ms.
- **Qué toca**: **actúa**: **habla** con el NPC y **compra**, gastando moneda.
- **Ajustes**: `ExpModBuy {name, amount}`, `BUY_MS=120`.
- **Archivos**: `/mods_zalo/diag_tienda.txt` y `/mods_zalo/diag_confirm.txt` (volcados de diagnóstico, una vez).
- **Pendientes y bugs**:
  - Los volcados de diagnóstico parecen restos de cuando se estaba desarrollando.
  - Repetir el `onTextChange` de `te` (`:1876` y `:1909`) es redundante: el segundo sustituye al primero.
- **Cómo comprobarlo**: **[seguro]** abre la tienda a mano, escribe en "Item:" y el buscador de la tienda debe copiar el texto. **[ACTÚA]** [Comprar].

### F39. Dungeon Runner (solo en el HUD de Slandish)
- **Qué hace**: recorre 10 dungeons en solitario desde la estatua 63529. Contesta "Solo Dungeon System" y "Confirm Entry", patrulla izquierda-centro-derecha y abre el cofre 24875.
- **Dónde**: `Eloria HUD.lua:249-531`.
- **Disparo**: botón del HUD de Slandish, temporizador de 100 ms y `Game.Events.MODAL_WINDOW`.
- **Qué toca**: **actúa**.
- **Ajustes**: `dungeonConfig`.
- **Archivos**: ninguno.
- **Pendientes y bugs**: **no está en el mod**: el generador corta justo antes (`cut('local CONFIG={', '-- Dungeon module transplanted')`). Si Gon lo usa, solo funciona desde EloriaBot.
- **Cómo comprobarlo**: no aplica al mod.

---

## 9. Diagnóstico y restos antiguos

### F40. Volcados de diagnóstico
- **Qué hace**:
  - En cada carga escribe qué expone EloriaBot (módulos, funciones del cavebot y de `ScriptingActions` con sus parámetros, estado del cavebot, widgets de session/category).
  - El resto de volcados (`diag_buffs`, `diag_inventario`, `diag_tienda`, `diag_confirm`) se describen en F13, F36 y F38.
- **Dónde**: `gen_expeditions_mod.py:2172-2264` → `expediciones.lua:3330-3422`.
- **Disparo**: automático al cargar el mod.
- **Qué toca**: solo lee.
- **Ajustes**: ninguno.
- **Archivos**: `/mods_zalo/diag_eloriabot.txt`.
- **Pendientes y bugs**: dice "para Claude". Es útil para la app (qué funciones de EloriaBot hay), pero recorre toda la interfaz en cada carga.
- **Cómo comprobarlo**: **[seguro]** la fecha de `diag_eloriabot.txt` cambia en cada carga.

### F41. Apagado del vigilante antiguo de consola
- **Qué hace**: si quedaba el vigilante viejo de "6 líneas" (`VigEmbark` y `VigModalOn`), lo quita.
- **Dónde**: `gen_expeditions_mod.py:122-123` → `expediciones.lua:49-50`.
- **Disparo**: al cargar el mod.
- **Qué toca**: nada en el juego.
- **Ajustes**: ninguno.
- **Archivos**: ninguno.
- **Pendientes y bugs**: **código antiguo**: ya nadie crea esas variables. Se puede quitar al portar.
- **Cómo comprobarlo**: **[seguro]** `print(VigEmbark, VigModalOn)` → `nil nil`.

---

## 10. Herramientas (Python)

### F42. `tools/gen_expeditions.py`
- **Qué hace**: genera `eloria_expeditions.lua`. Lee las 12 rutas del cavebot en JSON, comprueba que acaben junto a su cristal y añade al principio de las rutas de Venomfen el tramo grabado (`recorrido_venomfen_v3.txt`), rellenando los huecos.
- **Dónde**: `TABLE` en `:9`, `REC` en `:32`, plantilla en `:87-707`.
- **Disparo**: manual (`python gen_expeditions.py`).
- **Qué toca**: nada en el juego.
- **Ajustes**: `TABLE`, `MANDATORY` (vacío) y toda la configuración `CFG` de la plantilla.
- **Archivos**: escribe `eloria_expeditions.lua`.
- **Pendientes y bugs**:
  - Le faltan archivos de origen en el repo.
  - La ruta con `'\\'` solo funciona en Windows.
  - `tools/gen_expeditions_con_tramo_grabado.py` y `secuencia_expedicion_ANTIGUA.lua` aparecen en `.gitignore` como restos.
- **Cómo comprobarlo**: **[seguro]** en el PC de Gon, ejecútalo dentro de `tools\`. Imprime "tramo grabado Venomfen Hollows: N casillas" y "ok". Luego `git diff eloria_expeditions.lua` debe salir vacío.

### F43. `tools/gen_expeditions_mod.py`
- **Qué hace**: monta el mod juntando la cabecera (la API de EloriaBot hecha con `g_game`, `g_map` y `g_ui`), el cuerpo de `eloria_expeditions.lua` con 6 cambios de UI, el final del mod y dos trozos de `Eloria HUD.lua` con los mensajes traducidos.
- **Dónde**: `:19-72` (troceado y aserciones) y `:2269-2273` (escritura).
- **Disparo**: manual.
- **Qué toca**: nada en el juego.
- **Ajustes**: `MOD_UI` y la tabla de traducciones.
- **Archivos**: escribe `mods_zalo/expediciones/expediciones.lua`.
- **Pendientes y bugs**:
  - Las `assert` fallan si cambia el texto de origen. Es intencionado.
  - El README pide comprobar el resultado con `luaparser` y `tools/upcount.py`.
- **Cómo comprobarlo**: **[seguro]** ejecútalo y comprueba que `git diff mods_zalo/expediciones/expediciones.lua` sale vacío. Yo lo he hecho en una copia: idéntico.

### F44. `tools/gen_ranged_list.py`
- **Qué hace**: genera la lista "Ranged Monster Names" para el Targeting de EloriaBot, con "<bicho> [1]" a "[10]". Usa `monstruos_vistos.txt` (F18): los bichos con 3 o más golpes a distancia que sean al menos el 30 % de sus golpes. Si no hay datos, usa una lista fija con el prefijo "eternum".
- **Dónde**: `tools/gen_ranged_list.py:12-53`.
- **Disparo**: manual.
- **Qué toca**: nada en el juego.
- **Ajustes**: `LEVELS`, `MIN_FAR=3`, `FAR_RATIO=0.3`, `RANGED`, `PREFIX`.
- **Archivos**: escribe `ranged_monsters_eternum.txt`, en la raíz del cliente.
- **Pendientes y bugs**: el resultado hay que pegarlo a mano en EloriaBot.
- **Cómo comprobarlo**: **[seguro]** ejecútalo. Imprime "N bichos x 10 niveles = …" y el archivo tiene una sola línea separada por comas.

### F45. `tools/upcount.py`
- **Qué hace**: comprobación de mantenimiento. Cuenta cuántos locales de nivel superior usa cada función del mod, para no pasar el límite de Lua de 60 upvalues.
- **Dónde**: `tools/upcount.py:1-25`.
- **Disparo**: manual, necesita `luaparser`.
- **Qué toca**: nada en el juego.
- **Ajustes**: ninguno.
- **Archivos**: ninguno.
- **Pendientes y bugs**: no está en la lista pedida. Lo menciono porque el README lo pide tras regenerar.
- **Cómo comprobarlo**: `python tools/upcount.py mods_zalo/expediciones/expediciones.lua` imprime las 5 funciones con más upvalues.

---

## 11. Tabla resumen

Prioridad para la app:
- **Alta**: datos y estado que la app necesita ya.
- **Media**: útil, pero depende de un canal de órdenes.
- **Baja**: dejarlo en el mod.
- **No**: obsoleto o código muerto.

| # | Función | Archivo | Automático o manual | Actúa en el juego | Prioridad |
|---|---|---|---|---|---|
| F01 | ON/OFF expediciones y reanudación | expediciones.lua (gen_expeditions.py) | Manual (título / `ExpMod.toggle()`) + temporizador | sí | Alta (estado y ON/OFF) |
| F02 | Diálogo con el NPC hi/expeditions | expediciones.lua | Auto (con ON) | sí | Media |
| F03 | Vigilante del panel: mapa, pago, Begin | expediciones.lua | Auto (con ON) | sí | Media |
| F04 | Bucle de mapas Auto/Single | expediciones.lua | Manual | no | Alta (elegir desde la app) |
| F05 | Posición y fase del cristal (XTAL) | expediciones.lua | Auto (enganche) | no | Alta (mostrar oleada) |
| F06 | Elegir ruta según el cristal | expediciones.lua | Auto | no | Baja |
| F07 | Movimiento: map click, flechas, anti-atasco | expediciones.lua | Auto | sí | Baja |
| F08 | Cristal y oleadas | expediciones.lua | Auto | sí | Baja |
| F09 | Barrido sur/norte | expediciones.lua | Auto | sí | Baja |
| F10 | Ventana "Expedition complete" → Yes | expediciones.lua | Auto (onModalDialog) | sí | Baja |
| F11 | Vuelta y recuperación tras muerte | expediciones.lua | Auto | sí | Baja |
| F12 | Auto-EXP | expediciones.lua | Manual + auto | sí | Media |
| F13 | Temporizador de buffs | expediciones.lua | Auto | no | Alta |
| F14 | Auto-pociones | expediciones.lua | Auto (sin interruptor) | sí | Media (añadir ON/OFF) |
| F15 | XP Gain / RAW/h / XP/h | expediciones.lua | Auto + [Reset] | no | Alta |
| F16 | xp_logger.lua | mods_zalo/xp_logger.lua | Manual | no | No (sustituido por F29) |
| F17 | Daño recibido por elemento | expediciones.lua | Auto | no | Alta |
| F18 | Registro de monstruos distancia/pegado | expediciones.lua | Auto | no | Media |
| F19 | Analizador de sesión de Slandish | Eloria HUD.lua | Auto (solo en EloriaBot) | no | No (código muerto en el mod) |
| F20 | Panel ExpMod | expediciones.lua | Auto al cargar | no | Baja (la app es otra UI) |
| F21 | Pantallas y secciones | expediciones.lua | Manual | no | Baja |
| F22 | Mostrar/ocultar + vigilante de recarga | expediciones.lua | Auto | no | Media (la app debería ver si el mod vive) |
| F23 | HUD de Slandish (script de EloriaBot) | Eloria HUD.lua | Manual | sí | No |
| F24 | Carga manual / `ExpMod.stop()` | expediciones.lua | Manual (consola) | no | Media |
| F25 | CargarMod.ahk (RePag) | CargarMod.ahk | Manual (tecla) | no* | Media |
| F26 | vigia_clientes.ahk | tools/vigia_clientes.ahk | Auto | no* | Alta (la app podría hacerlo) |
| F27 | cargar_mod_nika.ahk | tools/cargar_mod_nika.ahk | Manual | no* | No (redundante con F26) |
| F28 | cargar_xp_logger.ahk | tools/cargar_xp_logger.ahk | Manual | no* | No |
| F29 | Recolector zalo_datos | mods_zalo/datos/zalo_datos.lua | Auto | no | Alta (ya es la base de la app) |
| F30 | Una automatización a la vez | expediciones.lua | Auto (desde botones) | sí | Media |
| F31 | Boss Run | expediciones.lua | Manual + auto | sí | Baja |
| F32 | Bosstiary | expediciones.lua | Manual + auto | sí | Baja |
| F33 | Mining | expediciones.lua | Manual + auto | sí | Baja |
| F34 | Pesca | expediciones.lua | Manual + auto | sí | Baja |
| F35 | Cazas EXP (cavebot de EloriaBot) | expediciones.lua | Manual | sí | Media |
| F36 | Forja: auto-fusión | expediciones.lua | Manual + auto | sí | Baja |
| F37 | Auto sliver | expediciones.lua | Manual (casilla) | sí | Baja |
| F38 | Compra en la tienda de la forja | expediciones.lua | Manual | sí | Baja |
| F39 | Dungeon Runner | Eloria HUD.lua | Manual | sí | No (no está en el mod) |
| F40 | Volcados de diagnóstico | expediciones.lua | Auto al cargar | no | Baja |
| F41 | Apagado del vigilante antiguo | expediciones.lua | Auto al cargar | no | No (código antiguo) |
| F42 | gen_expeditions.py | tools/ | Manual | no | Baja |
| F43 | gen_expeditions_mod.py | tools/ | Manual | no | Baja |
| F44 | gen_ranged_list.py | tools/ | Manual | no | Media (la app podría generar la lista) |
| F45 | upcount.py | tools/ | Manual | no | No |

\* Los AHK no actúan en el juego si todo va bien. **Si la consola ya estaba abierta, la línea se dice en el chat.**

**Total: 45 funciones.**

---

## 12. Globales que el mod deja a la vista (para que la app las lea o las controle)

**Importante**: hoy **no hay ningún canal de la app al mod**. La app (`analisis/eloria.py`) solo lee archivos. Para que pueda controlar algo, el mod tendría que leer, por ejemplo, un `/mods_zalo/orden.txt` cada segundo, o escribir su estado en un archivo. Además, el estado de la expedición (`ST`, la etapa, el nodo, el cristal), `BOSS`, `FG` y `HX.E` son `local` y **no se ven** desde fuera.

### Del mod (`expediciones.lua`)

| Global | Tipo | Qué es |
|---|---|---|
| `ExpMod` | tabla (= `EXP`) | `ExpMod.toggle()` (ON/OFF expediciones), `ExpMod.stop(reloading)` (quita el mod), `ExpMod.box` (panel: hijos 1 a 5 = título, paso, mapa, oleada, estado), `.events`, `.conns`, `.text` (manejadores de texto), `.modalTitle`, `.modalButtons`, `.onMain`, `.dragged`, `.lastErr` |
| `ExpModWD`, `ExpModWDAt` | evento, número | Vigilante de recarga y hora de la última recarga |
| `ExpModPos` | `{x,y}` | Posición del panel |
| `ExpModSel` | número | 0 = Auto; 1 a 3 = Single (Venomfen, Prismheart, Cinderfall) |
| `ExpModDaily` | `[pj] = {day, baseXp, lastXp, raw, active, lastGain, tickAt}` | XP del día |
| `ExpModBuffs`, `ExpModBuffsLoaded` | `[pj][buff] = segundos` | Buffs activos |
| `ExpModResDiag` | número | Última escritura de `res_<pj>.txt` |
| `ExpModSeen` | `[bicho] = {lv={}, far, near}` | Registro de monstruos |
| `ExpModOpen` | `[sección] = bool` | Secciones abiertas |
| `ExpModBossCat`, `ExpModBossWave` | números | Configuración de Boss Run (el estado `BOSS` no es global) |
| `ExpModFish` | `[i] = bool` | Modos de pesca encendidos (se pueden cambiar desde fuera; el bucle los lee) |
| `ExpModBT` | tabla | Progreso de Bosstiary: `index`, `room`, `stage`, `cycles`… |
| `ExpModAX` | `{on}` | Auto-EXP encendido |
| `ExpModAXCfg` | `[pj] = {lv, stage}` | Configuración de Auto-EXP |
| `ExpModHunt` | texto o nil | Caza del cavebot activa (nombre de `HUNTS`) |
| `ExpModHuntCtl(name, on)` | función | Carga y enciende, o apaga, una caza del cavebot de EloriaBot. Devuelve `ok, mensaje`. **Actúa.** |
| `ExpModForge` | `{conv, sliver, item, start, target}` | Configuración de la forja (`sliver=true` enciende el auto sliver desde fuera) |
| `ExpModBuy` | `{name, amount}` | Configuración de la compra |
| `VigEmbark`, `VigModalOn` | (antiguos) | El mod los pone a nil |

### Del recolector (`zalo_datos.lua`)

| Global | Qué es |
|---|---|
| `ZaloDatos` | `.stop(reloading)`, `.flush()`, `.emit(ev, datos)` (añadir un evento propio al `.jsonl`), `.enc(v)` (JSON), `.file` (archivo actual), `.lines`, `.acc` (lo acumulado desde el último tick: raw, xp, kills, dmgIn, src, dmgOut, imp), `.char`, `.dead`, `.DIR`, `.TICK_MS`, `.CHUNK_S`, `.VERSION` |

### De `xp_logger.lua` (antiguo)

| Global | Qué es |
|---|---|
| `ZX` | `.f` (archivo), `.t` (inicio), `.r` (raw acumulado), `.x` (XP final), `.k` (kills), `.l` (líneas), `.ev`, `.cb` |

### Funciones del cliente y de EloriaBot de las que depende el mod

Si cambian, se rompe la pieza indicada.

- `modules.game_eternum_crystals.setExpeditionCrystalSite` (F05)
- `modules.game_expedition.previousCycle` (F12)
- ventana `expeditionWindow`, con los hijos `maps`, `selected`, `embark`, `paymentButton`, `trail`, `heading` y `cycleLabel` (F03, F12)
- `modules.game_helper.cavebot` con `toggle`, `isEnabled`, `selectCategory`, `loadSession`, `getStatus`, `getCurrentIndex` y `getWaypoints` (F01, F14, F35)
- `modules.game_helper._Helper.ScriptingActions.bossSequenceStart` (F31)
- ventana `helperWindow` con su campo `sessionName` (F35)
- ventana `strengthForgeWindow` (F38)
- `g_game.sendForgeFusion` (F36)
- eventos `g_game`: `onUpdateExperience(raw, final)`, `onImpactTracker(tipo, cantidad, elemento, origen)`, `onModalDialog`, `onTextMessage`, `onTalk`, `onGameStart` y `onGameEnd`
