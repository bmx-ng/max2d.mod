cbuffer VertexUniforms : register(b0, space1) { float4 transform; };
cbuffer FragmentUniforms : register(b0, space3) { float4 mode; };
Texture2D image : register(t0, space2);
SamplerState sampleState : register(s0, space2);
struct Input { float2 position: TEXCOORD0; float4 colour: TEXCOORD1; float2 uv: TEXCOORD2; };
struct Output { float4 position: SV_Position; float4 colour: TEXCOORD0; float2 uv: TEXCOORD1; };
Output vertexMain(Input input) {
	Output output;
	output.position=float4(input.position*transform.xy+transform.zw,0,1);
	output.colour=input.colour;
	output.uv=input.uv;
	return output;
}
float4 pixelMain(Output input): SV_Target0 {
	float4 c=image.Sample(sampleState,input.uv);
	if(mode.x!=0) c=float4(1,1,1,c.r);
	if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:float3(0,0,0);
	c*=input.colour;
	if(mode.z!=0 && c.a<0.5) discard;
	if(mode.w!=0) c.rgb*=c.a;
	return c;
}
struct Sprite { float4 origin_dx; float4 dy_uv0; float4 uv1_pad; float4 colour; };
StructuredBuffer<Sprite> sprites : register(t0, space0);
Output compactMain(uint id : SV_VertexID) {
	const float2 corners[6]={float2(0,0),float2(1,0),float2(1,1),float2(0,0),float2(1,1),float2(0,1)};
	Sprite s=sprites[id/6];
	float2 corner=corners[id%6];
	float2 p=s.origin_dx.xy+s.origin_dx.zw*corner.x+s.dy_uv0.xy*corner.y;
	Output output;
	output.position=float4(p*transform.xy+transform.zw,0,1);
	output.colour=s.colour;
	output.uv=lerp(s.dy_uv0.zw,s.uv1_pad.xy,corner);
	return output;
}
