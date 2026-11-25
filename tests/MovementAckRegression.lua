local source = assert(arg[1])
local HEIGHT = tonumber(arg[2]) or 1
local host_print = print
local function setup()
    local t = {gt=false, queue={}, keys={}, controllers={}, logs={}, loops={}}
    print = function(msg) t.logs[#t.logs+1] = msg end
    Key = {ONE=0x31, TWO=0x32, SEVEN=0x37, EIGHT=0x38}
    IsInGameThread = function() return t.gt end
    ExecuteInGameThread = function(fn) t.queue[#t.queue+1] = fn end
    RegisterKeyBind = function(key, fn) assert(not t.keys[key]); t.keys[key] = fn end
    LoopInGameThreadWithDelay = function(ms, fn) t.loops[#t.loops+1] = fn; return #t.loops end
    FindAllOf = function(name) assert(t.gt); assert(name == "PlayerController"); return t.controllers end
    GonFishModAPI = {SendLocalChatMessage=function() assert(t.gt) end}
    t.module = assert(loadfile(source))()({SpeedMultiplier=2, JumpHeightMultiplier=HEIGHT})
    function t.run(fn)
        t.gt = true
        local ok, err = pcall(fn)
        t.gt = false
        assert(ok, err)
    end
    function t.tick() t.run(function() assert(t.module.Update() == false) end) end
    function t.flush()
        while #t.queue > 0 do t.run(table.remove(t.queue, 1)) end
    end
    function t.key(key) t.keys[key](); t.flush() end
    function t.object(data)
        local object = {}
        local methods = {
            IsValid=function() return data.valid ~= false end,
            GetAddress=function() assert(t.gt); return data.address end,
            IsLocalController=function() assert(t.gt); return data.local_player end,
            GetPawn=setmetatable({}, {__call=function() error("attempt to call a TrivialObject value (method 'GetPawn')") end}),
        }
        setmetatable(object, {
            __index=function(_, key)
                if methods[key] then return methods[key] end
                assert(t.gt, "object access outside GameThread")
                assert(data.valid ~= false, "invalid object accessed")
                return data[key]
            end,
            __newindex=function(_, key, value)
                assert(t.gt, "write outside GameThread")
                assert(data.valid ~= false, "invalid object written")
                data[key] = value
            end,
        })
        return object
    end
    function t.player(id, speed, jumps, local_player, jump_z)
        local md = {address=id+1, MaxWalkSpeed=speed, JumpZVelocity=jump_z or 420, GravityScale=1}
        local movement = t.object(md)
        local pd = {address=id, CharacterMovement=movement, JumpMaxCount=jumps, JumpCurrentCount=0}
        local pawn = t.object(pd)
        local cd = {address=id+2, Pawn=pawn, local_player=local_player ~= false}
        return {movement=movement, pawn=pawn, controller=t.object(cd), md=md, pd=pd, cd=cd}
    end
    return t
end

GonFishMultiplayer={IsHost=false,Ready=true,LocalMovementOverride=function()return nil end}
local t=setup();local p=t.player(100,300,1);t.controllers={p.controller};t.tick()
t.key(Key.SEVEN)
assert(p.md.MaxWalkSpeed==300,"client applied unacknowledged speed while server still at baseline: "..p.md.MaxWalkSpeed)
host_print("no client/server speed mismatch before ACK PASS")

local confirmed={Speed=900,JumpZ=500}
GonFishMultiplayer.LocalMovementOverride=function()return confirmed end
t.module.AirJumpEnabled=true;t.tick()
assert(p.md.MaxWalkSpeed==900 and p.md.JumpZVelocity==500 and p.pd.JumpMaxCount>1000000)
t.key(Key.SEVEN);assert(t.module.SpeedMultiplier==5 and p.md.MaxWalkSpeed==900)
confirmed={Speed=1500,JumpZ=500};t.tick();assert(p.md.MaxWalkSpeed==1500)
t.key(Key.SEVEN);assert(not t.module.SpeedEnabled and p.md.MaxWalkSpeed==1500)
confirmed={Speed=0,JumpZ=0};t.tick();assert(p.md.MaxWalkSpeed==300 and p.md.JumpZVelocity==420 and p.pd.JumpMaxCount==1)
host_print("pending transitions retain last ACK; absolute server speed/jump and OFF restore PASS")
