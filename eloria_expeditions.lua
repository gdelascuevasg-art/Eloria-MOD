--[[
eloria_expeditions.lua  (EloriaBot > Scripting)
------------------------------------------------
Hecho desde cero siguiendo el diagrama "Eloria Expeditions":

  NPC Eternum Questmaster -> hi / expeditions (si no empieza, repite)
  -> [la consola elige el mapa del bucle: Venomfen -> Prismheart -> Cinderfall]
  -> leer ubicacion del cristal -> seleccion de ruta segun coordenadas
  -> movimiento hacia el cristal (hasta llegar) -> cristal y oleadas
  -> movimiento de vuelta (safe spot -> TP) -> NPC -> ...

REQUISITO: el vigilante de la consola (Ctrl+T) encendido. Es el que pulsa
el panel, elige el mapa, contesta "Expedition complete" y pasa la posicion
del cristal a este script con el mensaje local "XTAL x y z fase cleared token".

Movimiento: map click (Map.goTo), salvo:
  - los mapas de CFG.ARROW_MAPS (Venomfen Hollows): toda la sala con flechas
    (Game.walk), empezando por el TRAMO GRABADO (nodos a=true), que se pisa
    casilla a casilla.
  - en otros mapas, los nodos a=true (tramo grabado) tambien van con flechas.
Con flechas el camino lo calcula el script (respeta AVOID y BLOCK_IDS).
Fuera de la sala (NPC, TP) siempre map click.

HUD: click en el titulo = ON/OFF.

REANUDAR: al darle a ON (o al recargar el script) detecta en que punto de la
secuencia estas y sigue desde ahi:
  - en la sala con el cristal roto        -> 8 salida (esperar el Yes)
  - en la sala, cristal despierto/dormido -> ruta desde el nodo mas cercano
                                             y luego cristal/oleadas
  - en el safe spot                       -> 8 vuelta (TP)
  - cerca del NPC o en cualquier otro sitio -> 1 NPC
(La posicion y fase del cristal las repite el vigilante cada 10 s.)
]]

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
local hudRoute  = row(38, "Ruta: -", COL.muted)
local hudXtal   = row(56, "Cristal: -", COL.muted)
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
    setTxt(hudXtal, string.format("Cristal: %d,%d,%d  fase %d  clicks %d/4%s",
      X.x, X.y, X.z, X.phase, ST.clicks, X.cleared and "  (roto)" or ""))
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
      setTxt(hudRoute, "Ruta: -"); paint(hudRoute, COL.muted)
      setTxt(hudXtal, "Cristal: -"); paint(hudXtal, COL.muted)
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
      setTxt(hudRoute, "Ruta: "..r.name.."  ("..r.map..")")
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

print("[Expeditions] cargado ("..#ROUTES.." rutas). Click en el titulo del HUD para ON/OFF.")
