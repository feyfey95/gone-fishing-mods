local source = assert(arg[1])
local host_print = print
local queued = arg[2] == "queued"
local gt = not queued
local keys, tasks, hooks, queue, messages = {}, {}, {}, {}, {}
print = function() end
Key = {F1=0x70}
local object = {IsValid=function() return true end, GetAddress=function() return 0x1234 end}
StaticFindObject = function() assert(gt); return object end
RegisterKeyBind = function(key,fn) keys[key]=fn end
RegisterHook = function(name,fn) hooks[name]=fn end
ExecuteInGameThread = function(fn)
    if queued then queue[#queue+1]=fn else fn() end
end
GonFishModAPI = {
    initialized=true,
    GetLocalPlayerFishingClient=function() assert(gt); return object end,
    SendLocalChatMessage=function(_,msg) assert(gt); messages[#messages+1]=msg end,
    AddTask=function(delay,fn) tasks[#tasks+1]={delay=delay,fn=fn} end,
    AddFunctionPrehook=function() return true end,
    AddRandomFloatInRangePosthook=function() return true end,
}
GonFishMultiplayer={BetSettings=function()return {MaxWin=CrazeirGambles.do_max_win}end}
assert(loadfile(source))()({GuaranteeMaxWinHotkey="F1"})
local function flush()
    gt=true
    while #queue>0 do table.remove(queue,1)() end
end
gt=true; tasks[1].fn()
for _,task in ipairs(tasks) do if task.delay==7500 then task.fn(); break end end
local post=assert(hooks[CrazeirGambles.targer_function])
assert(not CrazeirGambles.do_max_win)
gt=not queued; keys[Key.F1]()
if queued then assert(not CrazeirGambles.do_max_win, "toggle must be queued") end
flush()
assert(CrazeirGambles.do_max_win)
for i=1,3 do
    CrazeirGambles.ScaleFishCompeteServer_Pre("bloodpool")
    local value=CrazeirGambles.RandomFloatInRange_Post(1,10,3)
    assert(type(value)=="number" and value>=9.75 and value<=10)
    post()
    assert(CrazeirGambles.latest_bloodpool_instance==nil, "context must be cleared")
    assert(CrazeirGambles.do_max_win, "max-win toggle must persist after gamble "..i)
    assert(CrazeirGambles.RandomFloatInRange_Post(1,10,3)==nil, "no modification outside a gamble")
end
host_print("three gambles retain max-win mode and clear RNG context PASS")
gt=not queued; keys[Key.F1](); flush()
assert(not CrazeirGambles.do_max_win)
CrazeirGambles.ScaleFishCompeteServer_Pre("bloodpool")
assert(CrazeirGambles.RandomFloatInRange_Post(1,10,3)==nil)
post()
assert(not CrazeirGambles.do_max_win)
host_print("F1 toggles off PASS")
if queued then host_print("all F1 object work deferred to GameThread PASS") end
