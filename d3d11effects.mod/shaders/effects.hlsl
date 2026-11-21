cbuffer Settings : register(b0) {
 float4 transform;
 float4 options; // source kind, mask, source premultiplied, output premultiplied
 float4 parameters;
};
struct Input { float4 position:SV_POSITION; float4 color:COLOR0; float2 uv:TEXCOORD0; };
Texture2D image : register(t0);
SamplerState imageSampler : register(s0);
float4 source(float2 uv) {
 float4 c=image.Sample(imageSampler,uv);
 if(options.x>1) c=float4(1,1,1,c.r);
 if(options.z>0) c.rgb=c.a>0?c.rgb/c.a:float3(0,0,0);
 return c;
}
float4 outputColor(float4 c) {
 if(options.y>0) clip(c.a-0.5);
 if(options.w>0) c.rgb*=c.a;
 return c;
}
float4 saturation(Input i):SV_TARGET {
 float4 c=source(i.uv)*i.color;
 c.rgb=lerp(dot(c.rgb,float3(0.2126,0.7152,0.0722)).xxx,c.rgb,parameters.x);
 return outputColor(c);
}
float4 colorize(Input i):SV_TARGET {
 return outputColor(float4(parameters.rgb,source(i.uv).a)*i.color);
}
float4 samplePremultiplied(float2 uv) {
 if(any(uv<-0.000001)||any(uv>1.000001)) return 0;
 return image.SampleLevel(imageSampler,uv,0);
}
float4 blur(Input i):SV_TARGET {
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
float4 outline(Input i):SV_TARGET {
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
float4 bright(Input i):SV_TARGET {
 float4 c=source(i.uv)*i.color;
 float luminance=dot(c.rgb,float3(0.2126,0.7152,0.0722));
 c.a*=luminance>0?max(luminance-parameters.x,0)/luminance:0;
 return outputColor(c);
}
float4 tone(Input i):SV_TARGET {
 float4 c=source(i.uv)*i.color;
 c.rgb=1-1/(1+max(c.rgb,0)*parameters.x);
 c.rgb=pow(abs(c.rgb),parameters.y);
 return outputColor(c);
}
float4 linearOutput(Input i):SV_TARGET {
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
