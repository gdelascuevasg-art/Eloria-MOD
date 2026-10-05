--[[
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
-- ================== Ajustes ==================
local CFG = {
  NPC_POS     = {x=15840, y=19514, z=7},  -- casilla donde se habla con el NPC
  SAFE_SPOT   = {x=14439, y=19568, z=7},  -- donde apareces tras el Yes
  TP_TILE     = {x=14439, y=19562, z=7},  -- TP de vuelta al NPC
  INSTANCE_Z  = 0,                        -- piso de las salas de expedicion
  LOG         = false,   -- true = escribir cada paso en consola (la consola acumula lineas y ralentiza)
  WORD_GAP_MS = 1200,    -- pausa entre "hi" y "expeditions"
  START_WAIT_MS = 20000, -- si en este tiempo no empieza, repetir hi/expeditions
  START_TRIES = 3,       -- maximo de repeticiones (para no mutear)
  XTAL_WARN_MS = 10000,  -- avisar si no llega la posicion del cristal
  STUCK_MS    = 8000,    -- sin moverse en la ruta -> saltar al siguiente nodo
  CLICK_CHECK_MS = 4000, -- tras un click, si la fase no cambia -> re-click
  MATCH_TILES = 3,       -- cristal a <= esto de una ruta de la tabla = esa ruta
  NODE_DIST   = 5,       -- nodo alcanzado a <= estas casillas -> siguiente nodo
  BLOCK_IDS   = {[10228]=true}, -- casillas con estos objetos: no caminables (con flechas) y no se eligen en el barrido
  ARROW_MAPS  = {["Venomfen Hollows"]=true}, -- mapas que dentro de TODA la sala van con flechas
  CLICK_RETRY_MS = 1000, -- map click: repetir si lleva este tiempo sin moverse
  -- Monstruos de distancia en las oleadas: barrido como en las versiones
  -- anteriores: KITE_SQM casillas al SUR del cristal y luego KITE_SQM al NORTE.
  KITE_ON     = true,
  KITE_SQM    = 5,       -- casillas al sur y luego al norte del cristal
  KITE_RADIUS = 10,      -- solo cuentan monstruos a <= esto del cristal
  KITE_DIST   = 2,       -- mas lejos que esto de mi = "a distancia"
  KITE_WAIT_MS = 2000,   -- tanto tiempo seguido a distancia y nadie pegado -> barrido
  KITE_LEG_MS = 6000,    -- maximo por tramo; si no llega, pasa al siguiente
}

-- Casillas que nunca se pisan (junto al NPC).
local AVOID = {
  ["15836:19519:7"] = true,
  ["15832:19516:7"] = true,
  ["15834:19516:7"] = true,
}

-- ================== Rutas: cristal -> ruta ==================
-- Cada ruta empieza en la entrada de su mapa y acaba a 1 casilla del cristal.
-- {x,y,true} = punto OBLIGATORIO: hay que pisarlo exacto (no vale NODE_DIST).
-- {x,y,true,a=true} = tramo grabado: exacto y con FLECHAS.
local ROUTES = {
  { map="Prismheart Caverns", name="Prismaheart Cavern 1",
    crystal={x=15570, y=20371, z=0},
    wps={
      {15513,20401}, {15514,20396}, {15519,20392}, {15524,20392}, {15529,20392}, {15534,20392}, {15539,20396}, {15544,20396},
      {15549,20393}, {15550,20388}, {15554,20383}, {15559,20381}, {15560,20376}, {15560,20371}, {15560,20366}, {15555,20366},
      {15555,20361}, {15555,20356}, {15560,20353}, {15565,20353}, {15570,20352}, {15575,20352}, {15580,20352}, {15583,20357},
      {15583,20362}, {15581,20367}, {15576,20367}, {15571,20371},
    },
  },
  { map="Prismheart Caverns", name="Prismaheart Cavern 2",
    crystal={x=15576, y=20391, z=0},
    wps={
      {15513,20401}, {15514,20396}, {15519,20395}, {15524,20395}, {15529,20395}, {15534,20394}, {15539,20396}, {15544,20396},
      {15545,20391}, {15550,20390}, {15555,20388}, {15555,20383}, {15558,20378}, {15557,20373}, {15556,20368}, {15555,20363},
      {15555,20358}, {15555,20353}, {15560,20353}, {15565,20353}, {15570,20351}, {15575,20351}, {15580,20351}, {15581,20356},
      {15583,20361}, {15580,20366}, {15576,20371}, {15574,20376}, {15574,20381}, {15576,20386}, {15577,20391},
    },
  },
  { map="Prismheart Caverns", name="Prismaheart Cavern 3",
    crystal={x=15437, y=20406, z=0},
    wps={
      {15513,20401}, {15508,20399}, {15503,20399}, {15498,20398}, {15493,20396}, {15488,20396}, {15487,20401}, {15482,20401},
      {15477,20401}, {15475,20406}, {15475,20411}, {15473,20416}, {15473,20421}, {15472,20426}, {15472,20431}, {15472,20436},
      {15467,20438}, {15462,20442}, {15457,20442}, {15452,20441}, {15452,20436}, {15452,20431}, {15452,20426}, {15452,20421},
      {15452,20416}, {15452,20411}, {15450,20406}, {15448,20401}, {15443,20399}, {15438,20399}, {15437,20404}, {15437,20405},
    },
  },
  { map="Prismheart Caverns", name="Prismaheart Cavern 4",
    crystal={x=15600, y=20394, z=0},
    wps={
      {15513,20401}, {15514,20396}, {15519,20394}, {15524,20394}, {15529,20394}, {15534,20394}, {15539,20396}, {15544,20392},
      {15548,20387}, {15553,20386}, {15554,20381}, {15556,20376}, {15556,20371}, {15556,20366}, {15556,20361}, {15556,20356},
      {15561,20353}, {15566,20353}, {15571,20351}, {15576,20351}, {15581,20351}, {15581,20356}, {15581,20361}, {15581,20366},
      {15581,20371}, {15581,20376}, {15581,20381}, {15583,20386}, {15583,20391}, {15586,20396}, {15591,20396}, {15596,20396},
      {15599,20394},
    },
  },
  { map="Venomfen Hollows", name="Venomfen Hollows 1",
    crystal={x=15588, y=20236, z=0},
    wps={
      {15512,20242,true,a=true}, {15513,20242,true,a=true}, {15514,20242,true,a=true}, {15515,20242,true,a=true}, {15516,20242,true,a=true}, {15516,20241,true,a=true}, {15516,20240,true,a=true}, {15516,20239,true,a=true},
      {15516,20238,true,a=true}, {15516,20237,true,a=true}, {15516,20236,true,a=true}, {15516,20235,true,a=true}, {15516,20234,true,a=true}, {15516,20233,true,a=true}, {15516,20232,true,a=true}, {15516,20231,true,a=true},
      {15517,20231,true,a=true}, {15518,20231,true,a=true}, {15518,20230,true,a=true}, {15519,20230,true,a=true}, {15519,20229,true,a=true}, {15519,20228,true,a=true}, {15520,20228,true,a=true}, {15520,20227,true,a=true},
      {15520,20226,true,a=true}, {15520,20225,true,a=true}, {15520,20224,true,a=true}, {15521,20224,true,a=true}, {15521,20223,true,a=true}, {15521,20222,true,a=true}, {15521,20221,true,a=true}, {15522,20221,true,a=true},
      {15523,20221,true,a=true}, {15524,20221,true,a=true}, {15529,20226}, {15534,20226}, {15534,20231}, {15539,20232}, {15544,20232}, {15549,20232},
      {15554,20234}, {15559,20235}, {15564,20235}, {15569,20235}, {15574,20234}, {15579,20234}, {15584,20234}, {15587,20236},
    },
  },
  { map="Venomfen Hollows", name="Venomfen Hollows 2",
    crystal={x=15594, y=20212, z=0},
    wps={
      {15512,20242,true,a=true}, {15513,20242,true,a=true}, {15514,20242,true,a=true}, {15515,20242,true,a=true}, {15516,20242,true,a=true}, {15516,20241,true,a=true}, {15516,20240,true,a=true}, {15516,20239,true,a=true},
      {15516,20238,true,a=true}, {15516,20237,true,a=true}, {15516,20236,true,a=true}, {15516,20235,true,a=true}, {15516,20234,true,a=true}, {15516,20233,true,a=true}, {15516,20232,true,a=true}, {15516,20231,true,a=true},
      {15517,20231,true,a=true}, {15518,20231,true,a=true}, {15518,20230,true,a=true}, {15519,20230,true,a=true}, {15519,20229,true,a=true}, {15519,20228,true,a=true}, {15520,20228,true,a=true}, {15520,20227,true,a=true},
      {15520,20226,true,a=true}, {15520,20225,true,a=true}, {15520,20224,true,a=true}, {15521,20224,true,a=true}, {15521,20223,true,a=true}, {15521,20222,true,a=true}, {15521,20221,true,a=true}, {15522,20221,true,a=true},
      {15523,20221,true,a=true}, {15524,20221,true,a=true}, {15530,20225}, {15535,20225}, {15540,20225}, {15545,20229}, {15550,20230}, {15555,20234},
      {15560,20234}, {15565,20234}, {15570,20234}, {15575,20231}, {15580,20230}, {15580,20225}, {15585,20223}, {15590,20219},
      {15591,20214}, {15593,20212},
    },
  },
  { map="Venomfen Hollows", name="Venomfen Hollows 3",
    crystal={x=15594, y=20192, z=0},
    wps={
      {15512,20242,true,a=true}, {15513,20242,true,a=true}, {15514,20242,true,a=true}, {15515,20242,true,a=true}, {15516,20242,true,a=true}, {15516,20241,true,a=true}, {15516,20240,true,a=true}, {15516,20239,true,a=true},
      {15516,20238,true,a=true}, {15516,20237,true,a=true}, {15516,20236,true,a=true}, {15516,20235,true,a=true}, {15516,20234,true,a=true}, {15516,20233,true,a=true}, {15516,20232,true,a=true}, {15516,20231,true,a=true},
      {15517,20231,true,a=true}, {15518,20231,true,a=true}, {15518,20230,true,a=true}, {15519,20230,true,a=true}, {15519,20229,true,a=true}, {15519,20228,true,a=true}, {15520,20228,true,a=true}, {15520,20227,true,a=true},
      {15520,20226,true,a=true}, {15520,20225,true,a=true}, {15520,20224,true,a=true}, {15521,20224,true,a=true}, {15521,20223,true,a=true}, {15521,20222,true,a=true}, {15521,20221,true,a=true}, {15522,20221,true,a=true},
      {15523,20221,true,a=true}, {15524,20221,true,a=true}, {15528,20224}, {15533,20226}, {15538,20226}, {15543,20226}, {15544,20231}, {15549,20232},
      {15554,20235}, {15559,20235}, {15564,20235}, {15569,20235}, {15570,20230}, {15575,20230}, {15580,20227}, {15585,20224},
      {15589,20219}, {15591,20214}, {15591,20209}, {15591,20204}, {15591,20199}, {15593,20194}, {15593,20192},
    },
  },
  { map="Venomfen Hollows", name="Venomfen Hollows 4",
    crystal={x=15570, y=20201, z=0},
    wps={
      {15512,20242,true,a=true}, {15513,20242,true,a=true}, {15514,20242,true,a=true}, {15515,20242,true,a=true}, {15516,20242,true,a=true}, {15516,20241,true,a=true}, {15516,20240,true,a=true}, {15516,20239,true,a=true},
      {15516,20238,true,a=true}, {15516,20237,true,a=true}, {15516,20236,true,a=true}, {15516,20235,true,a=true}, {15516,20234,true,a=true}, {15516,20233,true,a=true}, {15516,20232,true,a=true}, {15516,20231,true,a=true},
      {15517,20231,true,a=true}, {15518,20231,true,a=true}, {15518,20230,true,a=true}, {15519,20230,true,a=true}, {15519,20229,true,a=true}, {15519,20228,true,a=true}, {15520,20228,true,a=true}, {15520,20227,true,a=true},
      {15520,20226,true,a=true}, {15520,20225,true,a=true}, {15520,20224,true,a=true}, {15521,20224,true,a=true}, {15521,20223,true,a=true}, {15521,20222,true,a=true}, {15521,20221,true,a=true}, {15522,20221,true,a=true},
      {15523,20221,true,a=true}, {15524,20221,true,a=true}, {15531,20224}, {15536,20228}, {15536,20233}, {15541,20231}, {15546,20231}, {15551,20231},
      {15556,20235}, {15561,20235}, {15566,20233}, {15571,20233}, {15572,20228}, {15572,20223}, {15570,20218}, {15568,20213},
      {15568,20208}, {15571,20203}, {15571,20202},
    },
  },
  { map="Cinderfall Abyss", name="Cinderfall Abyss 1",
    crystal={x=15785, y=20501, z=0},
    wps={
      {15736,20421}, {15731,20425}, {15726,20429}, {15723,20434}, {15719,20439}, {15719,20444}, {15722,20449}, {15726,20454},
      {15729,20459}, {15734,20459}, {15739,20459}, {15744,20459}, {15749,20456}, {15754,20453}, {15759,20453}, {15764,20453},
      {15768,20458}, {15771,20463}, {15773,20468}, {15773,20470}, {15773,20476}, {15774,20481}, {15774,20486}, {15779,20487},
      {15784,20491}, {15784,20496}, {15784,20501},
    },
  },
  { map="Cinderfall Abyss", name="Cinderfall Abyss 2",
    crystal={x=15764, y=20482, z=0},
    wps={
      {15736,20421}, {15734,20426}, {15729,20426}, {15724,20430}, {15722,20435}, {15720,20440}, {15720,20445}, {15722,20450},
      {15725,20455}, {15730,20455}, {15733,20460}, {15738,20460}, {15743,20460}, {15748,20458}, {15753,20455}, {15758,20453},
      {15763,20453}, {15768,20457}, {15771,20462}, {15771,20467}, {15768,20472}, {15763,20476}, {15763,20481},
    },
  },
  { map="Cinderfall Abyss", name="Cinderfall Abyss 3",
    crystal={x=15797, y=20474, z=0},
    wps={
      {15736,20421}, {15731,20425}, {15727,20430}, {15722,20431}, {15721,20436}, {15719,20441}, {15719,20446}, {15721,20451},
      {15726,20452}, {15728,20457}, {15733,20458}, {15738,20458}, {15743,20458}, {15748,20458}, {15753,20455}, {15758,20453},
      {15763,20453}, {15767,20458}, {15772,20460}, {15773,20465}, {15773,20470}, {15778,20471}, {15783,20471}, {15788,20471},
      {15793,20471}, {15796,20473},
    },
  },
  { map="Cinderfall Abyss", name="Cinderfall Abyss 4",
    crystal={x=15833, y=20426, z=0},
    wps={
      {15736,20421}, {15731,20425}, {15726,20429}, {15721,20433}, {15719,20438}, {15719,20443}, {15720,20448}, {15724,20453},
      {15729,20456}, {15734,20459}, {15739,20459}, {15744,20457}, {15749,20457}, {15754,20454}, {15759,20452}, {15764,20455},
      {15769,20458}, {15774,20458}, {15779,20456}, {15779,20451}, {15779,20446}, {15781,20441}, {15781,20436}, {15783,20431},
      {15787,20426}, {15792,20424}, {15793,20419}, {15798,20419}, {15803,20418}, {15808,20418}, {15813,20418}, {15813,20423},
      {15818,20424}, {15818,20429}, {15823,20429}, {15828,20433}, {15833,20433}, {15833,20428}, {15833,20427},
    },
  },
}

-- ================== Utilidades ==================
local TICK_MS = 50  -- cada cuanto corre el script (con flechas = un paso por vuelta, sin espera)
local ST = {  -- todo el estado en una tabla
  stage="off", at=0, tries=0,
  route=nil, idx=1, crystal=nil,
  xtal=nil, binding=false, destroyed=false,
  clickPhase=nil, clickAt=0,
  lastP=nil, movedAt=0, warned=false,
  clicks=0, alertLvl="ok", alertAt=0,
  clickGoal=nil, clickT=0, lastStep=nil,
  farSince=nil, kiteLeg=0, kiteTarget=nil, mon={n=0, at=-1},
  clock=os.time()*1000, due={},
}

local function now() return ST.clock end
local function due(k, ms)
  local t = now()
  if t < (ST.due[k] or 0) then return false end
  ST.due[k] = t + ms
  return true
end
local function pos() return Player.getPosition() end
local function dist(a, b)
  if not a or not b or a.z ~= b.z then return 99999 end
  return math.max(math.abs(a.x-b.x), math.abs(a.y-b.y))
end

-- ================== HUD ==================
-- Panel arrastrable:  titulo (click = ON/OFF) | paso del diagrama | ruta |
-- cristal | estado (verde OK, amarillo aviso, rojo error).
local COL = {
  title={225,187,112}, on={110,224,159}, off={255,212,59}, text={238,242,247},
  muted={162,177,193}, ok={110,224,159}, warn={255,212,59}, err={255,105,111},
}
local HX, HY, PW, PH = 20, 60, 300, 104
local rows, frame = {}, nil
-- Solo se toca el HUD si el texto/color cambia (evita repintar en cada vuelta).
local HUDC = {}
local function paint(h, c)
  local k = c[1]..","..c[2]..","..c[3]
  local e = HUDC[h] or {}; HUDC[h] = e
  if e.c ~= k then e.c = k; h:setColor(c[1], c[2], c[3]) end
end
local function setTxt(h, t)
  local e = HUDC[h] or {}; HUDC[h] = e
  if e.t ~= t then e.t = t; h:setText(t) end
end
local function row(dy, text, c, size)
  local h = HUD(HX, HY+dy, text, true)
  h:setFontSize(size or 10); paint(h, c); h:setZIndex(21); h:setDraggable(true)
  rows[#rows+1] = {h=h, dy=dy}
  return h
end
if HUD.newPanel then
  frame = HUD.newPanel(HX-10, HY-8, PW, PH)
  frame:setBackgroundColor(15,21,31); frame:setBorderColor(168,133,74)
  frame:setBorderWidth(1); frame:setOpacity(0.94); frame:setZIndex(20); frame:setDraggable(true)
end
local hudTitle  = row(0,  "[OFF] Eloria Expeditions", COL.off, 11)
local hudStep   = row(20, "Paso: -", COL.text)
local hudRoute  = row(38, "Mapa: -", COL.muted)
local hudXtal   = row(56, "Oleada: -", COL.muted)
local hudAlert  = row(76, "Estado: detenido", COL.muted)

Game.registerEvent(Game.Events.HUD_DRAG, function(id, x, y)
  local dy
  for _,r in ipairs(rows) do if r.h:getId() == id then dy = r.dy end end
  if frame and frame:getId() == id then dy = -8; x = x + 10 end
  if not dy then return end -- no es de este panel
  HX, HY = x, y - dy
  for _,r in ipairs(rows) do r.h:setPos(HX, HY+r.dy) end
  if frame then frame:setPos(HX-10, HY-8) end
end)

-- Paso del diagrama segun la etapa interna.
local STEPS = {
  npc="1/8 Ir al NPC", hi="2/8 Hi / expedition", empezar="2/8 Esperando inicio",
  xtal="4/8 Leer ubicacion del cristal", ruta="6/8 Hacia el cristal",
  cristal_ir="6/8 Junto al cristal", cristal_usar="7/8 Click en el cristal",
  oleada="7/8 Oleadas", kite="7/8 Barrido sur/norte", salida="8/8 Salida (Yes)", vuelta="8/8 Vuelta: TP -> NPC",
}

-- Estado: "ok" | "warn" (se limpia solo a los 10 s) | "err" (se queda).
local function alert(lvl, text)
  ST.alertLvl, ST.alertAt = lvl, now()
  setTxt(hudAlert, "Estado: "..text)
  paint(hudAlert, COL[lvl] or COL.ok)
  if lvl == "err" or (lvl == "warn" and CFG.LOG) then
    print("[Expeditions] "..(lvl=="err" and "ERROR: " or "AVISO: ")..text)
  end
end

local function status(text) setTxt(hudStep, "Paso "..(STEPS[ST.stage] or ST.stage)..(text and (" - "..text) or "")) end
local function setStage(s, text, msg)
  ST.stage, ST.at = s, now()
  status(nil)
  if msg and CFG.LOG then print("[Expeditions] "..msg) end
end

-- ================== Movimiento ==================
local DIRS = {{0,-1,0},{1,0,1},{0,1,2},{-1,0,3},{1,-1,4},{1,1,5},{-1,1,6},{-1,-1,7}}

-- Casillas con un objeto de CFG.BLOCK_IDS (objeto de arriba), cada 2 s como mucho.
-- (Map.getTiles() con todo su contenido era la llamada mas cara: quitada.)
local BLOCKED = {set={}, at=-99999}
local function refreshBlocked()
  if now() - BLOCKED.at < 2000 then return end
  BLOCKED.at = now()
  local set = {}
  for id in pairs(CFG.BLOCK_IDS) do
    local ok, list = pcall(Map.getAllPositionsWithTopItemId, id, true)
    if ok and type(list) == "table" then
      for _,q in ipairs(list) do set[q.x..":"..q.y..":"..q.z] = true end
    end
  end
  BLOCKED.set = set
end

local function free(x, y, z, ignoreMobs)
  if AVOID[x..":"..y..":"..z] or BLOCKED.set[x..":"..y..":"..z] then return false end
  -- (x,y,z, ignoreBlockPath, ignoreMagicField, ignoreMonsters, ignoreNpcs)
  return Map.isTileWalkable(x, y, z, false, true, ignoreMobs, ignoreMobs)
end

-- Flechas: primer paso (direccion 0..7) para quedar a <= range de goal. BFS
-- en un radio de 14 casillas atravesando monstruos; si no hay camino completo,
-- hacia la casilla alcanzable mas cercana.
local function firstStep(me, goal, range)
  local R = 10
  local seen = {[me.x..":"..me.y] = true}
  local memo = {}
  local function ok(x, y)  -- free() cacheado para esta busqueda
    local k = x..":"..y
    local v = memo[k]
    if v == nil then v = free(x, y, me.z, true) and true or false; memo[k] = v end
    return v
  end
  local q, head = {{me.x, me.y, nil}}, 1
  local best, bestD = nil, dist(me, goal)
  while head <= #q do
    local c = q[head]; head = head + 1
    for _,d in ipairs(DIRS) do
      local nx, ny = c[1]+d[1], c[2]+d[2]
      local k = nx..":"..ny
      if not seen[k] and math.abs(nx-me.x) <= R and math.abs(ny-me.y) <= R then
        seen[k] = true
        local diag = d[1] ~= 0 and d[2] ~= 0
        if ok(nx, ny) and (not diag or (ok(nx, c[2]) and ok(c[1], ny))) then
          local first = c[3] or d[3]
          local dg = math.max(math.abs(goal.x-nx), math.abs(goal.y-ny))
          if dg <= range then return first end
          if dg < bestD then best, bestD = first, dg end
          q[#q+1] = {nx, ny, first}
        end
      end
    end
  end
  return best
end

-- Flechas? Dentro de la instancia y: mapa en CFG.ARROW_MAPS, o yendo por la
-- ruta hacia un nodo del tramo grabado (a=true).
local function useArrows(me)
  if me.z ~= CFG.INSTANCE_Z or not ST.route then return false end
  if CFG.ARROW_MAPS[ST.route.map] then return true end
  local w = ST.stage == "ruta" and ST.route.wps[ST.idx]
  return w and w.a or false
end

-- Camina hacia goal. true = ya esta a <= range.
-- Map click: solo vuelve a clicar si cambia el destino o lleva CLICK_RETRY_MS
-- sin moverse. Flechas (mapas de ARROW_MAPS): un paso en cada tick.
local function walkTo(me, goal, range)
  if dist(me, goal) <= range then return true end
  if me.z ~= goal.z then return false end
  if useArrows(me) then
    -- solo si ya ha cambiado de casilla desde el ultimo paso (o lleva 300 ms)
    local L = ST.lastStep
    if L and L.x == me.x and L.y == me.y and now() - L.t < 300 then return false end
    refreshBlocked()
    local d = firstStep(me, goal, range)
    if d then Game.walk(d); ST.lastStep = {x=me.x, y=me.y, t=now()} end
    return false
  end
  local g = ST.clickGoal
  local changed = not g or g.x ~= goal.x or g.y ~= goal.y or g.z ~= goal.z
  if changed or (now() - ST.clickT >= CFG.CLICK_RETRY_MS and now() - ST.movedAt >= CFG.CLICK_RETRY_MS) then
    ST.clickGoal, ST.clickT = {x=goal.x, y=goal.y, z=goal.z}, now()
    Map.goTo(goal.x, goal.y, goal.z)
  end
  return false
end

-- Monstruos cerca del cristal (cache 200 ms): cuantos, el mas cercano a mi,
-- si hay alguno pegado y su centro.
local function waveMonsters(me)
  local M = ST.mon
  if now() - M.at < 500 then return M end
  local n, near, adj, sx, sy = 0, nil, false, 0, 0
  local ok, list = pcall(Map.getCreatures, true, false)
  if ok and type(list) == "table" then
    for _,c in ipairs(list) do
      local q = c.position
      if c.isMonster and q and q.z == me.z and ST.crystal and dist(q, ST.crystal) <= CFG.KITE_RADIUS then
        n = n + 1; sx, sy = sx + q.x, sy + q.y
        local d = dist(q, me)
        if d <= 1 then adj = true end
        if not near or d < near then near = d end
      end
    end
  end
  M = {n=n, near=near, adj=adj, cx=n>0 and sx/n or 0, cy=n>0 and sy/n or 0, at=now()}
  ST.mon = M
  return M
end

-- Casilla libre (o esa misma) mas cercana a x,y en un radio de 3.
local function freeNear(x, y, z)
  refreshBlocked()
  for r = 0, 3 do
    for dx = -r, r do
      for dy = -r, r do
        if math.max(math.abs(dx), math.abs(dy)) == r and free(x+dx, y+dy, z, false) then
          return {x=x+dx, y=y+dy, z=z}
        end
      end
    end
  end
  return nil
end

-- Pisar una casilla concreta (TP / casilla del NPC): map click sobre ella.
local function stepOnto(me, t)
  walkTo(me, t, 0)
end

-- ================== Seleccion de ruta segun el cristal ==================
local function nearestNode(r, me)
  local bi, bd = 1, nil
  for i,w in ipairs(r.wps) do
    local d = dist(me, {x=w[1], y=w[2], z=r.crystal.z})
    if not bd or d < bd then bi, bd = i, d end
  end
  return bi
end

local function pickRoute(c, me)
  for _,r in ipairs(ROUTES) do
    if dist(r.crystal, c) <= CFG.MATCH_TILES then return r, true end
  end
  -- sin ruta exacta: la del mismo mapa (entrada cerca) con el cristal mas cercano
  local best, bestD
  for _,r in ipairs(ROUTES) do
    local s = r.wps[1]
    if dist(me, {x=s[1], y=s[2], z=r.crystal.z}) <= 30 then
      local d = dist(r.crystal, c)
      if not bestD or d < bestD then best, bestD = r, d end
    end
  end
  return best, false
end

-- ================== Ciclo ==================
local function inInstance(p) return p.z == CFG.INSTANCE_Z end
local function nearSafe(p) return p.z == CFG.SAFE_SPOT.z and dist(p, CFG.SAFE_SPOT) <= 6 end

local function toggle()
  if ST.stage == "off" then
    Engine.enableCaveBot(false)
    ST.tries = 0
    setTxt(hudTitle, "[ON]  Eloria Expeditions"); paint(hudTitle, COL.on)
    setStage("npc", nil, "activado: detectando en que punto estoy")
    alert("ok", "OK")
  else
    setTxt(hudTitle, "[OFF] Eloria Expeditions"); paint(hudTitle, COL.off)
    setStage("off", nil, "desactivado")
    setTxt(hudStep, "Paso: -")
    alert("ok", "detenido")
  end
end
hudTitle:setCallback(toggle)

Timer("eloria-expeditions", function()
  ST.clock = math.max(ST.clock + TICK_MS, os.time()*1000)
  if ST.stage == "off" then return end
  if not Client.isConnected() or Player.getId() == 0 then return end
  local p = pos(); if not p then return end

  if not ST.lastP or p.x ~= ST.lastP.x or p.y ~= ST.lastP.y or p.z ~= ST.lastP.z then
    ST.lastP, ST.movedAt = {x=p.x, y=p.y, z=p.z}, now()
  end

  if ST.alertLvl == "warn" and now() - ST.alertAt > 10000 then alert("ok", "OK") end
  local X = ST.xtal
  if X and (X ~= ST.shownX or ST.clicks ~= ST.shownC) then
    ST.shownX, ST.shownC = X, ST.clicks
    paint(hudXtal, COL.text)
    setTxt(hudXtal, X.cleared and "Oleada: cristal destruido"
      or X.phase == 0 and "Oleada: cristal dormido" or string.format("Oleada %d/3", X.phase))
  end

  local s = ST.stage

  -- Fuera de la sala a mitad de expedicion (muerte, etc.): volver a empezar
  if (s == "ruta" or s == "cristal_ir" or s == "cristal_usar" or s == "oleada" or s == "kite") and not inInstance(p) then
    if nearSafe(p) then setStage("vuelta", nil, "fuera de la sala, en el safe spot")
    else setStage("npc", nil, "fuera de la sala, vuelvo al NPC"); alert("warn", "fuera de la sala (muerte?)") end
    return
  end

  -- 1) NPC
  if s == "npc" then
    if inInstance(p) then setStage("xtal", nil, "ya estoy en la sala"); return end
    if nearSafe(p) then setStage("vuelta", nil, "estoy en el safe spot"); return end
    if dist(p, CFG.NPC_POS) == 0 then
      ST.xtal, ST.warned = nil, false
      setTxt(hudRoute, "Mapa: -"); paint(hudRoute, COL.muted)
      setTxt(hudXtal, "Oleada: -"); paint(hudXtal, COL.muted)
      Game.talk("hi", Enums.TalkTypes.SAY)
      setStage("hi", nil, "en el NPC, hi")
    else
      stepOnto(p, CFG.NPC_POS)
    end
    return
  end

  -- 2) hi -> expeditions
  if s == "hi" then
    if now() - ST.at > CFG.WORD_GAP_MS then
      Game.talk("expeditions", Enums.TalkTypes.SAY)
      setStage("empezar", nil, "expeditions")
    end
    return
  end

  -- 3) Esperar a entrar (No -> repetir hi/expeditions)
  if s == "empezar" then
    if inInstance(p) or dist(p, CFG.NPC_POS) > 15 then
      ST.tries = 0
      setStage("xtal", nil, "dentro de la sala")
      return
    end
    if now() - ST.at > CFG.START_WAIT_MS then
      ST.tries = ST.tries + 1
      if ST.tries >= CFG.START_TRIES then
        setTxt(hudTitle, "[OFF] Eloria Expeditions"); paint(hudTitle, COL.off)
        setStage("off", nil, "la expedicion no empieza, paro")
        alert("err", "no empieza tras "..ST.tries.." intentos: vigilante Ctrl+T?")
      else
        setStage("npc", nil, "no empieza, repito hi/expeditions")
        alert("warn", "no empieza, reintento "..ST.tries.."/"..CFG.START_TRIES)
      end
    end
    return
  end

  -- 4) Leer ubicacion del cristal + 5) seleccion segun coordenadas
  if s == "xtal" then
    local X = ST.xtal
    if X and X.cleared and X.z == p.z then
      setStage("salida", nil, "retomo: el cristal ya esta roto, espero el Yes")
      return
    end
    if X and not X.cleared and X.z == p.z then
      local r, exact = pickRoute(X, p)
      if not r then
        if due("noroute", 5000) then alert("err", "cristal "..X.x..","..X.y.." sin ruta en la tabla") end
        return
      end
      ST.route, ST.idx = r, nearestNode(r, p)
      ST.crystal = {x=X.x, y=X.y, z=X.z}
      ST.binding, ST.destroyed, ST.clicks = false, false, X.phase
      if ST.idx > 1 or X.phase > 0 then
        if CFG.LOG then print("[Expeditions] retomo: nodo "..ST.idx.."/"..#r.wps..", cristal en fase "..X.phase) end
      end
      paint(hudRoute, COL.text)
      setTxt(hudRoute, "Mapa: "..r.map)
      if not exact then alert("warn", "cristal sin ruta exacta, uso la mas cercana") end
      setStage("ruta", nil,
        "cristal "..X.x..","..X.y.." -> "..r.name..(exact and "" or " (sin ruta exacta, la mas cercana)"))
      return
    end
    if not ST.warned and now() - ST.at > CFG.XTAL_WARN_MS then
      ST.warned = true
      alert("warn", "no llega la posicion del cristal: vigilante Ctrl+T?")
    end
    return
  end

  -- 6) Movimiento hacia el cristal (No -> sigue hasta llegar)
  if s == "ruta" then
    local wps = ST.route.wps
    local w = wps[ST.idx]
    local node = {x=w[1], y=w[2], z=p.z}
    local need = w[3] and 0 or CFG.NODE_DIST
    if dist(p, node) <= need then
      ST.idx = ST.idx + 1
      if ST.idx > #wps then setStage("cristal_ir", nil, "fin de la ruta"); end
      return
    end
    if now() - ST.movedAt > CFG.STUCK_MS then
      ST.movedAt = now()
      ST.idx = math.min(ST.idx + 1, #wps)
      alert("warn", "atascado, salto al nodo "..ST.idx.."/"..#wps)
    end
    walkTo(p, node, need, true)
    status("nodo "..ST.idx.."/"..#wps)
    return
  end

  if s == "cristal_ir" then
    if dist(p, ST.crystal) == 1 then setStage("cristal_usar", nil); return end
    if useArrows(p) then
      walkTo(p, ST.crystal, 1)
    else
      -- map click: el cristal no se puede pisar, ir a la ultima casilla de la ruta (a 1)
      local w = ST.route.wps[#ST.route.wps]
      walkTo(p, {x=w[1], y=w[2], z=p.z}, 0)
    end
    return
  end

  -- 7) Cristal y oleadas
  if s == "cristal_usar" then
    if dist(p, ST.crystal) ~= 1 then setStage("cristal_ir", nil); return end
    if due("use", 500) and Game.useItemFromGround(ST.crystal.x, ST.crystal.y, ST.crystal.z) then
      ST.clickPhase = ST.xtal and ST.xtal.phase
      ST.clickAt, ST.binding = now(), false
      ST.clicks = ST.clicks + 1
      ST.farSince = nil
      setStage("oleada", nil, "click en el cristal (fase "..tostring(ST.clickPhase)..")")
    end
    return
  end

  if s == "oleada" then
    local X = ST.xtal
    if ST.destroyed or (X and X.cleared) then
      setStage("salida", nil, "cristal destruido")
      return
    end
    if ST.binding then
      ST.binding = false
      setStage("cristal_usar", nil, "binding expuesto, siguiente click")
      return
    end
    if X and X.phase == ST.clickPhase and now() - ST.clickAt > CFG.CLICK_CHECK_MS then
      ST.clicks = math.max(0, ST.clicks - 1)
      setStage("cristal_usar", nil, "el cristal no reacciono, repito el click")
      alert("warn", "el cristal no reacciono (faltan kills?), re-click")
      return
    end
    -- Monstruos a distancia: nadie pegado y el mas cercano a > KITE_DIST
    if CFG.KITE_ON then
      local M = waveMonsters(p)
      if M.n > 0 and not M.adj and M.near and M.near > CFG.KITE_DIST then
        ST.farSince = ST.farSince or now()
        if now() - ST.farSince >= CFG.KITE_WAIT_MS then
          ST.farSince, ST.kiteLeg, ST.kiteTarget = nil, 0, nil
          setStage("kite", nil, "monstruos a distancia: barrido "..CFG.KITE_SQM.." al sur y "..CFG.KITE_SQM.." al norte del cristal")
        end
      else
        ST.farSince = nil
      end
    end
    return
  end

  -- 7b) Barrido sur/norte del cristal (como en las versiones anteriores)
  if s == "kite" then
    local X = ST.xtal
    if ST.destroyed or (X and X.cleared) then setStage("salida", nil, "cristal destruido"); return end
    if ST.binding then setStage("cristal_ir", nil, "binding expuesto, vuelvo al cristal"); return end
    -- tramo 1: KITE_SQM al sur; tramo 2: KITE_SQM al norte
    if not ST.kiteTarget or dist(p, ST.kiteTarget) == 0 or now() - ST.at > CFG.KITE_LEG_MS then
      if ST.kiteTarget and dist(p, ST.kiteTarget) ~= 0 then
        alert("warn", "no llegue al punto "..ST.kiteLeg.." del barrido, sigo")
      end
      ST.kiteLeg = ST.kiteLeg + 1
      if ST.kiteLeg > 2 then
        setStage("oleada", nil, "barrido hecho")
        return
      end
      local c = ST.crystal
      local dy = ST.kiteLeg == 1 and CFG.KITE_SQM or -CFG.KITE_SQM
      ST.kiteTarget, ST.at = freeNear(c.x, c.y + dy, c.z), now()
      if not ST.kiteTarget then
        alert("warn", "sin casilla libre para el punto "..ST.kiteLeg.." del barrido")
        return
      end
    end
    walkTo(p, ST.kiteTarget, 0, true)
    return
  end

  -- 8) Movimiento de vuelta
  if s == "salida" then
    if nearSafe(p) then setStage("vuelta", nil, "en el safe spot"); return end
    if now() - ST.at > 30000 and due("yeswarn", 30000) then
      alert("err", "sigo en la sala: nadie contesto 'Expedition complete'")
    end
    return
  end

  if s == "vuelta" then
    if p.z ~= CFG.TP_TILE.z or dist(p, CFG.TP_TILE) > 30 then
      setStage("npc", nil, "TP cruzado, al NPC")
      return
    end
    stepOnto(p, CFG.TP_TILE)
    return
  end
end, TICK_MS)

-- ================== Eventos ==================
Game.registerEvent(Game.Events.TEXT_MESSAGE, function(m)
  if type(m) ~= "table" then return end
  local txt = tostring(m.text or "")
  local x, y, z, ph, cl, tk = txt:match("^XTAL (%d+) (%d+) (%d+) (%d+) (%a+) (%S+)")
  if x then
    ST.xtal = {x=tonumber(x), y=tonumber(y), z=tonumber(z), phase=tonumber(ph), cleared=(cl=="true"), token=tk}
    return
  end
  local low = txt:lower()
  if low:find("the binding is exposed", 1, true) then ST.binding = true end
  if low:find("corrupted crystal destroyed", 1, true) then ST.destroyed = true end
end)

-- Respaldo del vigilante: "Expedition complete" -> Yes
Game.registerEvent(Game.Events.MODAL_WINDOW, function(m)
  if type(m) ~= "table" or ST.stage == "off" then return end
  if not tostring(m.title or ""):lower():find("expedition complete", 1, true) then return end
  for _,b in ipairs(m.buttons or {}) do
    if tostring(b.text or b.name or b[2] or ""):lower() == "yes" then
      Game.modalWindowAnswer(m.id, b.id or b[1], 0, true)
      if CFG.LOG then print("[Expeditions] 'Expedition complete' -> Yes") end
      return
    end
  end
end)
hudStep:hide()  -- mod: sin la fila de pasos

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
    if ExpModPotsOff then return why("apagadas (Panel Eloria)") end
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

local CONFIG={x=20,y=120,font=13,rowHeight=22}

local E = {version='4.6', enabled={}, fish={}, expanded='runners', widgets={}, timers={},
  status='Gotowy', errors={}, due={}, visits={}, blocked={}, rockDone={}, session={},
  boss={category=1,wave=5,stage='IDLE',statue={x=31595,y=17406,z=5},tried={}},
  dungeon={index=1,stage='IDLE',statue={x=14232,y=19348,z=3},skipped=0},
  bosstiary={index=1,room=1,stage='APPROACH'}, mining={stage='IDLE'}, alive=true}
local C={text='#e6edf5',muted='#97a9bb',on='#58e0ac',off='#ecad71',blue='#70cfff',red='#ff8080'}
local dirs={{0,-1,0},{1,0,1},{0,1,2},{-1,0,3},{1,-1,4},{1,1,5},{-1,1,6},{-1,-1,7}}
local fishModes={
 {name='Fish',ids={4602,4597,4599,4601,629,4600,622}},
 {name='Shimmer',ids={12560}}, {name='Sandfish',ids={13988}},
 {name='Old Nasty',ids={12560}}, {name='Rainbow',ids={7236}}, {name='Northern',ids={7236}}}
local fishCursor=0
E.clock=os.time()*1000
local function now() return E.clock end
local function pos() return Player.getPosition() end
local function copy(p) return p and {x=p.x,y=p.y,z=p.z} end
local function key(p) return p.x..':'..p.y..':'..p.z end
local function dist(a,b) if not a or not b or a.z~=b.z then return 99999 end return math.max(math.abs(a.x-b.x),math.abs(a.y-b.y)) end
local function same(a,b) return a and b and a.x==b.x and a.y==b.y and a.z==b.z end
local function teleport(a,b) return a and b and (a.z~=b.z or dist(a,b)>4) end
local function due(k,ms) local t=now(); if t<(E.due[k] or 0) then return false end E.due[k]=t+ms; return true end
local function status(s) E.status=s end
local function safe(tag,fn)
  if now()<(E.errors[tag..'retry'] or 0) then return end
  local ok,err=pcall(fn)
  if not ok then
    E.errors[tag]=(E.errors[tag] or 0)+1; E.errors[tag..'retry']=now()+5000
    status(tag..': '..tostring(err):sub(1,110))
    print('HUD '..tag..': '..tostring(err))
    if E.errors[tag]>=3 then E.enabled[tag]=false end
  else E.errors[tag]=0 end
end
E.api={Game=Game,Map=Map}
local function apiReady() return true end
local function count(k,n) E.session[k]=(E.session[k] or 0)+(n or 1) end
local function short(n)
  n=tonumber(n) or 0
  if math.abs(n)>=1000000000 then return string.format('%.2fkkk',n/1000000000) end
  if math.abs(n)>=1000000 then return string.format('%.2fkk',n/1000000) end
  if math.abs(n)>=1000 then return string.format('%.1fk',n/1000) end
  return string.format('%.0f',n)
end
local function readExperience()
  if type(Player.getExperience)~='function' then return nil end
  local ok,value=pcall(Player.getExperience)
  if ok then return tonumber(value) end
end
function E.resetSession()
  E.session={start=now(),level=tonumber(Player.getLevel()) or 0,
    experienceStart=readExperience(),damage=0,damageSeen=false,dps=0,
    maxHit=0,target='-',peak=0,hits={},messages=0,damageEvents=0,samples={}}
end
local function sampleStats()
  local s=E.session;if not s.start then E.resetSession();s=E.session end
  local t=now();local sum=0
  while s.hits[1] and s.hits[1].t<=t-10000 do table.remove(s.hits,1) end
  for _,hit in ipairs(s.hits) do sum=sum+hit.v end
  s.dps=sum/math.max(1,math.min(10,(t-s.start)/1000));s.peak=math.max(s.peak,s.dps)
  if Client.isConnected() then
    local xp=readExperience()
    if xp then
      if s.experienceStart==nil then s.experienceStart=xp end
      s.experience=xp-s.experienceStart
      s.experienceHour=s.experience*3600000/math.max(1000,t-s.start)
    end
  end
end
local function damageMessage(message)
  if type(message)~='table' then return end
  local s=E.session;s.messages=s.messages+1
  local mode=tonumber(message.messageType)
  local text=tostring(message.text or '')
  -- Bounded diagnostic history, printed only on explicit HUD click.
  s.samples[#s.samples+1]={mode=tostring(message.messageType),text=text:sub(1,220)}
  if #s.samples>12 then table.remove(s.samples,1) end
  local types=Enums.MessageTypes or {}
  local dealt=mode==(tonumber(types.MESSAGE_DAMAGE_DEALT) or 23)
  if dealt then s.damageEvents=s.damageEvents+1 end
  local lower=text:lower()
  -- Accept other categories only when text explicitly identifies our attack.
  local own=lower:find('due to your attack',1,true)~=nil
    or lower:match('^you deal%s+%d')~=nil
  if not dealt and not own then return end
  if lower:match('^you lose') or lower:find('healed',1,true) then return end
  local amount=0
  if dealt then
    amount=math.max(0,tonumber(message.messagePrimaryValue) or 0)
      +math.max(0,tonumber(message.messageSecondaryValue) or 0)
  end
  if amount<=0 then
    local value=lower:match('loses%s+([%d,]+)%s+hitpoints')
      or lower:match('loses%s+([%d,]+)%s+hit points')
      or lower:match('^you deal%s+([%d,]+)%s+damage')
    if value then amount=tonumber((value:gsub(',',''))) or 0 end
  end
  if amount<=0 then return end
  s.damageSeen=true;s.damage=s.damage+amount
  s.hits[#s.hits+1]={t=now(),v=amount}
  if amount>s.maxHit then
    s.maxHit=amount;s.target=text:match('^(.+)%s+loses%s+[%d,]+') or '-'
  end
end


local function stopMovement()
  E.pending=nil; E.nav=nil
end
local function step(direction)
  local p=pos(); if not p or not apiReady() then return false end
  local t=now();local pending=E.pending
  if pending then
    if not same(p,pending.from) then E.pending=nil
    elseif t-pending.at<math.max(700,pending.timeout or 0) then return false
    else E.blocked[key(p)..':'..pending.direction]=t+10000;E.pending=nil end
  end
  if t<(E.blocked[key(p)..':'..direction] or 0) then return false end
  if not due('step',100) then return false end
  if E.api.Game.walk(direction) then
    E.pending={from=copy(p),at=t,direction=direction,timeout=math.max(700,(Client.getLatency and Client.getLatency() or 0)*2+350)}
    return true
  end
  return false
end
local function screen()
  if not E.tiles or now()>=(E.due.mapScan or 0) then
    E.due.mapScan=now()+600
    E.tiles=E.api.Map.getTiles(); E.grid={}
    for _,tile in ipairs(E.tiles) do E.grid[key(tile.position)]=tile end
  end
  return E.tiles
end
local function walkable(p)
  if not E.grid[key(p)] then return false end
  return E.api.Map.isTileWalkable(p.x,p.y,p.z,false,true,false,false)
end
local function route(target,range)
  local origin=pos(); if not origin or not target or origin.z~=target.z then return nil end
  screen(); local q,seen={{p=origin}},{[key(origin)]=true};local head=1
  while head<=#q and head<=700 do
    local node=q[head];head=head+1
    if dist(node.p,target)<=range then return node.first end
    for _,d in ipairs(dirs) do
      local p={x=node.p.x+d[1],y=node.p.y+d[2],z=node.p.z};local k=key(p)
      local edge=key(node.p)..':'..d[3]
      if not seen[k] and now()>=(E.blocked[edge] or 0) and walkable(p) then
        local diagonal=d[1]~=0 and d[2]~=0
        if not diagonal or (walkable({x=p.x,y=node.p.y,z=p.z}) and walkable({x=node.p.x,y=p.y,z=p.z})) then
          seen[k]=true;q[#q+1]={p=p,first=node.first or d[3]}
        end
      end
    end
  end
end
local function go(target,range)
  range=range or 1;local p=pos();if dist(p,target)<=range then return true end
  local d=route(target,range); if d~=nil then step(d) end
  return false
end
local function findItem(ids,near,radius)
  local best,bestDistance
  for _,t in ipairs(screen()) do
    if not near or dist(t.position,near)<=(radius or 99999) then
      for _,item in ipairs(t.things) do
        if ids[item.id] then
          local d=dist(pos(),t.position)
          if not bestDistance or d<bestDistance then best=copy(t.position);bestDistance=d end
          break
        end
      end
    end
  end
  return best
end
local function useGround(p,tag)
  if not p or not due(tag or 'useGround',1200) then return false end
  return E.api.Game.useItemFromGround(p.x,p.y,p.z)
end
local function inLobby(b,p) return p and p.z==b.statue.z and dist(p,b.statue)<=10 end
local function nextBoss()
  local b=E.boss;b.tried[b.category]=true;b.stage='IDLE';b.startedAt=nil
  for i=1,3 do local c=b.category%3+1;b.category=c;if not b.tried[c] then return end end
  b.tried={};b.restUntil=now()+60000;status('Boss Run: kategorie sprawdzone, przerwa 60 s')
end
local function bossTick()
  local b,p=E.boss,pos();if not p then return end
  if now()<(b.restUntil or 0) then return end
  if b.stage=='WAIT_TELEPORT' then
    if teleport(b.origin,p) and not inLobby(b,p) then
      b.stage='ENTRY';b.entry=copy(p);b.entryY=p.y-4;b.entryAt=now();count('bossEntered')
    elseif now()-b.startedAt>10000 then nextBoss();status('Boss Run: brak wejscia, kolejna kategoria') end
    return
  end
  if b.stage=='ENTRY' then
    if p.z~=b.entry.z or inLobby(b,p) then b.stage='IDLE';return end
    if p.y<=b.entryY then b.stage='FIGHT';status('Boss Run: walka / 4 kroki wykonane')
    else step(0);status('Boss Run: wejscie '..math.min(4,b.entry.y-p.y)..'/4 N') end
    return
  end
  if b.stage=='FIGHT' then
    if inLobby(b,p) then count('boss'..b.category);nextBoss() end
    return
  end
  if not inLobby(b,p) then status('Boss Run: podejdz do pokoju z posagiem');return end
  local found=findItem({[46087]=true},b.statue,12);if found then b.statue=found end
  if not go(b.statue,1) then status('Boss Run: podchodze do posagu');return end
  if type(Game.bossSequenceStart)~='function' then
    E.enabled.boss=false;status('Boss Run: klient nie udostepnia API');return
  end
  -- GD7 checks that the statue panel is live before sending this command.
  -- Category, full mode and wave size are encoded in that single API call.
  if due('bossPanel',650) and Game.bossSequenceStart(b.category,b.wave) then
    b.stage='WAIT_TELEPORT';b.origin=copy(p);b.startedAt=now()
    status('Boss Run: Full / '..b.wave..' - czekam na teleport')
  else
    useGround(b.statue,'bossStatue');status('Boss Run: otwieram panel')
  end
end
local function option(v) return v.id or v[1],tostring(v.text or v.name or v[2] or '') end
local function button(modal,pattern)
  for _,b in ipairs(modal.buttons or {}) do local id,text=option(b);if text:lower():match(pattern) then return id end end
end
local function answer(m,buttonId,choiceId)
  if not buttonId or E.modal~=m or m.answered then return false end
  m.answered=true
  local accepted=Game.modalWindowAnswer(m.id,buttonId,choiceId or 0,true)
  if accepted==false then m.answered=false;return false end
  E.modal=nil;return true
end
local function cooldown(text)
  local lower=text:lower()
  if lower:find('%[cd:%s*0%s*%]') or lower:find('%[cd:%s*00:00%s*%]')
    or lower:find('cooldown:%s*none') or lower:find('cooldown:%s*0%s+seconds')
    or lower:find('cooldown:%s*00:00:00') then return false end
  return lower:find('cooldown') or lower:find('%[cd:') or lower:find('exhaust')
    or lower:find('you need to wait',1,true) or lower:find('you have to wait',1,true)
end
local function declaredButton(m,id)
  if id==nil then return nil end
  for _,v in ipairs(m.buttons) do local actual=option(v);if actual==id then return id end end
end

local BOSSTIARY_ENTRIES = {
    {index=1, x=15508,y=15267,z=0, name="bullwark"}, {index=2, x=15509,y=15265,z=0, name="deep terror"},
    {index=3, x=15509,y=15269,z=0, name="latrivan"}, {index=4, x=15511,y=15265,z=0, name="professor maxxen"},
    {index=5, x=15511,y=15269,z=0, name="hellgorak"}, {index=6, x=15513,y=15265,z=0, name="the lord of the lice"},
    {index=7, x=15513,y=15269,z=0, name="madareth"}, {index=8, x=15515,y=15265,z=0, name="lisa"},
    {index=9, x=15515,y=15269,z=0, name="annihilon"}, {index=10, x=15517,y=15265,z=0, name="evil mastermind"},
    {index=11, x=15517,y=15269,z=0, name="golgordan"}, {index=12, x=15519,y=15265,z=0, name="heoni"},
    {index=13, x=15519,y=15269,z=0, name="ushuriel"}, {index=14, x=15521,y=15265,z=0, name="mephiles"},
    {index=15, x=15521,y=15269,z=0, name="zugurosh"}, {index=16, x=15523,y=15265,z=0, name="dazed leaf golem"},
    {index=17, x=15523,y=15269,z=0, name="thalas"}, {index=18, x=15525,y=15265,z=0, name="owin"},
    {index=19, x=15525,y=15269,z=0, name="vashresamun"}, {index=20, x=15527,y=15265,z=0, name="the imperor"},
    {index=21, x=15527,y=15269,z=0, name="mahrdis"}, {index=22, x=15529,y=15265,z=0, name="mr. punish"},
    {index=23, x=15529,y=15269,z=0, name="ashmunrah"}, {index=24, x=15531,y=15265,z=0, name="massacre"},
    {index=25, x=15531,y=15269,z=0, name="morguthis"}, {index=26, x=15533,y=15265,z=0, name="grand canon dominus"},
    {index=27, x=15533,y=15269,z=0, name="the ravager"}, {index=28, x=15535,y=15265,z=0, name="grand commander soeren"},
    {index=29, x=15535,y=15269,z=0, name="dipthrah"}, {index=30, x=15537,y=15265,z=0, name="grand chaplain gaunder"},
    {index=31, x=15537,y=15269,z=0, name="omruc"}, {index=32, x=15539,y=15265,z=0, name="preceptor lazare"},
    {index=33, x=15539,y=15269,z=0, name="horestis"}, {index=34, x=15549,y=15265,z=0, name="bane lord"},
    {index=35, x=15549,y=15269,z=0, name="rahemos"}, {index=36, x=15551,y=15265,z=0, name="fleshslicer"},
    {index=37, x=15551,y=15269,z=0, name="glooth fairy"}, {index=38, x=15553,y=15265,z=0, name="guard captain quaid"},
    {index=39, x=15553,y=15269,z=0, name="mawhawk"}, {index=40, x=15555,y=15265,z=0, name="gaffir"},
    {index=41, x=15555,y=15269,z=0, name="dirtbeard"}, {index=42, x=15557,y=15265,z=0, name="custodian"},
    {index=43, x=15557,y=15269,z=0, name="doctor perhaps"}, {index=44, x=15559,y=15265,z=0, name="ekatrix"},
    {index=45, x=15559,y=15269,z=0, name="the welter"}, {index=46, x=15561,y=15265,z=0, name="grand mother foulscale"},
    {index=47, x=15561,y=15269,z=0, name="monstor"}, {index=48, x=15563,y=15265,z=0, name="glitterscale"},
    {index=49, x=15563,y=15269,z=0, name="boogey"}, {index=50, x=15565,y=15265,z=0, name="thawing dragon lord"},
    {index=51, x=15565,y=15269,z=0, name="jailer"}, {index=52, x=15567,y=15265,z=0, name="dracola"},
    {index=53, x=15567,y=15269,z=0, name="black knight"}, {index=54, x=15569,y=15265,z=0, name="tyrn"},
    {index=55, x=15569,y=15269,z=0, name="raging mage"}, {index=56, x=15571,y=15265,z=0, name="chizzoron the distorter"},
    {index=57, x=15571,y=15269,z=0, name="mad mage"}, {index=58, x=15573,y=15265,z=0, name="zorvorax"},
    {index=59, x=15573,y=15269,z=0, name="zushuka"}, {index=60, x=15575,y=15265,z=0, name="gelidrazah the frozen"},
    {index=61, x=15575,y=15269,z=0, name="diseased fred"}, {index=62, x=15577,y=15265,z=0, name="kalyassa"},
    {index=63, x=15577,y=15269,z=0, name="diseased bill"}, {index=64, x=15579,y=15265,z=0, name="tazhadur"},
    {index=65, x=15579,y=15269,z=0, name="diseased dan"}, {index=66, x=15581,y=15265,z=0, name="ancient spawn of morgathla"},
    {index=67, x=15581,y=15269,z=0, name="mozradek"}, {index=68, x=15583,y=15265,z=0, name="the shatterer"},
    {index=69, x=15583,y=15269,z=0, name="xogixath"}, {index=70, x=15585,y=15265,z=0, name="bragrumol"},
    {index=71, x=15585,y=15267,z=0, name="zulazza the corruptor"}, {index=72, x=15585,y=15269,z=0, name="the handmaiden"},
    {index=73, x=15546,y=15275,z=0, name="the lily of night"}, {index=74, x=15542,y=15275,z=0, name="the blazing rose"},
    {index=75, x=15542,y=15280,z=0, name="the diamond blossom"}, {index=76, x=15546,y=15280,z=0, name="the winter bloom"},
    {index=77, x=15537,y=15289,z=0, name="the plasmother"}, {index=78, x=15537,y=15293,z=0, name="countess sorrow"},
    {index=79, x=15539,y=15289,z=0, name="the voice of ruin"}, {index=80, x=15539,y=15293,z=0, name="warlord ruzad"},
    {index=81, x=15549,y=15289,z=0, name="the moonlight aster"}, {index=82, x=15549,y=15293,z=0, name="hairman the huge"},
    {index=83, x=15551,y=15289,z=0, name="the flaming orchid"}, {index=84, x=15551,y=15293,z=0, name="foreman kneebiter"},
    {index=85, x=15553,y=15289,z=0, name="lord of the elements"}, {index=86, x=15553,y=15293,z=0, name="jesse the wicked"},
    {index=87, x=15555,y=15289,z=0, name="dreadmaw"}, {index=88, x=15555,y=15293,z=0, name="smuggler baron silvertoe"},
    {index=89, x=15557,y=15289,z=0, name="zomba"}, {index=90, x=15557,y=15293,z=0, name="general murius"},
    {index=91, x=15559,y=15289,z=0, name="fleabringer"}, {index=92, x=15559,y=15293,z=0, name="barbaria"},
    {index=93, x=15561,y=15289,z=0, name="the abomination"}, {index=94, x=15561,y=15293,z=0, name="xenia"},
    {index=95, x=15563,y=15289,z=0, name="the frog prince"}, {index=96, x=15563,y=15293,z=0, name="white pale"},
    {index=97, x=15565,y=15289,z=0, name="rukor zad"}, {index=98, x=15565,y=15293,z=0, name="man in the cave"},
    {index=99, x=15567,y=15289,z=0, name="groam"}, {index=100, x=15567,y=15293,z=0, name="dharalion"},
    {index=101, x=15569,y=15289,z=0, name="elvira hammerthrust"}, {index=102, x=15569,y=15293,z=0, name="willi wasp"},
    {index=103, x=15571,y=15289,z=0, name="rotworm queen"}, {index=104, x=15571,y=15293,z=0, name="the blightfather"},
    {index=105, x=15573,y=15289,z=0, name="mornenion"}, {index=106, x=15573,y=15293,z=0, name="big boss trolliver"},
    {index=107, x=15575,y=15289,z=0, name="gravelord oshuran"}, {index=108, x=15575,y=15293,z=0, name="robby the reckless"},
    {index=109, x=15577,y=15289,z=0, name="the evil eye"}, {index=110, x=15577,y=15293,z=0, name="furyosa"},
    {index=111, x=15579,y=15289,z=0, name="captain jones"}, {index=112, x=15579,y=15293,z=0, name="yakchal"},
    {index=113, x=15581,y=15289,z=0, name="hirintror"}, {index=114, x=15581,y=15293,z=0, name="ocyakao"},
    {index=115, x=15583,y=15289,z=0, name="the percht queen"}, {index=116, x=15583,y=15293,z=0, name="yaga the crone"},
    {index=117, x=15585,y=15291,z=0, name="grorlam"}, {index=118, x=15585,y=15293,z=0, name="grandfather tridian"},
    {index=119, x=15542,y=15299,z=0, name="zevelon duskbringer"}, {index=120, x=15542,y=15304,z=0, name="diblis the fair"},
    {index=121, x=15544,y=15307,z=0, name="the pale count"}, {index=122, x=15546,y=15299,z=0, name="arachir the ancient one"},
    {index=123, x=15546,y=15304,z=0, name="sir valorcrest"}
}
-- Bosstiary control flow adapted from the user's BOSSTIARY.lua.
-- Uses the HUD timer and modal listener; no extra HUD, chat messages or blocking waits.
local function advanceBosstiary()
  local b=E.bosstiary
  b.room=b.room+1
  if b.room>5 then b.room=1;b.index=b.index+1 end
  if b.index>#BOSSTIARY_ENTRIES then b.index=1;b.cycles=(b.cycles or 0)+1 end
  b.stage='APPROACH';b.origin=nil;b.sentAt=nil;b.bossSeen=false
  b.lastMovePos=nil;b.stuck=0;E.pending=nil;E.tiles=nil
  status('Bosstiary: '..BOSSTIARY_ENTRIES[b.index].name..' / sala '..b.room)
end
local function bosstiaryWalkTo(target)
  local b,p=E.bosstiary,pos();if not p or p.z~=target.z then return end
  if not due('bosstiaryWalk',500) then return end
  if same(p,b.lastMovePos) then b.stuck=(b.stuck or 0)+1 else b.stuck=0 end
  b.lastMovePos=copy(p)
  if dist(p,target)<=45 and (b.stuck or 0)<3 then
    Map.goTo(target.x,target.y,target.z);return
  end
  -- Recalculate a reachable partial route when the destination is outside
  -- the autowalk range, including the final boss -> first boss leg.
  screen()
  local q={{p=p}};local seen={[key(p)]=true};local head=1
  local best,score
  while head<=#q and head<=700 do
    local node=q[head];head=head+1
    if node.first~=nil then
      local value=dist(node.p,target)*100+(E.bosstiary.routeVisits and E.bosstiary.routeVisits[key(node.p)] or 0)*5
      if not score or value<score then best=node;score=value end
    end
    if same(node.p,target) then best=node;break end
    for _,d in ipairs(dirs) do
      local n={x=node.p.x+d[1],y=node.p.y+d[2],z=p.z};local k=key(n)
      if not seen[k] and now()>=(E.blocked[key(node.p)..':'..d[3]] or 0) and (same(n,target) or walkable(n)) then
        if d[1]==0 or d[2]==0 or (walkable({x=n.x,y=node.p.y,z=p.z}) and walkable({x=node.p.x,y=n.y,z=p.z})) then
          seen[k]=true;q[#q+1]={p=n,first=node.first or d[3]}
        end
      end
    end
  end
  b.routeVisits=b.routeVisits or {}
  b.routeVisits[key(p)]=(b.routeVisits[key(p)] or 0)+1
  if best and best.first~=nil then step(best.first)
  else status('Bosstiary: sin camino a '..(target.name or 'la salida')) end
end
local function bosstiaryModal(m)
  local b=E.bosstiary
  if b.stage~='APPROACH' and b.stage~='MODAL' then return end
  if dist(pos(),BOSSTIARY_ENTRIES[b.index])>2 then return end
  local choice
  for _,v in ipairs(m.choices) do
    local id,label=option(v)
    if tonumber(label:lower():match('room%s*(%d+)'))==b.room then choice=id;break end
  end
  if choice==nil then return end
  if now()-m.at<500 then return end
  local enter=button(m,'enter') or button(m,'select') or button(m,'^ok$') or declaredButton(m,m.defaultEnter)
  if answer(m,enter,choice) then
    b.origin=copy(pos());b.sentAt=now();b.stage='WAIT_TELEPORT'
    b.lastMovePos=nil;b.stuck=0
  end
end
local function bosstiaryTick()
  local b,p=E.bosstiary,pos();if not p then return end
  local target=BOSSTIARY_ENTRIES[b.index]
  if not target then b.index=1;b.room=1;target=BOSSTIARY_ENTRIES[1] end
  -- Handle an automatic return in BOTH room states, before monster/exit logic.
  if (b.stage=='FIGHT' or b.stage=='EXIT') and dist(p,target)<=5 then
    advanceBosstiary();return
  end
  if b.stage=='WAIT_TELEPORT' then
    if dist(p,target)>15 then
      b.stage='FIGHT';b.enteredAt=now();b.bossSeen=false;b.lastMovePos=nil;b.stuck=0
    elseif now()-(b.sentAt or now())>6000 then b.stage='APPROACH' end
    return
  end
  if b.stage=='FIGHT' then
    if not due('bosstiaryMonsters',500) then return end
    local mobs=0
    for _,id in ipairs(Map.getCreatureIds(true,false) or {}) do
      local creature=Creature(id)
      if creature and creature:getType()==Enums.CreatureTypes.CREATURETYPE_MONSTER and dist(p,creature:getPosition())<=10 then mobs=mobs+1 end
    end
    if mobs>0 then b.bossSeen=true;status('Bosstiary: '..target.name..' / pelea')
    elseif b.bossSeen or now()-(b.enteredAt or now())>4000 then b.stage='EXIT';b.exitAt=now();b.lastMovePos=nil;b.stuck=0 end
    return
  end
  if b.stage=='EXIT' then
    local exit=findItem({[22761]=true},p,10)
    if exit then bosstiaryWalkTo(exit);status('Bosstiary: vuelta por la salida 22761')
    elseif now()-(b.exitAt or now())>3000 then
      -- Wait briefly for automatic return, then search reachable visible tiles.
      local searchTarget
      for _,tile in ipairs(screen()) do
        if tile.position.z==p.z and dist(p,tile.position)>=4 and walkable(tile.position) then
          if not searchTarget or (b.routeVisits and b.routeVisits[key(tile.position)] or 0)<(b.routeVisits and b.routeVisits[key(searchTarget)] or 0) then searchTarget=tile.position end
        end
      end
      if searchTarget then bosstiaryWalkTo(searchTarget) end
      status('Bosstiary: busco la salida 22761')
    end
    return
  end
  if p.z~=target.z then status('Bosstiary: ve a la sala de entradas, piso '..target.z);return end
  if dist(p,target)==0 then
    if b.stage~='MODAL' then b.openAt=now() end
    b.stage='MODAL';status('Bosstiary: '..target.name..' / espero las salas')
    if now()-(b.openAt or now())>5000 then b.stage='APPROACH' end
    return
  end
  b.stage='APPROACH';bosstiaryWalkTo(target)
  status('Bosstiary: voy a '..target.name..' / sala '..b.room)
end

function E.onModal(id,title,message,buttons,defaultEnter,defaultEscape,choices,priority)
  if not E.alive then return end
  E.modal={id=id,title=tostring(title or ''),message=tostring(message or ''),buttons=buttons or {},choices=choices or {},at=now(),defaultEnter=defaultEnter,defaultEscape=defaultEscape}
end

local function explorationTarget(p)
  local m=E.mining
  m.seen=m.seen or {};m.failed=m.failed or {}
  for _,tile in ipairs(screen()) do
    if tile.position.z==p.z then m.seen[key(tile.position)]=true end
  end
  local q={{p=p,depth=0}};local seen={[key(p)]=true};local head=1
  local best,score
  while head<=#q and head<=700 do
    local node=q[head];head=head+1
    if node.depth>0 and now()>=(m.failed[key(node.p)] or 0) then
      local frontier=0
      for i=1,4 do local d=dirs[i]
        if not m.seen[key({x=node.p.x+d[1],y=node.p.y+d[2],z=p.z})] then frontier=frontier+1 end
      end
      local visits=E.visits[key(node.p)] or 0
      local momentum=m.heading and (node.p.x-p.x)*m.heading.x+(node.p.y-p.y)*m.heading.y or 0
      local value=frontier*1000-visits*35+node.depth*2+momentum*3
      if not score or value>score then best=copy(node.p);score=value end
    end
    for _,d in ipairs(dirs) do
      local n={x=node.p.x+d[1],y=node.p.y+d[2],z=p.z};local k=key(n)
      if not seen[k] and now()>=(E.blocked[key(node.p)..':'..d[3]] or 0) and walkable(n) then
        if d[1]==0 or d[2]==0 or (walkable({x=n.x,y=node.p.y,z=p.z}) and walkable({x=node.p.x,y=n.y,z=p.z})) then
          seen[k]=true;q[#q+1]={p=n,depth=node.depth+1}
        end
      end
    end
  end
  return best
end

local function mineTick()
  local m,p=E.mining,pos();if not p then return end
  -- Position keys include z: keep depleted-rock and visited-tile memory per floor.
  -- Routes and outstanding actions belong only to the floor where they started.
  if m.floor~=p.z or (m.target and m.target.z~=p.z) or (m.explore and m.explore.z~=p.z) then
    m.floor=p.z
    m.target=nil;m.targetAt=nil;m.used=0;m.lastUse=nil
    m.explore=nil;m.exploreAt=nil;m.heading=nil;m.lastPosition=nil
    m.progressAt=now()
    E.pending=nil;E.nav=nil;E.tiles=nil;E.grid={}
    E.due.mapScan=0;E.due.explore=0;E.due.step=0;E.due.pickaxe=0
    status('Mining: piso '..p.z..' / busco rocas')
  end
  if not same(p,m.lastPosition) then
    if m.lastPosition and dist(p,m.lastPosition)<=1 then
      m.heading={x=p.x-m.lastPosition.x,y=p.y-m.lastPosition.y}
    end
    m.lastPosition=copy(p);m.progressAt=now()
    E.visits[key(p)]=(E.visits[key(p)] or 0)+1
    E.tiles=nil
  end
  if E.api.Game.getItemCount(19249)<1 then status('Mining: sin pico 19249');return end
  if m.target then
    if now()<(E.rockDone[key(m.target)] or 0) then m.target=nil;return end
    if now()-(m.targetAt or now())>18000 and dist(p,m.target)>1 then
      E.rockDone[key(m.target)]=now()+15000;m.target=nil;return
    end
    if now()-(m.lastUse or m.targetAt or now())>8000 and dist(p,m.target)<=1 then
      E.rockDone[key(m.target)]=now()+15000;m.target=nil
      status('Mining: la roca no acepta el pico, busco otra');return
    end
    if go(m.target,1) and due('pickaxe',1100) then
      if E.api.Game.useItemOnGround(19249,m.target.x,m.target.y,m.target.z) then
        m.used=(m.used or 0)+1;m.lastUse=now();count('miningUses');status('Mining: pico '..m.used..'/5')
        if m.used>=5 then E.rockDone[key(m.target)]=math.huge;count('rocksProcessed');m.target=nil end
      end
    end
    return
  end
  local candidate,best
  for _,t in ipairs(screen()) do
    local blocked=E.rockDone[key(t.position)]
    if t.position.z==p.z and (not blocked or blocked<now()) then
      for _,item in ipairs(t.things) do
        if item.id==19303 or item.id==19304 or item.id==19311 then
          local d=dist(p,t.position)
          if (not best or d<best) and (d<=1 or route(t.position,1)~=nil) then candidate=copy(t.position);best=d end
        end
      end
    end
  end
  if candidate then m.target=candidate;m.targetAt=now();m.lastUse=nil;m.used=0;return end
  if m.explore and dist(p,m.explore)==0 then m.explore=nil end
  if m.explore and now()-(m.progressAt or now())>3000 then
    m.failed=m.failed or {};m.failed[key(m.explore)]=now()+15000
    m.explore=nil;m.progressAt=now()
  end
  if not m.explore and due('explore',750) then
    m.explore=explorationTarget(p)
    m.exploreAt=now()
  end
  if m.explore then go(m.explore,0);status('Mining: busco mas rocas') else status('Mining: sin camino') end
end
function E.onText(mode,text)
  local m=E.mining;text=tostring(text or ''):lower()
  if E.enabled.mining and m.target and m.lastUse and now()-m.lastUse<2500 then
    if text:find('depleted') or text:find('exhausted') then E.rockDone[key(m.target)]=math.huge;count('depleted');m.target=nil
    elseif text:find('cannot mine here') or text:find('no way') then
      local p=pos();if p then E.visits[key(p)]=(E.visits[key(p)] or 0)+3 end
      E.rockDone[key(m.target)]=now()+15000;m.target=nil
    end
  end
end

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

-- ================== Mod: canal con Panel Eloria (la app) ==================
-- Cada 2 s escribe el estado de este personaje en /mods_zalo/app_estado_<pj>.json
-- y cada 1 s lee las ordenes de /mods_zalo/app_orden_<pj>.txt (lineas
-- "<id> <epoch> <orden...>"). Solo ejecuta ordenes nuevas (ids no vistos) y de los
-- ultimos 30 s, asi que recargar el mod no repite nada. Ordenes:
--   exp on|off            mapa auto|venomfen|prismheart|cinderfall
--   pociones on|off       caza <nombre de HUNTS>|off
--   pesca <n> on|off      parar   (apaga todo: expediciones, bosses, cavebot...)
do
  ExpModApp = ExpModApp or {last={}, res={}}
  local A = ExpModApp
  local function enc(v)
    local t = type(v)
    if t == "string" then return '"'..v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end)..'"' end
    if t == "number" then return (v ~= v or v == math.huge or v == -math.huge) and "null" or tostring(v) end
    if t == "boolean" then return tostring(v) end
    if t ~= "table" then return "null" end
    local n, out = #v, {}
    if n > 0 then
      for i = 1, n do out[i] = enc(v[i]) end
      return "["..table.concat(out, ",").."]"
    end
    for k, x in pairs(v) do out[#out+1] = enc(tostring(k))..":"..enc(x) end
    return "{"..table.concat(out, ",").."}"
  end
  local function txt(w) local ok, s = pcall(function() return w:getText() end); return ok and s or nil end
  local function pjName() local p = me(); return p and p:getName() end
  local MAPAS = {auto=0, venomfen=1, prismheart=2, cinderfall=3}

  local function orden(pj, palabras)
    local c, a, b = palabras[1], palabras[2], palabras[3]
    if c == "exp" and (a == "on" or a == "off") then
      local on = ST.stage ~= "off"
      if (a == "on") == on then return true, "ya estaba "..a end
      if a == "on" then onlyOne("exp") end
      toggle()
      return true, "expediciones "..a
    elseif c == "mapa" and a and MAPAS[a] then
      ExpModSel = MAPAS[a]
      if ExpModSel ~= 0 then VI = ExpModSel end
      pcall(paintMaps)
      return true, "mapa "..a
    elseif c == "pociones" and (a == "on" or a == "off") then
      ExpModPotsOff = (a == "off")
      return true, "pociones "..a
    elseif c == "caza" and a then
      if not ExpModHuntCtl then return false, "sin control del cavebot" end
      local nombre = table.concat(palabras, " ", 2)
      if nombre == "off" then return ExpModHuntCtl(ExpModHunt or "", false) end
      local ok = false
      for _, h in ipairs(HUNTS) do if h.name == nombre then ok = true end end
      if not ok then return false, "no conozco la caza '"..nombre.."'" end
      onlyOne("cavebot")
      return ExpModHuntCtl(nombre, true)
    elseif c == "pesca" and tonumber(a) and FISH[tonumber(a)] and (b == "on" or b == "off") then
      ExpModFish[tonumber(a)] = (b == "on")
      pcall(paintFish)
      return true, "pesca "..FISH[tonumber(a)].name.." "..b
    elseif c == "parar" then
      onlyOne("app")
      return true, "todo parado"
    end
    return false, "orden desconocida: "..table.concat(palabras, " ")
  end

  every(function()
    local pj = pjName()
    if not (pj and g_game.isOnline()) then return end
    local ruta = "/mods_zalo/app_orden_"..pj..".txt"
    if not g_resources.fileExists(ruta) then return end
    local ok, s = pcall(g_resources.readFileContents, ruta)
    if not ok or not s then return end
    local ahora = os.time()
    for linea in s:gmatch("[^\r\n]+") do
      local id, t, resto = linea:match("^(%S+)%s+(%d+)%s+(.+)$")
      local vistas = A.last[pj]
      if type(vistas) ~= "table" then vistas = {n=0}; A.last[pj] = vistas end
      if id and not vistas[id] and ahora - tonumber(t) <= 30 then
        if vistas.n > 200 then vistas = {n=0}; A.last[pj] = vistas end
        vistas[id], vistas.n = true, vistas.n + 1
        local palabras = {}
        for w in resto:gmatch("%S+") do palabras[#palabras+1] = w end
        local okc, r1, r2 = pcall(orden, pj, palabras)
        if not okc then r1, r2 = false, tostring(r1) end
        A.res[pj] = {id=id, ok=r1 and true or false, msg=tostring(r2 or ""), t=ahora}
        print("[Panel Eloria] "..resto.." -> "..tostring(r2))
      end
    end
  end, 1000)

  every(function()
    local pj = pjName()
    if not (pj and g_game.isOnline()) then return end
    local C = ebCavebot()
    local huntOn = ExpModHunt and C and C.isEnabled and C.isEnabled() and true or false
    local fish, hunts = {}, {}
    for i, m in ipairs(FISH) do fish[i] = {n=i, name=m.name, on=ExpModFish[i] and true or false} end
    for _, h in ipairs(HUNTS) do hunts[#hunts+1] = h.name end
    local E = HX and HX.E and HX.E.enabled or {}
    local estado = {
      v=1, pj=pj, t=os.time(),
      exp={on=ST.stage ~= "off", etapa=ST.stage, paso=txt(hudStep), estado=txt(hudAlert),
           ruta=ST.route and ST.route.name or nil, mapa=ST.route and ST.route.map or nil,
           seleccion=ExpModSel == 0 and "auto" or VL[ExpModSel], siguiente=VL[VI]},
      pociones={on=not ExpModPotsOff, activas=(ExpModBuffs or {})[pj] or {}},
      autoexp={on=ExpModAX and ExpModAX.on and true or false, cfg=(ExpModAXCfg or {})[pj]},
      caza={nombre=ExpModHunt, on=huntOn, lista=hunts},
      boss={on=BOSS.on and true or false, etapa=BOSS.stage},
      pesca=fish,
      bosstiary=E.bosstiary and true or false, mining=E.mining and true or false,
      forja={on=FG.on and true or false},
      orden=A.res[pj],
    }
    g_resources.writeFileContents("/mods_zalo/app_estado_"..pj..".json", enc(estado))
  end, 2000)
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
