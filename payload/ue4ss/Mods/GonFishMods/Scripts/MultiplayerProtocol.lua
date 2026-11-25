-- Pure codec. Never accepts Lua, function names, object paths, player IDs, or console commands.
local Protocol = {Version=1, MaxLength=160}
local speeds = {[0]=true,[2]=true,[5]=true,[10]=true}
local fish = {[5]=true,[50]=true,[500]=true,[5000]=true}

function Protocol.Encode(nonce, sequence, state)
    if type(nonce)~="string" or not nonce:match("^%x%x%x%x%x%x%x%x$") then return nil,"nonce" end
    if type(sequence)~="number" or sequence%1~=0 or sequence<1 or sequence>2147483647 then return nil,"sequence" end
    if type(state)~="table" or not speeds[state.Speed] or not fish[state.Rerolls] then return nil,"state" end
    for _, key in ipairs({"AirJump","MaxWin","Hotspot"}) do
        if type(state[key])~="boolean" then return nil,key end
    end
    return string.format("GFMP1|%s|%d|%d|%d|%d|%d|%d", nonce:lower(),sequence,state.Speed,
        state.AirJump and 1 or 0,state.MaxWin and 1 or 0,state.Rerolls,state.Hotspot and 1 or 0)
end

function Protocol.Decode(message)
    if type(message)~="string" or #message>Protocol.MaxLength then return nil,"length" end
    local nonce,seq,speed,air,win,rerolls,hotspot = message:match(
        "^GFMP1|(%x%x%x%x%x%x%x%x)|(%d+)|(%d+)|([01])|([01])|(%d+)|([01])$")
    if not nonce then return nil,"format/version" end
    local state={Speed=tonumber(speed),AirJump=air=="1",MaxWin=win=="1",Rerolls=tonumber(rerolls),Hotspot=hotspot=="1"}
    local canonical,err=Protocol.Encode(nonce,tonumber(seq),state)
    if not canonical then return nil,err end
    if canonical~=message then return nil,"noncanonical" end
    return {Nonce=nonce,Sequence=tonumber(seq),State=state}
end
return Protocol
