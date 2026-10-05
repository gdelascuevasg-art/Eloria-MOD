-- Logger de XP (Claude). Cada 30 s: seg,raw,final,kills,nivel,epoch -> /xp_exped.txt
if ZX then removeEvent(ZX.ev) disconnect(g_game,{onUpdateExperience=ZX.cb}) ZX=nil end
ZX={f="/xp_"..os.date("%m%d_%H%M")..".txt",t=os.time(),r=0,x=0,k=0,l={}}
ZX.cb=function(r,x) ZX.r=ZX.r+(tonumber(r) or 0) ZX.x=ZX.x+(tonumber(x) or 0) ZX.k=ZX.k+1 end
connect(g_game,{onUpdateExperience=ZX.cb})
ZX.ev=cycleEvent(function()
  local p=g_game.getLocalPlayer()
  ZX.l[#ZX.l+1]=string.format("%d,%.0f,%.0f,%d,%d,%d",os.time()-ZX.t,ZX.r,ZX.x,ZX.k,p and p:getLevel() or 0,os.time())
  g_resources.writeFileContents(ZX.f,table.concat(ZX.l,"\n"))
end,30000)
print("[XP] grabando en "..ZX.f)
