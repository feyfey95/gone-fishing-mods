return function(config)
    config = config or {}
    local P = require("GonFishPlayers")
    local seen, done, warned = {}, {}, {}
    local handle, ticks, attempts = nil, 0, 0
    local bet_observer_registered, bet_samples = false, 0
    local function log(message) print("[GFM-MP-DISCOVERY] " .. message .. "\n") end
    local function text(operation, fallback)
        local ok,value=pcall(operation)
        return ok and tostring(value) or fallback
    end
    local function warn_once(label, message)
        if not warned[label] then warned[label]=true;log(label..": "..tostring(message)) end
    end
    local function inspect_function(fn)
        local name=text(function() return fn:GetFullName() end,"<unknown function>")
        local flags=text(function() return string.format("0x%08X",fn:GetFunctionFlags()) end,"<unavailable>")
        local params={}
        local ok,err=pcall(function()
            fn:ForEachProperty(function(prop)
                params[#params+1]=text(function() return prop:GetFullName() end,"<unknown property>")
                if #params>=32 then return true end
            end)
        end)
        log("FUNCTION "..name.." FLAGS="..flags.." PARAMS="..table.concat(params," ; "))
        if not ok then warn_once(name,err) end
        return ok
    end
    local function inspect_class(class, label)
        if not P.Valid(class) then return false end
        local name=text(function() return class:GetFullName() end,"<unknown class>")
        if seen[name] then return true end
        local functions_complete=true
        local ok,err=pcall(function()
            log("CLASS "..label.." "..name)
            local count=0
            class:ForEachFunction(function(fn)
                if not inspect_function(fn) then functions_complete=false end
                count=count+1
                if count>=200 then return true end
            end)
            local fields=0
            class:ForEachProperty(function(prop)
                log("FIELD "..text(function() return prop:GetFullName() end,"<unknown>"))
                fields=fields+1;if fields>=120 then return true end
            end)
        end)
        if ok and functions_complete then seen[name]=true;return true end
        if not ok then warn_once(name,err) end
        return false
    end
    local function observe_bet(self,target)
        if bet_samples>=3 then return end
        local extracted,actor=pcall(function() return target:Get() end)
        if not extracted then return end
        bet_samples=bet_samples+1
        local sample=bet_samples
        local function inspect()
            if not P.Valid(actor) then log("BET sample="..sample.." target no longer valid");return end
            local name=text(function()return actor:GetClass():GetFullName()end,"<unknown class>")
            local candidate=nil
            for _,context in ipairs(P.Contexts()) do
                if P.Same(context.Pawn,actor) or P.Same(context.Controller,actor)
                    or P.Same(P.FishingForPawn(context.Pawn),actor) then
                    candidate=context
                    break
                end
            end
            log("BET sample="..sample.." TargetClass="..name.." matchedPlayerId="..
                tostring(candidate and candidate.PlayerId).." authority="..tostring(candidate and candidate.IsAuthority))
        end
        if IsInGameThread and IsInGameThread() then
            local ok,err=pcall(inspect)
            if not ok then warn_once("bet sample",err) end
        else
            ExecuteInGameThread(function()
                local ok,err=pcall(inspect)
                if not ok then warn_once("bet sample",err) end
            end)
        end
    end
    local function inspect_object(object,label)
        if not P.Valid(object) then return false end
        local ok,class=pcall(function() return object:GetClass() end)
        if not ok then warn_once(label,class);return false end
        local primary_ok=false
        for depth=1,4 do
            if not P.Valid(class) then break end
            local class_ok=inspect_class(class,label.." depth="..depth)
            if depth==1 then primary_ok=class_ok end
            local parent_ok,parent=pcall(function() return class:GetSuperStruct() end)
            if not parent_ok or not P.Valid(parent) or P.Same(parent,class) then break end
            class=parent
        end
        return primary_ok
    end
    local function tick()
        P.AssertGameThread()
        ticks=ticks+1
        local context=P.LocalContext()
        if context then
            if not done.controller then done.controller=inspect_object(context.Controller,"local controller") end
            if not done.character then done.character=inspect_object(context.Pawn,"local character") end
            if not done.chat then done.chat=inspect_object(P.Read(context.Controller,"MultiplayerChat_C"),"chat component") end
            if not done.perks then done.perks=inspect_object(P.Read(context.Pawn,"AC_Perks"),"perk component") end
            if not done.beer then done.beer=inspect_object(P.Read(context.Pawn,"AC_BEER"),"beer component") end
            if not done.fishing then done.fishing=inspect_object(P.FishingForPawn(context.Pawn),"fishing component") end
        end
        if not done.gamble then
            local path="/Game/PaulosCreations/DemonicAltar_HellGate_BloodPool/BloodPool/BluePrints/BP_BloodPool.BP_BloodPool_C:ScaleFishCompeteServer"
            local target=StaticFindObject(path)
            if P.Valid(target) then
                done.gamble=inspect_function(target)
                if done.gamble and not bet_observer_registered then
                    local ok,err=pcall(function()RegisterHook(path,observe_bet)end)
                    if ok then bet_observer_registered=true else warn_once("bet observer",err) end
                end
            end
        end
        if (done.controller and done.character and done.chat and done.fishing and done.gamble) or ticks>=180 then
            log("END ticks="..ticks.." controller="..tostring(done.controller).." character="..tostring(done.character)..
                " chat="..tostring(done.chat).." fishing="..tostring(done.fishing).." gamble="..tostring(done.gamble))
            CancelDelayedAction(handle)
            return true
        end
        return false
    end
    handle=LoopInGameThreadWithDelay(1000,function()
        attempts=attempts+1
        local ok,result=pcall(tick)
        if not ok then warn_once("probe",result) end
        if not ok and attempts>=180 then
            log("END after repeated probe errors; no network calls were attempted")
            CancelDelayedAction(handle)
            return true
        end
        return ok and result or false
    end)
    log("BEGIN read-only signatures; no RPC calls, property writes, or network messages")
end
