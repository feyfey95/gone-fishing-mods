local P=require("GonFishPlayers")
local Driver={}
Driver.__index=Driver
function Driver.New()return setmetatable({Records={}},Driver)end
local function finite(value)return type(value)=="number" and value==value and value>0 and value<math.huge end
function Driver:Restore(record)
    if not record then return end
    if P.Valid(record.Movement) then
        if record.SpeedBase then record.Movement.MaxWalkSpeed=record.SpeedBase end
        if record.JumpZBase then record.Movement.JumpZVelocity=record.JumpZBase end
    end
    if P.Valid(record.Pawn) and record.JumpBase then record.Pawn.JumpMaxCount=record.JumpBase end
end
function Driver:Apply(context,state)
    P.AssertGameThread()
    assert(context.IsAuthority and not context.IsLocal,"driver accepts remote authoritative pawns only")
    local movement=P.Read(context.Pawn,"CharacterMovement")
    if not P.Valid(movement) then return nil end
    local record=self.Records[context.Key]
    if record and (not P.Same(record.Pawn,context.Pawn) or not P.Same(record.Movement,movement)) then
        self:Restore(record);self.Records[context.Key]=nil;record=nil
    end
    if not record then record={Pawn=context.Pawn,Movement=movement};self.Records[context.Key]=record end
    if state.Speed>0 then
        if not record.SpeedBase then
            local baseline=movement.MaxWalkSpeed
            assert(finite(baseline) and baseline<=2000,"server speed baseline out of range")
            record.SpeedBase=baseline
        end
        movement.MaxWalkSpeed=record.SpeedBase*state.Speed
    elseif record.SpeedBase then
        movement.MaxWalkSpeed=record.SpeedBase;record.SpeedBase=nil
    end
    if state.AirJump then
        if not record.JumpBase then
            local count=context.Pawn.JumpMaxCount
            local velocity=movement.JumpZVelocity
            assert(type(count)=="number" and count>=0 and count%1==0,"jump count unavailable")
            assert(finite(velocity) and velocity<=5000,"jump velocity unavailable")
            record.JumpBase=count;record.JumpZBase=velocity
        end
        context.Pawn.JumpMaxCount=2147483647
        movement.JumpZVelocity=record.JumpZBase -- original 1x height, no gravity change
    else
        if record.JumpBase then context.Pawn.JumpMaxCount=record.JumpBase;record.JumpBase=nil end
        if record.JumpZBase then movement.JumpZVelocity=record.JumpZBase;record.JumpZBase=nil end
    end
    return {Speed=state.Speed>0 and movement.MaxWalkSpeed or 0,JumpZ=state.AirJump and movement.JumpZVelocity or 0}
end
function Driver:Prune(active)
    for key,record in pairs(self.Records) do
        if not active[key] then self:Restore(record);self.Records[key]=nil end
    end
end
function Driver:Reset()self:Prune({})end
return Driver
