local dir=assert(arg[1]);package.path=dir.."/?.lua;"..package.path
local Filter=require("ChatControlFilter")
local P={Valid=function(o)return type(o)=="table" and o.valid~=false end,Read=function(o,k)return o and o[k]end,Id=function(o)return tostring(o)end}
local filter=Filter.New(P,require("MultiplayerProtocol"))
local wire="GFMP1|25c800f0|4|5|0|1|5|1"
assert(filter:Wire(wire) and filter:Wire("GFM Coop: "..wire) and filter:Wire("<x>GFM Coop:</> "..wire))
assert(not filter:Wire("hello "..wire) and not filter:Wire("GFM Coop: ordinary chat"))
local function widget(text,getter)
 local b={Text=text};if getter then b.Text=nil;b.GetText=function()return {ToString=function()return text end}end end
 local w={MessageText=b,collapsed=0,SetVisibility=function(self,state)assert(state==1);self.collapsed=self.collapsed+1 end}
 return w,b
end
local w,b=widget(nil);filter:Observe(w);assert(w.collapsed==0)
b.Text=wire;filter:Tick();assert(w.collapsed==1)
local w2=widget("GFM Coop: "..wire,true);filter:Observe(w2);assert(w2.collapsed==1)
local normal=widget("hello friends");filter:Observe(normal);assert(normal.collapsed==0)
for i=1,100 do filter:Observe(widget(nil))end
assert(filter.Count<=64);for i=1,8 do filter:Tick()end;assert(filter.Count==0)
print("raw/formatted/rich text, deferred Text/GetText and bounded retries PASS; ordinary chat unchanged")
