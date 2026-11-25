local source = assert(arg[1], "source file required")
local host_print = print
local logs = {}
print = function(...) local t={...}; for i,v in ipairs(t) do t[i]=tostring(v) end; logs[#logs+1]=table.concat(t," ") end
local function setup(initial, sequence, factor)
    LuckierFishBite = nil
    logs = {}
    local tasks, hooks, keybinds = {}, {}, {}
    local calls, native_adds, native_removes = 0,0,0
    local fish = {valid=true}
    function fish:IsValid() return self.valid end
    function FName(v) return {value=v,ToString=function(self) return self.value end} end
    local curve = function(mult) return {IsValid=function()return true end,GetFloatValue=function(_,x)return x*mult end} end
    local curves={fish_test=curve(1),fish_a=curve(1),fish_b=curve(10)}
    function StaticFindObject(path)
        if path:find("DT_FishWeightScales",1,true) then
            return {ForEachRow=function(_,fn)
                for name,c in pairs(curves) do fn(name,{WeightScale_10_D50D86534BC4A3CA5F4B6083DB3B2BB7=c}) end
            end}
        end
        return {IsValid=function()return true end,GetAddress=function()return 0x1234 end}
    end
    Key=setmetatable({},{__index=function(_,k)return k end})
    function RegisterKeyBind(key,cb)keybinds[key]=cb end
    function RegisterHook(name,cb)hooks[name]=cb;return 1,2 end
    GonFishModAPI={initialized=true,
        BindGameThreadKey=RegisterKeyBind,
        GetLocalPlayerFishingClient=function()return fish end,
        SendLocalChatMessage=function(...)end,
        AddTask=function(delay,cb)tasks[#tasks+1]=cb end,
        AddFunctionPrehook=function(...)native_adds=native_adds+1;return true end,
        RemoveFunctionPrehook=function(...)native_removes=native_removes+1;return true end}
    assert(loadfile(source))()({LuckFactor=factor,CatchSpecial=false})
    for _,key in pairs(LuckierFishBite.StateBefore)do fish[key]=0 end
    for _,key in pairs(LuckierFishBite.StateAfter)do fish[key]=0 end
    fish.CurrentFishName=FName(initial.name);fish.FishWeight=initial.weight
    fish["Fish Ranking(1-10)(Each Type)"]=initial.rank
    fish["HotSpot?"]=false;fish["hotspotMythic?"]=false
    fish["DecideFish (FishBites)"]=function(self)
        calls=calls+1;local next=assert(sequence[calls],"unexpected reroll")
        self.CurrentFishName=FName(next.name);self.FishWeight=next.weight
        self["Fish Ranking(1-10)(Each Type)"]=next.rank
    end
    local out_rank={set=function(self,v)self.value=v end}
    local out_name={set=function(self,v)self.value=v end}
    local self={Get=function()return fish end}
    local flag={Get=function()return false end}
    return {fish=fish,rank=out_rank,name=out_name,self=self,flag=flag,tasks=tasks,hooks=hooks,
            calls=function()return calls end,native_adds=function()return native_adds end,
            native_removes=function()return native_removes end}
end
local cases={
 {"best-final-reroll",{name="Fish_Test",rank=1,weight=1},{{name="Fish_A",rank=10,weight=10},{name="Fish_A",rank=20,weight=20}},"Fish_A",20,20},
 {"best-first-reroll",{name="Fish_Test",rank=1,weight=1},{{name="Fish_A",rank=20,weight=20},{name="Fish_A",rank=10,weight=10}},"Fish_A",20,20},
 {"keep-better-initial",{name="Fish_Test",rank=30,weight=30},{{name="Fish_A",rank=20,weight=20},{name="Fish_A",rank=10,weight=10}},"Fish_Test",30,30},
 {"curve-weight-not-rank",{name="Fish_Test",rank=1,weight=1},{{name="Fish_A",rank=3,weight=3},{name="Fish_B",rank=2,weight=20}},"Fish_B",2,20}
}
for _,c in ipairs(cases) do
    local t=setup(c[2],c[3],#c[3])
    LuckierFishBite.OnFishBite_Pre()
    LuckierFishBite.OnFishBite(t.self,t.flag,t.flag,t.rank,t.name)
    assert(t.calls()==#c[3],c[1]..": reroll count")
    assert(t.rank.value==c[5],c[1]..": expected rank "..c[5]..", got "..tostring(t.rank.value))
    assert(t.fish.FishWeight==c[6],c[1]..": chosen fish weight")
    assert(t.fish.CurrentFishName:ToString()==c[4],c[1]..": chosen fish name")
    host_print(c[1].." PASS")
end
local t=setup({name="Fish_Test",rank=1,weight=1},{},0)
LuckierFishBite.OnFishBite(t.self,t.flag,t.flag,t.rank,t.name)
assert(t.calls()==0 and #t.tasks>0,"reporting-only must not reroll")
host_print("reporting-only PASS")
t=setup({name="Fish_Test",rank=1,weight=1},{},1);t.fish.valid=false
LuckierFishBite.OnFishBite(t.self,t.flag,t.flag,t.rank,t.name)
assert(t.calls()==0,"invalid fish client must not reroll")
host_print("invalid-client PASS")
t=setup({name="Fish_Test",rank=1,weight=1},{},1)
LuckierFishBite.OnFishBite=function()error("controlled test failure")end
local cb=assert(t.hooks[LuckierFishBite.DecideFishHookName]);cb(t.self,t.flag,t.flag,t.rank,t.name)
assert(not LuckierFishBite.IsRerollingOnFishBite and LuckierFishBite.PreFishBiteState==nil,"cleanup after failure")
local logged=false;for _,line in ipairs(logs)do if line:find("OnFishBite error ::",1,true)then logged=true end end
assert(logged,"callback errors must be observable")
host_print("callback-error-observable-and-cleaned-up PASS")

t=setup({name="Fish_Test",rank=1,weight=1},{},1)
GonFishModAPI.IsLocalFishingClient=function(object)return object==t.fish end
local cb=assert(t.hooks[LuckierFishBite.DecideFishHookName])
cb({Get=function()return {}end})
assert(t.native_removes()==0 and t.calls()==0,"remote event must not remove the local native hook or reroll local fish")
host_print("remote fish event leaves local hook/state untouched PASS")

LuckierFishBite.IsRerollingOnFishBite=true
GonFishModAPI.IsLocalFishingClient=function()error("nested rerolls must not rescan controllers")end
cb({Get=function()return {}end})
host_print("nested rerolls skip repeated multiplayer ownership scans PASS")
