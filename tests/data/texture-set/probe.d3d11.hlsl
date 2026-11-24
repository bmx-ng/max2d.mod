cbuffer Modes : register(b0) { float4 mode; };
cbuffer Parameters : register(b1) { float4 p[5]; };
Texture2D image : register(t0); SamplerState state : register(s0);
Texture2D secondImage : register(t1); SamplerState secondState : register(s1);
Texture2D thirdImage : register(t2); SamplerState thirdState : register(s2);
Texture2D fourthImage : register(t3); SamplerState fourthState : register(s3);
Texture2D fifthImage : register(t4); SamplerState fifthState : register(s4);
struct Output { float4 position:SV_Position; float4 colour:COLOR0; float2 uv:TEXCOORD0; };
float4 m2dEffectMain(Output input):SV_Target0 {
 float4 s,m;
 if(p[0].x<0.5){s=secondImage.SampleLevel(secondState,input.uv,0);m=p[1];}
 else if(p[0].x<1.5){s=thirdImage.SampleLevel(thirdState,input.uv,0);m=p[2];}
 else if(p[0].x<2.5){s=fourthImage.SampleLevel(fourthState,input.uv,0);m=p[3];}
 else{s=fifthImage.SampleLevel(fifthState,input.uv,0);m=p[4];}
 return float4(m.x>0.5?1:s.r,m.x>0.5?s.r:s.a,m.y,1)*image.SampleLevel(state,input.uv,0).r;
}
