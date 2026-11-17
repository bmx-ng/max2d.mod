cbuffer Modes : register(b0, space3) { float4 mode; };
cbuffer Parameters : register(b1, space3) { float4 parameters; };
Texture2D image : register(t0, space2);
SamplerState sampleState : register(s0, space2);
struct Output { float4 position: SV_Position; float4 colour: TEXCOORD0; float2 uv: TEXCOORD1; };
float4 samplePremultiplied(float2 uv) {
	float4 c=image.SampleLevel(sampleState,uv,0);
	if(any(uv<float2(0,0)) || any(uv>float2(1,1))) c=float4(0,0,0,0);
	if(mode.x!=0) c=float4(1,1,1,c.r);
	if(mode.y==0) c.rgb*=c.a;
	return c;
}
float4 blurMain(Output input): SV_Target0 {
	const float weights[9]={1,8,28,56,70,56,28,8,1};
	float4 c=float4(0,0,0,0);
	[unroll] for(int i=0;i<9;++i) c+=samplePremultiplied(input.uv+parameters.xy*float(i-4))*(weights[i]/256.0);
	c.rgb=c.a>0?c.rgb/c.a:float3(0,0,0);
	c*=input.colour;
	if(mode.z!=0 && c.a<0.5) discard;
	if(mode.w!=0) c.rgb*=c.a;
	return c;
}
