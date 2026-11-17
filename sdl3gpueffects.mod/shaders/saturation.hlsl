cbuffer Modes : register(b0, space3) { float4 mode; };
cbuffer Parameters : register(b1, space3) { float4 parameters; };
Texture2D image : register(t0, space2);
SamplerState sampleState : register(s0, space2);
struct Output { float4 position: SV_Position; float4 colour: TEXCOORD0; float2 uv: TEXCOORD1; };
float4 saturationMain(Output input): SV_Target0 {
	float4 c=image.Sample(sampleState,input.uv);
	if(mode.x!=0) c=float4(1,1,1,c.r);
	if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:float3(0,0,0);
	c*=input.colour;
	float gray=dot(c.rgb,float3(0.2126,0.7152,0.0722));
	c.rgb=lerp(float3(gray,gray,gray),c.rgb,parameters.x);
	if(mode.z!=0 && c.a<0.5) discard;
	if(mode.w!=0) c.rgb*=c.a;
	return c;
}
