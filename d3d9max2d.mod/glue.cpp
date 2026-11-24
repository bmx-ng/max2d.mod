#include <windows.h>
#include <max2d.mod/core.mod/blend.h>
#include <d3d9.h>
#include <vector>
#include <map>
#include <string>
#include <max2d.mod/shadereffects.mod/package.h>
#include <cstring>
#include <cstdint>
#include <limits>
#include <cmath>
#include <cstdio>
#include <algorithm>
extern const unsigned char m2d9_draw_shader[],m2d9_float_shader[];

struct M2D9Texture;
struct M2D9Package { IDirect3DPixelShader9 *shader; int slots,abi,samplers; };
struct M2D9 {
    IDirect3DDevice9 *device;
    IDirect3DPixelShader9 *shader,*floatShader;
    std::map<const void *,IDirect3DPixelShader9 *> effects;
    IDirect3DPixelShader9 *effect;
    float effectParameters[4];
 std::map<std::string,M2D9Package> packages;
 M2D9Package *package;
 M2D9Texture *auxiliary[4];
 /* Native material capacity; public package limits are unchanged. */
 float packageValues[M2D_NATIVE_PARAMETER_SLOTS*4];
    int effectBaseLevel;
    int mipmaps;
	D3DCAPS9 caps;
    float sx,sy;
    int ox,oy,width,height;
    RECT clip;
};
struct M2D9Texture {
    IDirect3DTexture9 *texture;
    D3DFORMAT format;
    int width,height,allocatedWidth,allocatedHeight,filtered,target,mipmapped,mipDirty;
};
struct M2D9Vertex { float x,y,z,rhw,u,v,color[4],screen[2]; };
static char errorText[192];
static int check(HRESULT hr,const char *operation) {
    if (SUCCEEDED(hr)) return 1;
    snprintf(errorText,sizeof(errorText),"%s failed (HRESULT 0x%08lx)",operation,(unsigned long)hr);
    return 0;
}
static int fail(const char *message) { snprintf(errorText,sizeof(errorText),"%s",message); return 0; }
static int clamp(int x,int lo,int hi) {return std::max(lo,std::min(hi,x));}
static int channel(float x) {return clamp((int)std::lround(x*255),0,255);}
static const D3DBLEND blendFactors[]={D3DBLEND_ZERO,D3DBLEND_ZERO,D3DBLEND_ONE,D3DBLEND_SRCCOLOR,D3DBLEND_INVSRCCOLOR,D3DBLEND_SRCALPHA,D3DBLEND_INVSRCALPHA,D3DBLEND_DESTCOLOR,D3DBLEND_INVDESTCOLOR,D3DBLEND_DESTALPHA,D3DBLEND_INVDESTALPHA};
static const D3DBLENDOP blendOps[]={D3DBLENDOP_ADD,D3DBLENDOP_ADD,D3DBLENDOP_SUBTRACT,D3DBLENDOP_REVSUBTRACT,D3DBLENDOP_MIN,D3DBLENDOP_MAX};
static const DWORD blendCaps[]={0,D3DPBLENDCAPS_ZERO,D3DPBLENDCAPS_ONE,D3DPBLENDCAPS_SRCCOLOR,D3DPBLENDCAPS_INVSRCCOLOR,D3DPBLENDCAPS_SRCALPHA,D3DPBLENDCAPS_INVSRCALPHA,D3DPBLENDCAPS_DESTCOLOR,D3DPBLENDCAPS_INVDESTCOLOR,D3DPBLENDCAPS_DESTALPHA,D3DPBLENDCAPS_INVDESTALPHA};
extern "C" {
int m2d9_blend(M2D9 *c,int mode) {
	if(mode>=1 && mode<=5) return 1;
	M2DBlend b;
	if(!m2d_blend_decode(mode,&b)) return 0;
	if((b.op!=1 || b.opAlpha!=1) && !(c->caps.PrimitiveMiscCaps&D3DPMISCCAPS_BLENDOP)) return 0;
	return (c->caps.SrcBlendCaps&blendCaps[b.src]) && (c->caps.SrcBlendCaps&blendCaps[b.srcAlpha]) &&
		(c->caps.DestBlendCaps&blendCaps[b.dst]) && (c->caps.DestBlendCaps&blendCaps[b.dstAlpha]);
}
const char *m2d9_error() { return errorText; }
void *m2d9_open(IDirect3DDevice9 *device) {
    if (!device) {fail("No D3D9 device");return NULL;}
    D3DCAPS9 caps;
    if(!check(device->GetDeviceCaps(&caps),"GetDeviceCaps"))return NULL;
    if(!(caps.PrimitiveMiscCaps&D3DPMISCCAPS_SEPARATEALPHABLEND)){fail("Separate alpha blending is required");return NULL;}
    M2D9 *c=new M2D9();
	c->caps=caps;
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
    if(!check(device->CreatePixelShader((const DWORD *)m2d9_draw_shader,&c->shader),"CreatePixelShader (ps_2_0 required)")){delete c;return NULL;}
    c->device=device; device->AddRef(); return c;
}
void *m2d9_create_image_effect(M2D9 *c,const void *code,size_t size) {
    if(!c||!code||!size) return NULL;
    if(c->caps.PixelShaderVersion<D3DPS_VERSION(3,0)) {
        check(E_NOTIMPL,"Image effects require pixel shader 3.0");return NULL;
    }
    auto found=c->effects.find(code);
    if(found!=c->effects.end()) return found->second;
    IDirect3DPixelShader9 *shader=NULL;
    if(!check(c->device->CreatePixelShader((const DWORD *)code,&shader),"Create image effect")) return NULL;
    c->effects[code]=shader;return shader;
}
void *m2d9_package_shader(M2D9 *c,M2DPackage *p) {
 if(!c||!p||!p->d3d9)return nullptr;
 if(p->slots<1||p->slots>M2D_NATIVE_PARAMETER_SLOTS || p->samplers<1 || p->samplers>5 ||
    (p->samplers>3 && p->abi!=M2D_NATIVE_MATERIAL_ABI) ||
    (p->abi==M2D_NATIVE_MATERIAL_ABI && p->slots<p->samplers-1)) {
  fail("Invalid native shader texture layout");return nullptr;
 }
 if(c->caps.PixelShaderVersion<D3DPS_VERSION(3,0))return nullptr;
 auto found=c->packages.find(p->key);
 if(found!=c->packages.end())return &found->second;
 IDirect3DPixelShader9 *shader=nullptr;
 if(!check(c->device->CreatePixelShader((const DWORD *)p->d3d9,&shader),"Create package shader"))return nullptr;
 M2D9Package entry={shader,p->slots,p->abi,p->samplers};
 return &c->packages.emplace(p->key,entry).first->second;
}
static void select_package(M2D9 *c,M2D9Package *p,const float *values,M2D9Texture **textures,int count) {
 c->package=p;c->effect=p->shader;
 memcpy(c->packageValues,values,p->slots*16);
 int modes=p->abi==M2D_NATIVE_MATERIAL_ABI?p->samplers-1:
     ((p->abi==5 || p->abi==M2D_NATIVE_LIGHTING_ABI)?2:(p->abi>=3?1:0));
 for(int i=0;i<4;i++) {
  M2D9Texture *texture=i<count?textures[i]:nullptr;
  c->auxiliary[i]=texture;
  if(i>=modes) continue;
  float *mode=c->packageValues+(p->slots-modes+i)*4;
  mode[0]=0;
  mode[1]=texture&&(texture->target||texture->mipmapped)?1.f:0.f;
 }
 c->effectBaseLevel=p->abi>=2;
}
int m2d9_select_texture_set(M2D9 *c,M2D9Package *p,const float *values,M2D9Texture **textures,int count) {
 if(!p || !values || count<0 || count>4 || count!=p->samplers-1)
  return fail("Texture count does not match native shader");
 for(int i=0;i<count;i++) if(!textures[i]) return fail("Missing native effect texture");
 select_package(c,p,values,textures,count);
 return 1;
}
void m2d9_select_package_effect(M2D9 *c,M2D9Package *p,const float *values,M2D9Texture *second,M2D9Texture *third) {
 M2D9Texture *textures[]={second,third};
 select_package(c,p,values,textures,third?2:(second?1:0));
}
void m2d9_select_image_effect(M2D9 *c,IDirect3DPixelShader9 *shader,float x,float y,float z,float w,int baseLevelOnly) {
    if(!c) return;
    c->package=nullptr;memset(c->auxiliary,0,sizeof(c->auxiliary));c->effect=shader;c->effectBaseLevel=shader&&baseLevelOnly;
    c->effectParameters[0]=x;c->effectParameters[1]=y;c->effectParameters[2]=z;c->effectParameters[3]=w;
}
void m2d9_close(M2D9 *c) {if(c){for(auto &entry:c->packages)entry.second.shader->Release();for(auto &entry:c->effects) entry.second->Release();c->shader->Release();if(c->floatShader)c->floatShader->Release();c->device->Release();delete c;}}
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
static D3DFORMAT floatFormat(int bits) { return bits==16?D3DFMT_A16B16G16R16F:bits==32?D3DFMT_A32B32G32R32F:D3DFMT_A8R8G8B8; }
int m2d9_float_supported(M2D9 *c,int bits,int filtered,int target) {
    IDirect3D9 *api=NULL; D3DDEVICE_CREATION_PARAMETERS creation={}; D3DDISPLAYMODE mode={};
    if(!c || c->caps.PixelShaderVersion<D3DPS_VERSION(3,0) || (bits!=16&&bits!=32)) return 0;
    if(FAILED(c->device->GetCreationParameters(&creation))||FAILED(c->device->GetDirect3D(&api))) return 0;
    DWORD usage=(target?D3DUSAGE_RENDERTARGET|D3DUSAGE_QUERY_POSTPIXELSHADER_BLENDING:0)|(filtered?D3DUSAGE_QUERY_FILTER:0);
    int supported=SUCCEEDED(api->GetAdapterDisplayMode(creation.AdapterOrdinal,&mode)) &&
        api->CheckDeviceFormat(creation.AdapterOrdinal,creation.DeviceType,mode.Format,usage,D3DRTYPE_TEXTURE,floatFormat(bits))==D3D_OK;
    api->Release();return supported;
}
int m2d9_mipmaps(M2D9 *c){return c&&c->mipmaps;}
void m2d9_dirty(M2D9Texture *t){if(t)t->mipDirty=t->mipmapped;}
void *m2d9_create(M2D9 *c,int w,int h,int flags,int target,int bits) {
    D3DCAPS9 caps;
    if (!check(c->device->GetDeviceCaps(&caps),"GetDeviceCaps")) return NULL;
    if((flags&4)&&!c->mipmaps){fail("Automatic mipmaps are unsupported on this device");return NULL;}
    if(bits && ((flags&4)||!m2d9_float_supported(c,bits,flags&2,target))) {fail("Unsupported floating-point texture flags/format");return NULL;}
    M2D9Texture *t=new M2D9Texture();
    t->format=floatFormat(bits);
    t->mipmapped=(flags&4)!=0;t->mipDirty=t->mipmapped;
    t->target=target;t->width=w;t->height=h;t->allocatedWidth=w;t->allocatedHeight=h;t->filtered=(flags&2)!=0;
    if(caps.TextureCaps&D3DPTEXTURECAPS_POW2){
        t->allocatedWidth=1;while(t->allocatedWidth<w)t->allocatedWidth*=2;
        t->allocatedHeight=1;while(t->allocatedHeight<h)t->allocatedHeight*=2;
    }
    if(caps.TextureCaps&D3DPTEXTURECAPS_SQUAREONLY)t->allocatedWidth=t->allocatedHeight=std::max(t->allocatedWidth,t->allocatedHeight);
    if(target&&(t->allocatedWidth!=w||t->allocatedHeight!=h)){delete t;fail("This device requires power-of-two/square render images");return NULL;}
    if(!check(c->device->CreateTexture(t->allocatedWidth,t->allocatedHeight,t->mipmapped?0:1,(target?D3DUSAGE_RENDERTARGET:0)|(t->mipmapped?D3DUSAGE_AUTOGENMIPMAP:0),t->format,target?D3DPOOL_DEFAULT:D3DPOOL_MANAGED,&t->texture,NULL),"CreateTexture")){delete t;return NULL;}
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
int m2d9_update_float(M2D9Texture *t,const unsigned char *pixels,int pitch) {
    int bytes=t->format==D3DFMT_A16B16G16R16F?8:16;
    D3DLOCKED_RECT lock;
    if(!check(t->texture->LockRect(0,&lock,NULL,0),"Float upload lock"))return 0;
    for(int y=0;y<t->allocatedHeight;++y) {
        unsigned char *out=(unsigned char *)lock.pBits+y*lock.Pitch;
        const unsigned char *in=pixels+std::min(y,t->height-1)*pitch;
        memcpy(out,in,t->width*bytes);
        for(int x=t->width;x<t->allocatedWidth;++x)memcpy(out+x*bytes,in+(t->width-1)*bytes,bytes);
    }
    return check(t->texture->UnlockRect(0),"Float upload unlock");
}
// Release device-held target/texture bindings before releasing default-pool resources.
void m2d9_unbind(M2D9 *c){
    c->device->SetTexture(0,NULL);c->device->SetTexture(1,NULL);c->device->SetTexture(2,NULL);
    IDirect3DSurface9 *back=NULL;
    if(SUCCEEDED(c->device->GetBackBuffer(0,0,D3DBACKBUFFER_TYPE_MONO,&back))){
        c->device->SetRenderTarget(0,back);back->Release();
    }
}
static int bindTarget(M2D9 *c,M2D9Texture *target){
    for(int i=0;i<5;i++) if(!check(c->device->SetTexture(i,NULL),"Unbind sampler"))return 0;
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
    // Supplied byte mipmaps retain their ordinary derivative-based sampling.
    bool floatCopy=!c->effect&&!(t&&t->mipmapped)&&((t&&t->format!=D3DFMT_A8R8G8B8)||(dest&&dest->format!=D3DFMT_A8R8G8B8));
    if(floatCopy&&!c->floatShader) {TRY(d->CreatePixelShader((const DWORD *)m2d9_float_shader,&c->floatShader));}
    TRY(d->SetVertexShader(NULL));TRY(d->SetPixelShader(c->effect?c->effect:(floatCopy?c->floatShader:c->shader)));
    float options[4]={t?1.f:0.f,t&&(t->target||t->mipmapped)?1.f:0.f,(blend==3||blend==4||(dest&&blend<=2))?1.f:0.f,blend==1?1.f:0.f};
    TRY(d->SetPixelShaderConstantF(0,options,1));
    if(c->package) {
        float mode[4]={0,options[1],options[3],options[2]};
        TRY(d->SetPixelShaderConstantF(0,mode,1));
        TRY(d->SetPixelShaderConstantF(1,c->packageValues,c->package->slots));
        float info[]={t?float(t->filtered):0.f,t&&t->format!=D3DFMT_A8R8G8B8?1.f:0.f,0,0};
        TRY(d->SetPixelShaderConstantF(c->package->abi==M2D_NATIVE_MATERIAL_ABI?c->package->slots+c->package->samplers+1:c->package->abi==M2D_NATIVE_LIGHTING_ABI?c->package->slots+4:(c->package->abi==5?20:13),info,1));
        M2D9Texture *textures[]={t,c->auxiliary[0],c->auxiliary[1],c->auxiliary[2],c->auxiliary[3]};
        for(int i=0;i<(c->package->abi==M2D_NATIVE_MATERIAL_ABI?c->package->samplers:((c->package->abi==5 || c->package->abi==M2D_NATIVE_LIGHTING_ABI)?3:2));++i) {
            M2D9Texture *tex=textures[i];
            float scale[4]={tex?float(tex->width)/tex->allocatedWidth:1.f,tex?float(tex->height)/tex->allocatedHeight:1.f,tex?1.f/tex->allocatedWidth:1.f,tex?1.f/tex->allocatedHeight:1.f};
            TRY(d->SetPixelShaderConstantF(((c->package->abi==M2D_NATIVE_LIGHTING_ABI || c->package->abi==M2D_NATIVE_MATERIAL_ABI)?c->package->slots+1:(c->package->abi==5?17:11))+i,scale,1));
        }
    } else if(c->effect) {
        float scale[4]={t?float(t->width)/t->allocatedWidth:1.f,t?float(t->height)/t->allocatedHeight:1.f,t?float(t->width):1.f,t?float(t->height):1.f};
        float parameters[4]={c->effectParameters[0],c->effectParameters[1],c->effectParameters[2],c->effectBaseLevel&&t?float(t->filtered):c->effectParameters[3]};
        TRY(d->SetPixelShaderConstantF(1,parameters,1));
        TRY(d->SetPixelShaderConstantF(2,scale,1));
        float info[]={t?float(t->filtered):0.f,t&&t->format!=D3DFMT_A8R8G8B8?1.f:0.f,0,0};
        TRY(d->SetPixelShaderConstantF(3,info,1));
    }
    if(floatCopy) {
        float info[]={t?1.f/t->allocatedWidth:1.f,t?1.f/t->allocatedHeight:1.f,t?float(t->width):1.f,t?float(t->height):1.f};
        float filter[]={t?float(t->filtered):0.f,0,0,0};
        TRY(d->SetPixelShaderConstantF(1,info,1));TRY(d->SetPixelShaderConstantF(2,filter,1));
    }
    TRY(d->SetFVF(D3DFVF_XYZRHW|D3DFVF_TEX3|D3DFVF_TEXCOORDSIZE4(1)));
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
	M2DBlend custom;
	if(m2d_blend_decode(blend,&custom)) {
		TRY(d->SetRenderState(D3DRS_BLENDOP,blendOps[custom.op]));
		TRY(d->SetRenderState(D3DRS_SRCBLEND,blendFactors[custom.src]));
		TRY(d->SetRenderState(D3DRS_DESTBLEND,blendFactors[custom.dst]));
		TRY(d->SetRenderState(D3DRS_BLENDOPALPHA,blendOps[custom.opAlpha]));
		TRY(d->SetRenderState(D3DRS_SRCBLENDALPHA,blendFactors[custom.srcAlpha]));
		TRY(d->SetRenderState(D3DRS_DESTBLENDALPHA,blendFactors[custom.dstAlpha]));
	} else {
		TRY(d->SetRenderState(D3DRS_BLENDOP,D3DBLENDOP_ADD));
		TRY(d->SetRenderState(D3DRS_SRCBLEND,blend==5?D3DBLEND_DESTCOLOR:D3DBLEND_ONE));
		TRY(d->SetRenderState(D3DRS_DESTBLEND,blend==5?D3DBLEND_ZERO:(blend==4?D3DBLEND_ONE:D3DBLEND_INVSRCALPHA)));
		TRY(d->SetRenderState(D3DRS_BLENDOPALPHA,D3DBLENDOP_ADD));
		TRY(d->SetRenderState(D3DRS_SRCBLENDALPHA,blend==3?D3DBLEND_ONE:D3DBLEND_ZERO));
		TRY(d->SetRenderState(D3DRS_DESTBLENDALPHA,blend==3?D3DBLEND_INVSRCALPHA:D3DBLEND_ONE));
	}
    TRY(d->SetTexture(0,t?t->texture:NULL));
    TRY(d->SetTextureStageState(0,D3DTSS_COLOROP,t?D3DTOP_MODULATE:D3DTOP_SELECTARG2));
    TRY(d->SetTextureStageState(0,D3DTSS_ALPHAOP,t?D3DTOP_MODULATE:D3DTOP_SELECTARG2));
    TRY(d->SetTextureStageState(0,D3DTSS_COLORARG1,D3DTA_TEXTURE));TRY(d->SetTextureStageState(0,D3DTSS_COLORARG2,D3DTA_DIFFUSE));
    TRY(d->SetTextureStageState(0,D3DTSS_ALPHAARG1,D3DTA_TEXTURE));TRY(d->SetTextureStageState(0,D3DTSS_ALPHAARG2,D3DTA_DIFFUSE));
    TRY(d->SetTextureStageState(1,D3DTSS_COLOROP,D3DTOP_DISABLE));
    TRY(d->SetSamplerState(0,D3DSAMP_MINFILTER,t&&t->filtered&&!c->effectBaseLevel&&!floatCopy&&!(c->effect&&t->format!=D3DFMT_A8R8G8B8)?D3DTEXF_LINEAR:D3DTEXF_POINT));
    TRY(d->SetSamplerState(0,D3DSAMP_MAGFILTER,t&&t->filtered&&!c->effectBaseLevel&&!floatCopy&&!(c->effect&&t->format!=D3DFMT_A8R8G8B8)?D3DTEXF_LINEAR:D3DTEXF_POINT));
    TRY(d->SetSamplerState(0,D3DSAMP_MIPFILTER,t&&t->mipmapped&&!c->effectBaseLevel&&!floatCopy&&!(c->effect&&t->format!=D3DFMT_A8R8G8B8)?(t->filtered?D3DTEXF_LINEAR:D3DTEXF_POINT):D3DTEXF_NONE));
    TRY(d->SetSamplerState(0,D3DSAMP_ADDRESSU,D3DTADDRESS_CLAMP));TRY(d->SetSamplerState(0,D3DSAMP_ADDRESSV,D3DTADDRESS_CLAMP));
    TRY(d->SetSamplerState(0,D3DSAMP_SRGBTEXTURE,FALSE));
    for(int i=0;i<4;i++) {
        M2D9Texture *texture=c->package?c->auxiliary[i]:nullptr;
        if(texture&&texture->mipDirty){texture->texture->PreLoad();texture->texture->GenerateMipSubLevels();texture->mipDirty=0;++generated;}
        TRY(d->SetTexture(i+1,texture?texture->texture:NULL));
        TRY(d->SetSamplerState(i+1,D3DSAMP_MINFILTER,D3DTEXF_POINT));
        TRY(d->SetSamplerState(i+1,D3DSAMP_MAGFILTER,D3DTEXF_POINT));
        TRY(d->SetSamplerState(i+1,D3DSAMP_MIPFILTER,D3DTEXF_NONE));
        TRY(d->SetSamplerState(i+1,D3DSAMP_ADDRESSU,D3DTADDRESS_CLAMP));
        TRY(d->SetSamplerState(i+1,D3DSAMP_ADDRESSV,D3DTADDRESS_CLAMP));
        TRY(d->SetSamplerState(i+1,D3DSAMP_SRGBTEXTURE,FALSE));
    }
    std::vector<M2D9Vertex> vertices(count);
    for(int i=0;i<count;++i,v+=8){M2D9Vertex &o=vertices[i];o.x=c->ox+v[0]*c->sx-0.5f;o.y=c->oy+v[1]*c->sy-0.5f;o.z=0;o.rhw=1;
        memcpy(o.color,v+2,4*sizeof(float));o.screen[0]=o.x;o.screen[1]=o.y;
        o.u=t?(c->effect?v[6]:v[6]*t->width/t->allocatedWidth):0;o.v=t?(c->effect?v[7]:v[7]*t->height/t->allocatedHeight):0;}
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
    if(bars&&!check(c->device->Clear(0,NULL,D3DCLEAR_TARGET,D3DCOLOR_XRGB(br,bg,bb),1,0),"Clear bars"))return 0;
    if(dest&&dest->format!=D3DFMT_A8R8G8B8) {
        // A shader clear preserves fractional alpha; D3DCOLOR Clear is only 8-bit.
        float x0=(c->clip.left-c->ox)/c->sx,y0=(c->clip.top-c->oy)/c->sy;
        float x1=(c->clip.right-c->ox)/c->sx,y1=(c->clip.bottom-c->oy)/c->sy;
        float positions[]={x0,y0,x1,y0,x1,y1,x0,y0,x1,y1,x0,y1},v[48];
        for(int i=0;i<6;++i){float *p=v+i*8;p[0]=positions[i*2];p[1]=positions[i*2+1];p[2]=r/255.f;p[3]=g/255.f;p[4]=b/255.f;p[5]=a;p[6]=p[7]=0;}
        auto effect=c->effect;auto package=c->package;int base=c->effectBaseLevel;
        c->effect=nullptr;c->package=nullptr;c->effectBaseLevel=0;
        int result=m2d9_submit(c,dest,nullptr,2,v,6);
        c->effect=effect;c->package=package;c->effectBaseLevel=base;
        return result;
    }
    if(dest){r=(int)std::lround(r*a);g=(int)std::lround(g*a);b=(int)std::lround(b*a);}
    if(c->clip.right<=c->clip.left||c->clip.bottom<=c->clip.top)return 1;
    D3DRECT rect={c->clip.left,c->clip.top,c->clip.right,c->clip.bottom};
    return check(c->device->Clear(1,&rect,D3DCLEAR_TARGET,D3DCOLOR_ARGB(channel(a),r,g,b),1,0),"Clear clip");
}
// System-memory snapshots retain exact premultiplied pixels across planned resets.
void *m2d9_snapshot(M2D9 *c,M2D9Texture *t){
 IDirect3DSurface9 *source=NULL,*copy=NULL;
 HRESULT hr=t->texture->GetSurfaceLevel(0,&source);
 if(SUCCEEDED(hr))hr=c->device->CreateOffscreenPlainSurface(t->width,t->height,t->format,D3DPOOL_SYSTEMMEM,&copy,NULL);
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
static float decode_half(uint16_t value) {
	int exponent=(value>>10)&31;
	int mantissa=value&1023;
	float result;
	if(!exponent) result=std::ldexp(float(mantissa),-24);
	else if(exponent==31) result=mantissa?std::numeric_limits<float>::quiet_NaN():std::numeric_limits<float>::infinity();
	else result=std::ldexp(float(1024+mantissa),exponent-25);
	return value&32768?-result:result;
}
int m2d9_read_float(M2D9 *c,M2D9Texture *t,float *pixels) {
    IDirect3DSurface9 *copy=(IDirect3DSurface9 *)m2d9_snapshot(c,t);
    if(!copy)return 0;
    bool half=t->format==D3DFMT_A16B16G16R16F;
    D3DLOCKED_RECT lock;HRESULT hr=copy->LockRect(&lock,NULL,D3DLOCK_READONLY);
    if(SUCCEEDED(hr)) {
        for(int y=0;y<t->height;++y)for(int x=0;x<t->width;++x) {
            const unsigned char *in=(const unsigned char *)lock.pBits+y*lock.Pitch+x*(half?8:16);
            float *out=pixels+(y*t->width+x)*4;
            if(half){uint16_t v[4];memcpy(v,in,8);for(int k=0;k<4;++k)out[k]=decode_half(v[k]);}
            else memcpy(out,in,16);
            for(int k=0;k<3;++k)out[k]=out[3]!=0?out[k]/out[3]:0;
        }
        hr=copy->UnlockRect();
    }
    copy->Release();return check(hr,"Float readback lock");
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
