#include <atomic>
#include <stdint.h>

// A shared caster may belong to several lighting environments. Its setters
// publish edits without retaining references back to those environments.
static std::atomic<uint64_t> epoch(0);

extern "C" uint64_t max2d_caster_epoch() {
    return epoch.load(std::memory_order_relaxed);
}

extern "C" void max2d_mark_caster_edit() {
    epoch.fetch_add(1, std::memory_order_relaxed);
}
