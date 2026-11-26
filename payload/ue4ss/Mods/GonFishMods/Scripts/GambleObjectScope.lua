-- Uses reflection from the loaded UFunction; never assumes a FishOwner byte offset.
local S={}
function S.Resolve(name)
    if type(name)~="string"then return name end
    if name==""then return nil end
    local P=require("GonFishPlayers")
    local ok,object=pcall(StaticFindObject,name)
    if ok and P.Valid(object)then return object end
    local path=name:match("^%S+%s+(.+)$")
    if path then
        ok,object=pcall(StaticFindObject,path)
        if ok and P.Valid(object)then return object end
    end
end
function S.Register(api,fn,pre,post)
    local offset
    fn:ForEachProperty(function(property)
        local name=property:GetFullName()
        if name:match("^ObjectProperty ")and name:match(":FishOwner$")then
            offset=property:GetOffset_Internal()
            return true
        end
        return nil -- this UE4SS build's iterator consumes false incorrectly
    end)
    assert(type(offset)=="number" and offset>=0 and offset<=128 and offset%8==0,"FishOwner reflected offset unavailable")
    assert(api.AddFunctionObjectScope,"updated native object-scope API required")
    local ok=api.AddFunctionObjectScope("ScaleFishCompeteServer",string.format("%X",fn:GetAddress()),tostring(offset),pre,post)
    assert(ok==true,"native object-scope registration rejected")
end
return S
