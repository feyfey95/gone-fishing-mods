local dir=assert(arg[1]);package.path=dir.."/?.lua;"..package.path
local output=print
local registered,required={},{}
print=function()end
RegisterKeyBind=function(key)registered[#registered+1]=key end
RegisterHook=function()error("removed module registered a hook")end
_G.CrazeirGambles=nil;_G.LuckierFishBite=nil
for _,name in ipairs({"CrazierGambles","LuckierFishBite"})do
    assert(loadfile(dir.."/"..name..".lua"))()({enabled=true})
end
assert(#registered==0 and CrazeirGambles==nil and LuckierFishBite==nil)
output("removed module paths are inert even when directly called with enabled=true PASS")
local initialize,cancelled
ExecuteInGameThread=function(fn)fn()end
LoopInGameThreadWithDelay=function(_,fn)initialize=fn;return 123 end
CancelDelayedAction=function(id)cancelled=id end
local API={initialized=true,PinNativeCallbackThread=function()end}
API.LoadConfig=function()
    API.ModConfig={CrazierGambles={enabled=true},LuckierFishBite={enabled=true},Unlisted={enabled=true},PlayerMovement={enabled=true}}
end
GonFishModAPI=API
local real_require=require
require=function(name)
    required[name]=true
    if name=="GonFishModAPI" then return API end
    assert(name=="PlayerMovement","unsupported module loaded: "..name)
    return function()end
end
assert(loadfile(dir.."/main.lua"))();assert(initialize()==true and cancelled==123)
assert(required.PlayerMovement and not required.CrazierGambles and not required.LuckierFishBite and not required.Unlisted)
require=real_require
output("stale or edited enabled settings cannot re-enable removed modules through public loader PASS")
local settings=assert(loadfile(dir.."/../settings.lua"))()
assert(settings.CrazierGambles==nil and settings.LuckierFishBite==nil)
output("public settings contain no removed feature entries PASS")
