#include <windows.h>
#include <d3d9.h>
#include <vector>
#include <cmath>
#include <cstdio>
#include <algorithm>
extern const DWORD m2d9_draw_shader[];

struct M2D9 {
    IDirect3DDevice9 *device;
    IDirect3DPixelShader9 *shader;
    int mipmaps;
    float sx,sy;
    int ox,oy,width,height;
    RECT clip;
};
struct M2D9Texture {
    IDirect3DTexture9 *texture;
    int width,height,allocatedWidth,allocatedHeight,filtered,target,mipmapped,mipDirty;
};
struct M2D9Vertex { float x,y,z,rhw; DWORD color; float u,v; };
static char errorText[192];
static int check(HRESULT hr,const char *operation) {
    if (SUCCEEDED(hr)) return 1;
    snprintf(errorText,sizeof(errorText),"%s failed (HRESULT 0x%08lx)",operation,(unsigned long)hr);
    return 0;
}
static int fail(const char *message) { snprintf(errorText,sizeof(errorText),"%s",message); return 0; }
static int clamp(int x,int lo,int hi) {return std::max(lo,std::min(hi,x));}
static int channel(float x) {return clamp((int)std::lround(x*255),0,255);}
extern "C" {
const char *m2d9_error() { return errorText; }
void *m2d9_open(IDirect3DDevice9 *device) {
    if (!device) {fail("No D3D9 device");return NULL;}
    D3DCAPS9 caps;
    if(!check(device->GetDeviceCaps(&caps),"GetDeviceCaps"))return NULL;
    if(!(caps.PrimitiveMiscCaps&D3DPMISCCAPS_SEPARATEALPHABLEND)){fail("Separate alpha blending is required");return NULL;}
    M2D9 *c=new M2D9();
    IDirect3D9 *api=NULL;D3DDEVICE_CREATION_PARAMETERS creation;D3DDISPLAYMODE mode;
    DWORD filters=D3DPTFILTERCAPS_MIPFPOINT|D3DPTFILTERCAPS_MIPFLINEAR|D3DPTFILTERCAPS_MINFLINEAR|D3DPTFILTERCAPS_MAGFLINEAR;
    if((caps.Caps2&D3DCAPS2_CANAUTOGENMIPMAP)&&(caps.TextureCaps&D3DPTEXTURECAPS_MIPMAP)&&
       (caps.TextureFilterCaps&filters)==filters&&SUCCEEDED(device->GetCreationParameters(&creation))&&
       SUCCEEDED(device->GetDirect3D(&api))){
        if(SUCCEEDED(api->GetAdapterDisplayMode(creation.AdapterOrdinal,&mode))){
            // D3DOK_NOAUTOGEN is a success code, but means no actual mipmaps.
            c->mipmaps=api->CheckDeviceFormat(creation.AdapterOrdinal,creation.DeviceType,mode.Format,
                D3DUSAGE_AUTOGENMIPMAP,D3DRTYPE_TEXTURE,D3DFMT_A8R8G8B8)==D3D_OK&&
                api->CheckDeviceFormat(creation.AdapterOrdinal,creation.DeviceType,mode.Format,
                D3DUSAGE_AUTOGENMIPMAP|D3DUSAGE_RENDERTARGET,D3DRTYPE_TEXTURE,D3DFMT_A8R8G8B8)==D3D_OK;
        }
        api->Release();
    }
    if(!check(device->CreatePixelShader(m2d9_draw_shader,&c->shader),"CreatePixelShader (ps_2_0 required)")){delete c;return NULL;}
    c->device=device; device->AddRef(); return c;
}
void m2d9_close(M2D9 *c) {if(c){c->shader->Release();c->device->Release();delete c;}}
void m2d9_texture_size(M2D9 *c,int *width,int *height) {
	D3DCAPS9 caps={};
	*width=*height=0;
	if(SUCCEEDED(c->device->GetDeviceCaps(&caps))) {
		*width=caps.MaxTextureWidth; *height=caps.MaxTextureHeight;
	}
}
int m2d9_render_image(M2D9 *c,int width,int height) {
	D3DCAPS9 caps={};
	if(FAILED(c->device->GetDeviceCaps(&caps)))return 0;
	if((caps.TextureCaps&D3DPTEXTURECAPS_POW2)&&((width&(width-1))||(height&(height-1))))return 0;
	if((caps.TextureCaps&D3DPTEXTURECAPS_SQUAREONLY)&&width!=height)return 0;
	IDirect3D9 *api=NULL;
	D3DDEVICE_CREATION_PARAMETERS creation={}; D3DDISPLAYMODE mode={};
	if(FAILED(c->device->GetCreationParameters(&creation))||FAILED(c->device->GetDirect3D(&api)))return 0;
	int supported=SUCCEEDED(api->GetAdapterDisplayMode(creation.AdapterOrdinal,&mode))&&
		SUCCEEDED(api->CheckDeviceFormat(creation.AdapterOrdinal,creation.DeviceType,mode.Format,D3DUSAGE_RENDERTARGET,D3DRTYPE_TEXTURE,D3DFMT_A8R8G8B8));
	api->Release(); return supported;
}
int m2d9_mipmaps(M2D9 *c){return c&&c->mipmaps;}
void m2d9_dirty(M2D9Texture *t){if(t)t->mipDirty=t->mipmapped;}
void *m2d9_create(M2D9 *c,int w,int h,int flags,int target) {
    D3DCAPS9 caps;
    if (!check(c->device->GetDeviceCaps(&caps),"GetDeviceCaps")) return NULL;
    if((flags&4)&&!c->mipmaps){fail("Automatic mipmaps are unsupported on this device");return NULL;}
    M2D9Texture *t=new M2D9Texture();
    t->mipmapped=(flags&4)!=0;t->mipDirty=t->mipmapped;
    t->target=target;t->width=w;t->height=h;t->allocatedWidth=w;t->allocatedHeight=h;t->filtered=(flags&2)!=0;
    if(caps.TextureCaps&D3DPTEXTURECAPS_POW2){
        t->allocatedWidth=1;while(t->allocatedWidth<w)t->allocatedWidth*=2;
        t->allocatedHeight=1;while(t->allocatedHeight<h)t->allocatedHeight*=2;
    }
    if(caps.TextureCaps&D3DPTEXTURECAPS_SQUAREONLY)t->allocatedWidth=t->allocatedHeight=std::max(t->allocatedWidth,t->allocatedHeight);
    if(target&&(t->allocatedWidth!=w||t->allocatedHeight!=h)){delete t;fail("This device requires power-of-two/square render images");return NULL;}
    if(!check(c->device->CreateTexture(t->allocatedWidth,t->allocatedHeight,t->mipmapped?0:1,(target?D3DUSAGE_RENDERTARGET:0)|(t->mipmapped?D3DUSAGE_AUTOGENMIPMAP:0),D3DFMT_A8R8G8B8,target?D3DPOOL_DEFAULT:D3DPOOL_MANAGED,&t->texture,NULL),"CreateTexture")){delete t;return NULL;}
    if(t->mipmapped&&!check(t->texture->SetAutoGenFilterType(D3DTEXF_LINEAR),"Mipmap generation filter")){t->texture->Release();delete t;return NULL;}
    if(target){
        IDirect3DSurface9 *surface=NULL;
        HRESULT hr=t->texture->GetSurfaceLevel(0,&surface);
        if(SUCCEEDED(hr)){hr=c->device->ColorFill(surface,NULL,0);surface->Release();}
        if(!check(hr,"Initialize render image")){t->texture->Release();delete t;return NULL;}
    }
    return t;
}
void m2d9_destroy(M2D9Texture *t){if(t){t->texture->Release();delete t;}}
/* pixels starts at the upload region; x/y locate it in the destination. */
int m2d9_update(M2D9Texture *t,const unsigned char *pixels,int pitch,int x,int y,int w,int h){
    // Lock the whole surface so right/bottom padding can be extruded on legacy
    // devices requiring power-of-two allocation. CPU source stays RGBA.
    D3DLOCKED_RECT lock;
    if(!check(t->texture->LockRect(0,&lock,NULL,0),"LockRect"))return 0;
    for(int row=y;row<y+h;++row){
        DWORD *out=(DWORD *)((unsigned char *)lock.pBits+row*lock.Pitch);
        const unsigned char *in=pixels+(row-y)*pitch;
        for(int col=x;col<x+w;++col,in+=4){
            int alpha=t->mipmapped?in[3]:255;
            out[col]=D3DCOLOR_ARGB(in[3],(in[0]*alpha+127)/255,(in[1]*alpha+127)/255,(in[2]*alpha+127)/255);
        }
        if(x+w==t->width)for(int col=t->width;col<t->allocatedWidth;++col)out[col]=out[t->width-1];
    }
    if(y+h==t->height){
        const DWORD *last=(DWORD *)((unsigned char *)lock.pBits+(t->height-1)*lock.Pitch);
        for(int row=t->height;row<t->allocatedHeight;++row){
            DWORD *out=(DWORD *)((unsigned char *)lock.pBits+row*lock.Pitch);
            for(int col=x;col<(x+w==t->width?t->allocatedWidth:x+w);++col)out[col]=last[col];
        }
    }
    t->mipDirty=t->mipmapped;
    return check(t->texture->UnlockRect(0),"UnlockRect");
}
// Release device-held target/texture bindings before releasing default-pool resources.
void m2d9_unbind(M2D9 *c){
    c->device->SetTexture(0,NULL);
    IDirect3DSurface9 *back=NULL;
    if(SUCCEEDED(c->device->GetBackBuffer(0,0,D3DBACKBUFFER_TYPE_MONO,&back))){
        c->device->SetRenderTarget(0,back);back->Release();
    }
}
static int bindTarget(M2D9 *c,M2D9Texture *target){
    if(!check(c->device->SetTexture(0,NULL),"Unbind sampler"))return 0;
    IDirect3DSurface9 *surface=NULL;
    HRESULT hr=target?target->texture->GetSurfaceLevel(0,&surface):c->device->GetBackBuffer(0,0,D3DBACKBUFFER_TYPE_MONO,&surface);
    if(!check(hr,"Get target surface"))return 0;
    hr=c->device->SetRenderTarget(0,surface);surface->Release();
    if(!check(hr,"SetRenderTarget")||!check(c->device->SetDepthStencilSurface(NULL),"Disable depth surface"))return 0;
    D3DVIEWPORT9 viewport={0,0,(DWORD)c->width,(DWORD)c->height,0,1};
    return check(c->device->SetViewport(&viewport),"Target viewport");
}
int m2d9_view(M2D9 *c,int width,int height,int ox,int oy,int vw,int vh,float sx,float sy,int x,int y,int w,int h){
    c->width=width;c->height=height;c->ox=ox;c->oy=oy;c->sx=sx;c->sy=sy;
    c->clip.left=clamp(ox+(int)floor(x*sx),ox,ox+vw);
    c->clip.top=clamp(oy+(int)floor(y*sy),oy,oy+vh);
    c->clip.right=w?clamp(ox+(int)ceil((x+w)*sx),ox,ox+vw):c->clip.left;
    c->clip.bottom=h?clamp(oy+(int)ceil((y+h)*sy),oy,oy+vh):c->clip.top;
    return 1;
}
int m2d9_submit(M2D9 *c,M2D9Texture *dest,M2D9Texture *t,int blend,const float *v,int count){
    if(c->clip.right<=c->clip.left||c->clip.bottom<=c->clip.top)return 1;
    if(!bindTarget(c,dest))return 0;
    int generated=0;
    if(t&&t->mipDirty){
        // Managed texture edits must reach GPU memory before deriving lower levels.
        t->texture->PreLoad();
        t->texture->GenerateMipSubLevels();
        t->mipDirty=0;generated=1;
    }
    IDirect3DDevice9 *d=c->device;
#define TRY(call) if(!check((call),#call))return 0
    TRY(d->SetVertexShader(NULL));TRY(d->SetPixelShader(c->shader));
    float options[4]={t?1.f:0.f,t&&(t->target||t->mipmapped)?1.f:0.f,(blend==3||blend==4||(dest&&blend<=2))?1.f:0.f,blend==1?1.f:0.f};
    TRY(d->SetPixelShaderConstantF(0,options,1));
    TRY(d->SetFVF(D3DFVF_XYZRHW|D3DFVF_DIFFUSE|D3DFVF_TEX1));
    D3DVIEWPORT9 viewport={0,0,(DWORD)c->width,(DWORD)c->height,0,1};
    TRY(d->SetViewport(&viewport));TRY(d->SetScissorRect(&c->clip));
    TRY(d->SetRenderState(D3DRS_SCISSORTESTENABLE,TRUE));
    TRY(d->SetRenderState(D3DRS_ZENABLE,FALSE));TRY(d->SetRenderState(D3DRS_ZWRITEENABLE,FALSE));
    TRY(d->SetRenderState(D3DRS_CULLMODE,D3DCULL_NONE));TRY(d->SetRenderState(D3DRS_LIGHTING,FALSE));
    TRY(d->SetRenderState(D3DRS_FOGENABLE,FALSE));TRY(d->SetRenderState(D3DRS_SRGBWRITEENABLE,FALSE));
    TRY(d->SetRenderState(D3DRS_COLORWRITEENABLE,15));
    TRY(d->SetRenderState(D3DRS_ALPHATESTENABLE,FALSE));
    TRY(d->SetRenderState(D3DRS_ALPHABLENDENABLE,blend>=3));
    TRY(d->SetRenderState(D3DRS_SEPARATEALPHABLENDENABLE,TRUE));
    TRY(d->SetRenderState(D3DRS_BLENDOP,D3DBLENDOP_ADD));
    TRY(d->SetRenderState(D3DRS_SRCBLEND,blend==5?D3DBLEND_DESTCOLOR:D3DBLEND_ONE));
    TRY(d->SetRenderState(D3DRS_DESTBLEND,blend==5?D3DBLEND_ZERO:(blend==4?D3DBLEND_ONE:D3DBLEND_INVSRCALPHA)));
    TRY(d->SetRenderState(D3DRS_BLENDOPALPHA,D3DBLENDOP_ADD));
    TRY(d->SetRenderState(D3DRS_SRCBLENDALPHA,blend==3?D3DBLEND_ONE:D3DBLEND_ZERO));
    TRY(d->SetRenderState(D3DRS_DESTBLENDALPHA,blend==3?D3DBLEND_INVSRCALPHA:D3DBLEND_ONE));
    TRY(d->SetTexture(0,t?t->texture:NULL));
    TRY(d->SetTextureStageState(0,D3DTSS_COLOROP,t?D3DTOP_MODULATE:D3DTOP_SELECTARG2));
    TRY(d->SetTextureStageState(0,D3DTSS_ALPHAOP,t?D3DTOP_MODULATE:D3DTOP_SELECTARG2));
    TRY(d->SetTextureStageState(0,D3DTSS_COLORARG1,D3DTA_TEXTURE));TRY(d->SetTextureStageState(0,D3DTSS_COLORARG2,D3DTA_DIFFUSE));
    TRY(d->SetTextureStageState(0,D3DTSS_ALPHAARG1,D3DTA_TEXTURE));TRY(d->SetTextureStageState(0,D3DTSS_ALPHAARG2,D3DTA_DIFFUSE));
    TRY(d->SetTextureStageState(1,D3DTSS_COLOROP,D3DTOP_DISABLE));
    TRY(d->SetSamplerState(0,D3DSAMP_MINFILTER,t&&t->filtered?D3DTEXF_LINEAR:D3DTEXF_POINT));
    TRY(d->SetSamplerState(0,D3DSAMP_MAGFILTER,t&&t->filtered?D3DTEXF_LINEAR:D3DTEXF_POINT));
    TRY(d->SetSamplerState(0,D3DSAMP_MIPFILTER,t&&t->mipmapped?(t->filtered?D3DTEXF_LINEAR:D3DTEXF_POINT):D3DTEXF_NONE));
    TRY(d->SetSamplerState(0,D3DSAMP_ADDRESSU,D3DTADDRESS_CLAMP));TRY(d->SetSamplerState(0,D3DSAMP_ADDRESSV,D3DTADDRESS_CLAMP));
    TRY(d->SetSamplerState(0,D3DSAMP_SRGBTEXTURE,FALSE));
    std::vector<M2D9Vertex> vertices(count);
    for(int i=0;i<count;++i,v+=8){M2D9Vertex &o=vertices[i];o.x=c->ox+v[0]*c->sx-0.5f;o.y=c->oy+v[1]*c->sy-0.5f;o.z=0;o.rhw=1;
        o.color=D3DCOLOR_ARGB(channel(v[5]),channel(v[2]),channel(v[3]),channel(v[4]));
        o.u=t?v[6]*t->width/t->allocatedWidth:0;o.v=t?v[7]*t->height/t->allocatedHeight:0;}
    TRY(d->BeginScene());
    HRESULT draw=d->DrawPrimitiveUP(D3DPT_TRIANGLELIST,count/3,vertices.data(),sizeof(M2D9Vertex));
    HRESULT end=d->EndScene();
    if(!check(draw,"DrawPrimitiveUP")||!check(end,"EndScene"))return 0;
    if(dest)dest->mipDirty=dest->mipmapped;
    return 1+generated;
#undef TRY
}
int m2d9_clear(M2D9 *c,M2D9Texture *dest,int bars,int r,int g,int b,float a,int br,int bg,int bb){
    if(!bindTarget(c,dest))return 0;
    if(dest)dest->mipDirty=dest->mipmapped;
    if(dest){r=(int)std::lround(r*a);g=(int)std::lround(g*a);b=(int)std::lround(b*a);}
    if(bars&&!check(c->device->Clear(0,NULL,D3DCLEAR_TARGET,D3DCOLOR_XRGB(br,bg,bb),1,0),"Clear bars"))return 0;
    if(c->clip.right<=c->clip.left||c->clip.bottom<=c->clip.top)return 1;
    D3DRECT rect={c->clip.left,c->clip.top,c->clip.right,c->clip.bottom};
    return check(c->device->Clear(1,&rect,D3DCLEAR_TARGET,D3DCOLOR_ARGB(channel(a),r,g,b),1,0),"Clear clip");
}
// System-memory snapshots retain exact premultiplied pixels across planned resets.
void *m2d9_snapshot(M2D9 *c,M2D9Texture *t){
 IDirect3DSurface9 *source=NULL,*copy=NULL;
 HRESULT hr=t->texture->GetSurfaceLevel(0,&source);
 if(SUCCEEDED(hr))hr=c->device->CreateOffscreenPlainSurface(t->width,t->height,D3DFMT_A8R8G8B8,D3DPOOL_SYSTEMMEM,&copy,NULL);
 if(SUCCEEDED(hr))hr=c->device->GetRenderTargetData(source,copy);
 if(source)source->Release();
 if(!check(hr,"Snapshot render image")){if(copy)copy->Release();return NULL;}
 return copy;
}
void m2d9_release_snapshot(IDirect3DSurface9 *copy){if(copy)copy->Release();}
int m2d9_restore(M2D9 *c,M2D9Texture *t,IDirect3DSurface9 *copy){
 IDirect3DSurface9 *dest=NULL;
 HRESULT hr=t->texture->GetSurfaceLevel(0,&dest);
 if(SUCCEEDED(hr))hr=c->device->UpdateSurface(copy,NULL,dest,NULL);
 if(dest)dest->Release();
 t->mipDirty=t->mipmapped;
 return check(hr,"Restore render image");
}
int m2d9_read(M2D9 *c,M2D9Texture *target,int x,int y,int w,int h,unsigned char *pixels,int pitch){
    IDirect3DSurface9 *back=NULL,*copy=NULL;
    if(!check((target?target->texture->GetSurfaceLevel(0,&back):c->device->GetBackBuffer(0,0,D3DBACKBUFFER_TYPE_MONO,&back)),"Get readback surface"))return 0;
    D3DSURFACE_DESC desc;HRESULT hr=back->GetDesc(&desc);
    if(FAILED(hr)){back->Release();return check(hr,"GetDesc");}
    if(x<0||y<0||w>int(desc.Width)-x||h>int(desc.Height)-y){back->Release();return fail("Readback outside backbuffer");}
    hr=c->device->CreateOffscreenPlainSurface(desc.Width,desc.Height,desc.Format,D3DPOOL_SYSTEMMEM,&copy,NULL);
    if(SUCCEEDED(hr))hr=c->device->GetRenderTargetData(back,copy);
    back->Release();
    if(FAILED(hr)){if(copy)copy->Release();return check(hr,"Backbuffer readback");}
    if(desc.Format!=D3DFMT_X8R8G8B8&&desc.Format!=D3DFMT_A8R8G8B8){copy->Release();return fail("Unsupported backbuffer readback format");}
    RECT rect={x,y,x+w,y+h};D3DLOCKED_RECT lock;
    hr=copy->LockRect(&lock,&rect,D3DLOCK_READONLY);
    if(SUCCEEDED(hr)){
        for(int row=0;row<h;++row){const DWORD *in=(DWORD *)((unsigned char *)lock.pBits+row*lock.Pitch);unsigned char *out=pixels+row*pitch;
            for(int col=0;col<w;++col,out+=4){DWORD color=in[col];out[0]=(color>>16)&255;out[1]=(color>>8)&255;out[2]=color&255;out[3]=target?(color>>24):255;
                if(target){for(int k=0;k<3;++k)out[k]=out[3]?std::min(255,(out[k]*255+out[3]/2)/out[3]):0;}}}
        hr=copy->UnlockRect();
    }
    copy->Release();return check(hr,"Readback lock");
}
}
