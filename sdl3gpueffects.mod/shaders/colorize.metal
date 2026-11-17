#include <metal_stdlib>
using namespace metal;
struct Output { float4 position [[position]]; float4 colour; float2 uv; };
fragment float4 colorizeMain(Output input [[stage_in]], texture2d<float> image [[texture(0)]], sampler sampleState [[sampler(0)]], constant float4 &mode [[buffer(0)]], constant float4 &parameters [[buffer(1)]]) {
	float4 c=image.sample(sampleState,input.uv);
	if(mode.x!=0) c=float4(1,1,1,c.r);
	c.rgb=parameters.rgb * input.colour.rgb;
	c.a*=input.colour.a;
	if(mode.z!=0 && c.a<0.5) discard_fragment();
	if(mode.w!=0) c.rgb*=c.a;
	return c;
}
