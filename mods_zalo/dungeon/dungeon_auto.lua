--[[
dungeon_auto.lua  (Dungeon Runner para el sistema nuevo de dungeons)
--------------------------------------------------------------------
Sistema nuevo (06/10/2026): cada entrada genera un mapa aleatorio. Hay 3 jefes
globales "dormidos" bajo un objeto que no se puede atacar directamente
(Ward Totem, o 3 Abyssal Rift); se rompe con el area y sale el jefe con
sufijo [127]. Muertos los 3, aparece Eloriak the Blighted; al matarlo el
premio va al reward chest y el juego te saca solo ("You escaped the dungeon").

Este script SOLO CAMINA: explora el mapa, se pega a los totems y a los jefes,
y espera a que EloriaBot (targeting + hechizos) haga la pelea. No ataca ni
lanza hechizos.

Cargar (consola Ctrl+T):
  local f,e=loadstring(g_resources.readFileContents("/mods_zalo/dungeon/dungeon_auto.lua"),"@dungeon_auto") if f then f() else print(e) end
Luego:  DungeonAuto.start()        una dungeon y para
        DungeonAuto.start(true)    repite mientras se pueda entrar
        DungeonAuto.stop()
Estado: DungeonAuto.estado  (y /mods_zalo/dungeon/auto_<Personaje>.log)
]]

local OLD = DungeonAuto
if OLD and OLD.stop then pcall(OLD.stop, true) end

local A = {
  VERSION = 1,
  CFG = {
    STATUE = {x=14232, y=19348, z=3},   -- estatua de entrada (id 63529)
    LOBBY_R = 30,                        -- "fuera" = a menos de esto de la estatua
    TOTEMS = {["ward totem"]=true, ["abyssal rift"]=true},
    BOSS_TAG = "%[127%]",                -- jefes globales y final
    FINAL = "eloriak the blighted",
    NEAR_TOTEM = 2,                      -- distancia a la que se queda junto al totem
    NEAR_BOSS = 3,
    HOLD_MOBS_R = 4,                     -- monstruos a esta distancia: parar y dejar pelear
    HOLD_MAX_S = 25,                     -- maximo parado por monstruos antes de seguir
    LOW_HP = 35,                         -- % vida: no caminar (que cure)
    WALK_EVERY_MS = 1200,
    STUCK_S = 12,                        -- sin moverse hacia el objetivo: se descarta
    RUN_MAX_S = 900,                     -- seguridad: maximo por dungeon
    ENTRY_TRIES = 6,
    VIEW_X = 8, VIEW_Y = 6,
  },
  events = {}, conns = {}, estado = "OFF",
}
DungeonAuto = A
local C = A.CFG

-- ---------------------------------------------------------------- utilidades
local function now() return g_clock.millis() / 1000 end
local function me() return g_game.isOnline() and g_game.getLocalPlayer() or nil end
local function call(o, m, ...)
  local f = o and o[m]
  if not f then return nil end
  local ok, r = pcall(f, o, ...)
  if ok then return r end
  return nil
end
local function cheb(a, b)
  if not a or not b or a.z ~= b.z then return 99999 end
  return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y))
end
local function key(x, y) return x * 100000 + y end
local function cleanName(n) return (tostring(n or ""):gsub("%s*%[.-%]%s*$", "")):lower() end

local logLines = {}
local function log(msg)
  local p = me()
  local line = os.date("%H:%M:%S").." "..msg
  logLines[#logLines+1] = line
  if #logLines > 400 then table.remove(logLines, 1) end
  if p then
    pcall(g_resources.writeFileContents, "/mods_zalo/dungeon/auto_"..p:getName()..".log",
      table.concat(logLines, "\n").."\n")
  end
end
local function setState(s, why)
  if A.estado ~= s then
    A.estado = s
    log("estado: "..s..(why and (" ("..why..")") or ""))
  end
end

-- ---------------------------------------------------------------- run
local R  -- datos de la dungeon actual

local function newRun()
  R = {
    t0 = now(), z = nil,
    seen = {},          -- key -> true (andable) / false (bloqueada o vacia)
    totems = {},        -- key -> {x,y,z,nombre,ultimaVez}
    bossSeen = {},      -- id -> {nombre, hp, p}
    globals = 0, final = false,
    target = nil, targetSince = 0, targetBest = 99999, bad = {},
    lastWalk = 0, holdSince = nil, lastPos = nil, lastMove = now(),
  }
end

local function inLobby(p) return cheb(p, C.STATUE) <= C.LOBBY_R end

-- ---------------------------------------------------------------- mapa
local function scanTiles(p)
  local seen = R.seen
  for dx = -C.VIEW_X, C.VIEW_X do for dy = -C.VIEW_Y, C.VIEW_Y do
    local x, y = p.x + dx, p.y + dy
    local t = g_map.getTile({x=x, y=y, z=p.z})
    if t then
      seen[key(x, y)] = call(t, "isWalkable", true) and true or false
    elseif seen[key(x, y)] == nil then
      seen[key(x, y)] = false
    end
  end end
end

local N8 = {{1,0},{-1,0},{0,1},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1}}
local N4 = {{1,0},{-1,0},{0,1},{0,-1}}

local function isFrontier(x, y)
  if R.seen[key(x, y)] ~= true then return false end
  for _, d in ipairs(N4) do
    if R.seen[key(x + d[1], y + d[2])] == nil then return true end
  end
  return false
end

-- BFS por casillas conocidas andables desde el jugador. Devuelve la frontera
-- mas cercana que no este descartada.
local function nearestFrontier(p)
  local seen, bad = R.seen, R.bad
  local q, head = {{p.x, p.y, 0}}, 1
  local visited = {[key(p.x, p.y)] = true}
  while head <= #q and head < 20000 do
    local c = q[head]; head = head + 1
    if c[3] >= 3 and isFrontier(c[1], c[2]) and not bad[key(c[1], c[2])] then
      return {x=c[1], y=c[2], z=p.z}, c[3]
    end
    for _, d in ipairs(N8) do
      local nx, ny = c[1] + d[1], c[2] + d[2]
      local k = key(nx, ny)
      if not visited[k] and seen[k] == true then
        visited[k] = true
        q[#q+1] = {nx, ny, c[3] + 1}
      end
    end
  end
  return nil
end

-- Casilla andable conocida mas cercana a "pos" (a distancia <= r), para
-- acercarse a un totem o a un jefe sin pisarlo.
local function standNear(pos, r, p)
  local best, bd = nil, 99999
  for dx = -r, r do for dy = -r, r do
    if not (dx == 0 and dy == 0) then
      local x, y = pos.x + dx, pos.y + dy
      if R.seen[key(x, y)] == true then
        local d = math.abs(x - p.x) + math.abs(y - p.y)
        if d < bd then best, bd = {x=x, y=y, z=pos.z}, d end
      end
    end
  end end
  return best
end

-- ---------------------------------------------------------------- caminar
local function walkTo(p, to)
  local t = now()
  if t - R.lastWalk < C.WALK_EVERY_MS / 1000 then return end
  R.lastWalk = t
  local flags = (PathFindAllowNotSeenTiles or 1) + (PathFindAllowNonPathable or 4)
  local ok, dirs = pcall(g_map.findPath, p, to, 5000, flags)
  if ok and type(dirs) == "table" and #dirs > 0 then
    if pcall(g_game.autoWalk, dirs, p) then return end
  end
  pcall(function() me():autoWalk(to) end)
end

local function stopWalk() pcall(g_game.stop) end

-- El cavebot de EloriaBot pelearia con este script por el movimiento: se apaga
-- al empezar y se deja como estaba al parar. El targeting no se toca.
local function ebCavebot() return modules and modules.game_helper and modules.game_helper.cavebot end
local function cavebot(on)
  local cb = ebCavebot()
  if not (cb and cb.toggle and cb.isEnabled) then return nil end
  local ok, was = pcall(cb.isEnabled)
  was = ok and was and true or false
  if was ~= on then pcall(cb.toggle, on) end
  return was
end

-- Objetivo con control de atasco: si en STUCK_S no nos acercamos, se descarta.
local function goal(p, to, label)
  if not R.target or R.target.x ~= to.x or R.target.y ~= to.y then
    R.target, R.targetSince, R.targetBest, R.targetLabel = to, now(), cheb(p, to), label
  end
  local d = cheb(p, to)
  if d < R.targetBest then R.targetBest, R.targetSince = d, now() end
  if now() - R.targetSince > C.STUCK_S then
    R.bad[key(to.x, to.y)] = true
    log("atascado yendo a "..label.." "..to.x..","..to.y.."; lo descarto")
    R.target = nil
    return
  end
  if d > 0 then walkTo(p, to) end
end

-- ---------------------------------------------------------------- criaturas
local function scanCreatures(p)
  local ok, list = pcall(g_map.getSpectators, p, false)
  local mobs, bosses, totems = {}, {}, {}
  if not ok or type(list) ~= "table" then return mobs, bosses, totems end
  local alive = {}
  for _, c in ipairs(list) do
    if c ~= p and call(c, "isMonster") then
      local raw = tostring(call(c, "getName") or "")
      local nm = cleanName(raw)
      local cp = call(c, "getPosition")
      local hp = call(c, "getHealthPercent") or 100
      local id = call(c, "getId")
      if cp and cp.z == p.z then
        if C.TOTEMS[nm] then
          totems[#totems+1] = cp
          local k = key(cp.x, cp.y)
          if not R.totems[k] then log("totem visto: "..raw.." en "..cp.x..","..cp.y) end
          R.totems[k] = {x=cp.x, y=cp.y, z=cp.z, nombre=nm, ultimaVez=now()}
        elseif raw:find(C.BOSS_TAG) then
          bosses[#bosses+1] = {c=c, p=cp, hp=hp, nombre=nm, id=id}
          if not R.bossSeen[id] then log("jefe visto: "..raw.." en "..cp.x..","..cp.y) end
          R.bossSeen[id] = {nombre=nm, hp=hp, p=cp}
          alive[id] = true
          -- al salir el jefe del totem, el totem ya no cuenta
          for k, t in pairs(R.totems) do
            if cheb(t, cp) <= 3 then R.totems[k] = nil end
          end
        elseif hp > 0 then
          mobs[#mobs+1] = {p=cp, hp=hp}
        end
      end
    end
  end
  return mobs, bosses, totems
end

local function onText(mode, text)
  if not R or A.estado == "OFF" then return end
  text = tostring(text or "")
  local who = text:match("for killing (.-)%.$")
  if who then
    who = cleanName(who)
    for id, b in pairs(R.bossSeen) do
      if b.nombre == who then
        R.bossSeen[id] = nil
        if who == C.FINAL then
          R.final = true
          log("boss final muerto")
        else
          R.globals = R.globals + 1
          log("jefe global muerto: "..who.." ("..R.globals.."/3)")
        end
        break
      end
    end
  end
  if text:find("You escaped the dungeon", 1, true) then
    log(string.format("dungeon terminada en %d s (globales %d, final %s)",
      now() - R.t0, R.globals, tostring(R.final)))
    A.done = (A.done or 0) + 1
    R.salida = true
  end
  if text:find("You are dead", 1, true) or text:find("You died", 1, true) then
    log("MUERTE: paro todo")
    A.stop()
  end
end

-- ---------------------------------------------------------------- entrada
local function onModal(id, title, message, buttons, enterB, escB, choices)
  if A.estado == "OFF" then return end
  local lt = tostring(title or ""):lower()
  local bs = {}
  for _, b in ipairs(buttons or {}) do bs[#bs+1] = b[1]..":"..tostring(b[2]) end
  local cs = {}
  for _, c in ipairs(choices or {}) do cs[#cs+1] = c[1]..":"..tostring(c[2]) end
  log("ventana: '"..tostring(title).."' botones["..table.concat(bs, " | ").."] opciones["
    ..table.concat(cs, " | ").."]")
  if not lt:find("dungeon", 1, true) and not lt:find("confirm", 1, true) then return end
  local choice = 0
  for _, c in ipairs(choices or {}) do
    if not tostring(c[2]):find("%[CD:") and not tostring(c[2]):lower():find("cooldown") then
      choice = c[1]; break
    end
  end
  if #(choices or {}) > 0 and choice == 0 then
    log("todas las dungeons en cooldown")
    A.sinEntrada = true
    pcall(g_game.answerModalDialog, id, escB or 255, 0)
    return
  end
  local btn = enterB
  for _, b in ipairs(buttons or {}) do
    local bt = tostring(b[2]):lower()
    if bt:find("enter") or bt:find("start") or bt:find("confirm") or bt == "yes" or bt == "ok" then
      btn = b[1]; break
    end
  end
  log("contesto boton "..tostring(btn).." opcion "..tostring(choice))
  pcall(g_game.answerModalDialog, id, btn, choice)
end

-- ---------------------------------------------------------------- bucle
local function tick()
  if A.estado == "OFF" then return end
  local p = me()
  if not p then return end
  local pos = p:getPosition()
  if not pos then return end

  -- FUERA: junto a la estatua
  if inLobby(pos) then
    if R and R.salida then
      R = nil
      if not A.repetir then A.stop(); return end
    end
    if A.sinEntrada then setState("SIN ENTRADA", "cooldown"); return end
    if cheb(pos, C.STATUE) > 10 then setState("LEJOS DE LA ESTATUA"); return end
    A.tries = A.tries or 0
    if A.tries >= C.ENTRY_TRIES then setState("NO ENTRA", "revisa el log"); return end
    if now() - (A.lastUse or 0) >= 4 then
      A.lastUse = now()
      A.tries = A.tries + 1
      local t = g_map.getTile(C.STATUE)
      local th = t and call(t, "getTopUseThing")
      if th then
        log("uso la estatua (intento "..A.tries..")")
        pcall(g_game.use, th)
      else
        log("no veo la estatua")
      end
    end
    setState("ENTRANDO")
    return
  end

  -- DENTRO
  if not R or R.salida or (R.z and R.z ~= pos.z) then newRun(); log("dentro en "..pos.x..","..pos.y..","..pos.z) end
  R.z = pos.z
  A.tries = 0
  if now() - R.t0 > C.RUN_MAX_S then
    log("demasiado tiempo dentro: paro")
    A.stop(); return
  end
  if R.lastPos and (R.lastPos.x ~= pos.x or R.lastPos.y ~= pos.y) then R.lastMove = now() end
  R.lastPos = {x=pos.x, y=pos.y, z=pos.z}

  scanTiles(pos)
  local mobs, bosses = scanCreatures(pos)
  -- totem recordado que ya no esta aunque su casilla se ve: roto
  for k, t in pairs(R.totems) do
    if cheb(pos, t) <= 5 and now() - t.ultimaVez > 1.5 then
      R.totems[k] = nil
      log("el "..t.nombre.." de "..t.x..","..t.y.." ya no esta")
    end
  end

  local hp = call(p, "getHealthPercent") or 100
  if hp < C.LOW_HP then setState("VIDA BAJA", hp.."%"); stopWalk(); return end

  -- 1) jefe [127] a la vista: pegarse y dejar pelear
  if #bosses > 0 then
    local b = bosses[1]
    setState("JEFE: "..b.nombre, b.hp.."%")
    if cheb(pos, b.p) > C.NEAR_BOSS then
      local s = standNear(b.p, C.NEAR_BOSS, pos)
      if s then goal(pos, s, "jefe") end
    end
    return
  end

  -- 2) totem conocido: ir al lado y quedarse hasta que salga el jefe
  local bestT, bd = nil, 99999
  for k, t in pairs(R.totems) do
    if not R.bad[k] then
      local d = cheb(pos, t)
      if d < bd then bestT, bd = t, d end
    end
  end
  if bestT then
    if bd <= C.NEAR_TOTEM then
      setState("ROMPIENDO "..bestT.nombre)
      stopWalk()
    else
      setState("A "..bestT.nombre, bd.." casillas")
      local s = standNear(bestT, C.NEAR_TOTEM, pos)
      if s then goal(pos, s, bestT.nombre) else R.bad[key(bestT.x, bestT.y)] = true end
    end
    return
  end

  -- 3) monstruos cerca: parar un rato para que EloriaBot los mate
  local close = 0
  for _, m in ipairs(mobs) do
    if cheb(pos, m.p) <= C.HOLD_MOBS_R then close = close + 1 end
  end
  if close > 0 then
    R.holdSince = R.holdSince or now()
    if now() - R.holdSince < C.HOLD_MAX_S then
      setState("PELEANDO", close.." cerca")
      return
    end
  else
    R.holdSince = nil
  end

  -- 4) explorar
  local f, dist = nearestFrontier(pos)
  if not f then
    setState("SIN MAPA POR EXPLORAR", "globales "..R.globals)
    R.bad = {}  -- reintentar fronteras descartadas
    return
  end
  setState("EXPLORANDO", "globales "..R.globals.."/3")
  goal(pos, f, "zona sin ver")
end

-- ---------------------------------------------------------------- control
local HANDLERS = {onTextMessage = onText, onModalDialog = onModal}

function A.start(repetir)
  A.stop(true)
  A.repetir = repetir and true or false
  A.tries, A.sinEntrada, A.done = 0, false, 0
  for sig, fn in pairs(HANDLERS) do connect(g_game, {[sig] = fn}) end
  A.events[#A.events+1] = cycleEvent(function()
    local ok, err = pcall(tick)
    if not ok then log("error: "..tostring(err)) end
  end, 300)
  A.cavebotAntes = cavebot(false)
  A.estado = "INICIO"
  log("arranco v"..A.VERSION..(A.repetir and " (repetir)" or ""))
end

function A.stop(silent)
  for _, e in ipairs(A.events) do removeEvent(e) end
  A.events = {}
  for sig, fn in pairs(HANDLERS) do pcall(disconnect, g_game, {[sig] = fn}) end
  if A.estado ~= "OFF" then
    stopWalk()
    if A.cavebotAntes then cavebot(true) end
    A.cavebotAntes = nil
  end
  A.estado = "OFF"
  if not silent then log("parado") end
end

A._test = {tick = tick, onText = onText, onModal = onModal, run = function() return R end}
print("[DungeonAuto] cargado. DungeonAuto.start() para empezar")
