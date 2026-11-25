local feature_dir, main_source = assert(arg[1]), assert(arg[2])
local host_print = print
package.path=feature_dir.."/?.lua;"..package.path
FindAllOf=function()return {}end
StaticFindObject=function()return {IsValid=function()return false end}end
RegisterHook=function()end
local loaded, keys, loops, cancelled = {}, {}, {}, {}
print = function() end
Key = {ONE=0x31,TWO=0x32,F1=0x70}
IsInGameThread = function() return true end
ExecuteInGameThread = function(fn) fn() end
RegisterKeyBind = function(key,fn) assert(not keys[key], "duplicate key"); keys[key]=fn end
LoopInGameThreadWithDelay = function(delay,fn) loops[#loops+1]={delay=delay,fn=fn}; return #loops end
CancelDelayedAction = function(handle) cancelled[handle]=true end
GonFishModAPI = {
    initialized=true, NativeFeatureCallbacksEnabled=true,
    PinNativeCallbackThread=function() end,
    LoadConfig=function() GonFishModAPI.ModConfig=assert(loadfile(feature_dir.."/settings.lua"))() end,
    AddTask=function() end, AddRandomFloatInRangePosthook=function() return true end,
    AddFunctionPrehook=function() return true end,
}
package.preload.GonFishModAPI = function() return GonFishModAPI end
for _,name in ipairs({"PlayerMovement","MultiplayerBridge","RemoteGambling","ForceEnablePerks","FasterBeerDrinking"}) do
    local module_name=name
    package.preload[module_name]=function()
        loaded[module_name]=true
        return assert(loadfile(feature_dir.."/"..module_name..".lua"))()
    end
end
for _,name in ipairs({"LuckierFishBite","CustomFishingCursor"}) do
    local module_name=name
    package.preload[module_name]=function() loaded[module_name]=true; return function() end end
end
assert(loadfile(main_source))()
assert(loops[1].delay==500)
assert(loops[1].fn()==true and cancelled[1])
assert(loaded.PlayerMovement and not loaded.CrazierGambles)
assert(not loaded.LuckierFishBite and loaded.ForceEnablePerks and loaded.FasterBeerDrinking and loaded.CustomFishingCursor)
assert(keys[Key.ONE] and keys[Key.TWO] and not keys[Key.F1])
assert(not GonFishModAPI.ModConfig.MultiplayerDiscovery.enabled)
assert(GonFishModAPI.ModConfig.MultiplayerBridge.enabled)
assert(GonFishModAPI.ModConfig.PlayerMovement.JumpHeightMultiplier==1)
assert(table.concat(GonFishModAPI.ModConfig.PlayerMovement.SpeedSteps,",")=="0,2,5,10")
assert(loaded.MultiplayerBridge and loaded.RemoteGambling)
assert(GonFishModAPI.ModConfig.MultiplayerBridge.AllowRemoteMaxWin==true)
host_print("public loader loads retained features, binds 1/2 and leaves F1 unbound PASS")
