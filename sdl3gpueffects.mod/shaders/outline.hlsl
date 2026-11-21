cbuffer Modes : register(b0, space3) { float4 mode; };
cbuffer Parameters : register(b1, space3) { float4 parameters; };
Texture2D image : register(t0, space2);
SamplerState sampleState : register(s0, space2);
struct Output { float4 position: SV_Position; float4 colour: TEXCOORD0; float2 uv: TEXCOORD1; };
float sampleAlpha(float2 uv) {
	float4 c=image.SampleLevel(sampleState,uv,0);
	if(any(uv<float2(0,0)) || any(uv>float2(1,1))) c=float4(0,0,0,0);
	return mode.x!=0?c.r:c.a;
}
float4 outlineMain(Output input): SV_Target0 {
	float centre=sampleAlpha(input.uv);
	float expanded=centre;
	[loop] for(int y=-4;y<=4;++y) [loop] for(int x=-4;x<=4;++x) {
		int distance=x*x+y*y;
		if(distance>0 && float(distance)<=parameters.z*parameters.z)
			expanded=max(expanded,sampleAlpha(input.uv+float2(x,y)*parameters.xy));
	}
	float4 c=float4(input.colour.rgb,max(expanded-centre,0.0)*input.colour.a);
	if(mode.z!=0 && c.a<0.5) discard;
	if(mode.w!=0) c.rgb*=c.a;
	return c;
}
