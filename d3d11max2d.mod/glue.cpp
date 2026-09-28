#include <windows.h>
#include <d3d11.h>
#include <d3d10.h>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <algorithm>
#include <vector>
#include <cstdint>
#include <limits>
extern const unsigned char m2d11_vertex_shader[],m2d11_pixel_shader[];
extern const size_t m2d11_vertex_shader_size,m2d11_pixel_shader_size;
struct M2D11 {
 ID3D11Device *device;ID3D11DeviceContext *context;
 ID3D11VertexShader *vs;ID3D11PixelShader *ps;ID3D11InputLayout *layout;
 ID3D11Buffer *vertices,*settings;UINT capacity;
 ID3D11BlendState *blends[5];ID3D11SamplerState *samplers[2];
 ID3D11RasterizerState *raster;ID3D11DepthStencilState *depth;
 int mipmaps;
	int coverage;
 int width,height,ox,oy;float sx,sy;D3D11_RECT clip;
};
struct M2D11Texture {
	ID3D11Texture2D *texture;
	ID3D11ShaderResourceView *view;
	ID3D11RenderTargetView *target;
	int filtered,mipmapped,mipDirty,coverage;
};
static char errorText[192];
static int check(HRESULT hr,const char *operation){
 if(SUCCEEDED(hr))return 1;
 snprintf(errorText,sizeof(errorText),"%s failed (HRESULT 0x%08lx)",operation,(unsigned long)hr);return 0;
}
static int clamp(int x,int lo,int hi){return std::max(lo,std::min(hi,x));}
template<class T> static void release(T *&p){if(p){p->Release();p=nullptr;}}
extern "C" {
const char *m2d11_error(){return errorText;}
void m2d11_close(M2D11 *c){
 if(!c)return;
 c->context->ClearState();
 release(c->vs);release(c->ps);release(c->layout);release(c->vertices);release(c->settings);
 for(auto &s:c->blends)release(s);for(auto &s:c->samplers)release(s);
 release(c->raster);release(c->depth);delete c;
}
void *m2d11_open(ID3D11Device *device,ID3D11DeviceContext *context){
 M2D11 *c=new M2D11();c->device=device;c->context=context;
 UINT support=0;
 const UINT required=D3D11_FORMAT_SUPPORT_TEXTURE2D|D3D11_FORMAT_SUPPORT_SHADER_SAMPLE|D3D11_FORMAT_SUPPORT_RENDER_TARGET|D3D11_FORMAT_SUPPORT_MIP_AUTOGEN;
 c->mipmaps=SUCCEEDED(device->CheckFormatSupport(DXGI_FORMAT_R8G8B8A8_UNORM,&support))&&(support&required)==required;
	support=0;
	const UINT coverageRequired=D3D11_FORMAT_SUPPORT_TEXTURE2D|D3D11_FORMAT_SUPPORT_SHADER_SAMPLE;
	c->coverage=SUCCEEDED(device->CheckFormatSupport(DXGI_FORMAT_R8_UNORM,&support))&&(support&coverageRequired)==coverageRequired;
 HRESULT hr=device->CreateVertexShader(m2d11_vertex_shader,m2d11_vertex_shader_size,nullptr,&c->vs);
 if(SUCCEEDED(hr))hr=device->CreatePixelShader(m2d11_pixel_shader,m2d11_pixel_shader_size,nullptr,&c->ps);
 D3D11_INPUT_ELEMENT_DESC input[]={
  {"POSITION",0,DXGI_FORMAT_R32G32_FLOAT,0,0,D3D11_INPUT_PER_VERTEX_DATA,0},
  {"COLOR",0,DXGI_FORMAT_R32G32B32A32_FLOAT,0,8,D3D11_INPUT_PER_VERTEX_DATA,0},
  {"TEXCOORD",0,DXGI_FORMAT_R32G32_FLOAT,0,24,D3D11_INPUT_PER_VERTEX_DATA,0}};
 if(SUCCEEDED(hr))hr=device->CreateInputLayout(input,3,m2d11_vertex_shader,m2d11_vertex_shader_size,&c->layout);
 D3D11_BUFFER_DESC buffer={};buffer.ByteWidth=32;buffer.Usage=D3D11_USAGE_DYNAMIC;buffer.BindFlags=D3D11_BIND_CONSTANT_BUFFER;buffer.CPUAccessFlags=D3D11_CPU_ACCESS_WRITE;
 if(SUCCEEDED(hr))hr=device->CreateBuffer(&buffer,nullptr,&c->settings);
 D3D11_RASTERIZER_DESC raster={};raster.FillMode=D3D11_FILL_SOLID;raster.CullMode=D3D11_CULL_NONE;raster.DepthClipEnable=TRUE;raster.ScissorEnable=TRUE;
 if(SUCCEEDED(hr))hr=device->CreateRasterizerState(&raster,&c->raster);
 D3D11_DEPTH_STENCIL_DESC depth={};depth.DepthEnable=FALSE;depth.DepthWriteMask=D3D11_DEPTH_WRITE_MASK_ZERO;depth.DepthFunc=D3D11_COMPARISON_ALWAYS;
 if(SUCCEEDED(hr))hr=device->CreateDepthStencilState(&depth,&c->depth);
 for(int b=1;b<=5&&SUCCEEDED(hr);++b){
  D3D11_BLEND_DESC desc={};auto &r=desc.RenderTarget[0];r.RenderTargetWriteMask=D3D11_COLOR_WRITE_ENABLE_ALL;
  r.BlendEnable=b>=3;r.BlendOp=r.BlendOpAlpha=D3D11_BLEND_OP_ADD;
  r.SrcBlend=b==5?D3D11_BLEND_DEST_COLOR:D3D11_BLEND_SRC_ALPHA;
  r.DestBlend=b==5?D3D11_BLEND_ZERO:(b==4?D3D11_BLEND_ONE:D3D11_BLEND_INV_SRC_ALPHA);
  r.SrcBlendAlpha=b==3?D3D11_BLEND_ONE:D3D11_BLEND_ZERO;r.DestBlendAlpha=b==3?D3D11_BLEND_INV_SRC_ALPHA:D3D11_BLEND_ONE;
  hr=device->CreateBlendState(&desc,&c->blends[b-1]);
 }
 for(int i=0;i<2&&SUCCEEDED(hr);++i){
  D3D11_SAMPLER_DESC s={};s.Filter=i?D3D11_FILTER_MIN_MAG_MIP_LINEAR:D3D11_FILTER_MIN_MAG_MIP_POINT;
  s.AddressU=s.AddressV=s.AddressW=D3D11_TEXTURE_ADDRESS_CLAMP;s.MaxAnisotropy=1;s.ComparisonFunc=D3D11_COMPARISON_NEVER;s.MaxLOD=D3D11_FLOAT32_MAX;
  hr=device->CreateSamplerState(&s,&c->samplers[i]);
 }
 if(!check(hr,"Create D3D11 rendering pipeline")){m2d11_close(c);return nullptr;}
 return c;
}
void m2d11_texture_size(M2D11 *c,int *width,int *height) {
	// The graphics driver requires feature level 10.0 or later.
	*width=*height=c->device->GetFeatureLevel()>=D3D_FEATURE_LEVEL_11_0 ? D3D11_REQ_TEXTURE2D_U_OR_V_DIMENSION : D3D10_REQ_TEXTURE2D_U_OR_V_DIMENSION;
}
int m2d11_render_image(M2D11 *c,int width,int height) {
	UINT support=0;
	const UINT required=D3D11_FORMAT_SUPPORT_TEXTURE2D|D3D11_FORMAT_SUPPORT_SHADER_SAMPLE|D3D11_FORMAT_SUPPORT_RENDER_TARGET|D3D11_FORMAT_SUPPORT_BLENDABLE;
	return SUCCEEDED(c->device->CheckFormatSupport(DXGI_FORMAT_R8G8B8A8_UNORM,&support))&&(support&required)==required;
}
int m2d11_float_target_supported(M2D11 *c,int bits) {
	if(bits!=16 && bits!=32) return 0;
	UINT support=0;
	const UINT required=D3D11_FORMAT_SUPPORT_TEXTURE2D|D3D11_FORMAT_SUPPORT_SHADER_SAMPLE|D3D11_FORMAT_SUPPORT_RENDER_TARGET|D3D11_FORMAT_SUPPORT_BLENDABLE;
	DXGI_FORMAT format=bits==16?DXGI_FORMAT_R16G16B16A16_FLOAT:DXGI_FORMAT_R32G32B32A32_FLOAT;
	return SUCCEEDED(c->device->CheckFormatSupport(format,&support))&&(support&required)==required;
}
int m2d11_compressed_supported(M2D11 *c,int compression) {
	if(compression!=1 && compression!=3) return 0;
	DXGI_FORMAT format=compression==1?DXGI_FORMAT_BC1_UNORM:DXGI_FORMAT_BC3_UNORM;
	UINT support=0;
	const UINT required=D3D11_FORMAT_SUPPORT_TEXTURE2D|D3D11_FORMAT_SUPPORT_SHADER_SAMPLE|D3D11_FORMAT_SUPPORT_MIP;
	return SUCCEEDED(c->device->CheckFormatSupport(format,&support))&&(support&required)==required;
}
int m2d11_float_supported(M2D11 *c,int bits) {
	if(bits!=16 && bits!=32) return 0;
	UINT support=0;
	const UINT required=D3D11_FORMAT_SUPPORT_TEXTURE2D|D3D11_FORMAT_SUPPORT_SHADER_SAMPLE;
	DXGI_FORMAT format=bits==16?DXGI_FORMAT_R16G16B16A16_FLOAT:DXGI_FORMAT_R32G32B32A32_FLOAT;
	return SUCCEEDED(c->device->CheckFormatSupport(format,&support))&&(support&required)==required;
}
int m2d11_supplied_supported(M2D11 *c,int coverage,int bits) {
	DXGI_FORMAT format=bits==16?DXGI_FORMAT_R16G16B16A16_FLOAT:bits==32?DXGI_FORMAT_R32G32B32A32_FLOAT:coverage?DXGI_FORMAT_R8_UNORM:DXGI_FORMAT_R8G8B8A8_UNORM;
	UINT support=0;
	const UINT required=D3D11_FORMAT_SUPPORT_TEXTURE2D|D3D11_FORMAT_SUPPORT_SHADER_SAMPLE|D3D11_FORMAT_SUPPORT_MIP;
	return SUCCEEDED(c->device->CheckFormatSupport(format,&support))&&(support&required)==required;
}
int m2d11_coverage_supported(M2D11 *c) {
	return c->coverage;
}
int m2d11_coverage(M2D11Texture *t) {
	return t->coverage;
}
int m2d11_mipmaps(M2D11 *c){return c->mipmaps;}
void m2d11_dirty(M2D11Texture *t){if(t&&t->mipmapped)t->mipDirty=1;}
ID3D11RenderTargetView *m2d11_target(M2D11Texture *t){return t->target;}
void m2d11_destroy(M2D11Texture *t){if(t){release(t->target);release(t->view);release(t->texture);delete t;}}
void *m2d11_create(M2D11 *c,int w,int h,int flags,int target,int coverage,int floatBits,int levels,int compression){
	if(compression && (target || !levels || (w%4) || (h%4) || !m2d11_compressed_supported(c,compression))) {
		check(E_NOTIMPL,"Compressed texture request unsupported");
		return nullptr;
	}
	if(floatBits && ((target && !m2d11_float_target_supported(c,floatBits)) || ((flags&4) && !levels) || !m2d11_float_supported(c,floatBits))) {
		check(E_NOTIMPL,"Floating-point texture request unsupported");
		return nullptr;
	}
	M2D11Texture *t=new M2D11Texture();
	t->filtered=(flags&2)!=0;
	// Only automatically generated chains use premultiplied storage.
	t->mipmapped=(flags&4)!=0 && !levels;
	t->mipDirty=t->mipmapped;
	t->coverage=coverage&&c->coverage&&!target&&!t->mipmapped&&!floatBits;
 if(t->mipmapped&&!c->mipmaps){delete t;check(E_NOTIMPL,"Automatic RGBA mipmaps unsupported");return nullptr;}
	D3D11_TEXTURE2D_DESC d={};
	d.Width=w;
	d.Height=h;
	d.ArraySize=1;
	d.MipLevels=levels?levels:t->mipmapped?0:1;
	d.Format=compression==1?DXGI_FORMAT_BC1_UNORM:compression==3?DXGI_FORMAT_BC3_UNORM:floatBits==16?DXGI_FORMAT_R16G16B16A16_FLOAT:floatBits==32?DXGI_FORMAT_R32G32B32A32_FLOAT:t->coverage?DXGI_FORMAT_R8_UNORM:DXGI_FORMAT_R8G8B8A8_UNORM;
	d.SampleDesc.Count=1;
 d.Usage=D3D11_USAGE_DEFAULT;d.BindFlags=D3D11_BIND_SHADER_RESOURCE|((target||t->mipmapped)?D3D11_BIND_RENDER_TARGET:0);
 d.MiscFlags=t->mipmapped?D3D11_RESOURCE_MISC_GENERATE_MIPS:0;
 HRESULT hr=c->device->CreateTexture2D(&d,nullptr,&t->texture);
 if(SUCCEEDED(hr))hr=c->device->CreateShaderResourceView(t->texture,nullptr,&t->view);
 if(SUCCEEDED(hr)&&target)hr=c->device->CreateRenderTargetView(t->texture,nullptr,&t->target);
 if(SUCCEEDED(hr)&&target){float zero[4]={};c->context->ClearRenderTargetView(t->target,zero);}
 if(!check(hr,"Create image texture")){m2d11_destroy(t);return nullptr;}return t;
}
int m2d11_update_level(M2D11 *c,M2D11Texture *t,int level,const unsigned char *pixels,int pitch) {
	ID3D11ShaderResourceView *empty=nullptr;
	c->context->PSSetShaderResources(0,1,&empty);
	c->context->UpdateSubresource(t->texture,level,nullptr,pixels,pitch,0);
	return check(c->device->GetDeviceRemovedReason(),"Upload supplied mip level");
}
/* pixels starts at the upload region; x/y locate it in the destination. */
int m2d11_update(M2D11 *c,M2D11Texture *t,const unsigned char *pixels,int pitch,int x,int y,int w,int h){
 ID3D11ShaderResourceView *empty=nullptr;c->context->PSSetShaderResources(0,1,&empty);
 D3D11_BOX box={(UINT)x,(UINT)y,0,(UINT)(x+w),(UINT)(y+h),1};
 // Filter premultiplied pixels so transparent RGB cannot bleed into lower levels.
 // Keep the caller's CPU pixmap straight-alpha, and convert only the dirty region.
 const unsigned char *source=pixels;
 std::vector<unsigned char> converted;
 if(t->mipmapped){
  converted.resize(size_t(w)*h*4);
  for(int row=0;row<h;++row)for(int col=0;col<w;++col){
   const auto in=source+row*pitch+col*4;auto out=converted.data()+(size_t(row)*w+col)*4;
   for(int k=0;k<3;++k)out[k]=(in[k]*in[3]+127)/255;out[3]=in[3];
  }
  source=converted.data();pitch=w*4;
 }
 c->context->UpdateSubresource(t->texture,0,&box,source,pitch,0);
 m2d11_dirty(t);
 return check(c->device->GetDeviceRemovedReason(),"Upload image");
}
int m2d11_view(M2D11 *c,int width,int height,int ox,int oy,int vw,int vh,float sx,float sy,int x,int y,int w,int h){
 c->width=width;c->height=height;c->ox=ox;c->oy=oy;c->sx=sx;c->sy=sy;
 c->clip.left=clamp(ox+(int)floor(x*sx),ox,ox+vw);c->clip.top=clamp(oy+(int)floor(y*sy),oy,oy+vh);
 c->clip.right=w?clamp(ox+(int)ceil((x+w)*sx),ox,ox+vw):c->clip.left;
 c->clip.bottom=h?clamp(oy+(int)ceil((y+h)*sy),oy,oy+vh):c->clip.top;return 1;
}
static int draw(M2D11 *c,ID3D11RenderTargetView *target,M2D11Texture *t,int blend,const float *v,int count,bool pixels,bool outputPremult){
 if(count<=0||c->clip.right<=c->clip.left||c->clip.bottom<=c->clip.top)return 1;
 if(c->width<=0||c->height<=0||blend<1||blend>5||count>0x7fffffff/32)return check(E_INVALIDARG,"Draw arguments");
 UINT bytes=count*32;
 if(bytes>c->capacity){
  D3D11_BUFFER_DESC d={};d.ByteWidth=std::max(bytes,UINT(65536));d.Usage=D3D11_USAGE_DYNAMIC;d.BindFlags=D3D11_BIND_VERTEX_BUFFER;d.CPUAccessFlags=D3D11_CPU_ACCESS_WRITE;
  ID3D11Buffer *next=nullptr;if(!check(c->device->CreateBuffer(&d,nullptr,&next),"Create vertex buffer"))return 0;
  release(c->vertices);c->vertices=next;c->capacity=d.ByteWidth;
 }
 auto ctx=c->context;D3D11_MAPPED_SUBRESOURCE mapped;
 if(!check(ctx->Map(c->vertices,0,D3D11_MAP_WRITE_DISCARD,0,&mapped),"Map vertices"))return 0;
 memcpy(mapped.pData,v,bytes);ctx->Unmap(c->vertices,0);
	float settings[]={
		2*(pixels?1:c->sx)/c->width,-2*(pixels?1:c->sy)/c->height,
		pixels?-1.f:2.f*c->ox/c->width-1,pixels?1.f:1-2.f*c->oy/c->height,
		t?(t->coverage?2.f:1.f):0.f,blend==1?1.f:0.f,
		t&&(t->target||t->mipmapped)?1.f:0.f,outputPremult&&blend<=2?1.f:0.f
	};
 if(!check(ctx->Map(c->settings,0,D3D11_MAP_WRITE_DISCARD,0,&mapped),"Map settings"))return 0;
 memcpy(mapped.pData,settings,sizeof(settings));ctx->Unmap(c->settings,0);
 UINT stride=32,offset=0;ctx->IASetVertexBuffers(0,1,&c->vertices,&stride,&offset);ctx->IASetInputLayout(c->layout);ctx->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_TRIANGLELIST);
 ctx->VSSetShader(c->vs,nullptr,0);ctx->PSSetShader(c->ps,nullptr,0);ctx->GSSetShader(nullptr,nullptr,0);ctx->HSSetShader(nullptr,nullptr,0);ctx->DSSetShader(nullptr,nullptr,0);
 ctx->VSSetConstantBuffers(0,1,&c->settings);ctx->PSSetConstantBuffers(0,1,&c->settings);
 // Unbind the previous source before making it a destination, and bind the
 // new destination before sampling a texture that was previously a target.
 ID3D11ShaderResourceView *empty=nullptr;ctx->PSSetShaderResources(0,1,&empty);
 ctx->OMSetRenderTargets(1,&target,nullptr);
 int generated=0;
 if(t&&t->mipmapped&&t->mipDirty){
  ctx->GenerateMips(t->view);t->mipDirty=0;generated=1;
 }
 ID3D11ShaderResourceView *image=t?t->view:nullptr;ctx->PSSetShaderResources(0,1,&image);ctx->PSSetSamplers(0,1,&c->samplers[t?t->filtered:0]);
 ctx->OMSetBlendState(c->blends[blend-1],nullptr,0xffffffff);ctx->OMSetDepthStencilState(c->depth,0);
 D3D11_VIEWPORT viewport={0,0,(float)c->width,(float)c->height,0,1};ctx->RSSetViewports(1,&viewport);ctx->RSSetState(c->raster);ctx->RSSetScissorRects(1,&c->clip);
 ctx->Draw(count,0);return check(c->device->GetDeviceRemovedReason(),"Draw triangles")?1+generated:0;
}
int m2d11_submit(M2D11 *c,ID3D11RenderTargetView *target,M2D11Texture *t,int blend,const float *v,int count,int premult){return draw(c,target,t,blend,v,count,false,premult!=0);}
int m2d11_clear(M2D11 *c,ID3D11RenderTargetView *target,int bars,int r,int g,int b,float a,int br,int bg,int bb,int premult){
 float rgba[]={r/255.f,g/255.f,b/255.f,a};
 if(premult)for(int i=0;i<3;++i)rgba[i]*=a;
 if(bars){float bar[]={br/255.f,bg/255.f,bb/255.f,1};c->context->ClearRenderTargetView(target,bar);}
 if(c->clip.right<=c->clip.left||c->clip.bottom<=c->clip.top)return 1;
 if(c->clip.left==0&&c->clip.top==0&&c->clip.right==c->width&&c->clip.bottom==c->height){c->context->ClearRenderTargetView(target,rgba);return check(c->device->GetDeviceRemovedReason(),"Clear");}
 float w=(float)c->width,h=(float)c->height,R=rgba[0],G=rgba[1],B=rgba[2];
 float v[]={0,0,R,G,B,a,0,0,w,0,R,G,B,a,0,0,w,h,R,G,B,a,0,0,0,0,R,G,B,a,0,0,w,h,R,G,B,a,0,0,0,h,R,G,B,a,0,0};
 return draw(c,target,nullptr,2,v,6,true,false);
}
int m2d11_read(M2D11 *c,ID3D11RenderTargetView *target,int x,int y,int w,int h,unsigned char *pixels,int pitch,int premult){
 ID3D11Resource *resource=nullptr;target->GetResource(&resource);ID3D11Texture2D *back=nullptr;
 HRESULT hr=resource->QueryInterface(__uuidof(ID3D11Texture2D),(void **)&back);release(resource);
 if(!check(hr,"Readback resource"))return 0;
 D3D11_TEXTURE2D_DESC d;back->GetDesc(&d);
 if(x<0||y<0||w<=0||h<=0||x>(int)d.Width-w||y>(int)d.Height-h){release(back);return check(E_INVALIDARG,"Readback bounds");}
 d.Width=w;d.Height=h;d.MipLevels=1;d.ArraySize=1;d.Usage=D3D11_USAGE_STAGING;d.CPUAccessFlags=D3D11_CPU_ACCESS_READ;d.BindFlags=0;d.MiscFlags=0;
 ID3D11Texture2D *copy=nullptr;hr=c->device->CreateTexture2D(&d,nullptr,&copy);
 if(FAILED(hr)){release(back);return check(hr,"Readback staging texture");}
 D3D11_BOX box={(UINT)x,(UINT)y,0,(UINT)(x+w),(UINT)(y+h),1};c->context->CopySubresourceRegion(copy,0,0,0,0,back,0,&box);release(back);
 D3D11_MAPPED_SUBRESOURCE map;hr=c->context->Map(copy,0,D3D11_MAP_READ,0,&map);
 if(SUCCEEDED(hr)){
  for(int row=0;row<h;++row){auto out=pixels+row*pitch;memcpy(out,(unsigned char *)map.pData+row*map.RowPitch,w*4);for(int col=0;col<w;++col){auto px=out+col*4;if(premult){for(int k=0;k<3;++k)px[k]=px[3]?std::min(255,(px[k]*255+px[3]/2)/px[3]):0;}else px[3]=255;}}
  c->context->Unmap(copy,0);
 }
 release(copy);return check(hr,"Map readback");
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
int m2d11_read_float(M2D11 *c,M2D11Texture *t,float *pixels) {
	D3D11_TEXTURE2D_DESC d;
	t->texture->GetDesc(&d);
	bool half=d.Format==DXGI_FORMAT_R16G16B16A16_FLOAT;
	if(!half && d.Format!=DXGI_FORMAT_R32G32B32A32_FLOAT) return check(E_INVALIDARG,"Float readback format");
	d.MipLevels=1;
	d.Usage=D3D11_USAGE_STAGING;
	d.CPUAccessFlags=D3D11_CPU_ACCESS_READ;
	d.BindFlags=0;
	d.MiscFlags=0;
	ID3D11Texture2D *copy=nullptr;
	HRESULT hr=c->device->CreateTexture2D(&d,nullptr,&copy);
	if(FAILED(hr)) return check(hr,"Float readback staging texture");
	c->context->CopySubresourceRegion(copy,0,0,0,0,t->texture,0,nullptr);
	D3D11_MAPPED_SUBRESOURCE mapped;
	hr=c->context->Map(copy,0,D3D11_MAP_READ,0,&mapped);
	if(SUCCEEDED(hr)) {
		for(UINT y=0;y<d.Height;++y) {
			const unsigned char *row=(const unsigned char *)mapped.pData+(size_t)y*mapped.RowPitch;
			float *output=pixels+(size_t)y*d.Width*4;
			for(UINT x=0;x<d.Width;++x) {
				float *p=output+x*4;
				if(half) {
					uint16_t channels[4];
					memcpy(channels,row+x*8,8);
					for(int k=0;k<4;++k) p[k]=decode_half(channels[k]);
				} else memcpy(p,row+x*16,16);
				for(int k=0;k<3;++k) p[k]=p[3]!=0?p[k]/p[3]:0;
			}
		}
		c->context->Unmap(copy,0);
	}
	release(copy);
	return check(hr,"Float readback mapping") && check(c->device->GetDeviceRemovedReason(),"Float readback");
}

}
