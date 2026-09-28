#include "timing.c"
typedef struct SDL_Window SDL_Window;
extern uint64_t SDL_GetWindowFlags(SDL_Window *window);
int max2d_bench_visibility(SDL_Window *window) {
	/* SDL3: occluded, hidden and minimized. Zero means none of these flags. */
	return (int)(SDL_GetWindowFlags(window) & (4 | 8 | 64));
}
