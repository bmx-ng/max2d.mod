cbuffer Settings : register(b0) {
 float4 transform; // logical XY to clip XY
 float4 options;   // source (0=none, 1=RGBA, 2=coverage), mask, source premultiplied, output premultiplied
};
struct Input {float2 position:POSITION;float4 color:COLOR0;float2 uv:TEXCOORD0;};
struct Output {float4 position:SV_POSITION;float4 color:COLOR0;float2 uv:TEXCOORD0;};
Output vertexMain(Input input) {
 Output o;
 o.position=float4(input.position*transform.xy+transform.zw,0,1);
 o.color=input.color;o.uv=input.uv;
 return o;
}
Texture2D image : register(t0);
SamplerState imageSampler : register(s0);
float4 pixelMain(Output input):SV_TARGET {
 float4 c=float4(1,1,1,1);
 if(options.x>0)c=image.Sample(imageSampler,input.uv);
	// R8 stores opacity; drawing colour supplies RGB.
	if(options.x>1)c=float4(1,1,1,c.r);
 if(options.z>0)c.rgb=c.a>0?c.rgb/max(c.a,0.0001):float3(0,0,0);
 c*=input.color;
 if(options.y>0)clip(c.a-0.5);
 if(options.w>0)c.rgb*=c.a;
 return c;
}
