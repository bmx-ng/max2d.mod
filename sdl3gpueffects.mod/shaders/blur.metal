#include <metal_stdlib>
using namespace metal;
struct Output { float4 position [[position]]; float4 colour; float2 uv; };
float4 samplePremultiplied(texture2d<float> image, sampler sampleState, float2 uv, float4 mode) {
	float4 c=image.sample(sampleState,uv,level(0));
	if(any(uv<float2(0)) || any(uv>float2(1))) c=float4(0);
	if(mode.x!=0) c=float4(1,1,1,c.r);
	if(mode.y==0) c.rgb*=c.a;
	return c;
}
fragment float4 blurMain(Output input [[stage_in]], texture2d<float> image [[texture(0)]], sampler sampleState [[sampler(0)]], constant float4 &mode [[buffer(0)]], constant float4 &parameters [[buffer(1)]]) {
	const float weights[9]={1,8,28,56,70,56,28,8,1};
	float4 c=float4(0);
	for(int i=0;i<9;++i) c+=samplePremultiplied(image,sampleState,input.uv+parameters.xy*float(i-4),mode)*(weights[i]/256.0);
	c.rgb=c.a>0?c.rgb/c.a:float3(0);
	c*=input.colour;
	if(mode.z!=0 && c.a<0.5) discard_fragment();
	if(mode.w!=0) c.rgb*=c.a;
	return c;
}
