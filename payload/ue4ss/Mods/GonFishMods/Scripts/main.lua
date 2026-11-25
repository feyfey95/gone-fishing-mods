-- Explicit allowlist: old settings cannot re-enable modules removed from this edition.
local supported = {
    ForceEnablePerks=true, FasterBeerDrinking=true, CustomFishingCursor=true,
    PlayerMovement=true, MultiplayerBridge=true, RemoteGambling=true,
}
ExecuteInGameThread(function()
    print("[GonFishMods] public edition initialization ...\n")
    require("GonFishModAPI")
    local initializationLoopHandle
    initializationLoopHandle = LoopInGameThreadWithDelay(500, function()
        if GonFishModAPI and GonFishModAPI.initialized then
            local status, err = pcall(function()
                GonFishModAPI.PinNativeCallbackThread()
                GonFishModAPI.LoadConfig()
                for name, config in pairs(GonFishModAPI.ModConfig) do
                    if type(config)=="table" and config.enabled then
                        if supported[name] and (name~="RemoteGambling" or GonFishModAPI.NativeFeatureCallbacksEnabled) then
                            print("[GonFishMods] loading mod :: "..name.."\n")
                            require(name)(config)
                        else
                            print("[GonFishMods] unsupported public-edition module skipped :: "..tostring(name).."\n")
                        end
                    end
                end
            end)
            if not status then print("[GonFishMods] loading mods error :: "..tostring(err).."\n") end
            CancelDelayedAction(initializationLoopHandle)
            return true
        end
        return false
    end)
end)
