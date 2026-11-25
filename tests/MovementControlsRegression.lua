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

local t = setup()
local p = t.player(100,600,1)
t.controllers = {p.controller}; t.tick()
assert(t.module.Current and p.md.MaxWalkSpeed==600 and p.pd.JumpMaxCount==1)
assert(t.keys[Key.SEVEN] and t.keys[Key.EIGHT] and not t.keys[Key.ONE] and not t.keys[Key.TWO])
host_print("new 7/8 bindings, defaults off and reflected Pawn ownership PASS")
for cycle=1,3 do
    for _,expected in ipairs({1800,3000,600}) do
        local previous=p.md.MaxWalkSpeed
        t.keys[Key.SEVEN]()
        assert(p.md.MaxWalkSpeed==previous,"queued key must not write before GameThread")
        t.flush()
        assert(p.md.MaxWalkSpeed==expected,"speed cycle expected "..expected..", got "..tostring(p.md.MaxWalkSpeed))
        t.tick(); assert(p.md.MaxWalkSpeed==expected,"speed multiplier must not compound")
    end
end
host_print("OFF/3/5/OFF speed cycle, three rounds without compounding PASS")
t.key(Key.SEVEN); p.md.MaxWalkSpeed=750; t.tick()
assert(p.md.MaxWalkSpeed==1800)
for i=1,2 do t.key(Key.SEVEN) end
assert(p.md.MaxWalkSpeed==600)
host_print("game overwrite recovery and original speed restore PASS")
t.key(Key.EIGHT)
assert(t.module.AirJumpEnabled and p.pd.JumpMaxCount>=1000000,"air jump limit must be practically unlimited")
local z=420*math.sqrt(HEIGHT)
assert(math.abs(p.md.JumpZVelocity-z)<0.01,"height multiplier must follow the configured value")
assert(math.abs((p.md.JumpZVelocity/420)^2-HEIGHT)<0.0001)
for i=1,200 do
    p.pd.JumpCurrentCount=i; t.tick()
    assert(p.pd.JumpMaxCount>p.pd.JumpCurrentCount)
    assert(p.pd.JumpCurrentCount==i,"must not reset engine's jump counter")
    assert(math.abs(p.md.JumpZVelocity-z)<0.01,"jump speed must not compound")
end
assert(p.md.GravityScale==1)
t.key(Key.EIGHT)
assert(p.pd.JumpMaxCount==1 and p.md.JumpZVelocity==420)
assert(p.pd.JumpCurrentCount==200)
host_print("200 air-jump count checks, configured ballistic height, gravity unchanged, restore PASS")
t.key(Key.EIGHT);t.key(Key.EIGHT);t.key(Key.EIGHT)
assert(math.abs(p.md.JumpZVelocity-z)<0.01)
t.key(Key.SEVEN);t.key(Key.SEVEN) -- 5x
local p2=t.player(200,400,3,true,500)
p.cd.valid=false;t.controllers={p2.controller};t.tick()
assert(p.md.MaxWalkSpeed==600 and p.pd.JumpMaxCount==1 and p.md.JumpZVelocity==420)
assert(p2.md.MaxWalkSpeed==2000 and p2.pd.JumpMaxCount>=1000000)
assert(math.abs(p2.md.JumpZVelocity-500*math.sqrt(HEIGHT))<0.01)
host_print("speed mode and air jump migrate to respawn with separate baselines PASS")
p2.cd.valid=false;t.controllers={};t.tick()
assert(p2.md.MaxWalkSpeed==400 and p2.pd.JumpMaxCount==3 and p2.md.JumpZVelocity==500)
assert(t.module.SpeedEnabled and t.module.AirJumpEnabled)
local remote=t.player(300,500,1,false)
local local_p=t.player(400,450,1,true,600)
t.controllers={remote.controller,local_p.controller};t.tick()
assert(remote.md.MaxWalkSpeed==500 and remote.pd.JumpMaxCount==1 and remote.md.JumpZVelocity==420)
assert(local_p.md.MaxWalkSpeed==2250 and local_p.pd.JumpMaxCount>=1000000)
assert(math.abs(local_p.md.JumpZVelocity-600*math.sqrt(HEIGHT))<0.01)
host_print("world transition restores originals and changes only local player PASS")
local_p.pd.valid=false;local_p.md.valid=false
local p3=t.player(500,300,1);p3.md.JumpZVelocity=nil
t.controllers={p3.controller};t.tick()
assert(p3.md.MaxWalkSpeed==1500 and p3.pd.JumpMaxCount==1,"missing jump velocity must not partially change jump count")
assert(t.module.Errors["air jump"])
p3.md.JumpZVelocity=400;t.tick()
assert(p3.pd.JumpMaxCount>=1000000 and not t.module.Errors["air jump"])
host_print("invalid old object and missing JumpZVelocity recovery PASS")
t=setup();p=t.player(600,0,1);t.controllers={p.controller};t.key(Key.SEVEN)
assert(p.md.MaxWalkSpeed==0 and t.module.Errors.speed)
p.md.MaxWalkSpeed=250;t.tick();assert(p.md.MaxWalkSpeed==750)
for i=1,2 do t.key(Key.SEVEN) end
assert(p.md.MaxWalkSpeed==250)
host_print("zero speed waits and restores actual acquired baseline PASS")
p.cd.valid=false;t.controllers={};t.key(Key.EIGHT)
p=t.player(700,300,1,true,450);t.controllers={p.controller};t.tick()
assert(p.pd.JumpMaxCount>=1000000 and math.abs(p.md.JumpZVelocity-450*math.sqrt(HEIGHT))<0.01)
host_print("toggle before spawn persists PASS")
host_print("NOTE: height1 preserves baseline JumpZVelocity; other heights remain a ballistic target")
