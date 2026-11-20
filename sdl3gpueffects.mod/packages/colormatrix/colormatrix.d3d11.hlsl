cbuffer Modes : register(b0) { float4 mode; };
cbuffer Parameters : register(b1) { float4 p[5]; };
Texture2D image : register(t0);
SamplerState sampleState : register(s0);
struct Output { float4 position: SV_Position; float4 colour: COLOR0; float2 uv: TEXCOORD0; };
float4 userEffect(float4 c) {
    float4 row0 = p[0];
    float4 row1 = p[1];
    float4 row2 = p[2];
    float4 row3 = p[3];
    float4 bias = p[4];
return float4(dot(row0,c), dot(row1,c), dot(row2,c), dot(row3,c)) + bias;
}
float4 m2dEffectMain(Output input): SV_Target0 {
float4 c=image.Sample(sampleState,input.uv);
if(mode.x!=0) c=float4(1,1,1,c.r);
if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:float3(0,0,0);
c*=input.colour;
c=userEffect(c);
c.a=clamp(c.a,0.0,1.0);
if(mode.z!=0 && c.a<0.5) discard;
if(mode.w!=0) c.rgb*=c.a;
return c;
}
