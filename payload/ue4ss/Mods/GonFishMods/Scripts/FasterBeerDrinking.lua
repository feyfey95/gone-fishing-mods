return function(config)
    local P=require("GonFishPlayers")
    FasterBeerDrinking=FasterBeerDrinking or {}
    local M=FasterBeerDrinking
    M.GetLocalPlayerFishingClient=P.LocalFishingClient
    function M.OnDrinkingBeerLogic(self)
        -- Hook execution may originate elsewhere; ownership and UObject work run on GameThread.
        local ok,component=pcall(function() return self:Get() end)
        if not ok then return end
        ExecuteInGameThread(function()
            local success,err=pcall(function()
                local owner=P.ForComponent(component,"AC_BEER")
                if not owner then return end
                if not owner.IsAuthority then
                    print("[FasterBeerDrinking] local animation only; awaiting host completion\n")
                    return
                end
                print("[FasterBeerDrinking] scheduling original drinker's completion\n")
                GonFishModAPI.AddTask(2550,function()
                    local completed,reason=pcall(function()
                        if not P.Valid(component) or not P.StillControls(owner) then return end
                        if not P.Same(P.Read(owner.Pawn,"AC_BEER"),component) then return end
                        if not component["CanDrink?"] then component.BeerComplete(component) end
                    end)
                    if not completed then print("[FasterBeerDrinking] completion failed: "..tostring(reason).."\n") end
                end)
            end)
            if not success then print("[FasterBeerDrinking] owner resolution failed: "..tostring(err).."\n") end
        end)
    end
    function M.SpeedUpBeerDrinking()
        P.AssertGameThread()
        local animation=StaticFindObject("/Game/Characters/PlaceHolder/Animations/Idle_DrinkReal.Idle_DrinkReal")
        if P.Valid(animation) then
            animation.RateScale=3.0
            print("[FasterBeerDrinking] Speeding up Idle_DrinkReal to 3x\n")
        end
        RegisterHook("/Game/Items/Beer/AC_BEERAndalsoUpgradesAndAlsoEmotes.AC_BEERAndalsoUpgradesAndAlsoEmotes_C:DrinkingBeerLogic",M.OnDrinkingBeerLogic)
    end
    M.SpeedUpBeerDrinking()
end
