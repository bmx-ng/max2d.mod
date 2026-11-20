// c0: textured, source premultiplied, output premultiplied, mask.
float4 options : register(c0);
float4 parameters : register(c1);
float4 textureScale : register(c2);
struct Input { float4 color:COLOR0; float2 uv:TEXCOORD0; };
sampler2D image : register(s0);
float4 source(float2 uv) {
 float4 c=tex2D(image,uv*textureScale.xy);
 if(options.y>0) c.rgb=c.a>0?c.rgb/c.a:float3(0,0,0);
 return c;
}
float4 outputColor(float4 c) {
 if(options.w>0) clip(c.a-0.5);
 if(options.z>0) c.rgb*=c.a;
 return c;
}
float4 saturation(Input i):COLOR0 {
 float4 c=source(i.uv)*i.color;
 c.rgb=lerp(dot(c.rgb,float3(0.2126,0.7152,0.0722)).xxx,c.rgb,parameters.x);
 return outputColor(c);
}
float4 colorize(Input i):COLOR0 {
 return outputColor(float4(parameters.rgb,source(i.uv).a)*i.color);
}
float4 pointSample(float2 pixel) {
 pixel=clamp(pixel,0,textureScale.zw-1);
 return tex2Dlod(image,float4((pixel+0.5)/textureScale.zw*textureScale.xy,0,0));
}
float4 samplePremultiplied(float2 uv) {
 if(any(uv<-0.000001)||any(uv>1.000001)) return 0;
 float2 pixel=uv*textureScale.zw-0.5;
 if(parameters.w==0) return pointSample(floor(pixel+0.5));
 // Point taps avoid legacy texture-unit interpolation error at texel centres.
 float2 base=floor(pixel), f=frac(pixel);
 // The legacy interpolator can drift by one 1/256 subtexel at exact centres.
 // Preserve fractional taps, but make the centre neighbourhood exact.
 f=float2(f.x<0.0078125?0:(f.x>0.9921875?1:f.x),
          f.y<0.0078125?0:(f.y>0.9921875?1:f.y));
 return lerp(lerp(pointSample(base),pointSample(base+float2(1,0)),f.x),
             lerp(pointSample(base+float2(0,1)),pointSample(base+1),f.x),f.y);
}
float4 blur(Input i):COLOR0 {
 float2 stepUV=parameters.xy;
 float4 c=samplePremultiplied(i.uv)*70;
 c+=(samplePremultiplied(i.uv-stepUV)+samplePremultiplied(i.uv+stepUV))*56;
 c+=(samplePremultiplied(i.uv-stepUV*2)+samplePremultiplied(i.uv+stepUV*2))*28;
 c+=(samplePremultiplied(i.uv-stepUV*3)+samplePremultiplied(i.uv+stepUV*3))*8;
 c+=samplePremultiplied(i.uv-stepUV*4)+samplePremultiplied(i.uv+stepUV*4);
 c/=256;
 c.rgb=c.a>0?c.rgb/c.a:float3(0,0,0);
 return outputColor(c*i.color);
}
float4 outline(Input i):COLOR0 {
 float centre=samplePremultiplied(i.uv).a;
 float expanded=centre;
 [loop] for(int y=-4;y<=4;++y) {
  [loop] for(int x=-4;x<=4;++x) {
   int distance=x*x+y*y;
   if(distance>0 && distance<=parameters.z*parameters.z)
    expanded=max(expanded,samplePremultiplied(i.uv+float2(x,y)*parameters.xy).a);
  }
 }
 return outputColor(float4(i.color.rgb,max(expanded-centre,0)*i.color.a));
}
float4 bright(Input i):COLOR0 {
 float4 c=source(i.uv)*i.color;
 float luminance=dot(c.rgb,float3(0.2126,0.7152,0.0722));
 c.a*=luminance>0?max(luminance-parameters.x,0)/luminance:0;
 return outputColor(c);
}
float4 tone(Input i):COLOR0 {
 float4 c=source(i.uv)*i.color;
 c.rgb=1-1/(1+max(c.rgb,0)*parameters.x);
 c.rgb=pow(abs(c.rgb),parameters.y);
 return outputColor(c);
}
float4 linearOutput(Input i):COLOR0 {
 float4 c=source(i.uv)*i.color;
 c.rgb=max(c.rgb,0)*parameters.x;
 if(parameters.z!=0) c.rgb*=parameters.y;
 else {
  c.rgb=1-1/(1+c.rgb);
  c.r=c.r<=0.0031308?12.92*c.r:1.055*pow(abs(c.r),1.0/2.4)-0.055;
  c.g=c.g<=0.0031308?12.92*c.g:1.055*pow(abs(c.g),1.0/2.4)-0.055;
  c.b=c.b<=0.0031308?12.92*c.b:1.055*pow(abs(c.b),1.0/2.4)-0.055;
 }
 return outputColor(c);
}
