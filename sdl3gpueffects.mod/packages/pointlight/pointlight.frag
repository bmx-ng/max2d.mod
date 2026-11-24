#version 450
layout(location=0) in vec4 tint;
layout(location=1) in vec2 texcoord;
layout(location=0) out vec4 result;
layout(set=2,binding=0) uniform sampler2D image;
layout(set=3,binding=0) uniform Modes { vec4 mode; };
layout(set=3,binding=1) uniform Parameters { vec4 p[7]; };
vec2 userEffect(vec2 uv) {
    vec4 light = p[0];
    vec4 colour = p[1];
    vec4 shape = p[2];
    vec4 basisX = p[3];
    vec4 basisY = p[4];
return uv;
}
vec4 userColour(vec4 c, vec2 uv) {
    vec4 light = p[0];
    vec4 colour = p[1];
    vec4 shape = p[2];
    vec4 basisX = p[3];
    vec4 basisY = p[4];
float attenuation=1.0;
if (shape.y>0.5) {
 vec2 position=vec2(dot(basisX.xy,uv)+basisX.z,dot(basisY.xy,uv)+basisY.z);
 float distanceFromLight=length((position-light.xy)/light.zw);
 attenuation=pow(max(0.0,1.0-distanceFromLight),shape.x);
}
return vec4(c.rgb*colour.rgb*colour.a*attenuation,c.a);
}
vec4 sampleRegion(vec2 uv) {
vec4 bounds=p[5], info=p[6];
vec2 origin=floor(bounds.xy/info.xy+0.5);
vec2 size=floor(bounds.zw/info.xy+0.5);
vec4 sampled=vec4(0,0,0,0);
bool outside=uv.x<0.0 || uv.y<0.0 || uv.x>=1.0 || uv.y>=1.0;
if(info.z>=0.5 || !outside) {
    if(info.z>1.5) uv=uv-floor(uv);
    else uv=clamp(uv,vec2(0,0),vec2(1,1));
    if(info.w>0.5) {
        vec2 pixel=uv*size-0.5;
        vec2 lo=floor(pixel), weight=pixel-lo;
        vec2 a=lo, b=lo+1.0;
        if(info.z>1.5) {
            a-=floor(a/size)*size;
            b-=floor(b/size)*size;
        } else {
            a=clamp(a,vec2(0,0),size-1.0);
            b=clamp(b,vec2(0,0),size-1.0);
        }
        vec2 q=origin+a;
        vec4 c00=texelFetch(image,ivec2(q),0);
        q=origin+vec2(b.x,a.y);
        vec4 c10=texelFetch(image,ivec2(q),0);
        q=origin+vec2(a.x,b.y);
        vec4 c01=texelFetch(image,ivec2(q),0);
        q=origin+b;
        vec4 c11=texelFetch(image,ivec2(q),0);
        sampled=mix(mix(c00,c10,weight.x),mix(c01,c11,weight.x),weight.y);
    } else {
        vec2 q=origin+clamp(floor(uv*size),vec2(0,0),size-1.0);
        sampled=texelFetch(image,ivec2(q),0);
    }
}
return sampled;
}
void main() {
vec4 c=sampleRegion(userEffect((texcoord-p[5].xy)/p[5].zw));
if(mode.x!=0) c=vec4(1,1,1,c.r);
if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:vec3(0);
c*=tint;
c=userColour(c,(texcoord-p[5].xy)/p[5].zw);
c.a=clamp(c.a,0.0,1.0);
if(mode.z!=0 && c.a<0.5) discard;
if(mode.w!=0) c.rgb*=c.a;
result=c;
}
