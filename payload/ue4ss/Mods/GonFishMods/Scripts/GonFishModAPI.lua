print("[GonFishModAPI] api init ...\n")
GonFishModAPI = GonFishModAPI or {}
GonFishModAPI.NativeHooksEnabled = true
GonFishModAPI.NativeFeatureCallbacksEnabled = true

-- Keep the owner coroutine alive while native code retains its lua_State pointer.
GonFishModAPI.NativeCallbackThreads = GonFishModAPI.NativeCallbackThreads or {}
GonFishModAPI.PinNativeCallbackThread = function()
    local owner = coroutine.running()
    if type(owner) ~= "thread" then
        error("[GFM-DIAG] Native callback registration has no Lua thread")
    end
    GonFishModAPI.NativeCallbackThreads[owner] = true
end
GonFishModAPI.KeepNativeCallbackThread = function(native_function)
    return function(...)
        GonFishModAPI.PinNativeCallbackThread()
        return native_function(...)
    end
end
GonFishModAPI.PinNativeCallbackThread()

local Players = require("GonFishPlayers")
GonFishModAPI.GetLocalPlayerFishingClient = function()
    local client = Players.LocalFishingClient()
    GonFishModAPI.CurrentFishingClient = client
    return client
end

GonFishModAPI.IsLocalFishingClient = function(object)
    return Players.Same(object, Players.LocalFishingClient())
end

GonFishModAPI.BindGameThreadKey = function(key, callback)
    RegisterKeyBind(key, function()
        ExecuteInGameThread(function()
            local ok, err = pcall(callback)
            if not ok then print("[GonFishModAPI] key callback failed: " .. tostring(err) .. "\n") end
        end)
    end)
end

GonFishModAPI.MySpecialMsgType = 31

GonFishModAPI.OnExecuteUbergraph_Message = function(self, ...)
    if GonFishModAPI.OnExecuteUbergraph_Message_Reroll then
        return
    end

    GonFishModAPI.OnExecuteUbergraph_Message_Reroll = true

    local status, error = pcall(function()
        local self = self:Get()

        local msg_type = self["Message Type"]

        if msg_type == GonFishModAPI.MySpecialMsgType then
            if not GonFishModAPI.HidingChatMessage then
                local text = self.Name:ToString()
                local color = self.NameColor
                local msg_text = self.MessageText

                self["Message Type"] = 0
                self:Message()
                self["Message Type"] = GonFishModAPI.MySpecialMsgType

                local MyColor = {
                    SpecifiedColor = {R=color.R, G=color.G, B=color.B, A=color.A},
                    ColorUseRule = 0
                }

                msg_text.SetDefaultColorAndOpacity(MyColor)
                msg_text:SetText(FText(text))
            else
                GonFishModAPI.HidingChatMessage = false
            end
        end
    end)

    GonFishModAPI.OnExecuteUbergraph_Message_Reroll = false

    if not status then
        print(error .. "\n")
    end
end

GonFishModAPI.OnHideMessage = function(self, ...)
    local self = self:Get()

    local msg_type = self["Message Type"]

    if msg_type == GonFishModAPI.MySpecialMsgType then
        GonFishModAPI.HidingChatMessage = true
    end
end

GonFishModAPI.TreadWithDelayID = 312

GonFishModAPI.SendLocalChatMessage = function(src, msg, color)
    local src = src
    local msg = msg
    local color = color

    GonFishModAPI.AddTask(10, function()
        local my_fishing_client = GonFishModAPI.GetLocalPlayerFishingClient()

        if my_fishing_client and my_fishing_client:IsValid() then
            local player_character = my_fishing_client.PlayerCharacter
            local PC = player_character.PlayerController
            local chat = PC.MultiplayerChat_C

            if chat and chat:IsValid() then

                local MessageType = 0
                local MyText = FText("")
                local MyPlayerName = FName("[".. src .. "] " .. msg)
                local Channel = 0

                chat["Enter Text Function"](chat, MessageType, MyText, MyPlayerName, color, Channel)

                local chat_internal = chat["Chat Ref"]
                if not (chat_internal and chat_internal:IsValid()) then
                    print("[GonFishModAPI] no Chat Ref !!!\n")
                    return
                end

                local chat_scroll = chat_internal.GeneralChatScrollBox
                if not (chat_scroll and chat_scroll:IsValid()) then
                    print("[GonFishModAPI] no GeneralChatScrollBox !!!\n")
                    return
                end

                local msg_slot = chat_scroll.Slots[1]
                if not (msg_slot and msg_slot:IsValid()) then
                    print("[GonFishModAPI] no Slots[1] !!!\n")
                    return
                end

                local chat_msg = msg_slot.Content
                if not (chat_msg and chat_msg:IsValid()) then
                    print("[GonFishModAPI] no Content !!!\n")
                    return
                end

                local msg_text = chat_msg.MessageText
                if not (msg_text and msg_text:IsValid()) then
                    print("[GonFishModAPI] no MessageText !!!\n")
                    return
                end

                chat_msg["Message Type"] = GonFishModAPI.MySpecialMsgType
                chat_msg.NameColor = color
                chat_msg:ShowMessage()
            end
        end
    end)
end

GonFishModAPI.ModConfig = {}

GonFishModAPI.LoadConfig = function()
    local cur_path = tostring(debug.getinfo(1).source):gsub("^@", ""):gsub("\\", "/"):gsub("/Scripts/GonFishModAPI.lua$", "")
    local configPath = cur_path .. "/settings.lua"
    local success, result = pcall(dofile, configPath)

    if success then
        for k, v in pairs(result) do
            GonFishModAPI.ModConfig[k] = v
        end
    else
        print("[GonFishModAPI] config error :: " .. tostring(result) .. "\n")
    end
end

GonFishModAPI.TaskCounter = 0
GonFishModAPI.SchedulerTasks = {}
GonFishModAPI.AddTask = function(delay, callback)
    if not (delay and type(callback) == "function") then
        print("GonFishModAPI] wrong parameters to AddTask() !\n")
        print("    delay :: " .. tostring(delay) .. "\n")
        print("    callback :: " .. tostring(callback) .. "\n")
        return
    end

    local time = os.clock() + (delay / 1000.0)

    GonFishModAPI.TaskCounter = GonFishModAPI.TaskCounter + 1
    GonFishModAPI.SchedulerTasks[GonFishModAPI.TaskCounter] = {
        time = time,
        callback = callback
    }
end 

GonFishModAPI.SchedulerRun = function()
    local time = os.clock()

    for key, task in pairs(GonFishModAPI.SchedulerTasks) do
        if task and task.time and task.callback and task.time <= time then
            task.callback()
            GonFishModAPI.SchedulerTasks[key] = nil
            break
        end
    end
end

GonFishModAPI.OnTick = function()
    local status, err = pcall(GonFishModAPI.SchedulerRun)

    if not status then
        print("[GonFishModAPI] lua error :: " .. tostring(err) .. "\n")
    end

    return false
end


print("[GonFishModAPI] delaying hooks and dll loading ...\n")

ExecuteInGameThreadWithDelay(2000, function()
    print("[GonFishModAPI] hooking and loading dlls ...\n")

    if not GonFishModAPI.RegisteredHookOnExecuteUbergraph_Message then
        RegisterHook("Function /Game/MultiplayerChat/ChatWidgets/Message.Message_C:ExecuteUbergraph_Message", function(self, ...)
            GonFishModAPI.OnExecuteUbergraph_Message(self, ...)
        end)

        GonFishModAPI.RegisteredHookOnExecuteUbergraph_Message = true
    end

    if not GonFishModAPI.RegisteredHookOnHideMessage then
        RegisterHook("Function /Game/MultiplayerChat/ChatWidgets/Message.Message_C:HideMessage", function(self, ...)
            GonFishModAPI.OnHideMessage(self, ...)
        end)
        RegisterHook("Function /Game/MultiplayerChat/ChatWidgets/Message.Message_C:HideBackground", function(self, ...)
            GonFishModAPI.OnHideMessage(self, ...)
        end)
        RegisterHook("Function /Game/MultiplayerChat/ChatWidgets/Message.Message_C:HideMessageAfterTimer", function(self, ...)
            GonFishModAPI.OnHideMessage(self, ...)
        end)
        RegisterHook("Function /Game/MultiplayerChat/ChatWidgets/Message.Message_C:HidebackgroundAfterTimer", function(self, ...)
            GonFishModAPI.OnHideMessage(self, ...)
        end)

        GonFishModAPI.RegisteredHookOnHideMessage = true
    end

    if GonFishModAPI.NativeHooksEnabled then
        local cur_path = tostring(debug.getinfo(1).source):gsub("^@", ""):gsub("\\", "/"):gsub("/Scripts/GonFishModAPI.lua$", "")
        local dll_path = cur_path .. "/Lib/ExtendedBPHooker.dll"

        print("[GonFishModAPI] loading dll at :: " .. dll_path .. "\n")
        if not (IsInGameThread and IsInGameThread()) then
            error("[GFM-DIAG] Native initialization must run on GameThread")
        end
        local configure_game_thread, configure_error = package.loadlib(dll_path, "configure_game_thread")
        if not configure_game_thread then
            error("[GFM-DIAG] Missing native configure export: " .. tostring(configure_error))
        end
        if configure_game_thread() ~= true then
            error("[GFM-DIAG] Native GameThread configuration failed")
        end
        print("[GFM-DIAG] native GameThread configured; callback thread lifetime fix active; reroll settings follow mod loading log\n")

        local add_function_prehook, err = package.loadlib(dll_path, "add_function_prehook")
        if not add_function_prehook then
            print("[GonFishModAPI] DLL Load Error: " .. tostring(err) .. "\n")
        else
            GonFishModAPI.AddFunctionPrehook = GonFishModAPI.KeepNativeCallbackThread(add_function_prehook)
        end
    
        local add_random_float_in_range_posthook, err = package.loadlib(dll_path, "add_random_float_in_range_posthook")
        if not add_random_float_in_range_posthook then
            print("[GonFishModAPI] DLL Load Error: " .. tostring(err) .. "\n")
        else
            GonFishModAPI.AddRandomFloatInRangePosthook = GonFishModAPI.KeepNativeCallbackThread(add_random_float_in_range_posthook)
        end
    
        local add_random_integer_in_range_posthook, err = package.loadlib(dll_path, "add_random_integer_in_range_posthook")
        if not add_random_integer_in_range_posthook then
            print("[GonFishModAPI] DLL Load Error: " .. tostring(err) .. "\n")
        else
            GonFishModAPI.AddRandomIntegerInRangePosthook = GonFishModAPI.KeepNativeCallbackThread(add_random_integer_in_range_posthook)
        end
    
        local remove_function_prehook, err = package.loadlib(dll_path, "remove_function_prehook")
        if not remove_function_prehook then
            print("[GonFishModAPI] DLL Load Error: " .. tostring(err) .. "\n")
        else
            GonFishModAPI.RemoveFunctionPrehook = remove_function_prehook
        end


    else
        print("[GFM-DIAG] ExtendedBPHooker loading disabled for isolation test\n")
    end

    LoopInGameThreadWithDelay(10, GonFishModAPI.OnTick)

    GonFishModAPI.initialized = true

    return true
end)

return GonFishModAPI