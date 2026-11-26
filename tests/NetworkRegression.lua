local dir=assert(arg[1]);package.path=dir.."/?.lua;"..package.path
local host_print=print
local active,server,clients=nil,nil,{}
local clock,ids=1000,100
local original_time=os.time;os.time=function()return clock end
local RPC="/Game/MultiplayerChat/Main/MultiplayerChat_C.MultiplayerChat_C_C:"
local function obj(node,data,methods)
    ids=ids+1;local id=ids;methods=methods or {}
    methods.IsValid=function()return data.valid~=false end
    methods.GetAddress=function()return id end
    return setmetatable({}, {__index=function(_,key)
        if methods[key]then return methods[key]end
        assert(active==node,"cross-process object read");return data[key]
    end,__newindex=function(_,key,value)assert(active==node,"cross-process object write");data[key]=value end}),data
end
local function install_globals(node)
    PlayerMovement=node and node.move;CrazeirGambles=node and node.gamble;LuckierFishBite=node and node.fish
    GonFishMultiplayer=node and node.bridge
    IsInGameThread=function()return active~=nil end
    FindAllOf=function(name)active.scan_count=(active.scan_count or 0)+1;return name=="PlayerController" and active.controllers or {}end
    RegisterHook=function(name,fn)active.hooks[name]=fn end
    LoopInGameThreadWithDelay=function(_,fn)active.loop=fn;return 1 end
    ExecuteInGameThread=function(fn)fn()end
    print=function(line)if active then active.logs[#active.logs+1]=line end end
    FText=function(s)return {ToString=function()return s end}end
    FName=function(s)return s end
end
local function within(node,fn)
    local old=active;active=node;install_globals(node)
    local result=table.pack(pcall(fn));active=old;install_globals(old)
    assert(result[1],result[2]);return table.unpack(result,2,result.n)
end
local function parameter(value)return {Get=function()return value end}end
local function deliver(node,path,component,message)
    within(node,function()node.hooks[RPC..path](parameter(component),parameter(0),parameter(FText(message)))end)
end
local function player(node,id,is_local,speed)
    local movement,md=obj(node,{MaxWalkSpeed=speed or 300,JumpZVelocity=420})
    local world=node.world
    local pawn,pd=obj(node,{CharacterMovement=movement,JumpMaxCount=1},{GetWorld=function()return world end})
    local state=obj(node,{PlayerId=id})
    local controller,cd=obj(node,{Pawn=pawn,PlayerState=state},{
        IsLocalController=function()return is_local end,HasAuthority=function()return node.host end})
    local chat
    chat=obj(node,{}, {
        ["SR_Send Message"]=function(self,kind,body,label,color,to,channel,team)
            assert(active==node and self==chat and kind==0 and label=="GFM Coop" and to=="" and channel==0 and team=="")
            node.sent=(node.sent or 0)+1
            deliver(server,"SR_Send Message",server.players[id].chat,body:ToString())
        end,
        ["MC_Enter Text"]=function(self,kind,body,label,color,channel)
            assert(active==server and self==chat and kind==0 and channel==0)
            local client=clients[id]
            if client then
                if client.drop_ack and body:ToString():match("^GFMPA1")then client.drop_ack=false;return end
                deliver(client,"MC_Enter Text",client.players[id].chat,body:ToString())
            end
        end,
    })
    cd.MultiplayerChat_C=chat
    return {pawn=pawn,pd=pd,controller=controller,cd=cd,chat=chat,movement=movement,md=md}
end
local function node(host,id)
    local n={host=host,id=id,controllers={},players={},hooks={},logs={},move={SpeedEnabled=false,SpeedMultiplier=0,AirJumpEnabled=false},
        gamble={do_max_win=false},fish={LuckFactor=5,LuckMult=1,ForceEnableHotsport=false}}
    n.world=obj(n,{})
    return n
end
local function add(n,id,local_player,speed)
    local p=player(n,id,local_player,speed);n.players[id]=p;n.controllers[#n.controllers+1]=p.controller;return p
end
server=node(true,1);add(server,1,true);add(server,2,false);add(server,3,false,350)
clients[2]=node(false,2);add(clients[2],2,true)
clients[3]=node(false,3);add(clients[3],3,true,350)
for _,n in ipairs({server,clients[2],clients[3]})do
    local client_dir=(not n.host and arg[2]) or dir
    n.bridge=within(n,function()return assert(loadfile(client_dir.."/MultiplayerBridge.lua"))()({AllowRemoteMaxWin=n.host})end)
end
local function tick(n)within(n,n.bridge.Tick)end
tick(server);tick(clients[2]);tick(clients[3])
assert(server.bridge.IsHost and clients[2].bridge.Ready and clients[3].bridge.Ready)
host_print("actual bridge hooks and verified RPC argument shape handshake for two clients PASS")
clients[2].move.SpeedEnabled=true;clients[2].move.SpeedMultiplier=5;clients[2].move.AirJumpEnabled=true;clients[2].gamble.do_max_win=true
clients[3].move.SpeedEnabled=true;clients[3].move.SpeedMultiplier=3
tick(clients[2]);tick(clients[3]);tick(server)
assert(server.players[2].md.MaxWalkSpeed==1500 and server.players[2].pd.JumpMaxCount==2147483647)
assert(server.players[3].md.MaxWalkSpeed==1050 and server.players[3].pd.JumpMaxCount==1)
assert(server.players[1].md.MaxWalkSpeed==300 and server.players[1].pd.JumpMaxCount==1)
within(clients[2],function()assert(clients[2].bridge.LocalMovementOverride().Speed==1500)end)
if not arg[2] then
    within(server,function()assert(not server.bridge.Session:StateFor(server.players[2].controller).MaxWin)end)
end
host_print("independent 5x+air / 3x player states mirror only correct server pawns PASS")
local Codec=require("MultiplayerProtocol")
within(server,function()
    assert(not server.bridge.ReceiveServer(server.players[2].chat,"GFMP1|"..server.bridge.Nonce.."|2|999|1|1|5000|0"))
    for _,old_speed in ipairs({2,10})do
        assert(not server.bridge.ReceiveServer(server.players[2].chat,"GFMP1|"..server.bridge.Nonce.."|2|"..old_speed.."|1|1|5000|0"))
    end
    assert(not server.bridge.ReceiveServer(server.players[2].chat,"GFMP1|"..server.bridge.Nonce.."|2|5|1|1|5000|0|player=3"))
end)
assert(server.players[3].md.MaxWalkSpeed==1050)
host_print("spoofed target fields and out-of-range speed rejected PASS")
clients[3].move.SpeedMultiplier=5;clients[3].drop_ack=true;tick(clients[3])
assert(server.players[3].md.MaxWalkSpeed==1750 and clients[3].bridge.LastPacket)
clock=clock+2;tick(clients[3])
assert(not clients[3].bridge.LastPacket and server.players[3].md.MaxWalkSpeed==1750)
host_print("lost unreliable multicast ACK recovers without compounding speed PASS")
clients[2].move.SpeedEnabled=false;clients[2].move.SpeedMultiplier=0;clients[2].move.AirJumpEnabled=false;tick(clients[2])
assert(server.players[2].md.MaxWalkSpeed==300 and server.players[2].pd.JumpMaxCount==1 and server.players[2].md.JumpZVelocity==420)
assert(server.players[3].md.MaxWalkSpeed==1750)
within(server,function()
    local pool2=obj(server,{Owner=server.players[2].controller})
    local pool3=obj(server,{Owner=server.players[3].controller})
    local host_pool=obj(server,{Owner=server.players[1].controller})
    local unknown=obj(server,{})
    -- Reproduce the unchanged full client's actual GFMP1 packet.
    local packet=assert(Codec.Encode(server.bridge.Nonce,100,{Speed=0,AirJump=false,MaxWin=true,Rerolls=5000,Hotspot=true}))
    assert(server.bridge.ReceiveServer(server.players[2].chat,packet))
    local state=server.bridge.Session:StateFor(server.players[2].controller)
    assert(state.MaxWin and state.Rerolls==5 and not state.Hotspot)
    assert(server.bridge.BetSettings(pool2).MaxWin)
    assert(not server.bridge.BetSettings(pool2,server.players[3].pawn).MaxWin)
    assert(server.bridge.BetSettings(pool2,unknown)==nil)
    assert(not server.bridge.BetSettings(pool3).MaxWin)
    assert(server.bridge.BetSettings(host_pool)==nil and server.bridge.BetSettings(unknown)==nil)
    server.bridge.AllowRemoteMaxWin=false
    assert(server.bridge.BetSettings(pool2)==nil)
    server.bridge.AllowRemoteMaxWin=true
end)
host_print("full-client packet enables only the matching remote bet; public host/other players and unknown owners stay normal PASS")
local old_server=server.players[3]
local new_server=player(server,3,false,400);server.players[3]=new_server;server.controllers[3]=new_server.controller
-- In-game respawn may retain the controller; reproduce that path exactly.
new_server.controller=old_server.controller;new_server.cd=old_server.cd;new_server.chat=old_server.chat;new_server.cd.Pawn=new_server.pawn
server.controllers[3]=old_server.controller
local old_client=clients[3].players[3]
local fresh_client=player(clients[3],3,true,400)
old_client.cd.Pawn=fresh_client.pawn
tick(clients[3]);tick(clients[3]);tick(server)
assert(old_server.md.MaxWalkSpeed==350 and new_server.md.MaxWalkSpeed==2000)
within(clients[3],function()assert(clients[3].bridge.LocalMovementOverride().Speed==2000)end)
host_print("respawn resets peer sequence safely and records fresh per-pawn baseline PASS")
local old_nonce=clients[3].bridge.Nonce
server.bridge.ContextKey=nil;clock=clock+5;tick(server)
within(clients[3],clients[3].bridge.NotifyStateChanged)
for i=1,8 do clock=clock+2;tick(clients[3]);tick(server)end
tick(clients[3])
assert(clients[3].bridge.Ready and clients[3].bridge.Nonce==server.bridge.Nonce)
assert(clients[3].bridge.Nonce~=old_nonce)
within(clients[3],function()assert(clients[3].bridge.LocalMovementOverride().Speed==2000)end)
host_print("server restart/stale session re-handshakes and restores confirmed settings PASS")
server.players[2].cd.valid=false;table.remove(server.controllers,2);tick(server)
within(server,function()assert(not server.bridge.ReceiveServer(server.players[2].chat,"GFMPQ1|12345678"))end)
host_print("disconnected controller/component no longer authorized PASS")
within(clients[3],function()
    local collapsed=0
    local block,bd=obj(clients[3],{Text=FText("GFMPQ1|12345678")})
    local widget=obj(clients[3],{MessageText=block},{SetVisibility=function(_,state)assert(state==1);collapsed=collapsed+1 end})
    local filter=clients[3].hooks["/Game/MultiplayerChat/ChatWidgets/Message.Message_C:ExecuteUbergraph_Message"]
    filter(parameter(widget));assert(collapsed==1)
    bd.Text=FText("hello friends");filter(parameter(widget));assert(collapsed==1)
end)
host_print("control-frame UI filtering leaves normal chat untouched PASS")
local scans=0;for _,n in ipairs({server,clients[3]})do scans=scans+(n.scan_count or 0)end
for i=1,100 do tick(server);tick(clients[3])end
local after=0;for _,n in ipairs({server,clients[3]})do after=after+(n.scan_count or 0)end
assert(after-scans<=2,"idle bridge ticks repeatedly scan the controller array")
host_print("200 idle ticks use cached valid controllers PASS")
local before_packets=clients[3].sent or 0
for i=1,30 do clock=clock+1;tick(clients[3]);tick(server)end
assert((clients[3].sent or 0)==before_packets,"idle clients emitted periodic full-state RPCs")
host_print("30 seconds with unchanged state send no chat RPCs and retain valid synchronization PASS")
os.time=original_time
host_print("NOTE: simulated bus exercises real bridge/driver code, not Steam networking or game physics")
