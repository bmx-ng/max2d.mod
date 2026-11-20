#version 120
uniform sampler2D image;
uniform int coverage, sourceTarget, sourcePremult, premultiply, mask;
uniform vec4 p[6];
varying vec4 tint;
varying vec2 texcoord;
vec4 m2dTexel(vec2 pixel, vec2 texelSize) {
vec2 uv=(pixel+0.5)*texelSize;
if(sourceTarget!=0) uv.y=1.0-uv.y;
return texture2D(image,uv);
}
vec2 userEffect(vec2 uv) {
    float time = p[0].x;
    float strength = p[1].x;
    float frequency = p[2].x;
    float ripple = p[3].x;
vec2 displacement=vec2(0,0);
if (ripple > 0.5) {
    vec2 delta=uv-vec2(0.5,0.5);
    float distance=length(delta);
    displacement=delta/max(distance,0.00001)*sin(distance*frequency-time)*strength;
} else {
    displacement=vec2(sin(uv.y*frequency+time)*strength,sin(uv.x*frequency*0.7-time)*strength*0.3);
}
return uv+displacement;
}
vec4 sampleRegion(vec2 uv) {
vec4 bounds=p[4], info=p[5];
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
        vec4 c00=m2dTexel(q,info.xy);
        q=origin+vec2(b.x,a.y);
        vec4 c10=m2dTexel(q,info.xy);
        q=origin+vec2(a.x,b.y);
        vec4 c01=m2dTexel(q,info.xy);
        q=origin+b;
        vec4 c11=m2dTexel(q,info.xy);
        sampled=mix(mix(c00,c10,weight.x),mix(c01,c11,weight.x),weight.y);
    } else {
        vec2 q=origin+clamp(floor(uv*size),vec2(0,0),size-1.0);
        sampled=m2dTexel(q,info.xy);
    }
}
return sampled;
}
void main() {
vec4 c=sampleRegion(userEffect((texcoord-p[4].xy)/p[4].zw));
if(coverage!=0) c=vec4(1,1,1,c.a);
if(sourcePremult!=0) c.rgb=c.a>0?c.rgb/c.a:vec3(0);
c*=tint;
c.a=clamp(c.a,0.0,1.0);
if(mask!=0 && c.a<0.5) discard;
if(premultiply!=0) c.rgb*=c.a;
gl_FragColor=c;
}
