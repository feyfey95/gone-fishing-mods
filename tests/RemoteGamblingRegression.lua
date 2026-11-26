local dir=assert(arg[1]);package.path=dir.."/?.lua;"..package.path
local output=print;print=function()end
IsInGameThread=function()return true end
RegisterKeyBind=function()error("host service must not register any hotkey")end
local function object(address)return {IsValid=function()return true end,GetAddress=function()return address end}end
local fn=object(123)
fn.ForEachProperty=function(_,callback)
    callback({GetFullName=function()return "ObjectProperty Dummy:FishOwner"end,GetOffset_Internal=function()return 16 end})
end
local pools={remote_on=object(1),remote_off=object(2),host=object(3),unknown=object(4)}
local tasks,prehooks,posts,randoms={},{},{},{}
StaticFindObject=function(name)return pools[name] or (name:match(":ScaleFishCompeteServer$") and fn or nil)end
RegisterHook=function(path,callback)posts[#posts+1]=callback end
GonFishModAPI={NativeFeatureCallbacksEnabled=true,
    AddTask=function(_,callback)tasks[#tasks+1]=callback end,
    AddFunctionObjectScope=function(name,addr,offset,pre,post)
        assert(offset=="16");prehooks[#prehooks+1]=pre;posts[#posts+1]=post;return true
    end,
    AddRandomFloatInRangePosthook=function(name,callback)randoms[#randoms+1]=callback;return true end}
GonFishMultiplayer={IsHost=true,Ready=true,AllowRemoteMaxWin=true,BetSettings=function(pool)
    if pool==pools.remote_on then return {MaxWin=true}end
    if pool==pools.remote_off then return {MaxWin=false}end
end}
local service=assert(loadfile(dir.."/RemoteGambling.lua"))()({})
assert(#tasks==1 and #randoms==1);tasks[1]();assert(#prehooks==1 and #posts==1)
service.Scan();assert(#prehooks==1 and #posts==1)
output("native callbacks register once per function address with no local hotkeys PASS")
assert(service.RandomPost(1,6.5,2)==nil)
service.Pre("remote_on");local boosted=service.RandomPost(1,6.5,2);assert(boosted>=6.25 and boosted<=6.5)
service.Pre("remote_off");assert(service.RandomPost(1,6.5,2)==nil);service.Post()
assert(service.RandomPost(1,6.5,2)>=6.25);service.Post();assert(service.RandomPost(1,6.5,2)==nil)
for _,name in ipairs({"remote_off","host","unknown","invalid"})do
    service.Pre(name);assert(service.RandomPost(1,6.5,2)==nil);service.Post()
end
service.Pre("BP_Pool_C remote_on","Player_C remote_on")
assert(service.RandomPost(1,6.5,2)>=6.25);service.Post()
output("only enabled remote-owner context modifies RNG; nested/OFF/local/unknown bets remain normal PASS")
service.Pre("remote_on");GonFishMultiplayer.AllowRemoteMaxWin=false
assert(service.RandomPost(1,6.5,2)==nil);service.Post();GonFishMultiplayer.AllowRemoteMaxWin=true
GonFishMultiplayer.IsHost=false;service.Pre("remote_on");assert(service.RandomPost(1,6.5,2)==nil);service.Post()
output("host opt-out and non-authority clients cannot apply the service PASS")
GonFishModAPI.NativeFeatureCallbacksEnabled=false
local count=#randoms;assert(loadfile(dir.."/RemoteGambling.lua"))()({});assert(#randoms==count)
output("incompatible native feature gate leaves gameplay unchanged PASS")
local Session=require("MultiplayerSession");local Codec=require("MultiplayerProtocol")
local disabled=Session.New("12345678",function()return 0 end,function(c)return c end,function()return true end)
local packet=assert(Codec.Encode("12345678",1,{Speed=3,AirJump=true,MaxWin=true,Rerolls=5000,Hotspot=true}))
local state=assert(disabled:Receive("peer",packet));assert(not state.MaxWin and state.Rerolls==5 and not state.Hotspot)
output("session max-win capability defaults OFF unless the public host explicitly enables it PASS")
