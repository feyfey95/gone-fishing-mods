local P = {}

function P.Valid(object)
    if object == nil then return false end
    local ok, value = pcall(function() return object:IsValid() end)
    return ok and value == true
end

function P.Read(object, name)
    if not P.Valid(object) then return nil end
    local ok, value = pcall(function() return object[name] end)
    if ok then return value end
end

function P.Id(object)
    if not P.Valid(object) then return nil end
    local ok, address = pcall(function() return object:GetAddress() end)
    if ok and address then return tostring(address) end
end

function P.Same(a, b)
    local id = P.Id(a)
    return id ~= nil and id == P.Id(b)
end

local function flag(controller, method)
    local ok, value = pcall(function() return controller[method](controller) end)
    return ok and value == true
end

function P.AssertGameThread()
    assert(IsInGameThread and IsInGameThread(), "GonFishPlayers requires GameThread")
end

function P.FromController(controller)
    P.AssertGameThread()
    local id=P.Id(controller)
    local pawn=P.Read(controller,"Pawn")
    if not id or not P.Valid(pawn)then return nil end
    local state=P.Read(controller,"PlayerState")
    local player_id=P.Read(state,"PlayerId")
    return {Controller=controller,Pawn=pawn,Key=id,PlayerId=type(player_id)=="number"and player_id or nil,
        IsLocal=flag(controller,"IsLocalController"),IsAuthority=flag(controller,"HasAuthority")}
end
function P.Contexts()
    P.AssertGameThread()
    local result,seen={},{}
    for _,controller in ipairs(FindAllOf("PlayerController")or {})do
        local context=P.FromController(controller)
        if context and not seen[context.Key]then seen[context.Key]=true;result[#result+1]=context end
    end
    return result
end

function P.LocalContext()
    for _, context in ipairs(P.Contexts()) do
        -- Ignore valid menu/lobby DefaultPawns: gameplay functions need the character's movement component.
        if context.IsLocal and P.Valid(P.Read(context.Pawn,"CharacterMovement")) then return context end
    end
end

function P.ForPawn(pawn)
    if not P.Valid(pawn) then return nil end
    for _, context in ipairs(P.Contexts()) do
        if P.Same(context.Pawn, pawn) then return context end
    end
end

function P.ForComponent(component, field)
    if not P.Valid(component) then return nil end
    for _, context in ipairs(P.Contexts()) do
        if P.Same(P.Read(context.Pawn, field), component) then return context end
    end
end

function P.StillControls(context)
    P.AssertGameThread()
    return context and P.Valid(context.Controller) and P.Valid(context.Pawn)
        and P.Same(P.Read(context.Controller, "Pawn"), context.Pawn)
end

function P.FishingForPawn(pawn)
    P.AssertGameThread()
    if not P.Valid(pawn) then return nil end
    for _, instance in ipairs(FindAllOf("AC_FishingonClientWIZARD_C") or {}) do
        if P.Valid(instance) and P.Same(P.Read(instance, "PlayerCharacter"), pawn) then
            return instance
        end
    end
end

function P.LocalFishingClient()
    local context = P.LocalContext()
    return context and P.FishingForPawn(context.Pawn) or nil
end

return P
