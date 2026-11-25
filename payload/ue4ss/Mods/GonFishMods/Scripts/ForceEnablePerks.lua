return function(config)
    config=config or {}
    local P=require("GonFishPlayers")
    ForceEnablePerks=ForceEnablePerks or {}
    local M=ForceEnablePerks
    local last_error=nil
    M.GetLocalPlayerFishingClient=P.LocalFishingClient
    M.GetAssetOrInstance=function(path)
        local object=StaticFindObject(path)
        return P.Valid(object) and object or nil
    end
    function M.CheckPlayer()
        P.AssertGameThread()
        for _,context in ipairs(P.Contexts()) do
            -- Private-room host applies the same always-on perks to authoritative player actors.
            -- A client only touches its own local pawn, never another player's proxy.
            local remote_allowed=config.ApplyToRemotePlayersOnHost~=false
            if context.IsLocal or (remote_allowed and context.IsAuthority) then
                local perks=P.Read(context.Pawn,"AC_Perks")
                if P.Valid(perks) then
                    local ok,err=pcall(function()
                        perks.SetStickyHook(true,context.Pawn)
                        local movement=PlayerMovement
                        local local_boost=context.IsLocal and movement and
                            (movement.SpeedEnabled or (movement.Current and movement.Current.SpeedOriginal~=nil))
                        local bridge=GonFishMultiplayer
                        local state=bridge and bridge.Session and bridge.Session:StateFor(context.Controller)
                        if not local_boost and not(state and state.Speed>0)then
                            perks.SetSprintSpeed(750,context.Pawn)
                        end
                        perks.SetHasFishWhisperer(true,context.Pawn)
                    end)
                    if not ok and last_error~=tostring(err) then
                        last_error=tostring(err)
                        print("[ForceEnablePerks] player-specific apply failed: "..last_error.."\n")
                    end
                end
            end
        end
    end
    if not M.LoopStarted then
        M.LoopStarted=true
        LoopInGameThreadWithDelay(3333,function()
            local ok,err=pcall(M.CheckPlayer)
            if not ok and last_error~=tostring(err) then
                last_error=tostring(err);print("[ForceEnablePerks] "..last_error.."\n")
            end
            return false
        end)
    end
end
