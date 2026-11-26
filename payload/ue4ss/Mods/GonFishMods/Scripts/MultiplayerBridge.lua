return function(config)
    config=config or {}
    local P=require("GonFishPlayers")
    local Codec=require("MultiplayerProtocol")
    local Session=require("MultiplayerSession")
    local Driver=require("MultiplayerMovement")
    local M={AllowRemoteMaxWin=config.AllowRemoteMaxWin==true,Driver=Driver.New(),Sequence=0,Pending={},Ready=false,LastState=nil,Nonce=nil,Attempts=0,Replies={},Hellos={}}
    GonFishMultiplayer=M
    local CHAT="/Game/MultiplayerChat/Main/MultiplayerChat_C.MultiplayerChat_C_C:"
    local color={R=0.3,G=0.8,B=0.5,A=1.0}
    local ChatFilter=require("ChatControlFilter").New(P,Codec)
    local generation=0
    local function log(text)print("[GFM-MP] "..text.."\n")end
    local function hash(text)
        local h=2166136261
        for i=1,#text do h=((h~text:byte(i))*16777619)&0xffffffff end
        return string.format("%08x",h)
    end
    local function value(param)
        local ok,result=pcall(function()return param:Get()end)
        return ok and result or nil
    end
    local function text(param)
        local result=value(param)
        if type(result)=="string" then return result end
        local ok,s=pcall(function()return result:ToString()end)
        return ok and s or nil
    end
    local function contexts()
        local now=os.time()
        local cached=M.ContextsCache
        local refresh=not cached or now~=(M.ContextsAt or 0)
        if not refresh then
            for _,ctx in ipairs(cached)do
                if not P.Valid(ctx.Controller)or not P.Same(ctx.Pawn,P.Read(ctx.Controller,"Pawn"))then refresh=true;break end
            end
        end
        if not refresh then return cached end
        local result={}
        for _,ctx in ipairs(P.Contexts())do
            if type(ctx.PlayerId)=="number" and ctx.PlayerId>=0 then
                ctx.Key=ctx.Key..":"..tostring(ctx.PlayerId);result[#result+1]=ctx
            end
        end
        M.ContextsCache=result;M.ContextsAt=now
        return result
    end
    local function local_context()
        for _,ctx in ipairs(contexts())do
            if ctx.IsLocal and P.Valid(P.Read(ctx.Pawn,"CharacterMovement"))then return ctx end
        end
    end
    local function for_chat(component)
        for _,ctx in ipairs(contexts())do
            if P.Valid(P.Read(ctx.Pawn,"CharacterMovement")) and P.Same(P.Read(ctx.Controller,"MultiplayerChat_C"),component)then
                local ok,world=pcall(function()return P.Id(ctx.Pawn:GetWorld())end)
                if ok and (not M.WorldId or world==M.WorldId)then return ctx end
            end
        end
    end
    local function local_state()
        local move=PlayerMovement or {}
        -- Legacy wire fields remain neutral for movement-only compatibility.
        return {Speed=move.SpeedEnabled and move.SpeedMultiplier or 0,
            AirJump=move.AirJumpEnabled==true,MaxWin=false,Rerolls=5,Hotspot=false}
    end
    local function fingerprint(state)return assert(Codec.Encode("00000000",1,state))end
    local function movement_signature(state)return tostring(state.Speed)..":"..tostring(state.AirJump)end
    local function send_server(ctx,message)
        local chat=P.Read(ctx.Controller,"MultiplayerChat_C")
        assert(P.Valid(chat),"local chat component missing")
        -- Verified 7-parameter NetServer RPC. The label is mod text, not a forged player identity.
        chat["SR_Send Message"](chat,0,FText(message),FName("GFM Coop"),color,FName(""),0,"")
    end
    local function send_client(ctx,message)
        assert(ctx.IsAuthority,"only host may issue multicast replies")
        local chat=P.Read(ctx.Controller,"MultiplayerChat_C")
        if P.Valid(chat)then chat["MC_Enter Text"](chat,0,FText(message),FName("GFM Coop"),color,0)end
    end
    local function new_session(ctx,key)
        M.Driver:Reset();M.Sequence=0;M.Pending={};M.LastState=nil;M.Ack=nil;M.Attempts=0;M.Ready=false
        M.LastHello=nil;M.LastPacket=nil;M.Replies={};M.Hellos={}
        M.ContextKey=key;M.IsHost=ctx.IsAuthority;M.LastAckAt=nil;M.HadAck=false;generation=generation+1
        if M.IsHost then
            M.Nonce=hash(key..":"..os.time()..":"..generation)
            M.Session=Session.New(M.Nonce,os.time,function(c)
                for _,v in ipairs(contexts())do if P.Same(v.Controller,c)then return v.Key end end
            end,function(c)
                for _,v in ipairs(contexts())do if P.Same(v.Controller,c)then return v.IsAuthority end end
                return false
            end,{RemoteMaxWin=M.AllowRemoteMaxWin})
            M.Ready=true;log("host session ready; per-player controls")
        else
            M.Nonce=nil;M.Session=nil;M.Challenge=hash(key..":"..os.time()..":"..generation)
            log("client waiting for matching host mod")
        end
    end
    local function ack(ctx,sequence,targets)
        send_client(ctx,string.format("GFMPA1|%s|%d|%.3f|%.3f",M.Nonce,sequence,targets.Speed,targets.JumpZ))
    end
    function M.ReceiveServer(component,message)
        P.AssertGameThread()
        local ctx=for_chat(component)
        if not ctx or not ctx.IsAuthority or not M.IsHost or not M.Session then return false end
        if type(message)~="string" or #message>160 then return false end
        local challenge=message:match("^GFMPQ1|(%x%x%x%x%x%x%x%x)$")
        if challenge then
            local previous=M.Hellos[ctx.Key]
            local now=os.time()
            if previous and now-previous.Time<1 then return false,"hello rate"end
            if not previous or previous.Challenge~=challenge then M.Session:Disconnect(ctx.Controller);M.Replies[ctx.Key]=nil end
            M.Hellos[ctx.Key]={Challenge=challenge,Time=now}
            send_client(ctx,"GFMPH1|"..M.Nonce.."|"..challenge);return true
        end
        local cached=M.Replies[ctx.Key]
        if cached and cached.Message==message then
            if os.time()-cached.Time>=1 then
                cached.Time=os.time();ack(ctx,cached.Sequence,cached.Targets)
            end
            return true
        end
        local state,reason=M.Session:Receive(ctx.Controller,message)
        if not state then return false,reason end
        if not ctx.IsLocal then
            local targets=M.Driver:Apply(ctx,state)
            if targets then
                local seq=M.Session.Peers[ctx.Key].Sequence
                M.Replies[ctx.Key]={Message=message,Sequence=seq,Targets=targets,Time=os.time()}
                ack(ctx,seq,targets)
            end
        end
        log("accepted player="..tostring(ctx.PlayerId).." speed="..state.Speed.." air="..tostring(state.AirJump))
        return true
    end
    function M.ReceiveClient(component,message)
        P.AssertGameThread()
        local ctx=for_chat(component)
        if not ctx or not ctx.IsLocal or ctx.IsAuthority or M.IsHost or type(message)~="string" or #message>160 then return false end
        local nonce,challenge=message:match("^GFMPH1|(%x%x%x%x%x%x%x%x)|(%x%x%x%x%x%x%x%x)$")
        if nonce and challenge==M.Challenge then
            if not M.Ready or M.Nonce~=nonce then M.Sequence=0;M.Pending={};M.LastState=nil;M.Ack=nil;M.LastPacket=nil end
            M.Nonce=nonce;M.Ready=true;log("host handshake received");return true
        end
        local n,seq,speed,jump=message:match("^GFMPA1|(%x%x%x%x%x%x%x%x)|(%d+)|(%d+%.%d%d%d)|(%d+%.%d%d%d)$")
        seq,speed,jump=tonumber(seq),tonumber(speed),tonumber(jump)
        if n~=M.Nonce or not seq or not speed or not jump or speed>20000 or jump>5000 then return false end
        local pending=M.Pending[seq]
        if not pending or pending~=fingerprint(local_state())then return false end
        M.Ack={Speed=speed,JumpZ=jump,Signature=movement_signature(local_state())}
        M.LastAckAt=os.time()
        M.LastPacket=nil
        if not M.HadAck then
            M.HadAck=true
            if GonFishModAPI and GonFishModAPI.SendLocalChatMessage then
                GonFishModAPI.SendLocalChatMessage("GFM Coop","Multiplayer sync connected",color)
            end
        end
        for k in pairs(M.Pending)do if k<=seq then M.Pending[k]=nil end end
        log("server acknowledged sequence="..seq)
        return true
    end
    function M.LocalMovementOverride()
        if M.IsHost then return nil end
        -- Keep the previous confirmed mode during a transition, rather than predicting a new speed.
        return M.Ack or {Speed=0,JumpZ=0,Pending=true}
    end
    function M.BetSettings(pool,fish_owner)
        P.AssertGameThread()
        if not M.IsHost or not M.Session then return nil end
        local queue={};local seen={}
        local first=P.Valid(fish_owner)and fish_owner or P.Read(pool,"Owner")
        if P.Valid(first)then queue[1]=first end
        local index=1
        while queue[index]and index<=16 do
            local owner=queue[index];index=index+1
            local id=P.Id(owner)
            if id and not seen[id]then
                seen[id]=true
                for _,ctx in ipairs(contexts())do
                    if ctx.IsAuthority and (P.Same(ctx.Controller,owner)or P.Same(ctx.Pawn,owner)
                        or P.Same(P.Read(ctx.Controller,"PlayerState"),owner))then
                        if ctx.IsLocal then return false and local_state()or nil end
                        if M.AllowRemoteMaxWin then return M.Session:StateFor(ctx.Controller)end
                        return nil
                    end
                end
                for _,field in ipairs({"Owner","PlayerCharacter","PlayerController","Controller"})do
                    local next_owner=P.Read(owner,field)
                    if P.Valid(next_owner)and #queue<16 then queue[#queue+1]=next_owner end
                end
            end
        end
        -- Legacy standalone calls may not supply an owner. Never use this fallback for a remote RPC.
        if false and not P.Valid(fish_owner)then
            local all=contexts()
            if #all==1 and all[1].IsLocal and all[1].IsAuthority then return local_state()end
        end
        if not M.OwnerWarning then
            M.OwnerWarning=true;log("bet owner unresolved from current FishOwner; RNG unchanged")
        end
        return nil
    end
    function M.Tick()
        P.AssertGameThread()
        ChatFilter:Tick()
        local ctx=local_context()
        if not ctx then
            if M.ContextKey then M.Driver:Reset()end
            M.ContextKey=nil;M.Ready=false;M.Session=nil;M.Ack=nil;return
        end
        if type(ctx.PlayerId)~="number" or ctx.PlayerId<0 then return end
        local world=P.Id(ctx.Pawn:GetWorld())or "world"
        M.WorldId=world
        local key=ctx.Key..":"..world..(ctx.IsAuthority and "" or (":"..tostring(P.Id(ctx.Pawn))))
        if key~=M.ContextKey then new_session(ctx,key)end
        local state=local_state();local signature=fingerprint(state)
        if M.IsHost then
            local active={}
            local present={}
            for _,peer in ipairs(contexts())do
                if peer.IsAuthority and not peer.IsLocal then
                    present[peer.Key]=true
                    local wanted=M.Session:StateFor(peer.Controller)
                    if wanted then
                        active[peer.Key]=true
                        local ok,err=pcall(M.Driver.Apply,M.Driver,peer,wanted)
                        if not ok and M.LastPeerError~=tostring(err)then M.LastPeerError=tostring(err);log("peer apply: "..M.LastPeerError)end
                    end
                end
            end
            M.Driver:Prune(active)
            for key,peer in pairs(M.Session.Peers)do if not active[key]then M.Session.Peers[key]=nil end end
            for key in pairs(M.Replies)do if not present[key]then M.Replies[key]=nil;M.Hellos[key]=nil end end
            return
        end
        local now=os.time()
        if M.Ready and M.LastPacket and (M.Retries or 0)>=3 and now-(M.LastSent or now)>=2 then
            M.Ready=false;M.Ack=nil;M.Pending={};M.LastState=nil;M.LastPacket=nil;M.LastAckAt=nil;M.HadAck=false;M.Nonce=nil
            M.Attempts=0;M.LastHello=nil;generation=generation+1
            M.Challenge=hash(key..":recover:"..generation..":"..now)
            log("host confirmation timed out; waiting for fresh synchronization")
        end
        if not M.Ready then
            local now=os.time()
            if M.Attempts>=10 and M.LastHello and now-M.LastHello>=10 then M.Attempts=0 end
            if M.Attempts<10 and (not M.LastHello or now-M.LastHello>=2)then
                M.LastHello=now;M.Attempts=M.Attempts+1;send_server(ctx,"GFMPQ1|"..M.Challenge)
            end
            return
        end
        if signature~=M.LastState then
            M.Sequence=M.Sequence+1
            local packet=assert(Codec.Encode(M.Nonce,M.Sequence,state))
            M.Pending[M.Sequence]=signature
            M.LastState=signature
            M.LastPacket=packet;M.LastSent=os.time();M.Retries=0
            send_server(ctx,packet)
            for seq in pairs(M.Pending)do if seq<M.Sequence-16 then M.Pending[seq]=nil end end
        elseif M.LastPacket and os.time()-M.LastSent>=2 and (M.Retries or 0)<3 then
            M.LastSent=os.time();M.Retries=(M.Retries or 0)+1
            send_server(ctx,M.LastPacket)
        end
    end
    local function hook(receiver)
        return function(self,_,body)
            local component=value(self);local message=text(body)
            if not message or not message:match("^GFMP")then return end
            local function run()
                local ok,err=pcall(receiver,component,message)
                if not ok then log("message rejected: "..tostring(err))end
            end
            if IsInGameThread and IsInGameThread()then run()else ExecuteInGameThread(run)end
        end
    end
    RegisterHook(CHAT.."SR_Send Message",hook(M.ReceiveServer))
    RegisterHook(CHAT.."MC_Enter Text",hook(M.ReceiveClient))
    local function observe_message(self)
        local widget=value(self)
        local function run()ChatFilter:Observe(widget)end
        if IsInGameThread and IsInGameThread()then run()else ExecuteInGameThread(run)end
    end
    for _,name in ipairs({"ExecuteUbergraph_Message","ShowMessage","Message"})do
        pcall(RegisterHook,"/Game/MultiplayerChat/ChatWidgets/Message.Message_C:"..name,observe_message)
    end
    function M.NotifyStateChanged()
        M.LastState=nil -- an explicit user action also requests a fresh confirmation
        local ok,err=pcall(M.Tick)
        if not ok and M.LastError~=tostring(err)then M.LastError=tostring(err);log("state change: "..M.LastError)end
    end
    LoopInGameThreadWithDelay(250,function()
        local ok,err=pcall(M.Tick)
        if not ok and M.LastError~=tostring(err)then M.LastError=tostring(err);log("tick: "..M.LastError)end
        return false
    end)
    log("v0.6 transport loaded; event-driven state channel")
    return M
end
