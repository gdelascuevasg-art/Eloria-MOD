--[[
zalo_datos.lua  (recolector del programa de analisis; consola Ctrl+T)
---------------------------------------------------------------------
Solo LEE el juego y escribe lo que pasa en archivos JSON Lines que luego
importa el programa (analisis/eloria.py). No mueve, no ataca, no usa nada.

Lo carga el mod de expediciones al arrancar (y con el se recarga cuando el
cliente reinicia la interfaz). Tambien se puede cargar a mano:
  local f,e=loadstring(g_resources.readFileContents("/mods_zalo/datos/zalo_datos.lua"),"@zalo_datos") if f then f() else print(e) end
PARAR: ZaloDatos.stop()

Archivos: /mods_zalo/datos/registros/<Personaje>_<AAAAMMDD_HHMM>.jsonl
Uno nuevo cada 10 minutos (asi el cliente nunca guarda mas de 10 min en
memoria); el de los ultimos 10 min se reescribe cada 30 s.

Una linea por evento:
  {"ev":"tick", ...}   cada 30 s: nivel, experiencia, raw/xp/kills de esos 30 s,
                       posicion, vida y mana %, daño recibido por elemento y
                       por origen, daño hecho, monstruos en pantalla
  {"ev":"login"} {"ev":"logout"} {"ev":"death"} {"ev":"buff"} {"ev":"carga"}
]]

local OLD = ZaloDatos
if OLD and OLD.stop then pcall(OLD.stop, true) end

local D = {
  VERSION = 1,
  DIR = "/mods_zalo/datos/registros/",
  TICK_MS = 30000,       -- resumen cada 30 s
  CHUNK_S = 600,         -- archivo nuevo cada 10 min
  events = {}, conns = {},
  lines = {}, file = nil, fileStart = 0,
  acc = nil, lastErr = 0, dead = false, char = nil,
}
ZaloDatos = D
-- Al recargar se sigue en el mismo archivo (no se pierde ni se pisa nada).
if OLD and OLD.file then
  D.file, D.lines, D.fileStart, D.char = OLD.file, OLD.lines or {}, OLD.fileStart or 0, OLD.char
end

-- ------------------------------------------------------------------ JSON
local function esc(s)
  s = tostring(s)
  s = s:gsub('[%c"\\]', function(c)
    if c == '"' then return '\\"' elseif c == '\\' then return '\\\\'
    elseif c == '\n' then return '\\n' elseif c == '\t' then return '\\t' end
    return string.format('\\u%04x', c:byte())
  end)
  return '"'..s..'"'
end
local function num(n)
  n = tonumber(n) or 0
  if n ~= n or n == math.huge or n == -math.huge then return "0" end
  if n == math.floor(n) and math.abs(n) < 1e18 then return string.format("%.0f", n) end
  return string.format("%.3f", n)
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
  elseif t == "number" then return num(v)
  elseif t == "boolean" then return v and "true" or "false"
  elseif v == nil then return "null" end
  return esc(v)
end
D.enc = enc

-- ---------------------------------------------------------------- utilidades
local function report(err)
  if os.time() - D.lastErr > 10 then
    D.lastErr = os.time()
    print("[Datos] error: "..tostring(err))
  end
end
local function me() return g_game.isOnline() and g_game.getLocalPlayer() or nil end
local function call(o, m)
  local f = o and o[m]
  if not f then return nil end
  local ok, r = pcall(f, o)
  if ok then return r end
  return nil
end
local function pct(a, b)
  a, b = tonumber(a), tonumber(b)
  if not a or not b or b <= 0 then return nil end
  return math.floor(a * 100 / b + 0.5)
end
local function newAcc()
  return {raw = 0, xp = 0, kills = 0, dmgIn = {}, src = {}, dmgOut = 0, heal = 0, imp = {}}
end
D.acc = newAcc()

-- ---------------------------------------------------------------- escritura
function D.flush()
  if not D.file or #D.lines == 0 then return end
  local ok, err = pcall(g_resources.writeFileContents, D.file, table.concat(D.lines, "\n").."\n")
  if not ok then report(err) end
end

local function openChunk(name, t)
  D.flush()
  D.lines = {}
  D.fileStart = t
  D.file = D.DIR..name.."_"..os.date("%Y%m%d_%H%M%S", t)..".jsonl"
end

function D.emit(ev, data)
  local p = me()
  local name = p and p:getName() or D.char
  if not name then return end
  local t = os.time()
  if name ~= D.char or not D.file or t - D.fileStart >= D.CHUNK_S then
    D.char = name
    openChunk(name, t)
  end
  data = data or {}
  data.ev, data.t, data.pj = ev, t, name
  D.lines[#D.lines+1] = enc(data)
end

-- ---------------------------------------------------------------- eventos
local function onExp(raw, final)
  D.acc.raw = D.acc.raw + (tonumber(raw) or 0)
  D.acc.xp = D.acc.xp + (tonumber(final) or 0)
  D.acc.kills = D.acc.kills + 1
end

-- onImpactTracker(tipo, cantidad, elemento, origen): tipo 2 = daño recibido
-- (comprobado). El resto de tipos se suman en "imp" por si acaso, y el 1 se
-- trata como daño hecho (sin confirmar).
local function onImpact(ty, amount, element, source)
  local a = tonumber(amount) or 0
  local acc = D.acc
  local k = tostring(ty)
  acc.imp[k] = (acc.imp[k] or 0) + a
  if ty == 2 then
    local e = tostring(element)
    acc.dmgIn[e] = (acc.dmgIn[e] or 0) + a
    if source and source ~= "" then
      local s = tostring(source):gsub("%s*%[.-%]%s*$", "")
      acc.src[s] = (acc.src[s] or 0) + a
    end
  elseif ty == 1 then
    acc.dmgOut = acc.dmgOut + a
  end
end

local function onText(mode, text)
  text = tostring(text or "")
  local buff, mins = text:match("You have activated (.-)%. It will last for (%d+) minutes")
  if buff then D.emit("buff", {nombre = buff, min = tonumber(mins)}) return end
  if text:find("World Boost", 1, true) or text:find("You are dead", 1, true) then
    D.emit("aviso", {texto = text:sub(1, 200)})
  end
end

local function onStart() D.dead = false; D.emit("login") end
local function onEnd() D.emit("logout"); D.flush() end

local HANDLERS = {
  onUpdateExperience = onExp, onImpactTracker = onImpact,
  onTextMessage = onText, onGameStart = onStart, onGameEnd = onEnd,
}
-- Reconectar cada minuto: si el cliente reinicia la interfaz y suelta las
-- conexiones, se recuperan solas (disconnect + connect no duplica).
local function wire()
  for sig, fn in pairs(HANDLERS) do
    pcall(disconnect, g_game, {[sig] = fn})
    connect(g_game, {[sig] = fn})
  end
end

local function monsters(p, pos)
  local out, n = {}, 0
  local ok, list = pcall(g_map.getSpectators, pos, false)
  if not ok or type(list) ~= "table" then return out end
  for _, c in ipairs(list) do
    if c ~= p and c.isMonster and c:isMonster() then
      local nm = tostring(c:getName()):gsub("%s*%[.-%]%s*$", "")
      out[nm] = (out[nm] or 0) + 1
      n = n + 1
      if n > 60 then break end
    end
  end
  return out
end

local function tick()
  local p = me()
  if not p then return end
  local pos = p:getPosition() or {}
  local acc = D.acc
  D.acc = newAcc()
  D.emit("tick", {
    nivel = call(p, "getLevel"), exp = call(p, "getExperience"),
    raw = acc.raw, xp = acc.xp, kills = acc.kills,
    x = pos.x, y = pos.y, z = pos.z,
    hp = pct(call(p, "getHealth"), call(p, "getMaxHealth")),
    mp = pct(call(p, "getMana"), call(p, "getMaxMana")),
    stamina = call(p, "getStamina"),
    pz = call(p, "isInProtectionZone") and true or nil,
    din = acc.dmgIn, src = acc.src, dout = acc.dmgOut, imp = acc.imp,
    mobs = monsters(p, pos),
    ping = (function() local ok, r = pcall(g_game.getPing) return ok and r or nil end)(),
  })
  D.flush()
end

-- Muerte: vida a 0 (se comprueba cada segundo; una sola vez por muerte).
local function watchDeath()
  local p = me()
  if not p then return end
  local hp = tonumber(call(p, "getHealth"))
  if hp and hp <= 0 then
    if not D.dead then
      D.dead = true
      local pos = p:getPosition() or {}
      D.emit("death", {nivel = call(p, "getLevel"), x = pos.x, y = pos.y, z = pos.z})
      D.flush()
    end
  elseif hp and hp > 0 then
    D.dead = false
  end
end

local function every(fn, ms)
  D.events[#D.events+1] = cycleEvent(function()
    local ok, err = pcall(fn)
    if not ok then report(err) end
  end, ms)
end

function D.stop(reloading)
  pcall(D.flush)
  for _, e in ipairs(D.events) do removeEvent(e) end
  for sig, fn in pairs(HANDLERS) do pcall(disconnect, g_game, {[sig] = fn}) end
  D.events = {}
  if not reloading then print("[Datos] parado") end
end

-- ---------------------------------------------------------------- arranque
pcall(g_resources.makeDir, "/mods_zalo/datos/registros")
wire()
every(tick, D.TICK_MS)
every(watchDeath, 1000)
every(wire, 60000)
D.emit("carga", {version = D.VERSION})
D.flush()
print("[Datos] recolector v"..D.VERSION.." grabando en "..D.DIR)
