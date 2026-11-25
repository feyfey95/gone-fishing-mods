-- Transport-independent host routing. Integration must supply the genuine owning controller.
local Protocol = require("MultiplayerProtocol")
local Session = {}
Session.__index = Session

function Session.New(nonce, clock, key_for_controller, authority_check, capabilities)
    assert(Protocol.Encode(nonce,1,{Speed=0,AirJump=false,MaxWin=false,Rerolls=5,Hotspot=false}))
    return setmetatable({Nonce=nonce:lower(),Clock=clock,KeyFor=key_for_controller,Authority=authority_check,Capabilities=capabilities or {},Peers={}},Session)
end

function Session:Receive(owning_controller, message)
    if not self.Authority(owning_controller) then return nil,"not host-owned connection" end
    local key = self.KeyFor(owning_controller)
    if key==nil then return nil,"unidentified connection" end
    local decoded,err=Protocol.Decode(message)
    if not decoded then return nil,err end
    if decoded.Nonce~=self.Nonce then return nil,"wrong session" end
    local peer=self.Peers[key]
    if peer and decoded.Sequence<=peer.Sequence then return nil,"replay/order" end
    local second=math.floor(self.Clock())
    local count=peer and peer.Second==second and peer.Count or 0
    if count>=8 then return nil,"rate limit" end
    -- Only explicitly enabled host support can accept remote max-win requests.
    decoded.State.MaxWin=self.Capabilities.RemoteMaxWin==true and decoded.State.MaxWin
    decoded.State.Rerolls=5
    decoded.State.Hotspot=false
    self.Peers[key]={Controller=owning_controller,Sequence=decoded.Sequence,State=decoded.State,Second=second,Count=count+1}
    return decoded.State
end

function Session:StateFor(controller)
    local key=self.KeyFor(controller)
    local peer=key and self.Peers[key]
    return peer and peer.State
end

function Session:Disconnect(controller)
    local key=self.KeyFor(controller)
    if key then self.Peers[key]=nil end
end

return Session
