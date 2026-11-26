#ifdef NDEBUG
#undef NDEBUG
#endif
#include <cassert>
#include <iostream>
#include <thread>
#include <stdexcept>
#include "../../Source/Native/ExtendedBPHooker.cpp"
static int current_ref=0, originals=0, pre_count=0, post_count=0;
static bool nested=false, throw_original=false, expect_rng_scope=false, rng_result=false;
static double rng_value=0;static int step=0;
struct TestFrame {void* slots[20]{};};
void** fake_node(void*f){return &static_cast<TestFrame*>(f)->slots[2];}
void** fake_locals(void*f){return &static_cast<TestFrame*>(f)->slots[5];}
void** fake_object(void*f){return &static_cast<TestFrame*>(f)->slots[3];}
void** fake_previous(void*f){return &static_cast<TestFrame*>(f)->slots[10];}
void fake_pushnumber(lua_State*,double){}
void fake_settop(lua_State*,int){}
int fake_isnumber(lua_State*,int){return rng_result;}
double fake_number(lua_State*,int,int*){return rng_value;}
void* fake_class(){return nullptr;}
void fake_step(void*,void*,void*out){*static_cast<double*>(out)=(step++%2)?6.5:1.;}
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
    else if(current_ref==2){assert(nargs==0 && !owners.empty());owners.pop_back();++post_count;}
    else {assert(nargs==3);if(expect_rng_scope)assert(!owners.empty()&&owners.back()=="Guest1");rng_result=!owners.empty();rng_value=6.4;}
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
    r_lua_pushnumber=fake_pushnumber;r_lua_settop=fake_settop;r_lua_isnumber=fake_isnumber;r_lua_tonumberx=fake_number;
    r_fdouble_property_static_class=fake_class;r_fframe_step=fake_step;
#ifdef GFM_FRAME_RNG_SCOPES
    r_frame_node=fake_node;r_frame_locals=fake_locals;r_frame_object=fake_object;r_frame_previous=fake_previous;
#endif
    lua_random_float_in_range_posthooks.push_back({nullptr,"rng-test",3});
    TestFrame frame;frame.slots[2]=function_ptr;frame.slots[3]=&context;frame.slots[4]=reinterpret_cast<void*>(1);frame.slots[5]=&first;
    expect_rng_scope=true;double output=0;step=0;
    hook_ukismet_math_library_exec_random_float_in_range(&context,&frame,&output);
    assert(output==6.4 && owners.empty());
    TestFrame child;child.slots[2]=reinterpret_cast<void*>(9);child.slots[3]=&context;child.slots[4]=reinterpret_cast<void*>(1);child.slots[10]=&frame;
    step=0;hook_ukismet_math_library_exec_random_float_in_range(&context,&child,&output);assert(output==6.4&&owners.empty());
    expect_rng_scope=false;child.slots[10]=nullptr;step=0;auto before_rng=pre_count;
    hook_ukismet_math_library_exec_random_float_in_range(&context,&child,&output);assert(pre_count==before_rng&&owners.empty());
    std::cout<<"direct Blueprint RNG and ancestor frame use current FishOwner; unrelated RNG untouched PASS\n";
    assert(pre_count==post_count);
    std::cout<<"ProcessEvent actual parameter blob, 100 alternating owners, nested contexts, null/invalid reads, exception cleanup and off-thread passthrough PASS\n";
}
