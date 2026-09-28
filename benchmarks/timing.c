#include <stdint.h>
/* SDL C entry points; no platform-dependent boolean types cross this helper. */
typedef struct SDL_Renderer SDL_Renderer;
extern uint64_t SDL_GetPerformanceCounter(void);
extern uint64_t SDL_GetPerformanceFrequency(void);
extern const char *SDL_GetRendererName(SDL_Renderer *renderer);
double max2d_bench_seconds(void) {
    return (double)SDL_GetPerformanceCounter() / (double)SDL_GetPerformanceFrequency();
}

const char *max2d_bench_renderer(SDL_Renderer *renderer) { return SDL_GetRendererName(renderer); }
