return function(config)

    config = config or {}

    local M = {

        SpeedEnabled = false, AirJumpEnabled = false,

        SpeedIndex = 1, SpeedMultiplier = 0,

        SpeedSteps = config.SpeedSteps or {0, 2, 5, 10},

        JumpHeightMultiplier = tonumber(config.JumpHeightMultiplier) or 1,

        Errors = {}, Current = nil,

    }

    local AIR_JUMP_LIMIT = 2147483647 -- int32 max: no practical session jump limit.

    assert(type(M.SpeedSteps) == "table" and #M.SpeedSteps >= 2 and M.SpeedSteps[1] == 0,

        "SpeedSteps must start with OFF (0)")

    for i, value in ipairs(M.SpeedSteps) do

        assert(type(value) == "number" and value == value and value >= 0 and value <= 10,

            "SpeedSteps values must be between 0 and 10")

        if i > 1 then assert(value > 0, "Only the first speed step may be OFF") end

    end

    assert(M.JumpHeightMultiplier >= 1 and M.JumpHeightMultiplier <= 10,

        "JumpHeightMultiplier must be between 1 and 10")

    PlayerMovement = M



    local function valid(object)

        if object == nil then return false end

        local ok, result = pcall(function() return object:IsValid() end)

        return ok and result == true

    end



    local function log(message)

        print("[PlayerMovement] " .. message .. "\n")

    end



    local function notify(message)

        log(message)

        if GonFishModAPI and GonFishModAPI.SendLocalChatMessage then

            local ok, err = pcall(GonFishModAPI.SendLocalChatMessage,

                "PlayerMovement", message, {R=0.3, G=0.8, B=0.5, A=1})

            if not ok then log("notification failed: " .. tostring(err)) end

        end

    end



    local function checked(label, operation)

        local ok, err = pcall(operation)

        if ok then M.Errors[label] = nil

        elseif M.Errors[label] ~= tostring(err) then

            M.Errors[label] = tostring(err)

            log(label .. ": " .. tostring(err))

        end

        return ok

    end



    local function identity(object)

        return tostring(object:GetAddress())

    end



    -- Select only a local controller, never the first remote player found.

    function M.ResolvePlayer()

        for _, controller in ipairs(FindAllOf("PlayerController") or {}) do

            if valid(controller) then

                local ok, is_local = pcall(function() return controller:IsLocalController() end)

                if ok and is_local == true then

                    -- GetPawn is a C++ accessor, not a callable UFunction in this build.

                    local pawn = controller.Pawn

                    if valid(pawn) then

                        local movement = pawn.CharacterMovement

                        if valid(movement) then return pawn, movement end

                    end

                end

            end

        end

    end



    function M.Restore(record)

        if not record then return end

        if record.SpeedOriginal ~= nil and valid(record.Movement) then

            checked("restore speed", function()

                record.Movement.MaxWalkSpeed = record.SpeedOriginal

                record.SpeedOriginal = nil

            end)

        end

        if record.JumpOriginal ~= nil and valid(record.Pawn) then

            checked("restore jumps", function()

                record.Pawn.JumpMaxCount = record.JumpOriginal

                record.JumpOriginal = nil

            end)

        end

        if record.JumpZOriginal ~= nil and valid(record.Movement) then

            checked("restore jump height", function()

                record.Movement.JumpZVelocity = record.JumpZOriginal

                record.JumpZOriginal = nil

            end)

        end

    end



    function M.Update()

        if not (IsInGameThread and IsInGameThread()) then

            log("update rejected outside GameThread")

            return false

        end

        local resolved, pawn, movement = pcall(M.ResolvePlayer)

        if not resolved then

            checked("resolve player", function() error(pawn) end)

            return false

        end

        M.Errors["resolve player"] = nil

        if not pawn then

            M.Restore(M.Current)

            M.Current = nil

            return false

        end

        local key = identity(pawn) .. ":" .. identity(movement)

        if M.Current and M.Current.Key ~= key then

            M.Restore(M.Current)

            M.Current = nil

        end

        if not M.Current then

            M.Current = {Key=key, Pawn=pawn, Movement=movement}

            log("local character acquired: " .. key)

        end

        local record = M.Current

        checked("speed", function()

            if M.SpeedEnabled then

                if record.SpeedOriginal == nil then

                    local original = movement.MaxWalkSpeed

                    assert(type(original) == "number" and original > 0 and original < math.huge,

                        "MaxWalkSpeed unavailable or zero; waiting for a movable character")

                    record.SpeedOriginal = original

                    log("speed baseline=" .. tostring(original) .. "; target=" .. tostring(original * M.SpeedMultiplier))

                end

                local target = record.SpeedOriginal * M.SpeedMultiplier
                local bridge=GonFishMultiplayer
                local override=bridge and bridge.LocalMovementOverride()
                if override and override.Speed>0 then target=override.Speed end

                if movement.MaxWalkSpeed ~= target then movement.MaxWalkSpeed = target end

                assert(math.abs(movement.MaxWalkSpeed - target) < 0.01, "MaxWalkSpeed write did not stick")

                if record.SpeedApplied ~= target then

                    log("speed applied=" .. tostring(movement.MaxWalkSpeed) .. "; mode=" .. tostring(M.SpeedMultiplier) .. "x")

                    record.SpeedApplied = target

                end

            elseif record.SpeedOriginal ~= nil then

                movement.MaxWalkSpeed = record.SpeedOriginal

                record.SpeedOriginal = nil

                record.SpeedApplied = nil

            end

        end)

        checked("air jump", function()

            if M.AirJumpEnabled then

                if record.JumpOriginal == nil then

                    local count = pawn.JumpMaxCount

                    local velocity = movement.JumpZVelocity

                    assert(type(count) == "number" and count >= 0 and count % 1 == 0,

                        "JumpMaxCount unavailable")

                    assert(type(velocity) == "number" and velocity > 0 and velocity < math.huge,

                        "JumpZVelocity unavailable or zero")

                    -- Validate both values before changing either property.

                    record.JumpOriginal = count

                    record.JumpZOriginal = velocity

                    record.JumpZTarget = velocity * math.sqrt(M.JumpHeightMultiplier)

                    log("air jump baseline count=" .. tostring(count) .. "; JumpZVelocity=" .. tostring(velocity))

                end

                if pawn.JumpMaxCount ~= AIR_JUMP_LIMIT then pawn.JumpMaxCount = AIR_JUMP_LIMIT end

                if math.abs(movement.JumpZVelocity - record.JumpZTarget) > 0.01 then

                    movement.JumpZVelocity = record.JumpZTarget

                end

                assert(pawn.JumpMaxCount == AIR_JUMP_LIMIT, "JumpMaxCount write did not stick")

                assert(math.abs(movement.JumpZVelocity - record.JumpZTarget) < 0.01,

                    "JumpZVelocity write did not stick")

                if not record.JumpApplied then

                    log("air jump applied; JumpMaxCount=" .. tostring(pawn.JumpMaxCount) ..

                        "; JumpZVelocity=" .. tostring(movement.JumpZVelocity) ..

                        "; ballistic height=" .. tostring(M.JumpHeightMultiplier) .. "x")

                    record.JumpApplied = true

                end

            else

                if record.JumpOriginal ~= nil then

                    pawn.JumpMaxCount = record.JumpOriginal

                    record.JumpOriginal = nil

                end

                if record.JumpZOriginal ~= nil then

                    movement.JumpZVelocity = record.JumpZOriginal

                    record.JumpZOriginal = nil

                end

                record.JumpApplied = nil

            end

        end)

        return false

    end



    local function schedule_change(feature)

        ExecuteInGameThread(function()

            local ok, err = pcall(function()

                if feature == "speed" then

                    M.SpeedIndex = M.SpeedIndex % #M.SpeedSteps + 1

                    M.SpeedMultiplier = M.SpeedSteps[M.SpeedIndex]

                    M.SpeedEnabled = M.SpeedMultiplier > 0

                else

                    M.AirJumpEnabled = not M.AirJumpEnabled

                end

                M.Update()

                local pending = not M.Current or M.Errors["resolve player"] or M.Errors["update"]

                if feature == "speed" then

                    local state = M.SpeedEnabled and ("ON (" .. tostring(M.SpeedMultiplier) .. "x)") or "OFF"

                    if M.SpeedEnabled and (pending or M.Errors.speed or not M.Current.SpeedApplied) then

                        state = state .. " - waiting for character; check log"

                    end

                    notify("Speed " .. state)

                else

                    local state = M.AirJumpEnabled and

                        ("ON (unlimited; height ~" .. tostring(M.JumpHeightMultiplier) .. "x)") or "OFF"

                    if M.AirJumpEnabled and (pending or M.Errors["air jump"] or not M.Current.JumpApplied) then

                        state = state .. " - waiting for character; check log"

                    end

                    notify("Air jump " .. state)

                end

            end)

            if not ok then log("toggle failed: " .. tostring(err)) end

        end)

    end



    RegisterKeyBind(Key[config.SpeedHotkey or "ONE"], function() schedule_change("speed") end)

    RegisterKeyBind(Key[config.AirJumpHotkey or config.DoubleJumpHotkey or "TWO"], function() schedule_change("air jump") end)

    M.LoopHandle = LoopInGameThreadWithDelay(tonumber(config.UpdateIntervalMs) or 100, function()

        checked("update", M.Update)

        return false

    end)

    log("loaded v2; 1=speed OFF/2x/5x/10x; 2=unlimited air jump; height=" .. tostring(M.JumpHeightMultiplier) .. "x; both OFF at startup")

    return M

end

