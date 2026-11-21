// Float copy path: exact-centre bilinear filtering and full precision tint.
float4 options : register(c0);
float4 sourceInfo : register(c1); // allocated texel size, logical dimensions
float4 filterMode : register(c2);
sampler2D image : register(s0);
float4 tap(float2 pixel) {
 return tex2Dlod(image,float4((clamp(pixel,0,sourceInfo.zw-1)+0.5)*sourceInfo.xy,0,0));
}
float4 main(float4 tint:TEXCOORD1,float2 uv:TEXCOORD0,float2 screen:TEXCOORD2,float2 position:VPOS):COLOR0 {
 uv+=ddx(uv)*(position.x-screen.x)+ddy(uv)*(position.y-screen.y);
 float4 c=1;
 if(options.x!=0) {
  float2 pixel=uv/sourceInfo.xy-0.5;
  if(filterMode.x!=0) {
   float2 base=floor(pixel), f=frac(pixel);
   f=lerp(f,0,step(f,0.000001));f=lerp(f,1,step(0.999999,f));
   c=lerp(lerp(tap(base),tap(base+float2(1,0)),f.x),lerp(tap(base+float2(0,1)),tap(base+1),f.x),f.y);
  } else c=tap(floor(pixel+0.5));
 }
 if(options.y!=0)c.rgb=c.a>0?c.rgb/c.a:0;
 c*=tint;
 if(options.w!=0)clip(c.a-0.5);
 if(options.z!=0)c.rgb*=c.a;
 return c;
}
