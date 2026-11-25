ExecuteInGameThread(function()
    print("\n")
    print("\n")
    print("\n")
    print("[GonFishMods] starting intialization ...\n")
    require("GonFishModAPI")
    
    local initializationLoopHandle
    initializationLoopHandle = LoopInGameThreadWithDelay(500, function()
        if GonFishModAPI and  GonFishModAPI.initialized then
            local status, err = pcall(function()
                GonFishModAPI.PinNativeCallbackThread()
                GonFishModAPI.LoadConfig()

                for k, v in pairs(GonFishModAPI.ModConfig) do
                    local requiresNativeHooks = (k == "LuckierFishBite" or k == "CrazierGambles")
                    if v.enabled and (not requiresNativeHooks or GonFishModAPI.NativeFeatureCallbacksEnabled) then
                        print("[GonFishMods] loading mod :: " .. tostring(k) .. " ...\n")
                        if k == "LuckierFishBite" then
                            v.LuckFactor = 5
                            v.LuckyPullLuckMult = 10
                            v.RarePullLuckMult = 100
                            v.MythicPullLuckMult = 1000
                            v.CatchSpecial = true
                            print("[GFM-DIAG] LuckierFishBite original high multipliers; LuckFactor=5; F7=50/F8=500/F9=5000 rerolls; CatchSpecial=true\n")
                        end
                        require(k)(v)
                    elseif v.enabled and requiresNativeHooks then
                        print("[GFM-DIAG] skipped native-dependent mod :: " .. tostring(k) .. "\n")
                    end
                end
            end)

            if not status then
                print("[GonFishMods] loading mods error :: " .. tostring(err) .. "\n")
            end

            CancelDelayedAction(initializationLoopHandle)
            return true
        elseif GonFishModAPI then
            print("[GonFishMods] GonFishModAPI is not ready yet!\n")
        end

        return false
    end)
end)
