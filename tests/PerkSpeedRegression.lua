local source=assert(arg[1]);local calls=0
local pawn={};local perks={SetStickyHook=function()end,SetHasFishWhisperer=function()end,SetSprintSpeed=function()calls=calls+1 end};pawn.AC_Perks=perks
local P={AssertGameThread=function()end,Contexts=function()return {{Pawn=pawn,IsLocal=true,IsAuthority=true}}end,Read=function(o,k)return o[k]end,Valid=function(o)return o~=nil end}
package.preload.GonFishPlayers=function()return P end
PlayerMovement={SpeedEnabled=true};LoopInGameThreadWithDelay=function()end
local mod=assert(loadfile(source))()({})
ForceEnablePerks.CheckPlayer();assert(calls==0,"perk loop rewrites sprint settings while movement boost is active")
PlayerMovement.SpeedEnabled=false;ForceEnablePerks.CheckPlayer();assert(calls==1)
print("periodic perk loop leaves active speed mode alone and restores normal perk refresh after OFF PASS")
