#pragma once
#include <mutex>
#include <utility>

namespace gfm_diagnostic {
// Invoke engine work without retaining this wrapper's callback mutex.
// Foreign-thread calls bypass Lua callbacks and callback-table locking.
template <typename Before, typename Original>
decltype(auto) dispatch(bool callbacks_allowed, std::recursive_mutex& mutex,
                        Before&& before, Original&& original) {
    if (!callbacks_allowed) {
        return std::forward<Original>(original)();
    }
    {
        std::lock_guard<std::recursive_mutex> guard(mutex);
        std::forward<Before>(before)();
    }
    return std::forward<Original>(original)();
}
}
