local P=require("GonFishPlayers")
local Driver={}
Driver.__index=Driver
function Driver.New()return setmetatable({Records={}},Driver)end
local function finite(value)return type(value)=="number" and value==value and value>0 and value<math.huge end
function Driver:Restore(record)
    if not record then return end
    if P.Valid(record.Movement) then
        if record.SpeedBase then record.Movement.MaxWalkSpeed=record.SpeedBase end
        if record.CrouchBase then record.Movement.MaxWalkSpeedCrouched=record.CrouchBase end
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
        local crouch=P.Read(movement,"MaxWalkSpeedCrouched")
        if not record.CrouchBase and finite(crouch) and crouch<=2000 then record.CrouchBase=crouch end
        if record.CrouchBase then movement.MaxWalkSpeedCrouched=record.CrouchBase*state.Speed end
        local target=record.SpeedBase*state.Speed
        if movement.MaxWalkSpeed~=target then movement.MaxWalkSpeed=target end
    elseif record.SpeedBase then
        movement.MaxWalkSpeed=record.SpeedBase;record.SpeedBase=nil
        if record.CrouchBase then movement.MaxWalkSpeedCrouched=record.CrouchBase;record.CrouchBase=nil end
    end
    if state.AirJump then
        if not record.JumpBase then
            local count=context.Pawn.JumpMaxCount
            local velocity=movement.JumpZVelocity
            assert(type(count)=="number" and count>=0 and count%1==0,"jump count unavailable")
            assert(finite(velocity) and velocity<=5000,"jump velocity unavailable")
            record.JumpBase=count;record.JumpZBase=velocity
        end
        if context.Pawn.JumpMaxCount~=2147483647 then context.Pawn.JumpMaxCount=2147483647 end
        if movement.JumpZVelocity~=record.JumpZBase then movement.JumpZVelocity=record.JumpZBase end -- original 1x height
    else
        if record.JumpBase then context.Pawn.JumpMaxCount=record.JumpBase;record.JumpBase=nil end
        if record.JumpZBase then movement.JumpZVelocity=record.JumpZBase;record.JumpZBase=nil end
    end
    return {Crouch=state.Speed>0 and record.CrouchBase and movement.MaxWalkSpeedCrouched or 0,Speed=state.Speed>0 and movement.MaxWalkSpeed or 0,JumpZ=state.AirJump and movement.JumpZVelocity or 0}
end
function Driver:Prune(active)
    for key,record in pairs(self.Records) do
        if not active[key] then self:Restore(record);self.Records[key]=nil end
    end
end
function Driver:Reset()self:Prune({})end
return Driver
