--[[
sonda_dungeon.lua  (solo LEE; no mueve, no ataca, no contesta ventanas)
----------------------------------------------------------------------
Graba todo lo que pasa mientras Gon hace una dungeon a mano, para poder
automatizarla despues: posicion, saltos (teletransportes), criaturas que
aparecen/mueren con su vida, ventanas (modales) con botones y opciones,
mensajes del servidor y el plano de casillas vistas en cada piso.

Cargar (consola Ctrl+T):
  local f,e=loadstring(g_resources.readFileContents("/mods_zalo/dungeon/sonda_dungeon.lua"),"@sonda_dungeon") if f then f() else print(e) end
PARAR: SondaDungeon.stop()

Archivos (en /mods_zalo/dungeon/):
  sonda_<Personaje>_<AAAAMMDD_HHMMSS>.jsonl   eventos, uno por linea
  casillas_<Personaje>_<AAAAMMDD_HHMMSS>.txt  plano: x,y,z,andable,ids
]]

local OLD = SondaDungeon
if OLD and OLD.stop then pcall(OLD.stop) end

local S = {
  VERSION = 1, DIR = "/mods_zalo/dungeon/",
  events = {}, conns = {}, lines = {}, tiles = {}, ntiles = 0,
  seen = {}, lastPos = nil, lastErr = 0, file = nil, tfile = nil,
}
SondaDungeon = S

local function esc(s)
  s = tostring(s)
  s = s:gsub('[%c"\\]', function(c)
    if c == '"' then return '\\"' elseif c == '\\' then return '\\\\'
    elseif c == '\n' then return '\\n' elseif c == '\t' then return '\\t' end
    return string.format('\\u%04x', c:byte())
  end)
  return '"'..s..'"'
end
local function enc(v)
  local t = type(v)
  if t == "table" then
    if #v > 0 then
      local o = {}
      for i = 1, #v do o[i] = enc(v[i]) end
      return "["..table.concat(o, ",").."]"
    end
    local o = {}
    for k, x in pairs(v) do o[#o+1] = esc(k)..":"..enc(x) end
    return "{"..table.concat(o, ",").."}"
  elseif t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then return "0" end
    if v == math.floor(v) then return string.format("%.0f", v) end
    return string.format("%.3f", v)
  elseif t == "boolean" then return v and "true" or "false"
  elseif v == nil then return "null" end
  return esc(v)
end

local function report(err)
  if os.time() - S.lastErr > 10 then
    S.lastErr = os.time()
    print("[Sonda] error: "..tostring(err))
  end
end
local function me() return g_game.isOnline() and g_game.getLocalPlayer() or nil end
local function call(o, m, ...)
  local f = o and o[m]
  if not f then return nil end
  local ok, r = pcall(f, o, ...)
  if ok then return r end
  return nil
end
local function P(p) return p and {p.x, p.y, p.z} or nil end

local function emit(ev, data)
  if not S.file then
    local p = me()
    if not p then return end
    local tag = p:getName().."_"..os.date("%Y%m%d_%H%M%S")
    S.file = S.DIR.."sonda_"..tag..".jsonl"
    S.tfile = S.DIR.."casillas_"..tag..".txt"
  end
  data = data or {}
  data.ev, data.ms = ev, g_clock.millis()
  data.t = os.time()
  S.lines[#S.lines+1] = enc(data)
end

function S.flush()
  if S.file and #S.lines > 0 then
    local ok, err = pcall(g_resources.writeFileContents, S.file, table.concat(S.lines, "\n").."\n")
    if not ok then report(err) end
  end
  if S.tfile and S.ntiles > 0 then
    local out = {}
    for k, v in pairs(S.tiles) do out[#out+1] = k..","..v end
    local ok, err = pcall(g_resources.writeFileContents, S.tfile, table.concat(out, "\n").."\n")
    if not ok then report(err) end
  end
end

-- ---------------------------------------------------------------- posicion
local function posTick()
  local p = me()
  if not p then return end
  local pos = p:getPosition()
  if not pos then return end
  local l = S.lastPos
  if not l or l.z ~= pos.z or math.abs(l.x - pos.x) > 3 or math.abs(l.y - pos.y) > 3 then
    emit("salto", {de = P(l), a = P(pos)})
  elseif l.x ~= pos.x or l.y ~= pos.y then
    emit("pos", {p = P(pos), hp = call(p, "getHealthPercent"),
      mp = (function() local m, mm = call(p, "getMana"), call(p, "getMaxMana")
        return (m and mm and mm > 0) and math.floor(m * 100 / mm) or nil end)()})
  end
  S.lastPos = {x = pos.x, y = pos.y, z = pos.z}
end

-- ---------------------------------------------------------------- criaturas
local function creatureTick()
  local p = me()
  if not p then return end
  local pos = p:getPosition()
  local ok, list = pcall(g_map.getSpectators, pos, true)
  if not ok or type(list) ~= "table" then return end
  local now = {}
  for _, c in ipairs(list) do
    if c ~= p then
      local id = call(c, "getId")
      if id then
        now[id] = true
        local hp = call(c, "getHealthPercent")
        local cp = call(c, "getPosition")
        local s = S.seen[id]
        if not s then
          local kind = call(c, "isMonster") and "monstruo" or call(c, "isNpc") and "npc"
            or call(c, "isPlayer") and "jugador" or "otro"
          local o = call(c, "getOutfit")
          emit("aparece", {id = id, nombre = call(c, "getName"), tipo = kind, p = P(cp), hp = hp,
            skull = call(c, "getSkull"), icono = call(c, "getIcon"), look = o and o.type or nil,
            vel = call(c, "getSpeed")})
          S.seen[id] = {hp = hp, p = cp, nombre = call(c, "getName")}
        else
          if hp ~= s.hp then emit("vida", {id = id, hp = hp, p = P(cp)}) end
          s.hp, s.p = hp, cp
        end
      end
    end
  end
  for id, s in pairs(S.seen) do
    if not now[id] then
      emit("se_va", {id = id, nombre = s.nombre, hp = s.hp, p = P(s.p)})
      S.seen[id] = nil
    end
  end
end

-- ---------------------------------------------------------------- casillas
local function tileTick()
  local p = me()
  if not p then return end
  local pos = p:getPosition()
  if not pos then return end
  for dx = -9, 9 do for dy = -7, 7 do
    local q = {x = pos.x + dx, y = pos.y + dy, z = pos.z}
    local key = q.x..","..q.y..","..q.z
    if not S.tiles[key] then
      local ok, t = pcall(g_map.getTile, q)
      if ok and t then
        local ids = {}
        for _, th in ipairs(call(t, "getThings") or {}) do
          if not call(th, "isCreature") then ids[#ids+1] = tostring(call(th, "getId")) end
        end
        S.tiles[key] = (call(t, "isWalkable", true) and "1" or "0")..","..table.concat(ids, " ")
        S.ntiles = S.ntiles + 1
      end
    end
  end end
end

-- ---------------------------------------------------------------- señales
local function onModal(id, title, message, buttons, enterB, escB, choices)
  local bs, cs = {}, {}
  for _, b in ipairs(buttons or {}) do bs[#bs+1] = {b[1], b[2]} end
  for _, c in ipairs(choices or {}) do cs[#cs+1] = {c[1], c[2]} end
  emit("modal", {id = id, titulo = title, texto = message, botones = bs, opciones = cs,
    enter = enterB, escape = escB})
end
local function onText(mode, text) emit("texto", {modo = mode, texto = text}) end
local function onTalk(name, level, mode, text, channelId, pos)
  emit("habla", {nombre = name, modo = mode, texto = text, canal = channelId, p = P(pos)})
end
local function onExp(raw, final) emit("exp", {raw = raw, final = final}) end

local HANDLERS = {onModalDialog = onModal, onTextMessage = onText, onTalk = onTalk,
  onUpdateExperience = onExp}

local function every(fn, ms)
  S.events[#S.events+1] = cycleEvent(function()
    local ok, err = pcall(fn); if not ok then report(err) end
  end, ms)
end

function S.stop()
  for _, e in ipairs(S.events) do removeEvent(e) end
  for sig, fn in pairs(HANDLERS) do pcall(disconnect, g_game, {[sig] = fn}) end
  S.events = {}
  emit("fin")
  S.flush()
  if SondaDungeon == S then SondaDungeon = nil end
  print("[Sonda] parada")
end

for sig, fn in pairs(HANDLERS) do connect(g_game, {[sig] = fn}) end
every(posTick, 250)
every(creatureTick, 500)
every(tileTick, 1000)
every(S.flush, 5000)
emit("inicio", {version = S.VERSION})
print("[Sonda] grabando en "..tostring(S.file))
