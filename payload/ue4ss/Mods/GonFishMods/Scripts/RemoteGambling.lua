-- Public host service, deliberately without local hotkeys or local gambling bias.
-- The installed full client sends its own toggle through the existing per-player protocol.
return function(config)
    local P=require("GonFishPlayers")
    local API=assert(GonFishModAPI)
    local M={Stack={},Registered={}}
    local target="/Game/PaulosCreations/DemonicAltar_HellGate_BloodPool/BloodPool/BluePrints/BP_BloodPool.BP_BloodPool_C:ScaleFishCompeteServer"
    local function log(message)print("[GFM-RemoteGambling] "..message.."\n")end
    function M.Pre(object_name,fish_owner_name)
        P.AssertGameThread()
        local entry={Enabled=false}
        -- Always push an entry so nested calls restore the enclosing scope.
        M.Stack[#M.Stack+1]=entry
        local bridge=GonFishMultiplayer
        if not bridge or not bridge.IsHost or not bridge.AllowRemoteMaxWin or not bridge.Ready then return end
        entry.Enabled=bridge.RoomMaxWin()==true
        M.ScopesSeen=(M.ScopesSeen or 0)+1
        if M.ScopesSeen<=3 then log("room gamble scope entered; maxwin="..tostring(entry.Enabled))end
    end
    function M.Post()
        P.AssertGameThread()
        M.Stack[#M.Stack]=nil
    end
    function M.RandomPost(minimum,maximum,result)
        P.AssertGameThread()
        local bridge=GonFishMultiplayer
        local active=M.Stack[#M.Stack]
        if not active or not active.Enabled or not bridge or not bridge.IsHost or not bridge.AllowRemoteMaxWin then return end
        if type(minimum)~="number" or type(maximum)~="number" or type(result)~="number" then return end
        if minimum~=minimum or maximum~=maximum or maximum<minimum or maximum==math.huge then return end
        return math.max(minimum,maximum-math.random()*math.min(0.25,maximum-minimum))
    end
    function M.Scan()
        P.AssertGameThread()
        local bridge=GonFishMultiplayer
        if bridge and bridge.IsHost and bridge.AllowRemoteMaxWin then
            local fn=StaticFindObject(target)
            if P.Valid(fn)then
                local address=string.format("%X",fn:GetAddress())
                if not M.Registered[address]then
                    require("GambleObjectScope").RegisterGlobal(API,fn,M.Pre,M.Post)
                    M.Registered[address]=true
                    log("host support active; local gambling controls unavailable")
                end
            end
        end
        API.AddTask(1500,M.Scan)
    end
    if not API.NativeFeatureCallbacksEnabled or not API.AddFunctionObjectScope or not API.AddRandomFloatInRangePosthook then
        log("host support unavailable: matching native API required")
        return M
    end
    API.AddRandomFloatInRangePosthook("ScaleFishCompeteServer",M.RandomPost)
    API.AddTask(10,M.Scan)
    return M
end
