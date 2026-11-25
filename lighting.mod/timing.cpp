#include <chrono>
#include <stdint.h>

extern "C" uint64_t max2d_lighting_ticks_ns() {
    using namespace std::chrono;
    return duration_cast<nanoseconds>(steady_clock::now().time_since_epoch()).count();
}
