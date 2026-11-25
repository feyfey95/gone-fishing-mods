-- Presentation-only filter for the fixed GFM wire protocol; no game/chat RPC cancellation.
local Filter={};Filter.__index=Filter
function Filter.New(P,Codec)return setmetatable({P=P,Codec=Codec,Pending={},Count=0},Filter)end
function Filter:Wire(text)
    if type(text)~="string" or #text>512 then return false end
    text=text:gsub("<[^>]*>","")
    text=text:match("^GFM Coop:%s*(GFMP.*)$") or text
    if #text>160 then return false end
    return self.Codec.Decode(text)~=nil or text:match("^GFMPQ1|%x%x%x%x%x%x%x%x$")~=nil
        or text:match("^GFMPH1|%x%x%x%x%x%x%x%x|%x%x%x%x%x%x%x%x$")~=nil
        or text:match("^GFMPA1|%x%x%x%x%x%x%x%x|%d+|%d+%.%d%d%d|%d+%.%d%d%d$")~=nil
end
local function string_value(value)
    if type(value)=="string" then return value end
    local ok,text=pcall(function()return value:ToString()end)
    return ok and text or nil
end
function Filter:Try(widget)
    if not self.P.Valid(widget)then return false end
    local block=self.P.Read(widget,"MessageText")
    local text=string_value(self.P.Read(block,"Text"))
    if not text then
        local ok,value=pcall(function()return block:GetText()end)
        if ok then text=string_value(value)end
    end
    if not text or text=="" then return nil end
    if not self:Wire(text)then return false end
    widget:SetVisibility(1) -- ESlateVisibility::Collapsed
    return true
end
function Filter:Observe(widget)
    local ok,handled=pcall(self.Try,self,widget)
    if ok and handled~=nil then return end
    local id=self.P.Id(widget)
    if id and self.Count<64 and not self.Pending[id]then
        self.Pending[id]={Widget=widget,Attempts=0};self.Count=self.Count+1
    end
end
function Filter:Tick()
    for id,entry in pairs(self.Pending)do
        local ok,handled=pcall(self.Try,self,entry.Widget)
        entry.Attempts=entry.Attempts+1
        if (ok and handled~=nil)or entry.Attempts>=8 then self.Pending[id]=nil;self.Count=self.Count-1 end
    end
end
return Filter
