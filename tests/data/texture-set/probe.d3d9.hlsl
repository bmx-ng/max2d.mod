float4 mode : register(c0);
float4 p[5] : register(c1);
float4 scales[5] : register(c6);
sampler2D image : register(s0);
sampler2D secondImage : register(s1);
sampler2D thirdImage : register(s2);
sampler2D fourthImage : register(s3);
sampler2D fifthImage : register(s4);
struct Output { float4 colour:TEXCOORD1; float2 uv:TEXCOORD0; float2 screen:TEXCOORD2; };
float4 m2dEffectMain(Output input):COLOR0 {
 float4 s,m;
 if(p[0].x<0.5){s=tex2Dlod(secondImage,float4(input.uv*scales[1].xy,0,0));m=p[1];}
 else if(p[0].x<1.5){s=tex2Dlod(thirdImage,float4(input.uv*scales[2].xy,0,0));m=p[2];}
 else if(p[0].x<2.5){s=tex2Dlod(fourthImage,float4(input.uv*scales[3].xy,0,0));m=p[3];}
 else{s=tex2Dlod(fifthImage,float4(input.uv*scales[4].xy,0,0));m=p[4];}
 return float4(s.r,s.a,m.y,1)*tex2Dlod(image,float4(input.uv*scales[0].xy,0,0)).r;
}
