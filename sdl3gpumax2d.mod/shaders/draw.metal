#include <metal_stdlib>
using namespace metal;
struct Input {
	float2 position [[attribute(0)]];
	float4 colour [[attribute(1)]];
	float2 uv [[attribute(2)]];
};
struct Output {
	float4 position [[position]];
	float4 colour;
	float2 uv;
};
vertex Output vertexMain(Input input [[stage_in]], constant float4 &transform [[buffer(0)]]) {
	Output output;
	output.position=float4(input.position*transform.xy+transform.zw,0,1);
	output.colour=input.colour;
	output.uv=input.uv;
	return output;
}
fragment float4 pixelMain(Output input [[stage_in]], texture2d<float> image [[texture(0)]], sampler sampleState [[sampler(0)]], constant float4 &mode [[buffer(0)]]) {
	float4 c=image.sample(sampleState,input.uv);
	if(mode.x!=0) c=float4(1,1,1,c.r);
	if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:float3(0);
	c*=input.colour;
	if(mode.z!=0 && c.a<0.5) discard_fragment();
	if(mode.w!=0) c.rgb*=c.a;
	return c;
}
