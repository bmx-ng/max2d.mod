#include <SDL3/SDL.h>
#include <stdlib.h>
#include <stdint.h>
#include "maskblend.h"

typedef struct M2DTexture {
    SDL_Renderer *renderer;
    SDL_Texture *straight;
    SDL_Texture *premult;
    int width, height, target, filtered;
    uint64_t revision, straight_revision, premult_revision;
} M2DTexture;

static SDL_Texture *make_texture(M2DTexture *frame, int target) {
    SDL_Texture *texture = SDL_CreateTexture(frame->renderer, SDL_PIXELFORMAT_RGBA32,
        target ? SDL_TEXTUREACCESS_TARGET : SDL_TEXTUREACCESS_STATIC, frame->width, frame->height);
    if (texture && !SDL_SetTextureScaleMode(texture, frame->filtered ? SDL_SCALEMODE_LINEAR : SDL_SCALEMODE_NEAREST)) {
        SDL_DestroyTexture(texture);
        return NULL;
    }
    return texture;
}

void *m2d_sdl_create(SDL_Renderer *renderer, int width, int height, int flags, int target) {
    M2DTexture *frame = SDL_calloc(1, sizeof(*frame));
    if (!frame) return NULL;
    frame->renderer = renderer;
    frame->width = width; frame->height = height;
    frame->filtered = (flags & 2) != 0; frame->target = target;
    frame->revision = 1;
    if (target) {
        frame->premult = make_texture(frame, 1);
        if (!frame->premult) { SDL_free(frame); return NULL; }
        SDL_Texture *old = SDL_GetRenderTarget(renderer);
        bool ok = SDL_SetRenderTarget(renderer, frame->premult);
        if (ok) ok = SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0) && SDL_RenderClear(renderer);
        bool restored = SDL_SetRenderTarget(renderer, old);
        if (!ok || !restored) {
            SDL_DestroyTexture(frame->premult);
            SDL_free(frame);
            return NULL;
        }
    } else {
        frame->straight = make_texture(frame, 0);
        if (!frame->straight) { SDL_free(frame); return NULL; }
    }
    return frame;
}

void m2d_sdl_destroy(M2DTexture *frame) {
    if (!frame) return;
    SDL_DestroyTexture(frame->straight);
    SDL_DestroyTexture(frame->premult);
    SDL_free(frame);
}

/* pixels starts at the upload region; x/y locate it in the destination. */
int m2d_sdl_update(M2DTexture *frame, const uint8_t *pixels, int pitch, int x, int y, int w, int h) {
    SDL_Rect rect = {x,y,w,h};
    if (!SDL_UpdateTexture(frame->straight, &rect, pixels, pitch)) return 0;
    ++frame->revision;
    return 1;
}

static void unpremultiply(SDL_Surface *surface) {
    for (int y = 0; y < surface->h; ++y) {
        uint8_t *p = (uint8_t *)surface->pixels + y*surface->pitch;
        for (int x = 0; x < surface->w; ++x, p += 4) {
            const int a = p[3];
            for (int c = 0; c < 3; ++c) p[c] = a ? SDL_min(255, (p[c]*255 + a/2)/a) : 0;
        }
    }
}

static SDL_Surface *read_surface(SDL_Renderer *renderer, M2DTexture *frame, const SDL_Rect *rect) {
    SDL_Texture *old = SDL_GetRenderTarget(renderer);
    if (!SDL_SetRenderTarget(renderer, frame ? frame->premult : NULL)) return NULL;
    /* Readback coordinates describe the complete pixel surface, independent
       of the drawing viewport (including letterbox bars). */
    SDL_Rect viewport;
    bool viewport_set = SDL_RenderViewportSet(renderer);
    SDL_GetRenderViewport(renderer, &viewport);
    bool reset = SDL_SetRenderViewport(renderer, NULL);
    SDL_Surface *surface = reset ? SDL_RenderReadPixels(renderer, rect) : NULL;
    bool restored_view = SDL_SetRenderViewport(renderer, viewport_set ? &viewport : NULL);
    bool restored = SDL_SetRenderTarget(renderer, old) && restored_view;
    if (!restored) { SDL_DestroySurface(surface); return NULL; }
    if (!surface) return NULL;
    SDL_Surface *rgba = SDL_ConvertSurface(surface, SDL_PIXELFORMAT_RGBA32);
    SDL_DestroySurface(surface);
    if (rgba && frame) unpremultiply(rgba);
    return rgba;
}

/* Straight assets and premultiplied render targets are converted only when an
   operation requires the other representation. Each conversion is versioned. */
static SDL_Texture *straight_texture(M2DTexture *frame) {
    if (!frame->target) return frame->straight;
    if (!frame->straight) frame->straight = make_texture(frame, 0);
    if (!frame->straight) return NULL;
    if (frame->straight_revision != frame->revision) {
        SDL_Surface *surface = read_surface(frame->renderer, frame, NULL);
        if (!surface) return NULL;
        bool ok = SDL_UpdateTexture(frame->straight, NULL, surface->pixels, surface->pitch);
        SDL_DestroySurface(surface);
        if (!ok) return NULL;
        frame->straight_revision = frame->revision;
    }
    return frame->straight;
}

static SDL_Texture *premult_texture(M2DTexture *frame) {
    if (frame->target) return frame->premult;
    if (!frame->premult) frame->premult = make_texture(frame, 1);
    if (!frame->premult) return NULL;
    if (frame->premult_revision != frame->revision) {
        SDL_Renderer *renderer = frame->renderer;
        SDL_Texture *old = SDL_GetRenderTarget(renderer);
        SDL_BlendMode blend;
        SDL_GetTextureBlendMode(frame->straight, &blend);
        bool ok = SDL_SetRenderTarget(renderer, frame->premult);
        if (ok) ok = SDL_SetRenderDrawColor(renderer,0,0,0,0) && SDL_RenderClear(renderer);
        if (ok) ok = SDL_SetTextureBlendMode(frame->straight,SDL_BLENDMODE_BLEND);
        if (ok) ok = SDL_RenderTexture(renderer,frame->straight,NULL,NULL);
        bool restored_blend = SDL_SetTextureBlendMode(frame->straight,blend);
        bool restored_target = SDL_SetRenderTarget(renderer,old);
        if (!ok || !restored_blend || !restored_target) return NULL;
        frame->premult_revision = frame->revision;
    }
    return frame->premult;
}

int m2d_sdl_submit(SDL_Renderer *renderer, M2DMask *mask, M2DTexture *destination, M2DTexture *frame, int blend, float *vertices, int count, float sx, float sy) {
    SDL_Texture *texture = NULL;
    bool premult_vertex = false;
    SDL_BlendMode mode;
    switch (blend) {
        case 1: /* MASK: shader tests filtered alpha, with blending disabled. */
            if (!mask) return SDL_SetError("Max2D: MASKBLEND unavailable on this renderer");
            mode = SDL_BLENDMODE_NONE;
            texture = frame ? (frame->target ? frame->premult : frame->straight) : mask->white;
            break;
        case 2: /* SOLID */
            mode = SDL_BLENDMODE_NONE;
            premult_vertex = destination != NULL;
            if (frame) texture = destination ? premult_texture(frame) : straight_texture(frame);
            break;
        case 3: /* ALPHA */
        case 4: /* LIGHT */
            if (frame && frame->target) {
                texture = frame->premult;
                premult_vertex = true;
                mode = blend == 3 ? SDL_BLENDMODE_BLEND_PREMULTIPLIED : SDL_BLENDMODE_ADD_PREMULTIPLIED;
            } else {
                if (frame) texture = frame->straight;
                mode = blend == 3 ? SDL_BLENDMODE_BLEND : SDL_BLENDMODE_ADD;
            }
            break;
        case 5: /* SHADE */
            if (frame) texture = straight_texture(frame);
            mode = SDL_BLENDMODE_MOD;
            break;
        default:
            SDL_SetError("Max2D: unsupported blend mode");
            return 0;
    }
    if (frame && !texture) return 0;
    if (texture) {
        if (!SDL_SetTextureBlendMode(texture,mode)) return 0;
    } else if (!SDL_SetRenderDrawBlendMode(renderer,mode)) return 0;
    for (int i = 0; i < count; ++i) {
        float *v = vertices + i*8;
        v[0] *= sx; v[1] *= sy;
        if (premult_vertex) {
            v[2] *= v[5]; v[3] *= v[5]; v[4] *= v[5];
        }
    }
    if (blend == 1 && !SDL_SetGPURenderState(renderer,mask->states[(frame && frame->target ? 1 : 0) | (destination ? 2 : 0)])) return 0;
	bool ok = true;
	/* SDL's software rectangle shortcut loses the UV orientation of quarter-turn
	 * quads. Submit those triangles separately; ordinary quads retain its fast
	 * (and filtered) rectangle path. This also preserves atlas trim offsets. */
	const char *renderer_name = SDL_GetRendererName(renderer);
	const bool software = renderer_name && SDL_strcmp(renderer_name, "software") == 0;
	int start = 0;
	for (int i = 0; software && texture && i + 5 < count; i += 6) {
		float *v = vertices + i * 8;
		if (v[0] != v[8] || v[1] == v[9] || v[6] == v[14]) continue;
		if (i > start) {
			float *first = vertices + start * 8;
			ok = SDL_RenderGeometryRaw(renderer, texture, first, 8*sizeof(float),
				(const SDL_FColor *)(first+2), 8*sizeof(float), first+6, 8*sizeof(float), i-start, NULL, 0, 0);
		}
		for (int triangle = 0; ok && triangle < 2; ++triangle) {
			float *first = v + triangle * 24;
			ok = SDL_RenderGeometryRaw(renderer, texture, first, 8*sizeof(float),
				(const SDL_FColor *)(first+2), 8*sizeof(float), first+6, 8*sizeof(float), 3, NULL, 0, 0);
		}
		start = i + 6;
		if (!ok) break;
	}
	if (ok && start < count) {
		float *first = vertices + start * 8;
		ok = SDL_RenderGeometryRaw(renderer, texture, first, 8*sizeof(float),
			(const SDL_FColor *)(first+2), 8*sizeof(float), first+6, 8*sizeof(float), count-start, NULL, 0, 0);
	}
    /* Restore immediately: clear/conversion draws must use SDL's own shaders. */
    if (blend == 1 && !SDL_SetGPURenderState(renderer,NULL)) ok = false;
    if (ok && destination) ++destination->revision;
    return ok ? 1 : 0;
}

int m2d_sdl_output_size(SDL_Renderer *renderer, int *w, int *h) {
    return SDL_GetWindowSizeInPixels(SDL_GetRenderWindow(renderer),w,h) ? 1 : 0;
}

int m2d_sdl_view(SDL_Renderer *renderer, M2DTexture *target, int vx, int vy, int vw, int vh,
                 float sx, float sy, int x, int y, int w, int h) {
    /* Keep SDL's scale at 1: SDL scales viewport offsets as well as geometry.
       Max2D's viewport is already in physical pixels, so scale vertices and
       clip edges explicitly to preserve exact centered pixel offsets. */
    SDL_Rect viewport = {vx,vy,vw,vh};
    int left = (int)SDL_floorf(x*sx), top = (int)SDL_floorf(y*sy);
    int right = w ? (int)SDL_ceilf((x+w)*sx) : left;
    int bottom = h ? (int)SDL_ceilf((y+h)*sy) : top;
    /* GPU scissor rectangles cannot have negative origins. Intersect in
       viewport-relative pixels instead of relying on each SDL driver to do it.
       Keep a disjoint/zero-area clip enabled with zero extent. */
    left = SDL_clamp(left,0,vw); top = SDL_clamp(top,0,vh);
    right = SDL_clamp(right,0,vw); bottom = SDL_clamp(bottom,0,vh);
    SDL_Rect clip = {left,top,SDL_max(0,right-left),SDL_max(0,bottom-top)};
    return SDL_SetRenderTarget(renderer,target ? target->premult : NULL)
        && SDL_SetRenderLogicalPresentation(renderer,0,0,SDL_LOGICAL_PRESENTATION_DISABLED)
        && SDL_SetRenderScale(renderer,1,1)
        && SDL_SetRenderViewport(renderer,&viewport)
        && SDL_SetRenderClipRect(renderer,&clip) ? 1 : 0;
}

int m2d_sdl_clear(SDL_Renderer *renderer, M2DTexture *target, int letterbox, float width, float height,
                  int red, int green, int blue, float alpha, int bar_red, int bar_green, int bar_blue) {
    if (letterbox) {
        if (!SDL_SetRenderDrawColor(renderer,bar_red,bar_green,bar_blue,255) || !SDL_RenderClear(renderer)) return 0;
    }
    float r=red/255.0f, g=green/255.0f, b=blue/255.0f;
    if (target) { r*=alpha; g*=alpha; b*=alpha; }
    SDL_FRect rect = {0,0,width,height};
    bool ok = SDL_SetRenderDrawBlendMode(renderer,SDL_BLENDMODE_NONE)
        && SDL_SetRenderDrawColorFloat(renderer,r,g,b,alpha)
        && SDL_RenderFillRect(renderer,&rect);
    if (ok && target) ++target->revision;
    return ok ? 1 : 0;
}

int m2d_sdl_read(SDL_Renderer *renderer, M2DTexture *frame, int x, int y, int w, int h, void *pixels, int pitch) {
    SDL_Rect rect = {x,y,w,h};
    SDL_Surface *surface = read_surface(renderer,frame,&rect);
    if (!surface) return 0;
    if (surface->w != w || surface->h != h) {
        SDL_DestroySurface(surface);
        SDL_SetError("Max2D: readback rectangle outside target");
        return 0;
    }
    for (int row=0;row<h;++row)
        SDL_memcpy((uint8_t *)pixels+row*pitch,(uint8_t *)surface->pixels+row*surface->pitch,(size_t)w*4);
    SDL_DestroySurface(surface);
    return 1;
}

void m2d_sdl_texture_size(SDL_Renderer *renderer, int *width, int *height) {
	Sint64 limit=SDL_GetNumberProperty(SDL_GetRendererProperties(renderer),SDL_PROP_RENDERER_MAX_TEXTURE_SIZE_NUMBER,0);
	*width=*height=limit>0 && limit<=INT32_MAX ? (int)limit : 0;
}
