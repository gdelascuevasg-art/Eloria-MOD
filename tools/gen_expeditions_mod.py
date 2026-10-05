# Genera el MOD de expediciones (consola Ctrl+T, entorno completo del cliente)
# a partir de ../eloria_expeditions.lua (que genera gen_expeditions.py).
#
#   python gen_expeditions.py       -> eloria_expeditions.lua (EloriaBot)
#   python gen_expeditions_mod.py   -> mods_zalo/expediciones/expediciones.lua (mod)
#
# El mod = capa de compatibilidad (misma API que EloriaBot, hecha con g_game/g_map/g_ui)
#        + el MISMO codigo del script de EloriaBot (sin tocar)
#        + el vigilante de consola (panel -> Begin, posicion del cristal).
import os

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, '..', 'eloria_expeditions.lua')
# Se carga desde la consola (Ctrl+T). La prueba de modulo con autoload
# (mods/zalo_expediciones + .otmod) se revirtio el 29/09: copia en tools/_backup_mod_autoload/.
OUTDIR = os.path.join(HERE, '..', 'mods_zalo', 'expediciones')
OUT = os.path.join(OUTDIR, 'expediciones.lua')

src = open(SRC, encoding='utf-8').read()
# quitar la cabecera --[[ ... ]] del script de EloriaBot (la del mod la sustituye)
assert src.startswith('--[[')
body = src[src.index(']]') + 2:].lstrip('\n')
last = 'print("[Expeditions] cargado ("..#ROUTES.." rutas). Click en el titulo del HUD para ON/OFF.")'
assert body.rstrip().endswith(last)
body = body.rstrip()[:-len(last)].rstrip() + '\n'

# Panel del mod mas simple (solo en el mod; el script de EloriaBot no cambia):
# sin la fila de pasos, "Mapa: <mapa>" en vez de la ruta, y solo la oleada del cristal.
MOD_UI = [
    ('local hudRoute  = row(38, "Ruta: -", COL.muted)', 'local hudRoute  = row(38, "Mapa: -", COL.muted)'),
    ('local hudXtal   = row(56, "Cristal: -", COL.muted)', 'local hudXtal   = row(56, "Oleada: -", COL.muted)'),
    ('''    setTxt(hudXtal, string.format("Cristal: %d,%d,%d  fase %d  clicks %d/4%s",
      X.x, X.y, X.z, X.phase, ST.clicks, X.cleared and "  (roto)" or ""))''',
     '''    setTxt(hudXtal, X.cleared and "Oleada: cristal destruido"
      or X.phase == 0 and "Oleada: cristal dormido" or string.format("Oleada %d/3", X.phase))'''),
    ('setTxt(hudRoute, "Ruta: -"); paint(hudRoute, COL.muted)', 'setTxt(hudRoute, "Mapa: -"); paint(hudRoute, COL.muted)'),
    ('setTxt(hudXtal, "Cristal: -"); paint(hudXtal, COL.muted)', 'setTxt(hudXtal, "Oleada: -"); paint(hudXtal, COL.muted)'),
    ('setTxt(hudRoute, "Ruta: "..r.name.."  ("..r.map..")")', 'setTxt(hudRoute, "Mapa: "..r.map)'),
]
for a, b in MOD_UI:
    assert body.count(a) == 1, a
    body = body.replace(a, b)
body += 'hudStep:hide()  -- mod: sin la fila de pasos\n'

# ---- Bosstiary y Mining: codigo ORIGINAL de "Eloria HUD.lua" (de Slandish) ----
# Se extraen dos trozos tal cual: utilidades (E, step, route, go, findItem, modales...)
# y desde BOSSTIARY_ENTRIES hasta mineTick/E.onText. Solo se traducen los mensajes.
HUDSRC = open(os.path.join(HERE, '..', 'Eloria HUD.lua'), encoding='utf-8').read().replace('\r\n', '\n')
def cut(a, b):
    i, j = HUDSRC.index(a), HUDSRC.index(b)
    assert i < j
    return HUDSRC[i:j]
HUD_A = cut('local CONFIG={', '-- Dungeon module transplanted')
HUD_B = cut('local BOSSTIARY_ENTRIES = {', 'local function fishingTick()')
for a, b in [
    ("' / pokoj '..b.room)", "' / sala '..b.room)"),
    ("'Bosstiary: brak dostepnej trasy do '..(target.name or 'wyjscia')", "'Bosstiary: sin camino a '..(target.name or 'la salida')"),
    ("' / walka'", "' / pelea'"),
    ("'Bosstiary: powrot przez wyjscie 22761'", "'Bosstiary: vuelta por la salida 22761'"),
    ("'Bosstiary: szukam wyjscia 22761'", "'Bosstiary: busco la salida 22761'"),
    ("'Bosstiary: podejdz do sali wejsc na poziomie '", "'Bosstiary: ve a la sala de entradas, piso '"),
    ("' / czekam na pokoje'", "' / espero las salas'"),
    ("'Bosstiary: ide do '", "'Bosstiary: voy a '"),
    ("'Mining: pietro '..p.z..' / szukam skal'", "'Mining: piso '..p.z..' / busco rocas'"),
    ("'Mining: brak kilofa 19249'", "'Mining: sin pico 19249'"),
    ("'Mining: skala nie przyjmuje kilofa, szukam kolejnej'", "'Mining: la roca no acepta el pico, busco otra'"),
    ("'Mining: kilof '", "'Mining: pico '"),
    ("'Mining: szukam kolejnych skal'", "'Mining: busco mas rocas'"),
    ("'Mining: brak dostepnej trasy'", "'Mining: sin camino'"),
]:
    assert a in HUD_B, a
    HUD_B = HUD_B.replace(a, b)

HEAD = r'''--[[
expediciones.lua  (MOD para la consola del cliente, Ctrl+T)
------------------------------------------------------------
Hace lo mismo que eloria_expeditions.lua (EloriaBot) + el vigilante de la
consola, todo en un archivo y en el entorno completo del cliente.

CARGAR (una linea en Ctrl+T; volver a pegarla = recargar):
  local f,e=loadstring(g_resources.readFileContents("/mods_zalo/expediciones/expediciones.lua"),"@expediciones") if f then f() else print(e) end
PARAR / QUITAR:  ExpMod.stop()
ON / OFF:        click en el titulo del panel, o ExpMod.toggle()
MAPAS:           boton Auto = bucle | boton Single = solo el mapa marcado; click en un mapa = elegirlo

ANTES DE USARLO: quitar eloria_expeditions.lua de EloriaBot > Scripting y
no pegar el vigilante antiguo (el mod ya lo lleva y apaga el viejo si esta).
El cavebot de EloriaBot hay que apagarlo a mano (el mod no puede tocarlo).

GENERADO por tools/gen_expeditions_mod.py a partir de eloria_expeditions.lua:
no editar a mano; cambiar gen_expeditions.py / este generador y regenerar.
]]

-- ================== Mod: arranque limpio ==================
if ExpMod and ExpMod.stop then pcall(ExpMod.stop, true) end
local EXP = {events={}, conns={}, text={}, lastErr=0}
ExpMod = EXP

-- Vigilante de recarga: al morir el cliente reinicia la interfaz y el panel
-- desaparece (el Lua sigue vivo). Cada 3 s: conectado y sin panel -> recargar
-- este archivo (como mucho una vez cada 15 s). Solo lo quita ExpMod.stop().
if ExpModWD then removeEvent(ExpModWD) end
ExpModWD = cycleEvent(function() pcall(function()
  if not g_game.isOnline() then return end
  local r = g_ui.getRootWidget()
  if r and r:getChildById("expModPanel") then return end
  if os.time() - (ExpModWDAt or 0) < 15 then return end
  ExpModWDAt = os.time()
  print("[ExpMod] la interfaz se ha reiniciado: recargo el mod")
  local f, e = loadstring(g_resources.readFileContents("/mods_zalo/expediciones/expediciones.lua"), "@expediciones")
  if f then f() else print(e) end
end) end, 3000)

-- Recolector de datos del programa de analisis (mods_zalo/datos/zalo_datos.lua):
-- se carga y se recarga con el mod. Si no esta o falla, el mod sigue igual.
pcall(function()
  local f, e = loadstring(g_resources.readFileContents("/mods_zalo/datos/zalo_datos.lua"), "@zalo_datos")
  if f then f() else print("[Datos] "..tostring(e)) end
end)

-- Apagar el vigilante antiguo de consola si estaba puesto.
if VigEmbark then removeEvent(VigEmbark); VigEmbark = nil end
if VigModalOn then disconnect(g_game, {onModalDialog=VigModalOn}); VigModalOn = nil end

local function report(err)
  if g_clock.millis() - EXP.lastErr > 5000 then
    EXP.lastErr = g_clock.millis()
    print("[ExpMod] error: "..tostring(err))
  end
end
local function every(fn, ms)
  local e = cycleEvent(function() local ok, err = pcall(fn); if not ok then report(err) end end, ms)
  EXP.events[#EXP.events+1] = e
  return e
end
local function hook(sig, fn)
  connect(g_game, {[sig]=fn})
  EXP.conns[#EXP.conns+1] = {[sig]=fn}
end
local function me() return g_game.getLocalPlayer() end
local function hex(r, g, b, a)
  return a and string.format("#%02x%02x%02x%02x", r, g, b, a) or string.format("#%02x%02x%02x", r, g, b)
end

-- ================== Mod: panel (sustituye al HUD de EloriaBot) ==================
-- Un panel arrastrable con las filas una debajo de otra.
local box = g_ui.createWidget("UIWidget", g_ui.getRootWidget())
EXP.box = box
box:setId("expModPanel")
box:setWidth(200)
box:setPadding(6)
box:setBackgroundColor("#0f151ff0")
box:setBorderWidth(1); box:setBorderColor("#a8854a")
local lay = UIVerticalLayout.create(box); lay:setFitChildren(true); box:setLayout(lay)
-- Posicion: la ultima donde lo dejaste (se conserva al recargar el mod).
if ExpModPos then
  box:setPosition(ExpModPos)
else
  local mp = modules.game_interface and modules.game_interface.getMapPanel and modules.game_interface.getMapPanel()
  local b = mp and mp:getPosition() or {x=0, y=0}
  box:setPosition({x=b.x+10, y=b.y+52})
end
-- Arrastrar: desde el panel o desde cualquier fila (titulo, mapas...). Tras
-- arrastrar no cuenta como click (para no encender/apagar sin querer).
local function dragHandle(w)
  w:setDraggable(true)
  w.onDragEnter = function(_, mp) EXP.dOff = {x=mp.x-box:getX(), y=mp.y-box:getY()}; return true end
  w.onDragMove = function(_, mp)
    EXP.dragged = true
    ExpModPos = {x=mp.x-EXP.dOff.x, y=mp.y-EXP.dOff.y}
    box:setPosition(ExpModPos)
    return true
  end
  w.onDragLeave = function() scheduleEvent(function() EXP.dragged = false end, 50); return true end
end
dragHandle(box)
local function click(fn)
  return function() if EXP.dragged then return true end; fn(); return true end
end

local HUDN = 0
local function hudObj(w)
  HUDN = HUDN + 1
  local o, id = {}, HUDN
  function o:getId() return id end
  function o:setText(t) w:setText(t) end
  function o:setColor(r, g, b) w:setColor(hex(r, g, b)) end
  function o:setFontSize(n) if n and n >= 11 then w:setHeight(19) end end
  function o:setCallback(fn) w:setPhantom(false); dragHandle(w); w.onClick = click(function() fn(id) end) end
  function o:setBackgroundColor(r, g, b) w:setBackgroundColor(hex(r, g, b, 240)) end
  function o:setBorderColor(r, g, b) w:setBorderColor(hex(r, g, b)) end
  function o:setBorderWidth(n) w:setBorderWidth(n) end
  function o:setOpacity(f) end
  function o:setZIndex() end
  function o:setDraggable() end
  function o:setPos() end
  function o:show() w:show() end
  function o:hide() w:hide() end
  return o
end
local HUD = setmetatable({
  newPanel = function() return hudObj(box) end,
}, {__call = function(_, x, y, text)
  local w = g_ui.createWidget("UIWidget", box)
  w:setHeight(16); w:setTextAlign(AlignLeft); w:setPhantom(true)
  pcall(function() w:setFont("verdana-11px-rounded") end)
  w:setText(tostring(text))
  return hudObj(w)
end})

-- ================== Mod: API de EloriaBot hecha con el cliente ==================
local Enums = {TalkTypes={SAY=1}}
local Client = {isConnected=function() return g_game.isOnline() end}
-- Cavebot de EloriaBot: modules.game_helper.cavebot (visto con el diagnostico).
local function ebCavebot() return modules.game_helper and modules.game_helper.cavebot end
local Engine = {enableCaveBot=function(on)
  local C = ebCavebot()
  if C and C.toggle and C.isEnabled and (C.isEnabled() and true or false) ~= (on and true or false) then pcall(C.toggle, on) end
end}
local Player = {
  getPosition=function() local p = me(); return p and p:getPosition() end,
  getId=function() local p = me(); return p and p:getId() or 0 end,
}
local function tileAt(x, y, z) return g_map.getTile({x=x, y=y, z=z}) end
local Map = {
  -- Map click. El autoWalk del cliente esquiva los campos (fire field); aqui el
  -- camino se calcula permitiendo pisarlos (suelo normal). Si no sale, autoWalk normal.
  goTo=function(x, y, z)
    local p = me()
    if not p then return false end
    local from, to = p:getPosition(), {x=x, y=y, z=z}
    local flags = (PathFindAllowNotSeenTiles or 1) + (PathFindAllowNonPathable or 4)
    local ok, dirs = pcall(g_map.findPath, from, to, 5000, flags)
    if ok and type(dirs) == "table" and #dirs > 0 then
      if pcall(g_game.autoWalk, dirs, from) or pcall(g_game.autoWalk, dirs) then return true end
    end
    p:autoWalk(to)
    return true
  end,
  isTileWalkable=function(x, y, z, _, _, ignoreMobs)
    local t = tileAt(x, y, z)
    return t ~= nil and t:isWalkable(ignoreMobs and true or false)
  end,
  getAllPositionsWithTopItemId=function(id)
    local out, p = {}, Player.getPosition()
    if not p then return out end
    for dx = -8, 8 do for dy = -6, 6 do
      local t = tileAt(p.x+dx, p.y+dy, p.z)
      if t then
        for _,it in ipairs(t:getItems() or {}) do
          if it:getId() == id then out[#out+1] = {x=p.x+dx, y=p.y+dy, z=p.z}; break end
        end
      end
    end end
    return out
  end,
  getCreatures=function()
    local out, p = {}, Player.getPosition()
    if not p then return out end
    for _,c in ipairs(g_map.getSpectators(p, false)) do
      out[#out+1] = {position=c:getPosition(), isMonster=c:isMonster()}
    end
    return out
  end,
}
local Game = {Events={TEXT_MESSAGE=4, MODAL_WINDOW=5, HUD_DRAG=15}}
function Game.talk(msg) g_game.talk(msg); return true end
function Game.walk(d) return g_game.walk(d) end
function Game.useItemFromGround(x, y, z)
  local t = tileAt(x, y, z)
  local th = t and t:getTopUseThing()
  if not th then return false end
  g_game.use(th)
  return true
end
-- Responder un modal. El cliente deja la ventana abierta si solo se manda la
-- respuesta, asi que se pulsa el boton de la propia ventana (responde y la cierra);
-- si no se encuentra la ventana, se manda la respuesta y ya.
local function findByText(w, low)
  for _,c in ipairs(w:getChildren()) do
    if (c:getText() or ""):lower() == low then return c end
    local f = findByText(c, low)
    if f then return f end
  end
end
function Game.modalWindowAnswer(id, button, choice)
  local title, btn = (EXP.modalTitle or ""):lower(), (EXP.modalButtons or {})[button]
  if choice and choice ~= 0 then
    -- Con una opcion elegida (salas de Bosstiary) no vale pulsar el boton de la
    -- ventana (mandaria la opcion marcada en ella): se responde y se cierra.
    g_game.answerModalDialog(id, button, choice)
    scheduleEvent(function() pcall(function()
      for _,win in ipairs(g_ui.getRootWidget():getChildren()) do
        if title ~= "" and win:isVisible() and (win:getText() or ""):lower() == title then win:destroy(); return end
      end
    end) end, 100)
    return true
  end
  scheduleEvent(function() pcall(function()
    for _,win in ipairs(g_ui.getRootWidget():getChildren()) do
      if title ~= "" and win:isVisible() and (win:getText() or ""):lower() == title then
        local b = btn and findByText(win, btn:lower())
        if b then b:onClick() else g_game.answerModalDialog(id, button, choice or 0); win:destroy() end
        return
      end
    end
    g_game.answerModalDialog(id, button, choice or 0)
  end) end, 100)
  return true
end
function Game.registerEvent(ev, fn)
  if ev == Game.Events.TEXT_MESSAGE then
    EXP.text[#EXP.text+1] = fn
    hook("onTextMessage", function(mode, text)
      local ok, err = pcall(fn, {messageType=mode, text=text}); if not ok then report(err) end
    end)
  elseif ev == Game.Events.MODAL_WINDOW then
    hook("onModalDialog", function(id, title, message, buttons)
      local bs = {}
      EXP.modalTitle, EXP.modalButtons = title, {}
      for _,b in ipairs(buttons or {}) do bs[#bs+1] = {id=b[1], text=b[2]}; EXP.modalButtons[b[1]] = b[2] end
      local ok, err = pcall(fn, {id=id, title=title, message=message, buttons=bs}); if not ok then report(err) end
    end)
  end
  -- HUD_DRAG: el panel del mod se arrastra solo
end
local function Timer(name, fn, ms) return every(fn, ms) end

-- ============================================================================
-- A partir de aqui: el MISMO codigo que eloria_expeditions.lua (EloriaBot)
-- ============================================================================
'''

TAIL = r'''
-- ============================================================================
-- Mod: vigilante (antes, las 6 lineas de la consola)
-- ============================================================================
-- Bucle de mapas: Venomfen -> Prismheart -> Cinderfall
local VL, VI, VO = {"venomfen", "prismheart", "cinderfall"}, 1, nil
-- Modo: 0 = bucle automatico; 1..3 = solo ese mapa (se conserva al recargar el mod)
ExpModSel = ExpModSel or 0
if ExpModSel > 0 then VI = ExpModSel end
local paintMaps  -- (seccion "Mapas", mas abajo)

-- Elegir en el panel la tarjeta del mapa que toca.
local function vigPick(w)
  for _,c in ipairs(w:recursiveGetChildById("maps"):getChildren()) do
    if c:recursiveGetChildById("name"):getText():lower():find(VL[VI], 1, true) then c:onClick() end
  end
end
local function notEnough(b) return b:getText():lower():find("not enough", 1, true) end
local function vigBegin(b, m)
  b:onClick()
  if ExpModSel == 0 then VI = VI % #VL + 1 end
  print("[Vigilante] Begin en "..m..", siguiente: "..VL[VI]..(ExpModSel == 0 and "" or " (solo este mapa)"))
  pcall(paintMaps)
end
-- Sin fondos con un modo de pago: probar el otro; si tampoco, dejarlo como estaba.
local function vigSwapPay(b, pb, m)
  pb:onClick()
  scheduleEvent(function() pcall(function()
    if notEnough(b) then pb:onClick(); print("[Vigilante] sin fondos: "..b:getText())
    else print("[Vigilante] "..pb:getText()); vigBegin(b, m) end
  end) end, 500)
end
-- Comprobar destino y pago, y pulsar Begin.
local function vigGo(w)
  local m = VL[VI]
  if not w:recursiveGetChildById("selected"):getText():lower():find(m, 1, true) then
    print("[Vigilante] destino mal, NO Begin"); return
  end
  local b, pb = w:recursiveGetChildById("embark"), w:recursiveGetChildById("paymentButton")
  if notEnough(b) then vigSwapPay(b, pb, m) else vigBegin(b, m) end
end
-- Cada 500 ms: si se abre el panel de expediciones, elegir mapa y Begin (una vez por
-- apertura). SOLO con las expediciones en ON: en OFF puedes abrirlo y usarlo a mano.
every(function()
  local w = g_ui.getRootWidget():getChildById("expeditionWindow")
  if not (w and w:isVisible()) then VO = nil
  elseif not VO and ST.stage ~= "off" and not (ExpModAX and ExpModAX.on) then
    VO = 1
    scheduleEvent(function()
      if ST.stage == "off" then return end
      pcall(vigPick, w)
      scheduleEvent(function() if ST.stage ~= "off" then pcall(vigGo, w) end end, 400)
    end, 1000)
  end
end, 500)

-- Posicion y fase del cristal: el cliente la recibe cada 2 s; se pasa al codigo
-- de arriba como el mensaje "XTAL x y z fase cleared token" (solo si cambia, o cada 60 s).
-- Se engancha cuando el modulo del cristal ya existe (al arrancar el cliente
-- puede cargarse despues que este mod).
local XM, XO
local VX, VT = nil, 0
local function hookCrystal()
  local m = modules.game_eternum_crystals
  if XM or not (m and m.setExpeditionCrystalSite) then return end
  XM = m
  XO = XM._osetExpeditionCrystalSite or XM.setExpeditionCrystalSite
  XM._osetExpeditionCrystalSite = XO
  XM.setExpeditionCrystalSite = function(a, ...)
    pcall(function()
      if ExpModAX and ExpModAX.on then return end  -- Auto-EXP: sin cristal
      local p = a.position
      local s = "XTAL "..p.x.." "..p.y.." "..p.z.." "..a.phase.." "..tostring(a.cleared).." "..tostring(a.token)
      if s ~= VX or os.time() - VT >= 60 then
        VX, VT = s, os.time()
        for _,fn in ipairs(EXP.text) do pcall(fn, {messageType=18, text=s}) end
      end
    end)
    return XO(a, ...)
  end
end
hookCrystal()
every(hookCrystal, 2000)

-- El panel solo se ve dentro del juego (al arrancar el cliente estas en el login).
local function showBox() if EXP.box then EXP.box:setVisible(g_game.isOnline()) end end
hook("onGameStart", function() scheduleEvent(showBox, 500) end)
hook("onGameEnd", showBox)
showBox()

-- ============================================================================
-- Mod: mapas (gema + nombre). Click = modo.
-- ============================================================================
-- Mismo orden que VL. Gemas vistas en las tarjetas del panel de expediciones.
local MAPS = {
  {name="Venomfen Hollows",   gem=63663, gemName="Wildroot"},
  {name="Prismheart Caverns", gem=63664, gemName="Tidevein"},
  {name="Cinderfall Abyss",   gem=63662, gemName="Emberheart"},
}
local function mkText(parent, w, text)
  local t = g_ui.createWidget("UIWidget", parent)
  t:setWidth(w); t:setHeight(22); t:setPhantom(true)
  t:setTextAlign(AlignLeftCenter or AlignLeft)
  pcall(function() t:setFont("verdana-11px-rounded") end)
  t:setText(text)
  return t
end
local function mkRow(h, spacing)
  local r = g_ui.createWidget("UIWidget", box)
  r:setHeight(h); r:setPhantom(false); dragHandle(r)
  local l = UIHorizontalLayout.create(r); l:setSpacing(spacing or 6); r:setLayout(l)
  return r
end
-- Separador: linea fina dorada entre bloques.
local function sepLine()
  local w = g_ui.createWidget("UIWidget", box)
  w:setHeight(1); w:setWidth(188); w:setPhantom(true)
  w:setMarginTop(5); w:setMarginBottom(5)
  w:setBackgroundColor("#a8854a90")
  return w
end
local function mkButton(parent, text, w, fn)
  local ok, b = pcall(g_ui.createWidget, "Button", parent)
  if not ok or not b then
    b = g_ui.createWidget("UIWidget", parent)
    b:setBorderWidth(1); b:setBorderColor("#a8854a"); b:setTextAlign(AlignCenter)
  end
  b:setWidth(w); b:setHeight(20); b:setText(text)
  b.onClick = function() fn(); return true end
  return b
end

local showPage  -- (pantallas, al final)

sepLine()  -- estado | mapas
local mapsHdr = mkRow(20)
local sep = mkText(mapsHdr, 188, "Mapas"); sep:setHeight(20); sep:setColor("#e1bb70")

for i, m in ipairs(MAPS) do
  local r = mkRow(26)
  local it = g_ui.createWidget("UIItem", r)
  it:setSize({width=24, height=24}); it:setVirtual(true); it:setPhantom(true); it:setItemId(m.gem)
  m.lbl = mkText(r, 150, m.name)
  r.onClick = click(function()
    VI = i
    if ExpModSel ~= 0 then ExpModSel = i end
    paintMaps()
  end)
end

-- Debajo de los mapas: fila "[Auto] [Single]" y debajo de Auto "[EXP]"; luego
-- la caza de EXP en marcha (verde) y la experiencia ganada.
--   Auto   = bucle Venomfen -> Prismheart -> Cinderfall; click en un mapa = el siguiente del bucle
--   Single = solo el mapa marcado, una y otra vez; click en un mapa = cambiar a ese
--   EXP    = cambia a la pantalla EXP (cazas con el cavebot de EloriaBot; "Volver" regresa)
local modeRow = mkRow(22, 4)
local btnAuto = mkButton(modeRow, "Auto", 56, function() ExpModSel = 0; paintMaps() end)
local btnSingle = mkButton(modeRow, "Single", 60, function() if ExpModSel == 0 then ExpModSel = VI end; paintMaps() end)
local forgeRow = mkRow(22, 4)  -- Forja encima de EXP
mkButton(forgeRow, "Forge", 56, function() showPage("forge") end)
local expRow = mkRow(22, 4)  -- EXP debajo de Auto
mkButton(expRow, "EXP", 56, function() showPage("exp") end)

-- Caza de la pantalla EXP que este en marcha: su nombre en verde (solo si hay una).
local huntRow = mkRow(18)
local huntTxt = mkText(huntRow, 188, ""); huntTxt:setHeight(18); huntTxt:setColor("#6ee09f")
huntRow:setVisible(false)

-- XP Gain / RAW/h / XP/h (XP Gain de tu Script 1 de EloriaBot):
-- - XP Gain: experiencia ganada desde el ultimo server save (04:00) o el [Reset].
-- - RAW/h y XP/h: experiencia BASE (sin bonus) y final por hora de TIEMPO CAZANDO:
--   el reloj solo avanza si has ganado experiencia en los ultimos ACTIVE_S segundos
--   (pausas, ciudad, muertes, la noche... no cuentan). La base se suma kill a kill
--   (onUpdateExperience(raw, final)).
-- [Reset] pone todo a cero para medir una caza concreta. Se guarda por personaje
-- mientras el cliente siga abierto; todo vuelve a cero en el server save.
local SERVER_SAVE_HOUR = 4
local ACTIVE_S = 120
ExpModDaily = ExpModDaily or {}
local function shortNum(n)
  n = tonumber(n) or 0
  if math.abs(n) >= 1000000000 then return string.format("%.2fkkk", n/1000000000) end
  if math.abs(n) >= 1000000 then return string.format("%.2fkk", n/1000000) end
  if math.abs(n) >= 1000 then return string.format("%.1fk", n/1000) end
  return string.format("%.0f", n)
end
local function serverDay() return os.date("%Y-%m-%d", os.time() - SERVER_SAVE_HOUR * 3600) end
local function resetDaily(d, xp)
  d.baseXp, d.lastXp, d.raw, d.active, d.lastGain, d.tickAt = xp, xp, 0, 0, nil, nil
end
-- Datos del dia del personaje (se reinician al cambiar de dia de servidor).
local function dailyOf(name, xp)
  local d = ExpModDaily[name] or {}
  ExpModDaily[name] = d
  local today = serverDay()
  -- (d.active == nil: datos de una version anterior del mod -> empezar de cero)
  if d.day ~= today or (xp and (d.baseXp == nil or d.active == nil)) then
    d.day = today
    resetDaily(d, xp)
  end
  d.raw, d.active = d.raw or 0, d.active or 0
  return d
end
local xr = mkRow(18, 4); local xpRow = mkText(xr, 132, "XP Gain: --"); xpRow:setHeight(18)
mkButton(xr, "Reset", 50, function()
  local p = me()
  if not p then return end
  resetDaily(dailyOf(p:getName(), tonumber(p:getExperience())), tonumber(p:getExperience()))
end)
local wr = mkRow(18); local rawRateRow = mkText(wr, 188, "RAW/h: --"); rawRateRow:setHeight(18)
local rr = mkRow(18); local xpRateRow = mkText(rr, 188, "XP/h: --"); xpRateRow:setHeight(18)
hook("onUpdateExperience", function(raw)
  local p = me()
  if not p then return end
  local d = dailyOf(p:getName(), tonumber(p:getExperience()))
  d.raw = d.raw + (tonumber(raw) or 0)
  d.lastGain = os.time()
end)
every(function()
  local p = me()
  if not (p and g_game.isOnline()) then
    xpRow:setColor("#a2b1c1"); rawRateRow:setColor("#a2b1c1"); xpRateRow:setColor("#a2b1c1")
    return
  end
  local xp = tonumber(p:getExperience())
  if not xp then return end
  local d = dailyOf(p:getName(), xp)
  local now = os.time()
  if d.lastXp and xp > d.lastXp then d.lastGain = now end
  d.lastXp = xp
  -- reloj de caza: solo suma si hubo experiencia hace poco
  if d.tickAt and d.lastGain and now - d.lastGain <= ACTIVE_S then
    d.active = d.active + math.min(5, now - d.tickAt)
  end
  d.tickAt = now
  local gain = xp - d.baseXp
  local hours = math.max(1 / 60, d.active / 3600)  -- (minimo 1 min para no disparar)
  xpRow:setText("XP Gain: "..shortNum(gain)); xpRow:setColor(gain < 0 and "#ffd43b" or "#eef2f7")
  rawRateRow:setText("RAW/h: "..(d.active > 0 and shortNum(d.raw / hours) or "--")); rawRateRow:setColor("#eef2f7")
  xpRateRow:setText("XP/h: "..(d.active > 0 and shortNum(gain / hours) or "--")); xpRateRow:setColor("#eef2f7")
end, 1000)



-- ============================================================================
-- Mod: POCIONES (amplification / resilience / charm upgrade...). Al tomarla el
-- servidor dice "You have activated fire amplification. It will last for 60
-- minutes while you are online." -> fila con su icono y el tiempo que queda.
-- Solo descuenta estando online (como el juego). Se guarda en
-- /mods_zalo/buffs_<personaje>.txt para que sobreviva a los reinicios del cliente.
-- Verde > 5 min | amarillo <= 5 min | rojo "YA" (1 min) y desaparece.
-- ============================================================================
EXP.onMain = true
do
  -- nombre (como lo dice el mensaje) -> objeto. Ids de Tibia; los de fire/ice/
  -- physical amplification, energy resilience y charm upgrade, vistos en tu bot.
  local BUFF_IDS = {
    ["fire resilience"]=36729, ["ice resilience"]=36730, ["earth resilience"]=36731,
    ["energy resilience"]=36732, ["holy resilience"]=36733, ["death resilience"]=36734,
    ["physical resilience"]=36735,
    ["fire amplification"]=36736, ["ice amplification"]=36737, ["earth amplification"]=36738,
    ["energy amplification"]=36739, ["holy amplification"]=36740, ["death amplification"]=36741,
    ["physical amplification"]=36742,
    ["kooldown-aid"]=36723, ["strike enhancement"]=36724, ["stamina extension"]=36725,
    ["charm upgrade"]=36726, ["wealth duplex"]=36727, ["bestiary betterment"]=36728,
  }
  -- Un archivo por personaje (/mods_zalo/buffs_<nombre>.txt): con varios
  -- clientes abiertos un archivo comun se pisaba con datos viejos de los otros.
  local function fileOf(c) return "/mods_zalo/buffs_"..c..".txt" end
  ExpModBuffs = ExpModBuffs or {}
  ExpModBuffsLoaded = ExpModBuffsLoaded or {}
  local function loadBuffs(c)
    local t = {}
    local ok, txt = pcall(g_resources.readFileContents, fileOf(c))
    if not (ok and txt) then ok, txt = pcall(g_resources.readFileContents, "/mods_zalo/buffs.txt") end
    for line in ((ok and txt) or ""):gmatch("[^\n]+") do
      local cc, n, l = line:match("^(.-)|(.-)|(%-?%d+)$")
      if cc == c then t[n] = tonumber(l) end
    end
    return t
  end
  local function mine()
    local p = me()
    if not p then return nil end
    local c = p:getName()
    if not ExpModBuffsLoaded[c] then
      ExpModBuffsLoaded[c] = true
      if not ExpModBuffs[c] then ExpModBuffs[c] = loadBuffs(c) end
    end
    ExpModBuffs[c] = ExpModBuffs[c] or {}
    return ExpModBuffs[c], c
  end
  local function save()
    local t, c = mine()
    if not t then return end
    local out = {}
    for n, l in pairs(t) do out[#out+1] = c.."|"..n.."|"..math.floor(l) end
    pcall(g_resources.writeFileContents, fileOf(c), table.concat(out, "\n"))
  end

  -- 10 filas preparadas (icono + nombre + tiempo); solo se ven las activas
  local ROWS = {}
  for i = 1, 10 do
    local r = mkRow(18, 4)
    local it = g_ui.createWidget("UIItem", r)
    it:setSize({width=18, height=18}); it:setVirtual(true); it:setPhantom(true)
    local tx = mkText(r, 166, ""); tx:setHeight(18)
    r:setVisible(false)
    ROWS[i] = {r=r, it=it, tx=tx}
  end
  local function fmt(sec)
    sec = math.max(0, math.floor(sec))
    return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
  end
  local function nice(n) return (n:gsub("^%l", string.upper)) end

  -- Mensaje de activacion: se busca en minusculas y con espacios flexibles, en los
  -- mensajes de texto y tambien en el chat (por si llega como mensaje de canal).
  -- Todo mensaje con "activated" se apunta en /mods_zalo/diag_buffs_<personaje>.txt (ultimos 20).
  local seen = {}
  local function onBuffText(text)
    text = tostring(text or "")
    local low = text:lower()
    if not low:find("activated", 1, true) then return end
    seen[#seen+1] = os.date("%H:%M:%S").." "..text
    if #seen > 20 then table.remove(seen, 1) end
    local _, c = mine()
    pcall(g_resources.writeFileContents, "/mods_zalo/diag_buffs_"..(c or "x")..".txt", table.concat(seen, "\n"))
    local n, m, unit = low:match("activated%s+(.-)%.%s*it will last for%s+(%d+)%s*(%a+)")
    if not n then return end
    local secs = tonumber(m) * ((unit:find("^hour") and 3600) or (unit:find("^sec") and 1) or 60)
    local t = mine()
    if not t then return end
    t[n] = secs
    save()
  end
  hook("onTextMessage", function(mode, text) onBuffText(text) end)
  hook("onTalk", function(name, level, mode, text) onBuffText(text) end)

  -- ==================== POCIONES: CONFIGURACION ====================
  -- Aqui se anaden personajes y protecciones nuevas.
  -- POTS_BASE: todos los personajes, siempre que esten cazando.
  -- POTS_DMG:  la amplification de su tipo de dano (segun sus hechizos de ataque).
  local POTS_BASE = {"physical resilience", "charm upgrade", "strike enhancement"}
  local POTS_DMG = {
    Nika = "fire amplification",                -- exevo gran mas flam
    ["Trafalgar Law"] = "ice amplification",    -- exevo gran mas frigo
    Zoro = "physical amplification",            -- exori gran
    Nefertari = "physical amplification",       -- exori mas nia (monk, SIN CONFIRMAR)
  }
  -- POTS_RES: resilience segun el DANO RECIBIDO (como el Input Analyser del
  -- cliente). Suma el dano por elemento de los ultimos RES_WINDOW s y toma la
  -- resilience de todo elemento que pase de RES_MIN (fraccion del dano
  -- mitigable). Drowning, lifedrain, manadrain y curaciones no cuentan.
  -- Codigos del cliente (comprobados con el Input Analyser en Echo Reaper:
  -- 8 = 58% drowning, 1 = 21% fire, 0 = physical, 6 = death).
  local POTS_RES = {[0]="physical resilience", [1]="fire resilience", [2]="earth resilience",
                    [3]="energy resilience", [4]="ice resilience", [5]="holy resilience",
                    [6]="death resilience"}
  local RES_WINDOW, RES_MIN = 300, 0.02
  -- "Cazando" = Auto-EXP en fase cazar, una caza de AUTO_HUNTS encendida, o
  -- algun monstruo en pantalla en los ultimos 60 s (cubre el cavebot de
  -- EloriaBot a pelo). Fuera de caza no gasta pociones.
  local AUTO_HUNTS = {["Eternum Monoliths"]=true, ["EchoMonolith"]=true, ["EchoMonolith 2"]=true,
                      ["Echo Reaper 2"]=true, ["Echo Reaper 2 LINEAL"]=true}
  -- ===================================================================
  -- Toma las que no esten activas, de una en una (2 s entre usos). No mira
  -- cuantas hay: la usa y espera el "You have activated"; si no llega
  -- reintenta a los 30 s, y tras 3 fallos espera 10 min (sin pocion / no
  -- existe). Avisa en la consola cada vez que cambia el motivo.
  -- dano recibido por elemento, en cubos de 10 s
  local dmg = {}
  hook("onImpactTracker", function(ty, amount, element)
    if ty ~= 2 or not POTS_RES[element] then return end
    local k = math.floor(os.time() / 10)
    dmg[k] = dmg[k] or {}
    dmg[k][element] = (dmg[k][element] or 0) + (tonumber(amount) or 0)
  end)
  local lastMob = 0
  local function resPots(p)
    local now, sum, tot = os.time(), {}, 0
    for k, b in pairs(dmg) do
      if k * 10 < now - RES_WINDOW then dmg[k] = nil
      else for e, a in pairs(b) do sum[e] = (sum[e] or 0) + a; tot = tot + a end end
    end
    local out = {}
    for e, a in pairs(sum) do
      if a >= tot * RES_MIN then out[#out+1] = {n=POTS_RES[e], a=a} end
    end
    table.sort(out, function(x, y) return x.a > y.a end)
    if now - (ExpModResDiag or 0) >= 30 then  -- /mods_zalo/res_<personaje>.txt
      ExpModResDiag = now
      local ln = {os.date("%H:%M:%S").." ultimos "..RES_WINDOW.." s, mitigable "..math.floor(tot)}
      for e, a in pairs(sum) do ln[#ln+1] = string.format("%s %.1f%%", POTS_RES[e], a * 100 / tot) end
      pcall(g_resources.writeFileContents, "/mods_zalo/res_"..p:getName()..".txt", table.concat(ln, "\n"))
    end
    for i, x in ipairs(out) do out[i] = x.n end
    local any = false
    local ok, specs = pcall(g_map.getSpectators, p:getPosition(), false)
    for _, c in ipairs((ok and specs) or {}) do if c:isMonster() then any = true; break end end
    return out, any
  end
  local tries, lastUse, lastWhy = {}, 0, nil
  local function why(w)
    if w ~= lastWhy then lastWhy = w; if w then print("[Pociones] "..w) end end
  end
  every(function()
    local p, C = me(), ebCavebot()
    if not (p and g_game.isOnline()) then return end
    local ax = ExpModAX and ExpModAX.on and ST.stage == "cazar"
    local hunt = AUTO_HUNTS[ExpModHunt or ""] and C and C.isEnabled and C.isEnabled()
    local t, now = mine(), os.time()
    if not t or now - lastUse < 2 then return end
    local zone, any = resPots(p)
    if any then lastMob = now end
    if not (ax or hunt or now - lastMob < 60) then return why(nil) end
    why("activas ("..(ax and "Auto-EXP" or hunt and ExpModHunt or "bichos en pantalla")..")")
    local all = {POTS_BASE[1]}
    for _, n in ipairs(zone) do all[#all+1] = n end
    if POTS_DMG[p:getName()] then all[#all+1] = POTS_DMG[p:getName()] end
    for i = 2, #POTS_BASE do all[#all+1] = POTS_BASE[i] end
    for _, n in ipairs(all) do
      local id, tr = BUFF_IDS[n], tries[n] or {n=0, at=0}
      if (t[n] or 0) > 0 then tries[n] = nil
      elseif id and now - tr.at >= (tr.n >= 3 and 600 or 30) then
        if tr.n >= 3 then tr.n = 0 end
        g_game.useInventoryItem(id)
        tries[n] = {n=tr.n + 1, at=now}; lastUse = now
        if tr.n + 1 == 3 then print("[Pociones] "..n..": 3 usos sin confirmar (no tienes?), reintento en 10 min") end
        return
      end
    end
  end, 1000)

  local lastTick, lastSave = os.time(), os.time()
  every(function()
    local now = os.time()
    local dt = math.min(5, now - lastTick)
    lastTick = now
    local t = g_game.isOnline() and mine()
    if t then
      for n, l in pairs(t) do
        l = l - dt
        if l < -60 then t[n] = nil else t[n] = l end
      end
      if now - lastSave >= 30 then lastSave = now; save() end
    end
    -- pintar: activas ordenadas por lo que les queda
    local list = {}
    for n, l in pairs(t or {}) do list[#list+1] = {n=n, l=l} end
    table.sort(list, function(x, y) return x.l < y.l end)
    for i, R in ipairs(ROWS) do
      local b = list[i]
      if b then
        R.it:setItemId(BUFF_IDS[b.n] or 0)
        R.tx:setText(nice(b.n).."  "..(b.l > 0 and fmt(b.l) or "YA"))
        R.tx:setColor(b.l <= 0 and "#ff696f" or (b.l <= 300 and "#ffd43b" or "#6ee09f"))
      end
      if EXP.onMain then R.r:setVisible(b ~= nil) end
    end
  end, 1000)
end


-- ============================================================================
-- Mod: REGISTRO DE MONSTRUOS (para la lista de "Ranged Monster Names").
-- Apunta cada monstruo que ves (nombre sin el "[nivel]" y los niveles vistos) y,
-- cuando te pega, si estaba A DISTANCIA (2+ casillas) o pegado. Se guarda en
-- /mods_zalo/monstruos_vistos.txt:  nombre|niveles|golpes a distancia|golpes pegado
-- ============================================================================
do
  local FILE = "/mods_zalo/monstruos_vistos.txt"
  if not ExpModSeen then
    ExpModSeen = {}
    local ok, txt = pcall(g_resources.readFileContents, FILE)
    for line in ((ok and txt) or ""):gmatch("[^\n]+") do
      local n, lv, far, near = line:match("^(.-)|(.-)|(%d+)|(%d+)$")
      if n then
        local e = {lv={}, far=tonumber(far), near=tonumber(near)}
        for x in lv:gmatch("%d+") do e.lv[tonumber(x)] = true end
        ExpModSeen[n] = e
      end
    end
  end
  local function split(name)
    local low = tostring(name or ""):lower()
    local b, lv = low:match("^(.-)%s*%[(%d+)%]%s*$")
    return b or low, tonumber(lv)
  end
  local function entry(b)
    ExpModSeen[b] = ExpModSeen[b] or {lv={}, far=0, near=0}
    return ExpModSeen[b]
  end
  local dirty = false
  local function save()
    local out = {}
    for n, e in pairs(ExpModSeen) do
      local lv = {}
      for x in pairs(e.lv) do lv[#lv+1] = x end
      table.sort(lv)
      out[#out+1] = n.."|"..table.concat(lv, ",").."|"..e.far.."|"..e.near
    end
    table.sort(out)
    pcall(g_resources.writeFileContents, FILE, table.concat(out, "\n"))
  end
  -- monstruos en pantalla (cada 2 s)
  every(function()
    local p = me()
    if not (p and g_game.isOnline()) then return end
    for _, c in ipairs(g_map.getSpectators(p:getPosition(), false)) do
      if c:isMonster() then
        local b, lv = split(c:getName())
        local e = entry(b)
        if lv and not e.lv[lv] then e.lv[lv] = true; dirty = true end
      end
    end
  end, 2000)
  -- golpe recibido: el monstruo con ese nombre mas cercano, a distancia o pegado
  hook("onImpactTracker", function(ty, amount, element, source)
    if ty ~= 2 or not source or source == "" then return end
    local p = me()
    if not p then return end
    local myPos, b = p:getPosition(), split(source)
    local best
    for _, c in ipairs(g_map.getSpectators(myPos, false)) do
      if c:isMonster() and split(c:getName()) == b then
        local q = c:getPosition()
        local d = math.max(math.abs(q.x - myPos.x), math.abs(q.y - myPos.y))
        if not best or d < best then best = d end
      end
    end
    if not best then return end
    local e = entry(b)
    if best >= 2 then e.far = e.far + 1 else e.near = e.near + 1 end
    dirty = true
  end)
  every(function() if dirty then dirty = false; save() end end, 30000)
end

sepLine()  -- experiencia | secciones

-- Boton del modo activo en verde. Mapas: "> " = el siguiente del bucle (amarillo)
-- | "* " = el unico que se hace en Single (verde)
paintMaps = function()
  btnAuto:setColor(ExpModSel == 0 and "#6ee09f" or "#a2b1c1")
  btnSingle:setColor(ExpModSel ~= 0 and "#6ee09f" or "#a2b1c1")
  for i, m in ipairs(MAPS) do
    local sel, nxt = ExpModSel == i, ExpModSel == 0 and VI == i
    m.lbl:setText((sel and "* " or nxt and "> " or "  ")..m.name)
    m.lbl:setColor(sel and "#6ee09f" or nxt and "#ffd43b" or "#eef2f7")
  end
end
paintMaps()

-- ============================================================================
-- Mod: secciones desplegables (click en la cabecera = abrir / cerrar)
-- ============================================================================
ExpModOpen = ExpModOpen or {}
local function section(key, title)
  local S = {rows={}}
  local hr = mkRow(20)
  local ht = mkText(hr, 188, ""); ht:setHeight(20); ht:setColor("#70cfff")
  local function paintHdr() ht:setText((ExpModOpen[key] and "[-] " or "[+] ")..title) end
  local function showRows() for _,r in ipairs(S.rows) do r:setVisible(ExpModOpen[key] and true or false) end end
  function S.add(text, fn, itemId)  -- itemId: icono delante (opcional)
    local r = mkRow(18, 4)
    if itemId then
      local it = g_ui.createWidget("UIItem", r)
      it:setSize({width=18, height=18}); it:setVirtual(true); it:setPhantom(true); it:setItemId(itemId)
    end
    local t = mkText(r, itemId and 166 or 188, text); t:setHeight(18)
    if fn then r.onClick = click(fn) end
    S.rows[#S.rows+1] = r
    r:setVisible(ExpModOpen[key] and true or false)
    return t
  end
  hr.onClick = click(function() ExpModOpen[key] = not ExpModOpen[key]; showRows(); paintHdr() end)
  paintHdr()
  return S
end

-- Casillas de pantalla con alguno de estos ids (suelo incluido): la mas cercana.
local function findNear(ids, near, radius)
  local p = pos()
  if not p then return nil end
  local best, bestD, bestThing
  for dx = -8, 8 do for dy = -6, 6 do
    local q = {x=p.x+dx, y=p.y+dy, z=p.z}
    if not near or dist(q, near) <= (radius or 99) then
      local t = g_map.getTile(q)
      if t then
        for _,th in ipairs(t:getThings() or {}) do
          if ids[th:getId()] then
            local d = dist(p, q)
            if not bestD or d < bestD then best, bestD, bestThing = q, d, th end
            break
          end
        end
      end
    end
  end end
  return best, bestThing
end

-- ============================================================================
-- Mod: BOSSES (Boss Run, de Eloria HUD.lua)
-- Estatua 46087 -> panel -> secuencia (categoria EASY/MEDIUM/HARD, 1/3/5 bosses)
-- -> teleport -> 4 pasos al norte -> pelea -> vuelta al lobby -> siguiente categoria.
-- Arranque: como el original, con bossSequenceStart(categoria, bosses) de
-- EloriaBot (modules.game_helper._Helper.ScriptingActions); necesita el panel
-- de la estatua abierto: si no arranca, se usa la estatua y se reintenta.
-- ============================================================================
local onlyOne  -- una automatizacion a la vez (expediciones, Boss Run, Bosstiary, Mining)
local CATS = {"EASY", "MEDIUM", "HARD"}
local BOSS = {on=false, cat=ExpModBossCat or 1, wave=ExpModBossWave or 5, stage="IDLE",
  statue={x=31595, y=17406, z=5}, tried={}, rest=0, at=0, useAt=0}
local bs = section("boss", "Bosses")
local paintBoss, bossStatus
local bOn = bs.add("", function()
  BOSS.on = not BOSS.on
  BOSS.stage, BOSS.tried, BOSS.rest = "IDLE", {}, 0
  if BOSS.on then onlyOne("boss") end
  bossStatus(BOSS.on and "ON" or "-")
  paintBoss()
end)
local bCat = bs.add("", function()
  if BOSS.on then return bossStatus("apaga Boss Run antes") end
  BOSS.cat = BOSS.cat % 3 + 1; ExpModBossCat = BOSS.cat; paintBoss()
end)
local bWave = bs.add("", function()
  if BOSS.on then return bossStatus("apaga Boss Run antes") end
  BOSS.wave = ({[1]=3, [3]=5, [5]=1})[BOSS.wave]; ExpModBossWave = BOSS.wave; paintBoss()
end)
local bSt = bs.add("Estado: -")
bSt:setColor("#a2b1c1")
bossStatus = function(s) bSt:setText(s) end
paintBoss = function()
  bOn:setText((BOSS.on and "[ON]  " or "[OFF] ").."Boss Run"); bOn:setColor(BOSS.on and "#6ee09f" or "#ecad71")
  bCat:setText("Categoria: "..CATS[BOSS.cat])
  bWave:setText("Bosses: "..BOSS.wave)
end
paintBoss()

-- Encender las expediciones apaga lo demas.
hudTitle:setCallback(function()
  if ST.stage == "off" then onlyOne("exp") end
  toggle()
end)

local function inLobby(p) return p and p.z == BOSS.statue.z and dist(p, BOSS.statue) <= 10 end
local function nextBoss()
  BOSS.tried[BOSS.cat] = true; BOSS.stage = "IDLE"
  for _ = 1, 3 do
    BOSS.cat = BOSS.cat % 3 + 1
    if not BOSS.tried[BOSS.cat] then paintBoss(); return end
  end
  BOSS.tried, BOSS.rest = {}, g_clock.millis() + 60000
  bossStatus("categorias hechas, pausa 60 s"); paintBoss()
end

-- bossSequenceStart de EloriaBot (true = aceptado).
local function bossStart(cat, wave)
  local H = modules.game_helper
  local SA = H and H._Helper and H._Helper.ScriptingActions
  if not (SA and SA.bossSequenceStart) then return false, "EloriaBot no expone bossSequenceStart" end
  local ok, res = pcall(SA.bossSequenceStart, cat, wave)
  if not ok then return false, tostring(res) end
  return res and true or false
end

every(function()
  if not BOSS.on or not g_game.isOnline() then return end
  local p = pos()
  if not p or g_clock.millis() < BOSS.rest then return end
  local t = g_clock.millis()
  if BOSS.stage == "WAIT_TELEPORT" then
    if (p.z ~= BOSS.origin.z or dist(p, BOSS.origin) > 4) and not inLobby(p) then
      BOSS.stage, BOSS.entry = "ENTRY", {x=p.x, y=p.y, z=p.z}
    elseif t - BOSS.at > 10000 then nextBoss(); bossStatus("no entro, siguiente categoria") end
    return
  end
  if BOSS.stage == "ENTRY" then
    if p.z ~= BOSS.entry.z or inLobby(p) then BOSS.stage = "IDLE"; return end
    if p.y <= BOSS.entry.y - 4 then BOSS.stage = "FIGHT"; bossStatus("pelea"); return end
    if t - BOSS.at > 300 then BOSS.at = t; g_game.walk(0) end
    bossStatus("entrada "..(BOSS.entry.y - p.y).."/4 N")
    return
  end
  if BOSS.stage == "FIGHT" then
    if inLobby(p) then nextBoss() end
    return
  end
  -- IDLE: ir a la estatua y abrir su panel
  if not inLobby(p) then bossStatus("ve a la sala de la estatua"); return end
  local sp = findNear({[46087]=true}, BOSS.statue, 12)
  if sp then BOSS.statue = sp end
  if dist(p, BOSS.statue) > 1 then
    if t - BOSS.at > 1000 then
      BOSS.at = t
      for _,d in ipairs({{0,1},{0,-1},{1,0},{-1,0},{1,1},{-1,1},{1,-1},{-1,-1}}) do
        local q = {x=BOSS.statue.x+d[1], y=BOSS.statue.y+d[2], z=BOSS.statue.z}
        local tl = g_map.getTile(q)
        if tl and tl:isWalkable() then Map.goTo(q.x, q.y, q.z); break end
      end
    end
    bossStatus("voy a la estatua")
    return
  end
  -- junto a la estatua: arrancar la secuencia; si no la acepta, abrir el panel
  if t - BOSS.useAt > 650 then
    BOSS.useAt = t
    local ok, err = bossStart(BOSS.cat, BOSS.wave)
    if ok then
      BOSS.stage, BOSS.origin, BOSS.at = "WAIT_TELEPORT", {x=p.x, y=p.y, z=p.z}, t
      bossStatus("Full / "..BOSS.wave.." - espero teleport")
    else
      if err and not BOSS.errShown then BOSS.errShown = true; print("[Boss] "..err) end
      if t - (BOSS.panelAt or 0) > 1200 then
        BOSS.panelAt = t
        local tl = g_map.getTile(BOSS.statue)
        local th = tl and tl:getTopUseThing()
        if th then g_game.use(th) end
      end
      bossStatus("abriendo el panel")
    end
  end
end, 250)

-- ============================================================================
-- Mod: PESCA (de Eloria HUD.lua): cana 3483 sobre el agua de cada modo activo.
-- Puede ir a la vez que el resto. Un uso cada 700 ms como mucho.
-- ============================================================================
local ROD = 3483
-- ids = agua donde se pesca | fish = icono del pescado (0 = sin confirmar, sin icono)
local FISH = {
  {name="Fish",      ids={4602, 4597, 4599, 4601, 629, 4600, 622}, fish=3578},  -- fish
  {name="Shimmer",   ids={12560}, fish=0},
  {name="Sandfish",  ids={13988}, fish=0},
  {name="Old Nasty", ids={12560}, fish=3578},  -- mismo icono que un fish normal
  {name="Rainbow",   ids={7236},  fish=7158},  -- rainbow trout
  {name="Northern",  ids={7236},  fish=3580},  -- northern pike
}
ExpModFish = ExpModFish or {}
local fs = section("fish", "Pesca")
local fishInfo, fishCursor, fishUses = nil, 0, 0
local function paintFish()
  for i, m in ipairs(FISH) do
    m.lbl:setText((ExpModFish[i] and "[ON]  " or "[OFF] ")..m.name)
    m.lbl:setColor(ExpModFish[i] and "#6ee09f" or "#ecad71")
  end
end
for i, m in ipairs(FISH) do
  m.set = {}
  for _,id in ipairs(m.ids) do m.set[id] = true end
  m.lbl = fs.add("", function() ExpModFish[i] = not ExpModFish[i]; paintFish() end, m.fish)
end
fishInfo = fs.add("Cana "..ROD.." | usos: 0")
fishInfo:setColor("#a2b1c1")
paintFish()

every(function()
  if not g_game.isOnline() then return end
  local any = false
  for i in ipairs(FISH) do if ExpModFish[i] then any = true end end
  if not any then return end
  local p = me()
  if not p or (p:getItemsCount(ROD) or 0) < 1 then fishInfo:setText("sin cana "..ROD); return end
  for off = 1, #FISH do
    local i = (fishCursor + off - 1) % #FISH + 1
    if ExpModFish[i] then
      local q, th = findNear(FISH[i].set)
      if q and th then
        g_game.useInventoryItemWith(ROD, th)
        fishCursor, fishUses = i, fishUses + 1
        fishInfo:setText("Cana "..ROD.." | usos: "..fishUses)
        return
      end
    end
  end
end, 700)

-- ============================================================================
-- Mod: BOSSTIARY y MINING. Codigo original de "Eloria HUD.lua" (lo pega el
-- generador) dentro de su propia funcion, con la API de EloriaBot que usa.
-- ============================================================================
local HX = (function()
  local Enums = {TalkTypes={SAY=1}, CreatureTypes={CREATURETYPE_MONSTER=1}, MessageTypes={}}
  local Client = {
    isConnected=function() return g_game.isOnline() end,
    getLatency=function() return g_game.getPing and g_game.getPing() or 0 end,
  }
  local Player = {
    getPosition=Player.getPosition, getId=Player.getId,
    getLevel=function() local p = me(); return p and p:getLevel() or 0 end,
    getExperience=function() local p = me(); return p and p:getExperience() or 0 end,
  }
  local Creature = function(id)
    local c = g_map.getCreatureById(id)
    if not c then return nil end
    return {getType=function() return c:isMonster() and 1 or 0 end, getPosition=function() return c:getPosition() end}
  end
  local Map = setmetatable({
    -- casillas de pantalla: {position, things={{id=...}}} (sin criaturas)
    getTiles=function()
      local out, p = {}, Player.getPosition()
      if not p then return out end
      for dx = -8, 8 do for dy = -6, 6 do
        local q = {x=p.x+dx, y=p.y+dy, z=p.z}
        local t = g_map.getTile(q)
        if t then
          local th = {}
          for _,x in ipairs(t:getThings() or {}) do if not x:isCreature() then th[#th+1] = {id=x:getId()} end end
          out[#out+1] = {position=q, things=th}
        end
      end end
      return out
    end,
    getCreatureIds=function()
      local out, p = {}, Player.getPosition()
      if not p then return out end
      for _,c in ipairs(g_map.getSpectators(p, false)) do out[#out+1] = c:getId() end
      return out
    end,
    useItem=function(x, y, z) return Game.useItemFromGround(x, y, z) end,
  }, {__index=Map})
  local Game = setmetatable({
    useItemOnGround=function(id, x, y, z)
      local t = g_map.getTile({x=x, y=y, z=z})
      local th = t and t:getTopUseThing()
      if not th then return false end
      g_game.useInventoryItemWith(id, th)
      return true
    end,
    getItemCount=function(id) local p = me(); return p and p:getItemsCount(id) or 0 end,
  }, {__index=Game})
  local HUD, Timer, destroyTimer = {}, function() end, function() end

%HUD_A%
%HUD_B%
  return {E=E, bosstiaryTick=bosstiaryTick, bosstiaryModal=bosstiaryModal, mineTick=mineTick,
    stopMovement=stopMovement, entries=BOSSTIARY_ENTRIES}
end)()

-- Bosstiary: por donde va (sala / boss) se conserva al recargar el mod.
if ExpModBT then HX.E.bosstiary = ExpModBT end
ExpModBT = HX.E.bosstiary

local paintHX
local bt = section("bosstiary", "Bosstiary")
local btOn = bt.add("", function()
  local on = not HX.E.enabled.bosstiary
  if on then onlyOne("bosstiary") end
  HX.E.enabled.bosstiary = on
  HX.E.bosstiary.stage = "APPROACH"; HX.E.modal = nil; HX.stopMovement()
  HX.E.status = on and "Bosstiary: ON" or "-"
  paintHX()
end)
local btRoom = bt.add("")
local btName = bt.add("")
local btSt = bt.add("-"); btSt:setColor("#a2b1c1")

local mn = section("mining", "Mining")
local mnOn = mn.add("", function()
  local on = not HX.E.enabled.mining
  if on then onlyOne("mining") end
  HX.E.enabled.mining = on
  HX.stopMovement(); HX.E.tiles = nil
  HX.E.status = on and "Mining: ON" or "-"
  paintHX()
end, 19249)
local mnSt = mn.add("-"); mnSt:setColor("#a2b1c1")

paintHX = function()
  local E = HX.E
  local b = E.bosstiary
  btOn:setText((E.enabled.bosstiary and "[ON]  " or "[OFF] ").."Bosstiary")
  btOn:setColor(E.enabled.bosstiary and "#6ee09f" or "#ecad71")
  btRoom:setText("Sala "..b.room.."/5 | boss "..b.index.."/"..#HX.entries.." | vueltas "..(b.cycles or 0))
  local t = HX.entries[b.index]
  btName:setText("Boss: "..(t and t.name or "-"))
  mnOn:setText((E.enabled.mining and "[ON]  " or "[OFF] ").."Mining (pico 19249)")
  mnOn:setColor(E.enabled.mining and "#6ee09f" or "#ecad71")
  local s = tostring(E.status or "-")
  btSt:setText(E.enabled.bosstiary and s or "-")
  mnSt:setText(E.enabled.mining and s or "-")
end
paintHX()

-- Una automatizacion a la vez (encender una del mod apaga el cavebot de EloriaBot).
onlyOne = function(which)
  if which ~= "cavebot" then Engine.enableCaveBot(false) end
  if which ~= "exp" and ST.stage ~= "off" then toggle() end
  if which ~= "boss" and BOSS.on then BOSS.on = false; bossStatus("-"); paintBoss() end
  if which ~= "bosstiary" then HX.E.enabled.bosstiary = false end
  if which ~= "mining" then HX.E.enabled.mining = false end
  if which ~= "autoexp" and ExpModAX then ExpModAX.on = false end
  HX.stopMovement()
  paintHX()
end

-- ============================================================================
-- Mod: Auto-EXP. Mismo camino y misma conversacion con el NPC que las
-- expediciones (etapas npc -> hi -> empezar del codigo de arriba), pero en el
-- panel: retrocede ciclos hasta el nivel elegido, pulsa la etapa elegida
-- (Echo Reaper 204 / Echo Monolith 205) y Venomfen, lo comprueba, paga y Begin.
-- Dentro de la sala no hace nada (caza EloriaBot). Si sale de la sala (muerte),
-- vuelve al NPC y repite. No manda el cristal (XTAL) mientras esta en ON.
-- ============================================================================
do
  local AX_MAP = "venomfen"
  local LVS = {1, 10, 20, 30, 40, 50}
  local STAGES = {"Echo Reaper", "Echo Monolith"}
  -- Caza (pantalla EXP) que se enciende al entrar: todas en el mismo mapa.
  local AX_HUNT = {["Echo Reaper"]="Eternum Monoliths", ["Echo Monolith"]="Eternum Monoliths"}
  local function huntCtl(on)
    if not ExpModHuntCtl then print("[Auto-EXP] sin control del cavebot"); return end
    local name = AX_HUNT[(ExpModAXCfg[(me() and me():getName()) or "?"] or {}).stage or ""] or "Eternum Monoliths"
    if not on and ExpModHunt == nil then return end
    local ok, msg = ExpModHuntCtl(name, on)
    print("[Auto-EXP] cavebot "..(on and name.." " or "")..": "..tostring(msg))
  end
  ExpModAX = ExpModAX or {on=false}
  ExpModAXCfg = ExpModAXCfg or {}
  local AX = ExpModAX
  STEPS.cazar = "Cazando (Auto-EXP)"
  local function cfg()
    local p = me()
    local n = p and p:getName() or "?"
    ExpModAXCfg[n] = ExpModAXCfg[n] or {lv=(n == "Nika" and 30 or 1), stage="Echo Reaper"}
    return ExpModAXCfg[n]
  end
  local function stopAX(why)
    AX.on = false
    if ST.stage == "cazar" then huntCtl(false) end
    if ST.stage ~= "off" then
      setStage("off", nil, "Auto-EXP off")
      setTxt(hudTitle, "[OFF] Eloria Expeditions"); paint(hudTitle, COL.off)
      setTxt(hudStep, "Paso: -")
    end
    if why then print("[Auto-EXP] OFF: "..why) end
  end
  local btn
  local function paintBtn() if btn then btn:setColor(AX.on and "#6ee09f" or "#a2b1c1") end end
  local function startAX(txt)
    AX.on = true
    ST.tries = 0
    setTxt(hudTitle, "[ON]  Auto-EXP"); paint(hudTitle, COL.on)
    setStage("npc", nil, "Auto-EXP: al NPC")
    local c = cfg()
    print("[Auto-EXP] "..txt..": Lv "..c.lv.." | "..c.stage.." | Venomfen")
    paintBtn()
  end
  btn = mkButton(expRow, "Auto-EXP", 70, function()
    if AX.on then stopAX("a mano"); paintBtn(); return end
    onlyOne("autoexp")
    startAX("ON")
  end)
  -- Recargado (p. ej. tras morir) con Auto-EXP encendido: sigue solo.
  if AX.on then huntCtl(false); startAX("sigue tras recargar") end
  -- Desplegables (debajo de la fila EXP): nivel del ciclo y etapa
  local row = mkRow(22, 6)
  pcall(function() box:moveChildToIndex(row, box:getChildIndex(expRow) + 1) end)
  local function combo(w, list, get, set)
    local ok, cb = pcall(g_ui.createWidget, "ComboBox", row)
    if ok and cb then
      cb:setWidth(w); cb:setHeight(20)
      for _, v in ipairs(list) do cb:addOption(v) end
      cb:setCurrentOption(get())
      cb.onOptionChange = function(self, text) set(text) end
      return function() pcall(cb.setCurrentOption, cb, get()) end
    end
    -- sin estilo ComboBox: texto que pasa al siguiente valor con cada click
    cb = mkText(row, w, ""); cb:setHeight(22); cb:setPhantom(false)
    local function show() cb:setText("[ "..get().." ]") end
    cb.onClick = click(function()
      local i = 1
      for k, v in ipairs(list) do if v == get() then i = k end end
      set(list[i % #list + 1]); show()
    end)
    show()
    return show
  end
  local lvNames = {}
  for _, l in ipairs(LVS) do lvNames[#lvNames+1] = "Lv "..l end
  local refreshLv = combo(70, lvNames, function() return "Lv "..cfg().lv end,
    function(t) cfg().lv = tonumber(t:match("%d+")) end)
  local refreshSt = combo(112, STAGES, function() return cfg().stage end,
    function(t) cfg().stage = t end)
  local lastName
  local function lvOf(w) return tonumber(w:getChildById("cycleLabel"):getText():match("Lv%s*(%d+)")) end
  local function begin(w)
    local b, pb = w:recursiveGetChildById("embark"), w:recursiveGetChildById("paymentButton")
    if not notEnough(b) then b:onClick(); print("[Auto-EXP] Begin ("..pb:getText()..")"); return end
    pb:onClick()
    scheduleEvent(function() pcall(function()
      if notEnough(b) then pb:onClick(); print("[Auto-EXP] sin fondos: "..b:getText())
      else b:onClick(); print("[Auto-EXP] Begin ("..pb:getText()..")") end
    end) end, 500)
  end
  local function run(w)
    local c = cfg()
    local want, stName, n = c.lv, c.stage:lower(), 0
    local function step()
      if not (AX.on and w:isVisible()) then return end
      local lv = lvOf(w)
      if lv ~= want then
        if n >= 15 or (lv and lv < want) then
          print("[Auto-EXP] no llego a Lv "..want.." (el panel esta en Lv "..tostring(lv).."): NO Begin"); return
        end
        n = n + 1; modules.game_expedition.previousCycle()
        scheduleEvent(function() pcall(step) end, 500); return
      end
      local stg
      for _, x in ipairs(w:recursiveGetChildById("trail"):getChildren()) do
        if x:getText():lower() == stName then stg = x end
      end
      if not stg then print("[Auto-EXP] no encuentro la etapa "..c.stage..": NO Begin"); return end
      stg:onClick()
      for _, x in ipairs(w:recursiveGetChildById("maps"):getChildren()) do
        local nm = x:recursiveGetChildById("name")
        if nm and nm:getText():lower():find(AX_MAP, 1, true) then x:onClick() end
      end
      scheduleEvent(function() pcall(function()
        if not (AX.on and w:isVisible()) then return end
        local num = stg:getId():match("%d+") or "?"
        local okLv = lvOf(w) == want
        local okSt = w:getChildById("heading"):getText():find("STAGE "..num.." ", 1, true) ~= nil
        local okMp = w:recursiveGetChildById("selected"):getText():lower():find(AX_MAP, 1, true) ~= nil
        if okLv and okSt and okMp then begin(w)
        else
          local yn = function(x) return x and "OK" or "MAL" end
          print("[Auto-EXP] Lv "..want.." "..yn(okLv).." | etapa "..num.." "..yn(okSt).." | mapa "..yn(okMp).." -> NO Begin")
        end
      end) end, 600)
    end
    pcall(step)
  end
  local opened
  every(function()
    paintBtn()
    local p = me()
    local nm = p and p:getName()
    if nm and nm ~= lastName then lastName = nm; refreshLv(); refreshSt() end
    if AX.on and ST.stage == "off" then AX.on = false; paintBtn() end  -- lo apagaron desde el titulo
    if AX.on and p then
      local pp = p:getPosition()
      if ST.stage == "xtal" then setStage("cazar", nil, "Auto-EXP: dentro, cazando"); huntCtl(true)
      elseif ST.stage == "cazar" and not inInstance(pp) then
        ST.tries = 0
        huntCtl(false)
        setStage("npc", nil, "Auto-EXP: fuera de la sala, vuelvo al NPC")
        print("[Auto-EXP] fuera de la sala (muerte?): vuelvo al NPC")
      end
    end
    local w = g_ui.getRootWidget():getChildById("expeditionWindow")
    if not (w and w:isVisible()) then opened = nil
    elseif AX.on and not opened then
      opened = 1
      scheduleEvent(function() pcall(run, w) end, 1000)
    end
  end, 500)
end

-- Ciclo (100 ms, como el original): reloj, modal de salas, bosstiary o mining.
local hxPaintAt = 0
every(function()
  local E = HX.E
  E.clock = math.max(E.clock + 100, os.time()*1000)
  if not g_game.isOnline() then return end
  if E.enabled.bosstiary then
    if E.modal and E.clock - E.modal.at >= 150 then HX.bosstiaryModal(E.modal) end
    HX.bosstiaryTick()
  elseif E.enabled.mining then
    HX.mineTick()
  end
  if g_clock.millis() - hxPaintAt > 1000 then hxPaintAt = g_clock.millis(); paintHX() end
end, 100)
hook("onModalDialog", function(...) if HX.E.enabled.bosstiary then HX.E.onModal(...) end end)
hook("onTextMessage", function(mode, text) if HX.E.enabled.mining then pcall(HX.E.onText, mode, text) end end)

-- ============================================================================
-- Mod: FORJA (pantalla propia, boton "Forja"): fusion automatica del objeto que
-- sueltes en el hueco, subiendo tier a tier y guardando SIEMPRE 1 copia de cada
-- tier (solo fusiona el excedente: hace falta 3 o mas de un tier).
-- Convergencia (casilla) = 100% exito. Logica de auto_forge.lua:
--   g_game.sendForgeFusion(convergencia, itemId, tier, sacrificeItemId, usedCore, reduceTierLoss)
-- Solo ve las mochilas ABIERTAS. Pausa aleatoria entre fusiones. Se para sola
-- cuando no quedan pares, o si 2 fusiones seguidas no cambian nada (oro/dust?).
-- Auto sliver (casilla): usa el objeto sliver (37109) cada SLIVER_MS mientras
-- lleves alguno, como el timer "sliver" de EloriaBot (1 s).
-- TIER OBJETIVO (hueco "Objetivo"): si pones un tier, en vez de guardar 1 de cada
-- tier fusiona por PAREJAS (2 del mismo tier -> 1 del siguiente) desde el tier mas
-- bajo hasta tener 1 objeto MAS en ese tier que al empezar (aunque ya tengas otros
-- en ese tier: la forja siempre necesita parejas del mismo tier para seguir
-- subiendo). No toca los que ya estan en el objetivo o por encima. Hacen falta 2^objetivo "puntos" (un tier t vale 2^t): si no llegan,
-- no empieza y dice cuantos de tier 0 faltan. Sin objetivo: modo de antes.
-- TIER INICIAL: el tier del arma que ya tienes. Solo cambia las cuentas: el arma
-- no cuenta como material y hace falta 2^objetivo - 2^inicial en tier 0 (subir
-- otra pieza al tier inicial, luego al siguiente... hasta el objetivo). El arma
-- tiene que estar en una mochila abierta para poder fusionarla.
-- ============================================================================
ExpModForge = ExpModForge or {conv=true, sliver=false}
local FG = {on=false, item=ExpModForge.item, sent=0, stall=0, next=0}
local FGUI = {}  -- widgets de la pantalla Forja (se crean con las pantallas)
-- Cuantos hay de cada tier. Primero el recuento de TODO el inventario que manda el
-- servidor (tambien mochilas cerradas): LocalPlayer:getInventoryCount(id, tier).
-- Si este cliente no lo tiene o da 0, las mochilas ABIERTAS (como antes).
FG.source = "-"
local function forgeScan(itemId)
  local counts, total = {}, 0
  local p = me()
  if p and p.getInventoryCount then
    for t = 0, 10 do
      local ok, n = pcall(p.getInventoryCount, p, itemId, t)
      n = ok and tonumber(n) or 0
      if n > 0 then counts[t], total = n, total + n end
    end
    if total > 0 then FG.source = "inventario"; return counts end
    counts = {}
  end
  for _, c in pairs(g_game.getContainers()) do
    for _, it in ipairs(c:getItems()) do
      if it:getId() == itemId then
        local t = it.getTier and it:getTier() or 0
        counts[t] = (counts[t] or 0) + 1
      end
    end
  end
  FG.source = "mochilas abiertas"
  return counts
end
-- Diagnostico (una vez): que recuentos de inventario tiene el cliente -> /mods_zalo/diag_inventario.txt
local function forgeInvDiag(itemId)
  if FG.invDiag then return end
  FG.invDiag = true
  pcall(function()
    local p, out = me(), {}
    local names = {}
    local mt = getmetatable(p)
    for _, src in ipairs({LocalPlayer or {}, Player or {}, Creature or {}}) do
      for k, v in pairs(src) do
        local l = tostring(k):lower()
        if type(v) == "function" and (l:find("count") or l:find("inventor") or l:find("item")) then names[#names+1] = tostring(k) end
      end
    end
    table.sort(names)
    out[#out+1] = "metodos: "..table.concat(names, " ")
    for _, m in ipairs({"getItemsCount", "getInventoryCount", "getItemCount", "getResourceBalance"}) do
      local f = p[m]
      out[#out+1] = m.." : "..type(f)
      if type(f) == "function" then
        local r0 = {pcall(f, p, itemId)}
        out[#out+1] = "  ("..itemId..") -> "..tostring(r0[1]).." "..tostring(r0[2])
        for t = 0, 3 do
          local r = {pcall(f, p, itemId, t)}
          out[#out+1] = "  ("..itemId..", tier "..t..") -> "..tostring(r[1]).." "..tostring(r[2])
        end
      end
    end
    g_resources.writeFileContents("/mods_zalo/diag_inventario.txt", table.concat(out, "\n"))
  end)
end
-- Tier a fusionar. Sin objetivo: el mas bajo con 3+ (guarda 1 de cada tier).
-- Con objetivo: el mas bajo por debajo del objetivo con 2+ (parejas).
local function forgePick(counts)
  local target = ExpModForge.target
  local tiers = {}
  for t in pairs(counts) do tiers[#tiers+1] = t end
  table.sort(tiers)
  for _, t in ipairs(tiers) do
    if target then
      if t < target and counts[t] >= 2 then return t end
    elseif counts[t] >= 3 then return t end
  end
end
-- Material para el objetivo. SLIVER_ID = sliver (37109, el de tus timers).
-- Coste en slivers por fusion: SIN CONFIRMAR (nil = "?"); si depende del tier o
-- de convergencia, se cambia aqui: FORGE_SLIVERS(tier, convergencia) -> numero.
local SLIVER_ID = 37109
local SLIVER_MS = 1000  -- ms entre uso y uso del sliver
local function FORGE_SLIVERS(tier, conv) return nil end
-- Fusiones que faltan para tener 1 objeto en el tier T con lo que llevas (+ los de
-- tier 0 que falten): se juntan los de mayor tier primero; k objetos -> k-1 fusiones.
local function forgePlan(counts, T)
  local need, list = 2^T, {}
  for t, n in pairs(counts) do if t < T then for _ = 1, n do list[#list+1] = t end end end
  table.sort(list, function(x, y) return x > y end)
  local sum, used, byTier = 0, 0, {}
  for _, t in ipairs(list) do
    if sum >= need then break end
    sum, used = sum + 2^t, used + 1
    byTier[t] = (byTier[t] or 0) + 1
  end
  local missing = math.max(0, need - sum)
  return used + missing - 1, missing, byTier
end
-- Objetivo: ya hay uno en ese tier (o mas)? Y cuantos "puntos" hay / hacen falta.
-- Devuelve: cuantos objetos hay YA en el objetivo o por encima (no cuentan como
-- material ni paran la forja), puntos de material por debajo, puntos necesarios.
-- El objetivo es conseguir UNO MAS en ese tier que al pulsar Auto-fusion.
local function forgeGoal(counts)
  local target = ExpModForge.target
  if not target then return 0, 0, 0 end
  local have, above = 0, 0
  for t, n in pairs(counts) do
    if t >= target then above = above + n else have = have + n * 2^t end
  end
  return above, have, 2^target
end
local function sameCounts(x, y)
  for k, v in pairs(x) do if y[k] ~= v then return false end end
  for k, v in pairs(y) do if x[k] ~= v then return false end end
  return true
end
local function paintForge()
  if not FGUI.on then return end
  FGUI.on:setText((FG.on and "[ON]  " or "[OFF] ").."Auto-fusion"); FGUI.on:setColor(FG.on and "#6ee09f" or "#ecad71")
  FGUI.conv:setText((ExpModForge.conv and "[X] " or "[ ] ").."Convergencia (100%)")
  local ps = me()
  local ns = ps and (ps:getItemsCount(37109) or 0) or 0
  FGUI.sliver:setText((ExpModForge.sliver and "[X] " or "[ ] ").."Auto sliver (37109: "..ns..")")
  FGUI.slot:setItemId(FG.item or 0)
  FGUI.item:setText(FG.item and ("ID "..FG.item) or "suelta aqui el objeto")
  if FG.item then forgeInvDiag(FG.item) end
  -- Arma del tier inicial: amarillo = no esta en las mochilas abiertas, verde = si.
  local S0 = ExpModForge.start
  if S0 and FG.item and not (ExpModForge.target and S0 >= ExpModForge.target) then
    local okW = (forgeScan(FG.item)[S0] or 0) > 0
    FGUI.weapon:setText(okW and ("Arma T"..S0..": disponible") or ("Arma T"..S0..": no disponible"))
    FGUI.weapon:setColor(okW and "#6ee09f" or "#ffd43b")
  else
    FGUI.weapon:setText(""); FGUI.weapon:setColor("#a2b1c1")
  end
  -- Target: T5 | Slivers: llevas / Needed | Items: llevas / Needed
  -- (Items en "tier 0": un objeto de tier t cuenta como 2^t; Needed = 2^objetivo)
  local T = ExpModForge.target
  local p = me()
  local slivers = p and (p:getItemsCount(SLIVER_ID) or 0) or 0
  if p and p.getInventoryCount then
    local okS, nS = pcall(p.getInventoryCount, p, SLIVER_ID, 0)
    if okS and tonumber(nS) and tonumber(nS) > slivers then slivers = tonumber(nS) end
  end
  local S = ExpModForge.start
  if S and T and S >= T then S = nil end
  FGUI.goal:setText("Target: "..(T and ("T"..T) or "-")..(S and (" (desde T"..S..")") or ""))
  if T and FG.item then
    local counts = forgeScan(FG.item)
    local above, have, need = forgeGoal(counts)
    if FG.base and above > FG.base then
      FGUI.matSliver:setText("Slivers: "..slivers.." / Needed: 0")
      FGUI.matItems:setText("Items: T"..T.." conseguido")
    else
      local _, missing = forgePlan(counts, T)
      -- slivers: suma del coste de cada fusion segun su tier (si se conoce)
      local total, known = 0, true
      local c = {}
      for t, n in pairs(counts) do if t < T then c[t] = n end end
      c[0] = (c[0] or 0) + missing
      for t = 0, T - 1 do
        local pairs_ = math.floor((c[t] or 0) / 2)
        local cost = FORGE_SLIVERS(t, ExpModForge.conv)
        if pairs_ > 0 and not cost then known = false end
        total = total + pairs_ * (cost or 0)
        c[t + 1] = (c[t + 1] or 0) + pairs_
      end
      FGUI.matSliver:setText("Slivers: "..slivers.." / Needed: "..(known and total or "?"))
      if S then
        -- el arma de tier S no es material: para subirla de S a T hace falta subir
        -- otra pieza a S, luego a S+1, ... hasta T-1 = 2^T - 2^S en tier 0
        local weapon = (counts[S] or 0) > 0
        local mat = have - (weapon and 2^S or 0)
        FGUI.matItems:setText("Items: "..mat.." / Needed: "..(need - 2^S))
      else
        FGUI.matItems:setText("Items: "..have.." / Needed: "..need)
      end
      FGUI.src:setText("(contando: "..FG.source..")")
    end
  else
    FGUI.matSliver:setText("Slivers: "..slivers.." / Needed: -")
    local have = 0
    if FG.item then for _, n in pairs(forgeScan(FG.item)) do have = have + n end end
    FGUI.matItems:setText("Items: "..have.." / Needed: -")
  end
  FGUI.st:setText(FG.msg or "-")
end

-- Auto sliver: usar 37109 cada SLIVER_MS si la casilla esta marcada. Sin mirar
-- cuantos llevas (el recuento del cliente puede dar 0 aunque los tengas, p.ej. en
-- una mochila cerrada): como el timer de EloriaBot, el servidor busca el objeto.
every(function()
  if not (ExpModForge.sliver and g_game.isOnline()) then return end
  g_game.useInventoryItem(SLIVER_ID)
end, SLIVER_MS)

every(function()
  if not g_game.isOnline() then return end
  if FG.on and FG.item and g_clock.millis() >= FG.next then
    local counts = forgeScan(FG.item)
    local tier = forgePick(counts)
    local above, have, need = forgeGoal(counts)
    if FG.base == nil then FG.base = above end
    if ExpModForge.target and above > FG.base then
      FG.on, FG.msg = false, "objetivo tier "..ExpModForge.target.." conseguido ("..FG.sent.." fusiones)"
      print("[Forja] "..FG.msg)
    elseif ExpModForge.target and have < need then
      FG.on, FG.msg = false, "faltan "..(need - have).." de tier 0 para el tier "..ExpModForge.target
      print("[Forja] "..FG.msg)
    elseif not tier then
      FG.on, FG.msg = false, "terminado: "..FG.sent.." fusiones"
      print("[Forja] terminado. Fusiones enviadas: "..FG.sent)
    elseif FG.last and sameCounts(FG.last, counts) then
      FG.stall = FG.stall + 1
      if FG.stall >= 2 then
        FG.on, FG.msg = false, "no avanza: oro/dust/cores?"
        print("[Forja] parada: 2 fusiones sin cambios")
      end
    else
      FG.stall = 0
    end
    if FG.on then
      g_game.sendForgeFusion(ExpModForge.conv and true or false, FG.item, tier, FG.item, false, false)
      FG.sent, FG.last = FG.sent + 1, counts
      FG.next = g_clock.millis() + math.random(1800, 3200)
      FG.msg = "fusion #"..FG.sent.." (tier "..tier.." -> "..(tier + 1)..")"
    end
  end
  paintForge()
end, 500)

-- ============================================================================
-- Mod: pantallas. Pantalla principal = todo lo de arriba. Boton EXP -> pantalla
-- EXP (cazas); "Volver" -> la principal tal como estaba.
-- ============================================================================
local PAGE1 = {}
for _,w in ipairs(box:getChildren()) do PAGE1[#PAGE1+1] = w end
local PAGE2 = {}
-- Cazas de la pantalla EXP: ruta del cavebot de EloriaBot (carpeta, nombre).
-- Click = cargar la ruta y encender el cavebot; otra vez = apagarlo.
local HUNTS = {
  {name="EchoMonolith", cat="Echo", route="EchoMonolith"},
  {name="Echo Reaper 2", cat="Echo", route="Echo Reaper 2"},  -- la de Trafalgar Law
  {name="Echo Reaper 2 LINEAL", cat="Echo", route="Echo Reaper 2 LINEAL"},  -- 140 nodos, Stop 6 / Back 0
  {name="FateDemon", cat="Fate", route="FateDemon"},
  {name="Fate Warden", cat="Fate", route="Fate Warden"},
  {name="EchoTide", cat="Echo", route="EchoTide"},
  {name="Eternum Monoliths", cat="Eternum", route="Monoliths"},
  {name="EchoMonolith 2", cat="Echo", route="EchoMonolith 2"},  -- copia desplazada (15450,15171,7)
}
do
  local r = mkRow(22, 4)
  local t = mkText(r, 136, "EXP"); t:setColor("#e1bb70")
  mkButton(r, "Volver", 48, function() showPage("main") end)
  PAGE2[#PAGE2+1] = r
  PAGE2[#PAGE2+1] = sepLine()


  -- Cavebot de EloriaBot: cargar una ruta como su boton Load
  -- (selectCategory(carpeta) + nombre en el cuadro sessionName + loadSession()).
  -- "(raiz)" = rutas sueltas en /cavebots (sin carpeta): categoria nil.
  local ROOT = "(raiz)"
  local function cbSessionEdit()
    local win = g_ui.getRootWidget():getChildById("helperWindow")
    return win and win:recursiveGetChildById("sessionName")
  end
  local function ebLoadRoute(cat, route)
    local C, ed = ebCavebot(), cbSessionEdit()
    if not (C and C.loadSession and C.selectCategory) then return false, "EloriaBot no disponible" end
    if not ed then return false, "abre una vez el cavebot de EloriaBot" end
    pcall(C.selectCategory, cat ~= ROOT and cat or nil)
    ed:setText(route)
    local ok, err = pcall(C.loadSession)
    if not ok then print("[Cavebot] "..tostring(err)); return false, "error: "..tostring(err) end
    return true, "cargada: "..route
  end

  for _, h in ipairs(HUNTS) do
    local hr = mkRow(18)
    h.lbl = mkText(hr, 188, ""); h.lbl:setHeight(18)
    hr.onClick = click(function()
      local C = ebCavebot()
      if not (C and C.toggle and C.isEnabled) then h.msg = "EloriaBot no disponible"; return end
      if ExpModHunt == h.name and C.isEnabled() then
        pcall(C.toggle, false); ExpModHunt = nil; h.msg = "apagado"
        return
      end
      onlyOne("cavebot")
      local ok, msg = ebLoadRoute(h.cat, h.route)
      h.msg = msg
      if ok then pcall(C.toggle, true); ExpModHunt = h.name end
    end)
    PAGE2[#PAGE2+1] = hr
    local sr = mkRow(18)
    h.st = mkText(sr, 188, "-"); h.st:setHeight(18); h.st:setColor("#a2b1c1")
    PAGE2[#PAGE2+1] = sr
  end
  for _,w in ipairs(PAGE2) do w:setVisible(false) end
  -- Para Auto-EXP: cargar una caza de esta lista por su nombre y encender el
  -- cavebot (on=true), o apagarlo (on=false). Devuelve ok, mensaje.
  ExpModHuntCtl = function(name, on)
    local C = ebCavebot()
    if not (C and C.toggle) then return false, "EloriaBot no disponible" end
    if not on then
      pcall(C.toggle, false); ExpModHunt = nil
      return true, "cavebot apagado"
    end
    for _, h in ipairs(HUNTS) do
      if h.name == name then
        local ok, msg = ebLoadRoute(h.cat, h.route)
        if ok then pcall(C.toggle, true); ExpModHunt = h.name end
        h.msg = msg
        return ok, msg
      end
    end
    return false, "no hay caza "..tostring(name)
  end
end
-- Estado de cada caza (1 s): ON solo si el cavebot esta encendido con su ruta.
every(function()
  local C = ebCavebot()
  local on = C and C.isEnabled and C.isEnabled() and true or false
  for _, h in ipairs(HUNTS) do
    local mine = on and ExpModHunt == h.name
    h.lbl:setText((mine and "[ON]  " or "[OFF] ")..h.name); h.lbl:setColor(mine and "#6ee09f" or "#ecad71")
    if mine then
      local okS, st = pcall(C.getStatus)
      local okI, idx = pcall(C.getCurrentIndex)
      local okW, wps = pcall(C.getWaypoints)
      h.st:setText(tostring(okS and st or "-").." | wp "..tostring(okI and idx or "?").."/"..(okW and type(wps) == "table" and #wps or "?"))
    else
      h.st:setText(h.msg or "-")
    end
  end
end, 1000)
-- Pantalla FORJA
local PAGE3 = {}
do
  local r = mkRow(22, 4)
  local t = mkText(r, 136, "Forge"); t:setColor("#e1bb70")
  mkButton(r, "Volver", 48, function() showPage("main") end)
  PAGE3[#PAGE3+1] = r
  PAGE3[#PAGE3+1] = sepLine()
  local function row(fn)
    local rw = mkRow(18)
    local tx = mkText(rw, 188, ""); tx:setHeight(18)
    if fn then rw.onClick = click(fn) end
    PAGE3[#PAGE3+1] = rw
    return tx
  end
  FGUI.on = row(function()
    if not FG.on and not FG.item then FG.msg = "primero suelta un objeto"; paintForge(); return end
    FG.on = not FG.on
    FG.sent, FG.stall, FG.last, FG.next, FG.base = 0, 0, nil, 0, nil
    FG.msg = FG.on and "ON" or "parada"
    paintForge()
  end)
  FGUI.conv = row(function() ExpModForge.conv = not ExpModForge.conv; paintForge() end)
  FGUI.sliver = row(function() ExpModForge.sliver = not ExpModForge.sliver; paintForge() end)
  -- Hueco del objeto: arrastra un objeto de la mochila aqui y coge su ID.
  local sr = mkRow(36, 6)
  FGUI.slot = g_ui.createWidget("UIItem", sr)
  FGUI.slot:setSize({width=34, height=34}); FGUI.slot:setVirtual(true); FGUI.slot:setPhantom(false)
  FGUI.slot:setBorderWidth(1); FGUI.slot:setBorderColor("#a8854a"); FGUI.slot:setBackgroundColor("#00000060")
  FGUI.slot.onDrop = function(self, widget)
    local it = widget and widget.currentDragThing
    if not (it and it.getId and it:isItem()) then return false end
    if FG.on then FG.msg = "para la forja para cambiar"; paintForge(); return true end
    FG.item = it:getId(); ExpModForge.item = FG.item
    FG.msg = nil
    paintForge()
    return true
  end
  FGUI.item = mkText(sr, 140, ""); FGUI.item:setHeight(34)
  PAGE3[#PAGE3+1] = sr
  -- Desplegable de tier: "-" (sin valor) y from..to; guarda en ExpModForge[key].
  local function tierCombo(label, key, from, to)
    local tr = mkRow(22, 6)
    local tl = mkText(tr, 100, label); tl:setHeight(22)
    local ok, cb = pcall(g_ui.createWidget, "ComboBox", tr)
    if ok and cb then
      cb:setWidth(50); cb:setHeight(20)
      cb:addOption("-")
      for i = from, to do cb:addOption(tostring(i)) end
      cb:setCurrentOption(ExpModForge[key] and tostring(ExpModForge[key]) or "-")
      cb.onOptionChange = function(self, text)
        ExpModForge[key] = tonumber(text)
        paintForge()
      end
    else
      -- sin estilo ComboBox: texto que va pasando -,from..to con cada click
      cb = mkText(tr, 50, ""); cb:setHeight(22); cb:setPhantom(false)
      local function show() cb:setText("[ "..(ExpModForge[key] or "-").." ]") end
      cb.onClick = click(function()
        local t = ExpModForge[key]
        ExpModForge[key] = (not t) and from or (t < to and t + 1 or nil)
        show(); paintForge()
      end)
      show()
    end
    PAGE3[#PAGE3+1] = tr
    return cb
  end
  -- Tier inicial = el tier del arma que ya tienes; objetivo = al que quieres llegar.
  FGUI.start = tierCombo("Tier inicial:", "start", 0, 9)
  FGUI.target = tierCombo("Tier objetivo:", "target", 1, 10)
  FGUI.goal = row()
  FGUI.matSliver = row()
  FGUI.matItems = row()
  FGUI.weapon = row()
  FGUI.src = row(); FGUI.src:setColor("#a2b1c1")
  FGUI.st = row(); FGUI.st:setColor("#a2b1c1")

  -- ============================================================================
  -- Mod: COMPRA en la tienda de la forja (ventana strengthForgeWindow: Tiers /
  -- buscador / tarjetas con "Buy 1"). Escribes el nombre del objeto, la cantidad
  -- y [Comprar]: el mod lo escribe en el buscador de la tienda, busca la tarjeta
  -- con ese nombre y pulsa su "Buy 1" y el "Yes" de "Confirm Purchase", N veces.
  -- La tienda tiene que estar abierta (hi al NPC).
  -- ============================================================================
  do
    local BUY_MS = 120  -- ms entre compra y compra (tras el Yes)
    ExpModBuy = ExpModBuy or {amount=10, name=""}
    local B = {left=0, done=0, next=0}
    PAGE3[#PAGE3+1] = sepLine()
    local hr = mkRow(20)
    local ht = mkText(hr, 188, "Compra (tienda de la forja)"); ht:setHeight(20); ht:setColor("#e1bb70")
    PAGE3[#PAGE3+1] = hr
    local paintBuy
    local function line(text, fn)
      local r = mkRow(18)
      local t = mkText(r, 188, text); t:setHeight(18)
      if fn then r.onClick = click(fn) end
      PAGE3[#PAGE3+1] = r
      return t
    end
    line("[ Hablar con el NPC (hi) ]", function() g_game.talk("hi"); B.msg = "hi enviado"; paintBuy() end):setColor("#70cfff")
    -- nombre del objeto (como en el buscador de la tienda)
    local nr = mkRow(22, 4)
    local nl = mkText(nr, 36, "Item:"); nl:setHeight(22)
    local ok, te = pcall(g_ui.createWidget, "TextEdit", nr)
    if not ok or not te then te = g_ui.createWidget("UITextEdit", nr) end
    te:setWidth(148); te:setHeight(20)
    te:setText(ExpModBuy.name or "")
    te.onTextChange = function(self, text) ExpModBuy.name = text or "" end
    PAGE3[#PAGE3+1] = nr
    -- cantidad: la escribes tu
    local ar = mkRow(22, 4)
    local al = mkText(ar, 60, "Cantidad:"); al:setHeight(22)
    local ok2, ae = pcall(g_ui.createWidget, "TextEdit", ar)
    if not ok2 or not ae then ae = g_ui.createWidget("UITextEdit", ar) end
    ae:setWidth(60); ae:setHeight(20)
    ae:setText(tostring(ExpModBuy.amount or 1))
    ae.onTextChange = function(self, text)
      local n = tonumber((text or ""):match("^%s*(%d+)%s*$"))
      if n and n > 0 then ExpModBuy.amount = n end
    end
    PAGE3[#PAGE3+1] = ar

    local function shopWindow()
      local w = g_ui.getRootWidget():getChildById("strengthForgeWindow")
      return w and w:isVisible() and w or nil
    end
    -- primer descendiente que cumpla f
    local function findDesc(w, f)
      for _, c in ipairs(w:getChildren()) do
        if f(c) then return c end
        local r = findDesc(c, f)
        if r then return r end
      end
    end
    local function lower(w) return (w:getText() or ""):lower() end
    -- buscador de la tienda (el primer cuadro de texto de su ventana)
    local function shopSearch(w)
      return findDesc(w, function(c) return c:getClassName() == "UITextEdit" or c.setCursorPos ~= nil and c.getText ~= nil and c:getClassName():find("TextEdit") ~= nil end)
    end
    -- Lo que escribes en "Item:" se escribe a la vez en el buscador de la tienda.
    te.onTextChange = function(self, text)
      ExpModBuy.name = text or ""
      local w = shopWindow()
      local search = w and shopSearch(w)
      if search and search ~= self then search:setText(text or "") end
    end
    -- boton "Buy ..." de la tarjeta cuyo nombre es exactamente el buscado.
    -- Se salta los cuadros de texto (el buscador tambien pone el nombre) y mira,
    -- de cada texto que coincida, su tarjeta (padre y abuelo) buscando "Buy".
    local function isEdit(c) return c:getClassName():find("TextEdit") ~= nil end
    local function buyButton(w, name)
      local found
      local function scan(x)
        for _, c in ipairs(x:getChildren()) do
          if found then return end
          if c:isVisible() and not isEdit(c) and lower(c) == name then
            local card = c:getParent()
            for _ = 1, 2 do
              if not card then break end
              found = findDesc(card, function(y) return y:isVisible() and lower(y):find("^buy") ~= nil end)
              if found then return end
              card = card:getParent()
            end
          end
          scan(c)
        end
      end
      scan(w)
      return found
    end

    local buyBtn = line("", function()
      if B.left > 0 then B.left = 0; B.msg = "parada: "..B.done.." compradas"; paintBuy(); return end
      local name = (ExpModBuy.name or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
      if name == "" then B.msg = "escribe el nombre del objeto"; paintBuy(); return end
      local w = shopWindow()
      if not w then B.msg = "abre la tienda (hi al NPC)"; paintBuy(); return end
      -- pestana "All" y el nombre en el buscador de la tienda
      local all = findDesc(w, function(c) return lower(c) == "all" end)
      if all then pcall(function() all:onClick() end) end
      local search = shopSearch(w)
      if search then search:setText(ExpModBuy.name) else print("[Compra] no encuentro el buscador de la tienda") end
      B.name, B.left, B.done, B.next, B.state = name, ExpModBuy.amount, 0, g_clock.millis() + 400, nil
      paintBuy()
    end)
    local st = line("-"); st:setColor("#a2b1c1")

    paintBuy = function()
      buyBtn:setText(B.left > 0 and "[ PARAR ]" or "[ Comprar ]")
      buyBtn:setColor(B.left > 0 and "#ff696f" or "#6ee09f")
      st:setText(B.left > 0 and ("comprando "..B.done.."/"..(B.done + B.left)) or (B.msg or "-"))
    end
    paintBuy()

    -- Diagnostico: estructura de la tienda (visible) -> /mods_zalo/diag_tienda.txt
    local function dumpShop(w)
      local out = {}
      local function scan(x, d)
        if d > 9 or #out > 1500 or not x:isVisible() then return end
        local tx = x:getText()
        local ev = {}
        for _, k in ipairs({"onClick", "onMouseRelease", "onMousePress", "onDoubleClick"}) do
          local okk, v = pcall(function() return x[k] end)
          if okk and v then ev[#ev+1] = k end
        end
        out[#out+1] = string.rep(" ", d)..tostring(x:getId()).." ["..x:getClassName().."]"
          ..((tx and tx ~= "") and (" '"..tx:sub(1, 40).."'") or "")
          ..(#ev > 0 and (" {"..table.concat(ev, ",").."}") or "")
          ..(x.getItemId and (" item="..tostring(x:getItemId())) or "")
        for _, c in ipairs(x:getChildren()) do scan(c, d+1) end
      end
      scan(w, 0)
      g_resources.writeFileContents("/mods_zalo/diag_tienda.txt", table.concat(out, "\n"))
    end

    -- Ventana "Confirm Purchase" (sale al pulsar Buy 1) y su boton Yes. Se busca en
    -- toda la interfaz (puede estar dentro de la tienda): el texto "Confirm Purchase"
    -- (titulo o etiqueta) y, en ese widget, su padre o su abuelo, el boton "Yes".
    local function confirmYes()
      local title = findDesc(g_ui.getRootWidget(), function(c)
        return c:isVisible() and lower(c):find("confirm purchase", 1, true) ~= nil
      end)
      local box = title
      for _ = 1, 3 do
        if not box then return nil end
        local yes = findDesc(box, function(x) return x:isVisible() and lower(x) == "yes" end)
        if yes then return yes end
        box = box:getParent()
      end
    end

    -- Pulsar un boton de varias formas, por si no usa onClick:
    -- 1 = onClick, 2 = soltar el raton encima, 3 = Enter en su ventana.
    local function press(w, how)
      if how == 1 and w.onClick then
        if signalcall then return pcall(signalcall, w.onClick, w) end
        return pcall(w.onClick, w)
      end
      if how == 2 and w.onMouseRelease then
        local pos = w:getPosition()
        return pcall(w.onMouseRelease, w, {x=pos.x+2, y=pos.y+2}, MouseLeftButton or 1)
      end
      if how == 3 then
        local win = w
        for _ = 1, 4 do
          win = win and win:getParent()
          if win and win.onEnter then return pcall(win.onEnter, win) end
        end
      end
      return false
    end
    -- Volcado (una vez) de la ventana de confirmacion y del modulo de la tienda
    -- -> /mods_zalo/diag_confirm.txt (para saber como se acepta la compra).
    local function dumpConfirm(yes)
      pcall(function()
        local out = {}
        local base = UIWidget and UIWidget.onClick
        local function scan(x, d)
          if d > 6 or #out > 400 then return end
          local tx = x:getText()
          local ev = {}
          for _, k in ipairs({"onClick", "onMouseRelease", "onMousePress", "onEnter", "onEscape"}) do
            local okk, v = pcall(function() return x[k] end)
            if okk and v and v ~= (UIWidget and UIWidget[k]) then ev[#ev+1] = k..":"..type(v) end
          end
          out[#out+1] = string.rep(" ", d)..tostring(x:getId()).." ["..x:getClassName().."]"
            ..((tx and tx ~= "") and (" '"..tx:sub(1, 50).."'") or "")..(#ev > 0 and (" {"..table.concat(ev, ",").."}") or "")
          for _, c in ipairs(x:getChildren()) do scan(c, d+1) end
        end
        -- ruta desde la raiz hasta el Yes
        local path, w = {}, yes
        while w do table.insert(path, 1, tostring(w:getId()).."["..w:getClassName().."]"); w = w:getParent() end
        out[#out+1] = "== ruta del Yes: "..table.concat(path, " / ")
        -- la ventana de confirmacion: el antepasado del Yes justo debajo de la raiz
        local win = yes
        while win:getParent() and win:getParent() ~= g_ui.getRootWidget() do win = win:getParent() end
        out[#out+1] = "== ventana (hija de la raiz): "..tostring(win:getId())
        -- si la ventana es la tienda entera, bajar al contenedor del Yes con "Confirm Purchase"
        local box = yes:getParent()
        for _ = 1, 3 do
          if box and not findDesc(box, function(c) return lower(c):find("confirm purchase", 1, true) ~= nil end) then box = box:getParent() end
        end
        scan(box or yes, 0)
        -- funciones del modulo de la tienda (con parametros)
        for _, mn in ipairs({"game_strengthforge", "game_forge", "game_cloudveil_forge"}) do
          local m = modules[mn]
          out[#out+1] = "== modules."..mn.." ("..type(m)..")"
          local keys = {}
          for k in pairs(m or {}) do keys[#keys+1] = tostring(k) end
          table.sort(keys)
          for _, k in ipairs(keys) do
            local v = m[k]
            local line = "  "..k.." : "..type(v)
            if type(v) == "function" then
              local ps = {}
              for i = 1, 8 do
                local okp, n = pcall(debug.getlocal, v, i)
                if not okp or not n then break end
                ps[#ps+1] = n
              end
              line = "  "..k.."("..table.concat(ps, ", ")..")"
            end
            out[#out+1] = line
          end
        end
        g_resources.writeFileContents("/mods_zalo/diag_confirm.txt", table.concat(out, "\n"))
      end)
    end

    -- Bucle de compra: "Buy 1" -> "Confirm Purchase" -> "Yes" -> (se cierra) -> repetir.
    -- Solo cuenta una compra cuando la confirmacion se ha cerrado tras el Yes.
    every(function()
      if B.left <= 0 or g_clock.millis() < B.next then return end
      local now = g_clock.millis()
      if B.state == "close" then
        -- Yes pulsado: esperar a que se cierre la confirmacion
        if not confirmYes() then
          B.left, B.done, B.state = B.left - 1, B.done + 1, nil
          B.next = now + BUY_MS
          if B.left <= 0 then B.msg = "hecho: "..B.done.." compradas" end
          paintBuy()
          return
        end
        local yes = confirmYes()
        if B.how < 3 and now - B.at > 400 then
          B.how, B.at = B.how + 1, now
          press(yes, B.how)
        elseif now - B.at > 1500 then
          B.left, B.state, B.msg = 0, nil, "no se pulsa el Yes: "..B.done.." compradas"
          paintBuy()
        end
        return
      end
      local yes = confirmYes()
      if yes then
        if not B.confDumped then B.confDumped = true; dumpConfirm(yes) end
        B.state, B.how, B.at = "close", 1, now
        press(yes, 1)
        return
      end
      if B.state == "confirm" then
        -- pulsado Buy 1, esperando la confirmacion
        if now - B.at < 1500 then return end
        B.left, B.state, B.msg = 0, nil, "no sale la confirmacion: "..B.done.." compradas"
        pcall(dumpShop, g_ui.getRootWidget())
        paintBuy()
        return
      end
      local w = shopWindow()
      local btn = w and buyButton(w, B.name)
      if w and not B.dumped then B.dumped = true; pcall(dumpShop, w) end
      if not btn then
        B.left, B.msg = 0, (w and ("no encuentro '"..B.name.."' en la tienda") or "tienda cerrada")..": "..B.done.." compradas"
        paintBuy()
        return
      end
      btn:onClick()
      B.state, B.at, B.next = "confirm", now, now + 30
      paintBuy()
    end, 20)
  end

  for _,w in ipairs(PAGE3) do w:setVisible(false) end
  paintForge()
end

local PAGES = {exp=PAGE2, forge=PAGE3}
local shownP1, curPage = nil, nil
every(function()
  local C = ebCavebot()
  local active = ExpModHunt and C and C.isEnabled and C.isEnabled() and true or false
  huntTxt:setText(ExpModHunt or "")
  if not shownP1 then huntRow:setVisible(active) end
end, 1000)
showPage = function(name)
  EXP.onMain = (name == "main")
  if curPage then for _,w in ipairs(PAGES[curPage]) do w:setVisible(false) end end
  if name == "main" then
    for _,w in ipairs(shownP1 or {}) do w:setVisible(true) end
    shownP1, curPage = nil, nil
    return
  end
  if not shownP1 then
    shownP1 = {}
    for _,w in ipairs(PAGE1) do if w:isVisible() then shownP1[#shownP1+1] = w; w:setVisible(false) end end
  end
  for _,w in ipairs(PAGES[name]) do w:setVisible(true) end
  curPage = name
end

-- ================== Mod: control ==================
function EXP.toggle() toggle() end
function EXP.stop(reloading)
  if not reloading and ExpModWD then removeEvent(ExpModWD); ExpModWD = nil end
  for _,e in ipairs(EXP.events) do removeEvent(e) end
  for _,c in ipairs(EXP.conns) do disconnect(g_game, c) end
  EXP.events, EXP.conns, EXP.text = {}, {}, {}
  if XM then XM.setExpeditionCrystalSite = XO end
  pcall(function() me():stopAutoWalk() end)
  if EXP.box then EXP.box:destroy(); EXP.box = nil end
  print("[ExpMod] parado")
end

-- ================== Mod: diagnostico de EloriaBot (para Claude) ==================
-- Solo lee y apunta en /mods_zalo/diag_eloriabot.txt que expone EloriaBot
-- (modules.game_helper) y lo que suene a cavebot. No toca nada.
pcall(function()
  local out, seen = {}, {}
  local function dump(name, t, depth)
    if type(t) ~= "table" or seen[t] or depth > 3 or #out > 3000 then return end
    seen[t] = true
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = tostring(k) end
    table.sort(keys)
    for _,k in ipairs(keys) do
      local v = t[k]
      if v == nil then v = t[tonumber(k)] end
      local s = string.rep("  ", depth)..name.."."..k.." : "..type(v)
      if type(v) ~= "table" and type(v) ~= "function" then s = s.." = "..tostring(v):sub(1, 80) end
      out[#out+1] = s
      if type(v) == "table" then dump(name.."."..k, v, depth+1) end
    end
  end
  out[#out+1] = "== modulos con helper / bot / cave en el nombre"
  for k in pairs(modules) do
    local l = tostring(k):lower()
    if l:find("helper") or l:find("bot") or l:find("cave") then out[#out+1] = tostring(k) end
  end
  out[#out+1] = "== globales con cave / helper / waypoint en el nombre"
  for k, v in pairs(_G) do
    local l = tostring(k):lower()
    if l:find("cave") or l:find("helper") or l:find("waypoint") then out[#out+1] = tostring(k).." : "..type(v) end
  end
  out[#out+1] = "== modules.game_helper"
  dump("game_helper", modules.game_helper, 0)
  -- Firmas (nombres de los parametros) de las funciones del cavebot y de ScriptingActions.
  local function sig(name, f)
    if type(f) ~= "function" then return end
    local ps, info = {}, nil
    pcall(function() info = debug.getinfo(f, "Su") end)
    for i = 1, 12 do
      local ok, n = pcall(debug.getlocal, f, i)
      if not ok or not n then break end
      ps[#ps+1] = n
    end
    if info and info.isvararg then ps[#ps+1] = "..." end
    out[#out+1] = name.."("..table.concat(ps, ", ")..")"..(info and ("  "..tostring(info.short_src)..":"..tostring(info.linedefined)) or "")
  end
  local H = modules.game_helper or {}
  local groups = {cavebot=H.cavebot, ScriptingActions=H._Helper and H._Helper.ScriptingActions}
  for gname, g in pairs(groups) do
    out[#out+1] = "== firmas "..gname
    local keys = {}
    for k in pairs(g or {}) do keys[#keys+1] = k end
    table.sort(keys)
    for _,k in ipairs(keys) do sig(gname.."."..k, g[k]) end
  end
  sig("toggleCavebotFromButton", H.toggleCavebotFromButton)
  -- Estado actual del cavebot (solo lecturas)
  out[#out+1] = "== estado cavebot"
  local C = H.cavebot or {}
  for _,k in ipairs({"isEnabled", "isRunning", "getStatus", "getCurrentIndex", "getProfileDir", "getCategoryDir", "getScriptPath"}) do
    local ok, a, b = pcall(C[k])
    out[#out+1] = k.." -> "..tostring(ok).." "..tostring(a).." "..tostring(b)
  end
  local ok, w = pcall(C.getWaypoints)
  out[#out+1] = "getWaypoints -> "..tostring(ok).." "..(type(w) == "table" and (#w.." waypoints") or tostring(w))
  -- Widgets de la interfaz relacionados con rutas (session / category / script / cavebot)
  out[#out+1] = "== widgets session / category / script / cavebot"
  local n = 0
  local function scan(wd, path)
    if n > 300 then return end
    local id = tostring(wd:getId())
    local l = id:lower()
    local p = path.."/"..id
    if l:find("session") or l:find("categor") or l:find("script") or l:find("cavebot") then
      n = n + 1
      local s = p.." ["..wd:getClassName().."] visible="..tostring(wd:isVisible())
      local tx = wd:getText()
      if tx and tx ~= "" then s = s.." text='"..tx:sub(1, 60).."'" end
      if wd.getCurrentOption then
        local okc, co = pcall(wd.getCurrentOption, wd)
        s = s.." current='"..tostring(okc and co and co.text).."'"
      end
      if type(wd.options) == "table" then
        local names = {}
        for i, o in ipairs(wd.options) do if i <= 40 then names[#names+1] = tostring(o.text) end end
        s = s.." options("..#wd.options.."): "..table.concat(names, " | ")
      end
      out[#out+1] = s
    end
    for _,c in ipairs(wd:getChildren()) do scan(c, p) end
  end
  scan(g_ui.getRootWidget(), "")
  g_resources.writeFileContents("/mods_zalo/diag_eloriabot.txt", table.concat(out, "\n"))
end)

print("[ExpMod] cargado ("..#ROUTES.." rutas). Click en el titulo del panel = ON/OFF. Parar: ExpMod.stop()")
'''

os.makedirs(OUTDIR, exist_ok=True)
assert '%HUD_A%' in TAIL and '%HUD_B%' in TAIL
TAIL = TAIL.replace('%HUD_A%', HUD_A).replace('%HUD_B%', HUD_B)
open(OUT, 'w', encoding='utf-8', newline='\n').write(HEAD + body + TAIL)
print('ok', os.path.normpath(OUT))
