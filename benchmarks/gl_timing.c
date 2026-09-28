#include "../../pub.mod/glew.mod/GL/glew.h"
#ifdef _WIN32
#include <windows.h>
double max2d_bench_seconds(void) {
    LARGE_INTEGER ticks, frequency;
    QueryPerformanceCounter(&ticks); QueryPerformanceFrequency(&frequency);
    return (double)ticks.QuadPart / (double)frequency.QuadPart;
}
#else
#include <time.h>
double max2d_bench_seconds(void) {
    struct timespec now; clock_gettime(CLOCK_MONOTONIC, &now);
    return (double)now.tv_sec + (double)now.tv_nsec / 1000000000.0;
}
#endif
const char *max2d_bench_renderer(void *unused) { return (const char *)glGetString(GL_RENDERER); }
