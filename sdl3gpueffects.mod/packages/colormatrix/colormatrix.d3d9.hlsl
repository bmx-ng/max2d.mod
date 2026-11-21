float4 mode : register(c0);
float4 p[5] : register(c1);
float4 sourceScale : register(c11);
float4 mapScale : register(c12);
sampler2D image : register(s0);
struct Output { float4 colour: TEXCOORD1; float2 uv: TEXCOORD0; float2 screen:TEXCOORD2; };
float4 userEffect(float4 c) {
    float4 row0 = p[0];
    float4 row1 = p[1];
    float4 row2 = p[2];
    float4 row3 = p[3];
    float4 bias = p[4];
return float4(dot(row0,c), dot(row1,c), dot(row2,c), dot(row3,c)) + bias;
}
float4 sourceMode : register(c13); // filtered, floating-point storage
float4 sourceTap(float2 pixel) {
 return tex2Dlod(image,float4((clamp(pixel,0,sourceScale.xy/sourceScale.zw-1)+0.5)*sourceScale.zw,0,0));
}
float4 sourceColour(float2 uv) {
 if(sourceMode.y==0) return tex2D(image,uv*sourceScale.xy);
 float2 pixel=uv*sourceScale.xy/sourceScale.zw-0.5;
 if(sourceMode.x==0) return sourceTap(floor(pixel+0.5));
 float2 base=floor(pixel), f=frac(pixel);
 f=lerp(f,0,step(f,0.000001)); f=lerp(f,1,step(0.999999,f));
 return lerp(lerp(sourceTap(base),sourceTap(base+float2(1,0)),f.x),lerp(sourceTap(base+float2(0,1)),sourceTap(base+1),f.x),f.y);
}
float4 m2dEffectMain(Output input,float2 pixel:VPOS): COLOR0 {
input.uv+=ddx(input.uv)*(pixel.x-input.screen.x)+ddy(input.uv)*(pixel.y-input.screen.y);
float4 c=sourceColour(input.uv);
if(mode.x!=0) c=float4(1,1,1,c.r);
if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:float3(0,0,0);
c*=input.colour;
c=userEffect(c);
c.a=clamp(c.a,0.0,1.0);
if(mode.z!=0 && c.a<0.5) discard;
if(mode.w!=0) c.rgb*=c.a;
return c;
}
