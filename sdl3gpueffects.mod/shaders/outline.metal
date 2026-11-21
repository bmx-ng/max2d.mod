#include <metal_stdlib>
using namespace metal;
struct Output { float4 position [[position]]; float4 colour; float2 uv; };
float sampleAlpha(texture2d<float> image, sampler sampleState, float2 uv, float4 mode) {
	if(any(uv<float2(0)) || any(uv>float2(1))) return 0;
	float4 c=image.sample(sampleState,uv,level(0));
	return mode.x!=0?c.r:c.a;
}
fragment float4 outlineMain(Output input [[stage_in]], texture2d<float> image [[texture(0)]], sampler sampleState [[sampler(0)]], constant float4 &mode [[buffer(0)]], constant float4 &parameters [[buffer(1)]]) {
	float centre=sampleAlpha(image,sampleState,input.uv,mode);
	float expanded=centre;
	for(int y=-4;y<=4;++y) for(int x=-4;x<=4;++x) {
		int distance=x*x+y*y;
		if(distance>0 && float(distance)<=parameters.z*parameters.z)
			expanded=max(expanded,sampleAlpha(image,sampleState,input.uv+float2(x,y)*parameters.xy,mode));
	}
	float4 c=float4(input.colour.rgb,max(expanded-centre,0.0f)*input.colour.a);
	if(mode.z!=0 && c.a<0.5) discard_fragment();
	if(mode.w!=0) c.rgb*=c.a;
	return c;
}
