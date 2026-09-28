#include <windows.h>
#include <ddraw.h>
#include <d3d.h>
#include <vector>
#include <cmath>
#include <cstdio>
#include <algorithm>
#include <cstring>

struct M2D7 {
 IDirectDraw7 *dd;
 IDirect3DDevice7 *device;
 IDirectDrawSurface7 *back;
 D3DDEVICEDESC7 caps;
 float sx,sy;
 int ox,oy,width,height;
 RECT clip;
};
struct M2D7Texture {IDirectDrawSurface7 *surface;int width,height,aw,ah,filtered;};
struct M2D7Vertex {float x,y,z,rhw;DWORD color;float u,v;};
struct ClipVertex {float v[8];};
static char errorText[192];
static int fail(const char *message){snprintf(errorText,sizeof(errorText),"%s",message);return 0;}
static int check(HRESULT hr,const char *operation){
 if(SUCCEEDED(hr))return 1;
 snprintf(errorText,sizeof(errorText),"%s failed (HRESULT 0x%08lx)",operation,(unsigned long)hr);return 0;
}
static int clamp(int x,int lo,int hi){return std::max(lo,std::min(hi,x));}
static int channel(float v){return clamp((int)std::lround(v*255),0,255);}
static DWORD color(int a,int r,int g,int b){return (DWORD(a)<<24)|(DWORD(r)<<16)|(DWORD(g)<<8)|DWORD(b);}
// D3D7 has no scissor state. Clip triangles before the half-pixel adjustment,
// interpolating both texture coordinates and tint at each generated vertex.
static void clipEdge(std::vector<ClipVertex> &poly,int axis,float edge,bool greater){
 if(poly.empty())return;
 std::vector<ClipVertex> out;
 ClipVertex a=poly.back();bool ain=greater?a.v[axis]>=edge:a.v[axis]<=edge;
 for(const ClipVertex &b:poly){
  bool bin=greater?b.v[axis]>=edge:b.v[axis]<=edge;
  if(ain!=bin){float t=(edge-a.v[axis])/(b.v[axis]-a.v[axis]);ClipVertex q;
   for(int k=0;k<8;++k)q.v[k]=a.v[k]+t*(b.v[k]-a.v[k]);out.push_back(q);}
  if(bin)out.push_back(b);a=b;ain=bin;
 }
 poly.swap(out);
}
static HRESULT CALLBACK findARGB(DDPIXELFORMAT *p,void *context){
 if((p->dwFlags&(DDPF_RGB|DDPF_ALPHAPIXELS))==(DDPF_RGB|DDPF_ALPHAPIXELS)&&
    p->dwRGBBitCount==32&&p->dwRBitMask==0xff0000&&p->dwGBitMask==0xff00&&
    p->dwBBitMask==0xff&&p->dwRGBAlphaBitMask==0xff000000)*(bool *)context=true;
 return D3DENUMRET_OK;
}
extern "C" {
const char *m2d7_error(){return errorText;}
void *m2d7_open(IDirectDraw7 *dd,IDirect3DDevice7 *device,IDirectDrawSurface7 *back){
 M2D7 *c=new M2D7();c->dd=dd;c->device=device;c->back=back;
 if(!check(device->GetCaps(&c->caps),"GetCaps")){delete c;return NULL;}
 bool argb=false;
 if(!check(device->EnumTextureFormats(findARGB,&argb),"EnumTextureFormats")){delete c;return NULL;}
 if(!argb){delete c;fail("32-bit ARGB textures are required");return NULL;}
 DWORD ops=D3DTEXOPCAPS_MODULATE|D3DTEXOPCAPS_SELECTARG2;
 if((c->caps.dwTextureOpCaps&ops)!=ops){delete c;fail("Texture modulation is required");return NULL;}
 return c;
}
void m2d7_close(M2D7 *c){if(c){c->device->SetTexture(0,NULL);delete c;}}
int m2d7_blend(M2D7 *c,int blend){
 const D3DPRIMCAPS &p=c->caps.dpcTriCaps;
 if(blend==1)return (p.dwAlphaCmpCaps&D3DPCMPCAPS_GREATEREQUAL)!=0;
 if(blend==2)return 1;
 if(blend==3)return (p.dwSrcBlendCaps&D3DPBLENDCAPS_SRCALPHA)&&(p.dwDestBlendCaps&D3DPBLENDCAPS_INVSRCALPHA);
 if(blend==4)return (p.dwSrcBlendCaps&D3DPBLENDCAPS_SRCALPHA)&&(p.dwDestBlendCaps&D3DPBLENDCAPS_ONE);
 if(blend==5)return (p.dwSrcBlendCaps&D3DPBLENDCAPS_DESTCOLOR)&&(p.dwDestBlendCaps&D3DPBLENDCAPS_ZERO);
 return 0;
}
int m2d7_filtered(M2D7 *c){
 DWORD bits=D3DPTFILTERCAPS_MINFLINEAR|D3DPTFILTERCAPS_MAGFLINEAR;
 return (c->caps.dpcTriCaps.dwTextureFilterCaps&bits)==bits;
}
void *m2d7_create(M2D7 *c,int w,int h,int flags){
 M2D7Texture *t=new M2D7Texture();t->width=w;t->height=h;t->aw=std::max(w,(int)c->caps.dwMinTextureWidth);t->ah=std::max(h,(int)c->caps.dwMinTextureHeight);t->filtered=(flags&2)!=0;
 if(w<=0||h<=0||t->aw>(int)c->caps.dwMaxTextureWidth||t->ah>(int)c->caps.dwMaxTextureHeight){delete t;fail("Invalid image size or device texture limit exceeded");return NULL;}
 if(c->caps.dpcTriCaps.dwTextureCaps&D3DPTEXTURECAPS_POW2){
  int aw=t->aw,ah=t->ah;t->aw=1;while(t->aw<aw)t->aw*=2;t->ah=1;while(t->ah<ah)t->ah*=2;
 }
 if(c->caps.dwMaxTextureAspectRatio){
  while((double)t->aw>double(c->caps.dwMaxTextureAspectRatio)*t->ah)t->ah*=2;
  while((double)t->ah>double(c->caps.dwMaxTextureAspectRatio)*t->aw)t->aw*=2;
 }
 if(c->caps.dpcTriCaps.dwTextureCaps&D3DPTEXTURECAPS_SQUAREONLY)t->aw=t->ah=std::max(t->aw,t->ah);
 if(t->aw>(int)c->caps.dwMaxTextureWidth||t->ah>(int)c->caps.dwMaxTextureHeight){delete t;fail("Image exceeds device texture limits");return NULL;}
 DDSURFACEDESC2 d={};d.dwSize=sizeof(d);d.dwFlags=DDSD_CAPS|DDSD_WIDTH|DDSD_HEIGHT|DDSD_PIXELFORMAT;
 d.dwWidth=t->aw;d.dwHeight=t->ah;d.ddsCaps.dwCaps=DDSCAPS_TEXTURE;d.ddsCaps.dwCaps2=DDSCAPS2_TEXTUREMANAGE;
 d.ddpfPixelFormat.dwSize=sizeof(DDPIXELFORMAT);d.ddpfPixelFormat.dwFlags=DDPF_RGB|DDPF_ALPHAPIXELS;
 d.ddpfPixelFormat.dwRGBBitCount=32;d.ddpfPixelFormat.dwRBitMask=0xff0000;d.ddpfPixelFormat.dwGBitMask=0xff00;
 d.ddpfPixelFormat.dwBBitMask=0xff;d.ddpfPixelFormat.dwRGBAlphaBitMask=0xff000000;
 if(!check(c->dd->CreateSurface(&d,&t->surface,NULL),"Create ARGB texture")){delete t;return NULL;}
 return t;
}
void m2d7_destroy(M2D7Texture *t){if(t){t->surface->Release();delete t;}}
/* pixels starts at the upload region; x/y locate it in the destination. */
int m2d7_update(M2D7Texture *t,const unsigned char *pixels,int pitch,int x,int y,int w,int h){
 DDSURFACEDESC2 d={};d.dwSize=sizeof(d);
 if(!check(t->surface->Lock(NULL,&d,DDLOCK_WAIT|DDLOCK_WRITEONLY,NULL),"Lock texture"))return 0;
 for(int row=y;row<y+h;++row){
  DWORD *out=(DWORD *)((unsigned char *)d.lpSurface+row*d.lPitch);
  const unsigned char *in=pixels+(row-y)*pitch;
  for(int col=x;col<x+w;++col,in+=4)out[col]=color(in[3],in[0],in[1],in[2]);
  if(x+w==t->width)for(int col=t->width;col<t->aw;++col)out[col]=out[t->width-1];
 }
 if(y+h==t->height)for(int row=t->height;row<t->ah;++row){
  DWORD *out=(DWORD *)((unsigned char *)d.lpSurface+row*d.lPitch);
  DWORD *last=(DWORD *)((unsigned char *)d.lpSurface+(t->height-1)*d.lPitch);
  for(int col=x;col<(x+w==t->width?t->aw:x+w);++col)out[col]=last[col];
 }
 return check(t->surface->Unlock(NULL),"Unlock texture");
}
int m2d7_view(M2D7 *c,int width,int height,int ox,int oy,int vw,int vh,float sx,float sy,int x,int y,int w,int h){
 c->width=width;c->height=height;c->ox=ox;c->oy=oy;c->sx=sx;c->sy=sy;
 c->clip.left=clamp(ox+(int)floor(x*sx),ox,ox+vw);c->clip.top=clamp(oy+(int)floor(y*sy),oy,oy+vh);
 c->clip.right=w?clamp(ox+(int)ceil((x+w)*sx),ox,ox+vw):c->clip.left;
 c->clip.bottom=h?clamp(oy+(int)ceil((y+h)*sy),oy,oy+vh):c->clip.top;
 return 1;
}
int m2d7_submit(M2D7 *c,M2D7Texture *t,int blend,const float *v,int count){
 if(c->clip.right<=c->clip.left||c->clip.bottom<=c->clip.top)return 1;
 std::vector<M2D7Vertex> vertices;
 for(int i=0;i+2<count;i+=3){
  std::vector<ClipVertex> poly(3);
  for(int n=0;n<3;++n){memcpy(poly[n].v,v+(i+n)*8,8*sizeof(float));poly[n].v[0]=c->ox+poly[n].v[0]*c->sx;poly[n].v[1]=c->oy+poly[n].v[1]*c->sy;}
  clipEdge(poly,0,c->clip.left,true);clipEdge(poly,0,c->clip.right,false);
  clipEdge(poly,1,c->clip.top,true);clipEdge(poly,1,c->clip.bottom,false);
  for(size_t n=1;n+1<poly.size();++n){size_t indices[]={0,n,n+1};
   for(size_t index:indices){const float *p=poly[index].v;M2D7Vertex o={p[0]-.5f,p[1]-.5f,0,1,color(channel(p[5]),channel(p[2]),channel(p[3]),channel(p[4])),t?p[6]*t->width/t->aw:0,t?p[7]*t->height/t->ah:0};vertices.push_back(o);}
  }
 }
 if(vertices.empty())return 1;
 IDirect3DDevice7 *d=c->device;
#define TRY(call) if(!check((call),#call))return 0
 D3DVIEWPORT7 viewport={0,0,(DWORD)c->width,(DWORD)c->height,0,1};
 TRY(d->SetViewport(&viewport));
 TRY(d->SetRenderState(D3DRENDERSTATE_ZENABLE,FALSE));TRY(d->SetRenderState(D3DRENDERSTATE_ZWRITEENABLE,FALSE));
 TRY(d->SetRenderState(D3DRENDERSTATE_CULLMODE,D3DCULL_NONE));TRY(d->SetRenderState(D3DRENDERSTATE_LIGHTING,FALSE));
 TRY(d->SetRenderState(D3DRENDERSTATE_SHADEMODE,D3DSHADE_GOURAUD));
 TRY(d->SetRenderState(D3DRENDERSTATE_FOGENABLE,FALSE));TRY(d->SetRenderState(D3DRENDERSTATE_SPECULARENABLE,FALSE));
 TRY(d->SetRenderState(D3DRENDERSTATE_ALPHATESTENABLE,blend==1));
 if(blend==1){TRY(d->SetRenderState(D3DRENDERSTATE_ALPHAREF,128));TRY(d->SetRenderState(D3DRENDERSTATE_ALPHAFUNC,D3DCMP_GREATEREQUAL));}
 TRY(d->SetRenderState(D3DRENDERSTATE_ALPHABLENDENABLE,blend>=3));
 if(blend>=3){TRY(d->SetRenderState(D3DRENDERSTATE_SRCBLEND,blend==5?D3DBLEND_DESTCOLOR:D3DBLEND_SRCALPHA));
 TRY(d->SetRenderState(D3DRENDERSTATE_DESTBLEND,blend==5?D3DBLEND_ZERO:(blend==4?D3DBLEND_ONE:D3DBLEND_INVSRCALPHA)));}
 TRY(d->SetTexture(0,t?t->surface:NULL));
 TRY(d->SetTextureStageState(0,D3DTSS_COLOROP,t?D3DTOP_MODULATE:D3DTOP_SELECTARG2));
 TRY(d->SetTextureStageState(0,D3DTSS_ALPHAOP,t?D3DTOP_MODULATE:D3DTOP_SELECTARG2));
 TRY(d->SetTextureStageState(0,D3DTSS_COLORARG1,D3DTA_TEXTURE));TRY(d->SetTextureStageState(0,D3DTSS_COLORARG2,D3DTA_DIFFUSE));
 TRY(d->SetTextureStageState(0,D3DTSS_ALPHAARG1,D3DTA_TEXTURE));TRY(d->SetTextureStageState(0,D3DTSS_ALPHAARG2,D3DTA_DIFFUSE));
 TRY(d->SetTextureStageState(1,D3DTSS_COLOROP,D3DTOP_DISABLE));
 TRY(d->SetTextureStageState(0,D3DTSS_MINFILTER,t&&t->filtered?D3DTFN_LINEAR:D3DTFN_POINT));
 TRY(d->SetTextureStageState(0,D3DTSS_MAGFILTER,t&&t->filtered?D3DTFG_LINEAR:D3DTFG_POINT));
 TRY(d->SetTextureStageState(0,D3DTSS_MIPFILTER,D3DTFP_NONE));
 TRY(d->SetTextureStageState(0,D3DTSS_ADDRESSU,D3DTADDRESS_CLAMP));TRY(d->SetTextureStageState(0,D3DTSS_ADDRESSV,D3DTADDRESS_CLAMP));
 TRY(d->BeginScene());
 // Keep batches within the legacy DrawPrimitive vertex limit.
 HRESULT hr=S_OK;
 for(size_t first=0;first<vertices.size()&&SUCCEEDED(hr);first+=65532){DWORD n=(DWORD)std::min(size_t(65532),vertices.size()-first);
  hr=d->DrawPrimitive(D3DPT_TRIANGLELIST,D3DFVF_XYZRHW|D3DFVF_DIFFUSE|D3DFVF_TEX1,&vertices[first],n,0);}
 HRESULT end=d->EndScene();return check(hr,"DrawPrimitive")&&check(end,"EndScene");
#undef TRY
}
int m2d7_clear(M2D7 *c,int bars,int r,int g,int b,float a,int br,int bg,int bb){
 D3DVIEWPORT7 viewport={0,0,(DWORD)c->width,(DWORD)c->height,0,1};
 if(!check(c->device->SetViewport(&viewport),"Clear viewport"))return 0;
 if(bars&&!check(c->device->Clear(0,NULL,D3DCLEAR_TARGET,color(255,br,bg,bb),1,0),"Clear bars"))return 0;
 if(c->clip.right<=c->clip.left||c->clip.bottom<=c->clip.top)return 1;
 D3DRECT rect={c->clip.left,c->clip.top,c->clip.right,c->clip.bottom};
 return check(c->device->Clear(1,&rect,D3DCLEAR_TARGET,color(channel(a),r,g,b),1,0),"Clear clip");
}
static unsigned char unpack(DWORD value,DWORD mask){
 if(!mask)return 0;
 while(!(mask&1)){mask>>=1;value>>=1;}
 return (unsigned char)(((value&mask)*255+mask/2)/mask);
}
int m2d7_read(M2D7 *c,int x,int y,int w,int h,unsigned char *pixels,int pitch){
 if(x<0||y<0||w>c->width-x||h>c->height-y)return fail("Readback outside backbuffer");
 DDSURFACEDESC2 d={};d.dwSize=sizeof(d);
 if(!check(c->back->Lock(NULL,&d,DDLOCK_READONLY|DDLOCK_WAIT,NULL),"Lock backbuffer"))return 0;
 int bytes=d.ddpfPixelFormat.dwRGBBitCount/8;
 if(!(d.ddpfPixelFormat.dwFlags&DDPF_RGB)||bytes<2||bytes>4){c->back->Unlock(NULL);return fail("Unsupported readback format");}
 for(int row=0;row<h;++row){const unsigned char *in=(unsigned char *)d.lpSurface+(y+row)*d.lPitch+x*bytes;unsigned char *out=pixels+row*pitch;
  for(int col=0;col<w;++col,in+=bytes,out+=4){DWORD p=0;memcpy(&p,in,bytes);out[0]=unpack(p,d.ddpfPixelFormat.dwRBitMask);out[1]=unpack(p,d.ddpfPixelFormat.dwGBitMask);out[2]=unpack(p,d.ddpfPixelFormat.dwBBitMask);out[3]=255;}}
 return check(c->back->Unlock(NULL),"Unlock backbuffer");
}
}
