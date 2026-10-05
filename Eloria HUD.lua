-- ELORIA / ZEROBOT HUD 4.5 — GameData(7)
-- Paste this entire file into one EloriaBot/ZeroBot scripting slot.
-- Uses only the documented sandbox API; no client file modification.
-- Boss Sequence requires the Game.bossSequenceStart extension in GD7.
-- Native profit/loot/supply counters are NOT exported by this sandbox.
-- Damage below is explicitly the sum of received DAMAGE_DEALT messages.
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
-- Dungeon module transplanted from the user-confirmed working Eloria Pack.
local dungeonTick,dungeonModal,resetDungeon
 do
local dungeonConfig={
  statueId=63529,statue={x=14232,y=19348,z=3},spawn={x=14232,y=19349,z=3},chestId=24875,
  names={"EldKar","Elorveth","Dreloriax","Noxeloria","Eldens Bane",
    "The Elorian Scourge","Eldenborn Shade","Voice of Eloria","Ashen Eldress","Eloriak the Blighted"}}
local function nowSec() return os.time() end
local function copyPos(p)
  if not p then return nil end
  return {x=p.x,y=p.y,z=p.z}
end

local function cheb(a,b)
  if not a or not b or a.z~=b.z then return 99999 end
  return math.max(math.abs(a.x-b.x),math.abs(a.y-b.y))
end

local function norm(s)
  return string.lower(tostring(s or "")):gsub("%s+"," ")
end

local function playerPos()
  local p=Player.getPosition()
  if p then return {x=p.x,y=p.y,z=p.z} end
  return Map.getCameraPosition()
end

local function online()
  local id=Player.getId()
  return id~=nil and id~=0
end

local function tileWalkable(p)
  if not p then return false end
  return Map.isTileWalkable(p.x,p.y,p.z,false,false,false,false)==true
end

local function nearestWalkableAround(target,me)
  local offsets={{1,0},{-1,0},{0,1},{0,-1}}
  local best=nil
  local bd=99999
  for _,o in ipairs(offsets) do
    local p={x=target.x+o[1],y=target.y+o[2],z=target.z}
    if tileWalkable(p) then
      local d=cheb(me,p)
      if d<bd then best=p; bd=d end
    end
  end
  return best
end

local function findButton(modal,needles,fallback)
  for _,b in ipairs(modal.buttons or {}) do
    local text=norm(b.text)
    for _,n in ipairs(needles) do
      if string.find(text,norm(n),1,true) then return b.id end
    end
  end
  return fallback
end

local D=E.dungeon
resetDungeon=function()
  D.current=1
  D.stage=E.enabled.dungeon and "WAIT STATUE" or "OFF"
  D.awaiting=false
  D.confirmAt=0
  D.inside=false
  D.enteredAt=0
  D.lastUse=0
  D.entryTarget=nil
  D.patrolCenter=nil
  D.phase=1
  D.lastWalk=0
  D.chestLastUse=0
  D.chestClicked=false
end

local function nextDungeon(reason)
  if reason then E.status="Dungeon: "..reason end
  D.current=(D.current or 1)+1
  D.awaiting=false
  D.inside=false
  D.entryTarget=nil
  D.patrolCenter=nil
  D.phase=1
  D.chestClicked=false
  D.lastUse=0
  if D.current>#dungeonConfig.names then
    E.enabled.dungeon=false
    D.stage="DONE"
    E.status="Dungeon list finished"
  else
    D.stage="NEXT: "..dungeonConfig.names[D.current]
  end
end

local function cooldownSeconds(text)
  text=tostring(text or "")
  local h,m,s=string.match(text,"%[CD:%s*(%d+):(%d+):(%d+)%]")
  if not h then
    h,m,s=string.match(string.lower(text),"cooldown%s+remaining:%s*(%d+):(%d+):(%d+)")
  end
  if not h then return 0 end
  return (tonumber(h) or 0)*3600+(tonumber(m) or 0)*60+(tonumber(s) or 0)
end

local function selectDungeonChoice(modal)
  for wanted=D.current,#dungeonConfig.names do
    local wantedName=norm(dungeonConfig.names[wanted])
    for _,c in ipairs(modal.choices or {}) do
      local text=norm(c.text)
      if string.find(text,wantedName,1,true) and cooldownSeconds(c.text)==0 then
        return wanted,c.id
      end
    end
  end
  -- Fallback: pozycja na liscie, nadal z prawdziwym choice.id.
  local first=math.max(1,D.current or 1)
  for i=first,#(modal.choices or {}) do
    local c=modal.choices[i]
    if c and cooldownSeconds(c.text)==0 then return i,c.id end
  end
  return nil,nil
end

local function dungeonOnModal(modal)
  if not E.enabled.dungeon then return false end
  local title=norm(modal.title)
  local message=norm(modal.message)

  if title=="solo dungeon system" or string.find(title,"solo dungeon",1,true) then
    local wanted,choiceId=selectDungeonChoice(modal)
    if not wanted then
      D.stage="NO FREE DUNGEON"
      return true
    end
    local enter=findButton(modal,{"enter","select","start","continue"},modal.defaultEnterButton)
    if enter==nil then enter=3 end
    D.current=wanted
    D.stage="SELECT "..dungeonConfig.names[wanted]
    if Game.modalWindowAnswer(modal.id,enter,choiceId,true) then
      D.stage="WAIT CONFIRM"
    else
      D.stage="SELECT REJECTED"
    end
    return true
  end

  if title=="confirm entry" or string.find(title,"confirm entry",1,true) then
    local enter=findButton(modal,{"enter now","enter","confirm","yes","start","ok"},nil)
    local cancel=findButton(modal,{"cancel","close","back"},modal.defaultEscapeButton)
    local isCooldown=string.find(message,"cooldown",1,true)~=nil or (cancel~=nil and enter==nil)

    if isCooldown then
      if cancel~=nil then Game.modalWindowAnswer(modal.id,cancel,255,true) end
      nextDungeon("cooldown -> next")
      return true
    end

    if enter==nil then enter=modal.defaultEnterButton end
    if enter==nil then
      D.stage="NO CONFIRM BUTTON"
      return true
    end

    if Game.modalWindowAnswer(modal.id,enter,255,true) then
      D.awaiting=true
      D.confirmAt=nowSec()
      D.stage="WAIT TELEPORT"
    else
      D.stage="CONFIRM REJECTED"
    end
    return true
  end

  return false
end

local function findDungeonChest()
  local me=playerPos()
  if not me then return nil end
  local best=nil
  local bd=99999
  for _,tile in ipairs(Map.getTiles() or {}) do
    local p=tile.position
    if p and p.z==me.z then
      for _,thing in ipairs(tile.things or {}) do
        if tonumber(thing.id)==dungeonConfig.chestId then
          local d=cheb(me,p)
          if d<bd then best=copyPos(p); bd=d end
        end
      end
    end
  end
  return best
end

dungeonTick=function()
  if not E.enabled.dungeon or not online() then return end
  local p=playerPos(); if not p then return end
  local now=nowSec()

  if D.awaiting then
    if cheb(p,dungeonConfig.spawn)>3 then
      D.awaiting=false
      D.inside=true
      D.enteredAt=now
      D.entryTarget=nil
      D.patrolCenter=copyPos(p)
      D.phase=1
      D.stage="PATROL LEFT"
      D.lastWalk=0
      return
    end
    if now-(D.confirmAt or now)>12 then
      nextDungeon("entry timeout")
    end
    return
  end

  if D.inside then
    if now-(D.enteredAt or now)>5 and cheb(p,dungeonConfig.spawn)<=2 then
      nextDungeon("completed")
      return
    end

    local chest=findDungeonChest()
    if chest then
      if cheb(p,chest)<=1 then
        if now-(D.chestLastUse or 0)>=2 then
          D.chestLastUse=now
          D.stage="USE CHEST 24875"
          if Map.useItem(chest.x,chest.y,chest.z) then
            D.chestClicked=true
            D.stage="CHEST CLICKED / WAIT TP"
          end
        end
      else
        local approach=nearestWalkableAround(chest,p)
        if approach and now-(D.lastWalk or 0)>=2 then
          D.lastWalk=now
          D.stage="GO CHEST 24875"
          Map.goTo(approach.x,approach.y,approach.z)
        end
      end
      return
    end

    if not D.patrolCenter then D.patrolCenter=copyPos(p) end
    local c=D.patrolCenter
    local targets={
      {x=c.x-11,y=c.y,z=c.z,label="LEFT"},
      {x=c.x,y=c.y,z=c.z,label="CENTER"},
      {x=c.x+11,y=c.y,z=c.z,label="RIGHT"},
      {x=c.x,y=c.y,z=c.z,label="CENTER"}
    }
    local target=targets[D.phase or 1]
    if cheb(p,target)==0 then
      D.phase=(D.phase or 1)+1
      if D.phase>4 then D.phase=1 end
      target=targets[D.phase]
    end
    D.stage="PATROL "..target.label
    if now-(D.lastWalk or 0)>=2 then
      D.lastWalk=now
      Map.goTo(target.x,target.y,target.z)
    end
    return
  end

  if cheb(p,dungeonConfig.statue)<=10 and now-(D.lastUse or 0)>=2 then
    D.lastUse=now
    D.stage="OPEN MODAL"
    Map.useItem(dungeonConfig.statue.x,dungeonConfig.statue.y,dungeonConfig.statue.z)
  else
    D.stage="WAIT STATUE"
  end
end
dungeonModal=dungeonOnModal
resetDungeon()
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
  status('Bosstiary: '..BOSSTIARY_ENTRIES[b.index].name..' / pokoj '..b.room)
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
  else status('Bosstiary: brak dostepnej trasy do '..(target.name or 'wyjscia')) end
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
    if mobs>0 then b.bossSeen=true;status('Bosstiary: '..target.name..' / walka')
    elseif b.bossSeen or now()-(b.enteredAt or now())>4000 then b.stage='EXIT';b.exitAt=now();b.lastMovePos=nil;b.stuck=0 end
    return
  end
  if b.stage=='EXIT' then
    local exit=findItem({[22761]=true},p,10)
    if exit then bosstiaryWalkTo(exit);status('Bosstiary: powrot przez wyjscie 22761')
    elseif now()-(b.exitAt or now())>3000 then
      -- Wait briefly for automatic return, then search reachable visible tiles.
      local searchTarget
      for _,tile in ipairs(screen()) do
        if tile.position.z==p.z and dist(p,tile.position)>=4 and walkable(tile.position) then
          if not searchTarget or (b.routeVisits and b.routeVisits[key(tile.position)] or 0)<(b.routeVisits and b.routeVisits[key(searchTarget)] or 0) then searchTarget=tile.position end
        end
      end
      if searchTarget then bosstiaryWalkTo(searchTarget) end
      status('Bosstiary: szukam wyjscia 22761')
    end
    return
  end
  if p.z~=target.z then status('Bosstiary: podejdz do sali wejsc na poziomie '..target.z);return end
  if dist(p,target)==0 then
    if b.stage~='MODAL' then b.openAt=now() end
    b.stage='MODAL';status('Bosstiary: '..target.name..' / czekam na pokoje')
    if now()-(b.openAt or now())>5000 then b.stage='APPROACH' end
    return
  end
  b.stage='APPROACH';bosstiaryWalkTo(target)
  status('Bosstiary: ide do '..target.name..' / pokoj '..b.room)
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
    status('Mining: pietro '..p.z..' / szukam skal')
  end
  if not same(p,m.lastPosition) then
    if m.lastPosition and dist(p,m.lastPosition)<=1 then
      m.heading={x=p.x-m.lastPosition.x,y=p.y-m.lastPosition.y}
    end
    m.lastPosition=copy(p);m.progressAt=now()
    E.visits[key(p)]=(E.visits[key(p)] or 0)+1
    E.tiles=nil
  end
  if E.api.Game.getItemCount(19249)<1 then status('Mining: brak kilofa 19249');return end
  if m.target then
    if now()<(E.rockDone[key(m.target)] or 0) then m.target=nil;return end
    if now()-(m.targetAt or now())>18000 and dist(p,m.target)>1 then
      E.rockDone[key(m.target)]=now()+15000;m.target=nil;return
    end
    if now()-(m.lastUse or m.targetAt or now())>8000 and dist(p,m.target)<=1 then
      E.rockDone[key(m.target)]=now()+15000;m.target=nil
      status('Mining: skala nie przyjmuje kilofa, szukam kolejnej');return
    end
    if go(m.target,1) and due('pickaxe',1100) then
      if E.api.Game.useItemOnGround(19249,m.target.x,m.target.y,m.target.z) then
        m.used=(m.used or 0)+1;m.lastUse=now();count('miningUses');status('Mining: kilof '..m.used..'/5')
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
  if m.explore then go(m.explore,0);status('Mining: szukam kolejnych skal') else status('Mining: brak dostepnej trasy') end
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
local function fishingTick()
  if not due('fishing',700) then return end
  local active=false;for _,on in pairs(E.fish) do if on then active=true end end
  if not active then return end
  if E.api.Game.getItemCount(3483)<1 then status('Fishing: brak wedki 3483');return end
  -- One shared map scan and at most one use per tick, even with six modes on.
  for offset=1,#fishModes do
    local i=(fishCursor+offset-1)%#fishModes+1;local mode=fishModes[i]
    if E.fish[i] then
      local ids={};for _,id in ipairs(mode.ids) do ids[id]=true end
      local p=findItem(ids)
      if p and E.api.Game.useItemOnGround(3483,p.x,p.y,p.z) then fishCursor=i;count('fishingUses');return end
    end
  end
end
function E.toggle(name)
  local value=not E.enabled[name]
  for _,n in ipairs({'boss','dungeon','bosstiary','mining'}) do E.enabled[n]=false end
  if value and name=='boss' and type(Game.bossSequenceStart)~='function' then status('Boss Run: brak API klienta');E.refresh();return end
  E.enabled[name]=value;stopMovement();E.modal=nil;E.tiles=nil
  if name=='boss' then E.boss.stage='IDLE';E.boss.tried={};E.boss.restUntil=0 end
  if name=='dungeon' then resetDungeon() end
  if name=='bosstiary' then E.bosstiary.stage='APPROACH' end
  status(value and (name..': ON') or 'Automatyzacja zatrzymana');E.refresh()
end

E.x,E.y=CONFIG.x,CONFIG.y
E.sections={runners=true,fishing=false,stats=false}
local colors={text={230,237,245},muted={165,180,195},on={88,224,172},off={236,173,113},blue={112,207,255},red={255,128,128}}
local function paint(h,color) local c=colors[color or 'text'];h:setColor(c[1],c[2],c[3]) end
local function label(id,text,y,callback,color,x)
  local r=E.widgets[id];x=x or E.x
  if not r then
    local h=HUD.new(x,y,text,true);local shadow=HUD.new(x+1,y+1,text,true)
    h:setFontSize(CONFIG.font);shadow:setFontSize(CONFIG.font)
    shadow:setColor(0,0,0);shadow:setPhantom(true);shadow:setZIndex(190);h:setZIndex(191)
    h:setDraggable(id=='title')
    if callback then h:setCallback(callback) end
    r={hud=h,shadow=shadow};E.widgets[id]=r
  end
  if r.text~=text then r.hud:setText(text);r.shadow:setText(text);r.text=text end
  if r.x~=x or r.y~=y then r.hud:setPos(x,y);r.shadow:setPos(x+1,y+1);r.x=x;r.y=y end
  paint(r.hud,color);r.keep=true
  if not r.shown then r.hud:show();r.shadow:show();r.shown=true end
end
function E.refresh()
  for _,r in pairs(E.widgets) do r.keep=false end
  label('title','Eloria HUD by Slandish',E.y,nil,'blue')
  label('min',E.minimized and '[+]' or '[-]',E.y,function() E.minimized=not E.minimized;E.refresh() end,'on',E.x+325)
  if not E.minimized then
    local y=E.y+CONFIG.rowHeight+7
    local function add(id,text,cb,color) label(id,text,y,cb,color);y=y+CONFIG.rowHeight end
    local function section(id,text)
      add('section'..id,(E.sections[id] and '[-] ' or '[+] ')..text,function() E.sections[id]=not E.sections[id];E.refresh() end,'blue')
      return E.sections[id]
    end
    if section('runners','RUNNERS & ROOMS') then
      for _,v in ipairs({{'boss','Boss Run'},{'dungeon','Dungeon Runner'},{'bosstiary','Bosstiary'},{'mining','Mining'}}) do
        local id,name=v[1],v[2]
        add(id,(E.enabled[id] and '[ON]  ' or '[OFF] ')..name,function() E.toggle(id) end,E.enabled[id] and 'on' or 'off')
      end
      add('category','Kategoria: '..({'EASY','MEDIUM','HARD'})[E.boss.category],function()
        if E.enabled.boss then status('Wylacz Boss Run przed zmiana');return end
        E.boss.category=E.boss.category%3+1;E.refresh()
      end)
      add('wave','Full Sequence / bossow: '..E.boss.wave,function()
        if E.enabled.boss then status('Wylacz Boss Run przed zmiana');return end
        E.boss.wave=({[1]=3,[3]=5,[5]=1})[E.boss.wave];E.refresh()
      end)
      add('room','Bosstiary: pokoj '..E.bosstiary.room..'/5 / boss '..E.bosstiary.index..'/123',nil,'muted')
      add('bosstiaryCycles','Bosstiary: pelne petle '..(E.bosstiary.cycles or 0),nil,'muted')

    end
    if section('fishing','FISHING / 6 TRYBOW') then
      for i,mode in ipairs(fishModes) do local index=i
        add('fish'..i,(E.fish[i] and '[ON]  ' or '[OFF] ')..mode.name,function() E.fish[index]=not E.fish[index];E.refresh() end,E.fish[i] and 'on' or 'off')
      end
      add('fishInfo','Wedka 3483 / bez wyrzucania itemow',nil,'muted')
    end
    if section('stats','SESSION ANALYZER') then
      local s=E.session;local seconds=math.floor((now()-s.start)/1000)
      add('time',string.format('Sesja %02d:%02d:%02d',math.floor(seconds/3600),math.floor(seconds/60)%60,seconds%60))
      add('profit','Profit / Loot / Supplies: brak API',nil,'off')
      add('xp','XP: '..(s.experience~=nil and short(s.experience) or '--')..' /h: '..(s.experienceHour and short(s.experienceHour) or '--'))
      add('damage','DMG z komunikatow: '..(s.damageSeen and short(s.damage) or '--'))
      add('dps','DPS 10s / peak: '..(s.damageSeen and short(s.dps)..' / '..short(s.peak) or '--'))
      add('maxHit','Max hit (komunikaty): '..(s.damageSeen and short(s.maxHit) or '--'))
      if s.damageSeen then add('target','Cel: '..s.target:sub(1,32)) end
      if not s.damageSeen then add('nodamage','Brak rozpoznanych danych obrazen',nil,'off') end
      local level=Player.getLevel()-(s.level or Player.getLevel())
      add('levels','Poziomy: '..level..'  /h: '..string.format('%.2f',level*3600/math.max(seconds,1)))
      add('reset','[ RESET SESJI ]',function() E.resetSession();E.refresh() end,'off')
    end
    if E.enabled.dungeon then
      add('dungeonState','Dungeon #'..tostring(E.dungeon.current)..': '..E.dungeon.stage,nil,'on')
    end
    local text=tostring(E.status)
    add('status',text:sub(1,46),nil,'muted')
    if #text>46 then add('status2',text:sub(47,92),nil,'muted') end
  end
  for _,r in pairs(E.widgets) do
    if not r.keep and r.shown then r.hud:hide();r.shadow:hide();r.shown=false end
  end
end
local function online() return Client.isConnected() and pos()~=nil end
local wasOnline=online()
function E.tick()
  if not E.alive then return end
  E.clock=math.max(E.clock+100,os.time()*1000)
  safe('ui',function()
    local r=E.widgets.title
    if r then
      local p=r.hud:getPos()
      if p.x~=E.x or p.y~=E.y then
        E.x=math.max(0,p.x);E.y=math.max(0,p.y);E.refresh()
      end
    end
  end)
  local connected=online()
  if connected~=wasOnline then
    E.enabled={};E.fish={};E.pending=nil;E.modal=nil;E.tiles=nil
    if connected then E.resetSession();status('Zalogowano / automatyzacje OFF') else status('Offline / automatyzacje OFF') end
    wasOnline=connected
  end
  if connected then
    if E.modal and now()-E.modal.at>=150 then
      local m=E.modal
      safe('modal',function() if E.enabled.bosstiary then bosstiaryModal(m) end end)
    end
    if E.enabled.boss then safe('boss',bossTick)
    elseif E.enabled.dungeon then safe('dungeon',function()
      local wasInside=E.dungeon.inside
      local wasChest=E.dungeon.chestClicked
      dungeonTick()
      if wasInside and not E.dungeon.inside and E.status=='Dungeon: completed' then count('dungeons') end
      if not wasChest and E.dungeon.chestClicked then count('chests') end
    end)
    elseif E.enabled.bosstiary then safe('bosstiary',bosstiaryTick)
    elseif E.enabled.mining then safe('mining',mineTick) end
    safe('fishing',fishingTick)
  end
  if due('refresh',1000) then safe('stats',sampleStats);safe('ui',E.refresh) end
end
E.callbacks={}
local function register(id,fn)
  Game.registerEvent(id,fn);E.callbacks[#E.callbacks+1]={id=id,fn=fn}
end
function E.shutdown()
  E.alive=false;destroyTimer('eloria-zerobot-gd7-v2')
  for _,cb in ipairs(E.callbacks) do Game.unregisterEvent(cb.id,cb.fn) end
  for _,r in pairs(E.widgets) do r.hud:destroy();r.shadow:destroy() end
end
E.resetSession()
register(Game.Events.MODAL_WINDOW,function(m)
  if E.enabled.dungeon then
    safe('dungeonModal',function()
      local previous=E.dungeon.current
      dungeonModal(m)
      if E.dungeon.current~=previous and E.status=='Dungeon: cooldown -> next' then count('cooldowns') end
    end)
    return
  end
  E.onModal(m.id,m.title,m.message,m.buttons,m.defaultEnterButton,m.defaultEscapeButton,m.choices,m.priority)
end)
register(Game.Events.TEXT_MESSAGE,function(m)
  if type(m)~='table' then return end
  safe('analyzerText',function() damageMessage(m) end)
  safe('text',function() E.onText(m.messageType,tostring(m.text or '')) end)
end)
E.refresh()
Timer.new('eloria-zerobot-gd7-v2',E.tick,100,true)
print('Eloria ZeroBot HUD 4.5 GD7: gotowy. Profit: brak API; damage: tylko dostarczone komunikaty.')
