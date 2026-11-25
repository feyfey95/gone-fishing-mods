#include <cassert>
#include <iostream>
#include <thread>
#include <stdexcept>
#include "../../Source/Native/ExtendedBPHooker.cpp"
static int current_ref=0, originals=0, pre_count=0, post_count=0;
static bool nested=false, throw_original=false;
static std::vector<std::string> arguments;
static std::vector<std::string> owners;
static void* function_ptr=reinterpret_cast<void*>(0x123456);
static int owner1,owner2,context;
struct Params {void*target;void*cls;void*owner;};
int fake_rawget(lua_State*,int,int64_t ref){current_ref=static_cast<int>(ref);return 6;}
int fake_type(lua_State*,int){return 6;}
const char* fake_string(lua_State*,const char*value){arguments.emplace_back(value);return value;}
int fake_pcall(lua_State*,int nargs,int,int,intptr_t,void*) {
    auto copy=arguments;arguments.clear();
    if(current_ref==1){assert(nargs==2);assert(copy[0]=="Pool");owners.push_back(copy[1]);++pre_count;}
    else {assert(nargs==0 && !owners.empty());owners.pop_back();++post_count;}
    return 0;
}
FakeFString* fake_name(void*object,FakeFString*out,void*,uint32_t){
    static wchar_t pool[]=L"Pool",guest1[]=L"Guest1",guest2[]=L"Guest2";
    out->Data=object==&owner1?guest1:object==&owner2?guest2:pool;return out;
}
void fake_original(void*object,void*fn,void*params){
    ++originals;
    if(!callbacks_allowed_here())return;
    if(fn!=function_ptr)return;
    auto*owner=params?reinterpret_cast<Params*>(params)->owner:nullptr;
    // Only valid parameter blobs are used by this fake original.
    const auto expected=owner==&owner1?"Guest1":owner==&owner2?"Guest2":"";
    assert(!owners.empty() && owners.back()==expected);
    if(nested){nested=false;Params inner{nullptr,nullptr,&owner2};hook_uobject_process_event(object,fn,&inner);assert(owners.back()==expected);}
    if(throw_original)throw std::runtime_error("fake original");
}
int main(){
    g_game_thread_id.store(GetCurrentThreadId());
    r_lua_rawgeti=fake_rawget;r_lua_type=fake_type;r_lua_pushstring=reinterpret_cast<lua_pushstring_t>(fake_string);
    r_lua_pcallk=fake_pcall;r_uobject_base_utility_get_full_name=fake_name;
    r_uobject_process_event=reinterpret_cast<uobject_process_event_t>(fake_original);
    lua_object_param_scopes.emplace(function_ptr,object_param_scope{nullptr,16,1,2});
    Params first{nullptr,nullptr,&owner1},second{nullptr,nullptr,&owner2};
    assert(read_object_parameter(&first,16)==&owner1);
    assert(read_object_parameter(nullptr,16)==nullptr && read_object_parameter(&first,3)==nullptr);
    assert(read_object_parameter(reinterpret_cast<void*>(1),16)==nullptr);
    for(int i=0;i<100;++i){hook_uobject_process_event(&context,function_ptr,i%2?&first:&second);assert(owners.empty());}
    hook_uobject_process_event(&context,function_ptr,nullptr);assert(owners.empty());
    nested=true;hook_uobject_process_event(&context,function_ptr,&first);assert(owners.empty());
    throw_original=true;try{hook_uobject_process_event(&context,function_ptr,&first);assert(false);}catch(const std::runtime_error&){}throw_original=false;assert(owners.empty());
    auto before=pre_count;
    std::thread worker([&]{hook_uobject_process_event(&context,function_ptr,&first);});worker.join();assert(pre_count==before);
    hook_uobject_process_event(&context,reinterpret_cast<void*>(2),&first);assert(pre_count==before);
    assert(pre_count==post_count);
    std::cout<<"ProcessEvent actual parameter blob, 100 alternating owners, nested contexts, null/invalid reads, exception cleanup and off-thread passthrough PASS\n";
}
