#include <metal_stdlib>
using namespace metal;
struct Output { float4 position [[position]]; float4 colour; float2 uv; };
fragment float4 linearoutputMain(Output input [[stage_in]], texture2d<float> image [[texture(0)]], sampler sampleState [[sampler(0)]], constant float4 &mode [[buffer(0)]], constant float4 &parameters [[buffer(1)]]) {
	float4 c=image.sample(sampleState,input.uv);
	if(mode.x!=0) c=float4(1,1,1,c.r);
	if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:float3(0);
	c*=input.colour;
	c.rgb=max(c.rgb,0.0)*parameters.x;
	if(parameters.z!=0) c.rgb*=parameters.y;
	else {
		c.rgb=1.0-1.0/(1.0+c.rgb);
		c.r=c.r<=0.0031308?12.92*c.r:1.055*pow(abs(c.r),1.0/2.4)-0.055;
		c.g=c.g<=0.0031308?12.92*c.g:1.055*pow(abs(c.g),1.0/2.4)-0.055;
		c.b=c.b<=0.0031308?12.92*c.b:1.055*pow(abs(c.b),1.0/2.4)-0.055;
	}
	if(mode.z!=0 && c.a<0.5) discard_fragment();
	if(mode.w!=0) c.rgb*=c.a;
	return c;
}
