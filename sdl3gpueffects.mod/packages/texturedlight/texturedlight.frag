#version 450
layout(location=0) in vec4 tint;
layout(location=1) in vec2 texcoord;
layout(location=0) out vec4 result;
layout(set=2,binding=0) uniform sampler2D image;
layout(set=3,binding=0) uniform Modes { vec4 mode; };
layout(set=3,binding=1) uniform Parameters { vec4 p[15]; };
layout(set=2,binding=1) uniform sampler2D secondImage;
layout(set=2,binding=2) uniform sampler2D thirdImage;
vec2 userEffect(vec2 uv, vec4 m, vec4 t) {
    vec4 light = p[0];
    vec4 colour = p[1];
    vec4 shape = p[2];
    vec4 basisX = p[3];
    vec4 basisY = p[4];
    vec4 cookieX = p[5];
    vec4 cookieY = p[6];
return uv;
}
vec4 userColour(vec4 c, vec2 uv, vec4 m, vec4 t) {
    vec4 light = p[0];
    vec4 colour = p[1];
    vec4 shape = p[2];
    vec4 basisX = p[3];
    vec4 basisY = p[4];
    vec4 cookieX = p[5];
    vec4 cookieY = p[6];
vec2 position=vec2(dot(basisX.xy,uv)+basisX.z,dot(basisY.xy,uv)+basisY.z);
vec3 delta=vec3(light.xy-position,light.w);
float attenuation=1.0;
if (shape.x<0.0) {
 delta=light.xyz;
} else {
 attenuation=pow(max(0.0,1.0-length(delta.xy)/light.z),shape.x);
}
vec3 n=vec3(0.0,0.0,1.0);
if (shape.y>=0.0) {
 n=m.rgb*2.0-1.0;
 n.xy*=shape.y;
}
float a=basisX.x*basisX.w, b=basisX.y*basisY.w;
float d=basisY.x*basisX.w, e=basisY.y*basisY.w;
float determinant=a*e-b*d;
if (abs(determinant)>0.000001) {
 n=vec3((e*n.x-d*n.y)/determinant,(-b*n.x+a*n.y)/determinant,n.z);
} else {
 n=vec3(0.0,0.0,1.0);
}
n=n/max(length(n),0.000001);
vec3 direction=delta/max(length(delta),0.000001);
float diffuse=shape.y < -1.5 ? 1.0 : max(0.0,dot(n,direction));
vec3 halfway=direction+vec3(0.0,0.0,1.0);
halfway=halfway/max(length(halfway),0.000001);
float specular=0.0;
if (diffuse>0.0 && shape.z>0.0) {
 specular=shape.z*pow(max(0.0,dot(n,halfway)),abs(shape.w));
 if(shape.w<0.0) specular*=clamp(m.a,0.0,1.0);
}
return vec4((c.rgb*diffuse+vec3(specular))*colour.rgb*colour.a*attenuation*t.rgb*t.a,c.a);
}
vec2 userThirdUV(vec2 uv) {
    vec4 light = p[0];
    vec4 colour = p[1];
    vec4 shape = p[2];
    vec4 basisX = p[3];
    vec4 basisY = p[4];
    vec4 cookieX = p[5];
    vec4 cookieY = p[6];
return vec2(dot(cookieX.xy,uv)+cookieX.z,dot(cookieY.xy,uv)+cookieY.z);
}
vec4 sampleThird(vec2 uv) {
vec4 bounds=p[11], info=p[12];
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
        vec4 c00=texelFetch(thirdImage,ivec2(q),0);
        q=origin+vec2(b.x,a.y);
        vec4 c10=texelFetch(thirdImage,ivec2(q),0);
        q=origin+vec2(a.x,b.y);
        vec4 c01=texelFetch(thirdImage,ivec2(q),0);
        q=origin+b;
        vec4 c11=texelFetch(thirdImage,ivec2(q),0);
        sampled=mix(mix(c00,c10,weight.x),mix(c01,c11,weight.x),weight.y);
    } else {
        vec2 q=origin+clamp(floor(uv*size),vec2(0,0),size-1.0);
        sampled=texelFetch(thirdImage,ivec2(q),0);
    }
}
return sampled;
}
vec4 sampleMap(vec2 uv) {
vec4 bounds=p[9], info=p[10];
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
        vec4 c00=texelFetch(secondImage,ivec2(q),0);
        q=origin+vec2(b.x,a.y);
        vec4 c10=texelFetch(secondImage,ivec2(q),0);
        q=origin+vec2(a.x,b.y);
        vec4 c01=texelFetch(secondImage,ivec2(q),0);
        q=origin+b;
        vec4 c11=texelFetch(secondImage,ivec2(q),0);
        sampled=mix(mix(c00,c10,weight.x),mix(c01,c11,weight.x),weight.y);
    } else {
        vec2 q=origin+clamp(floor(uv*size),vec2(0,0),size-1.0);
        sampled=texelFetch(secondImage,ivec2(q),0);
    }
}
return sampled;
}
vec4 sampleRegion(vec2 uv) {
vec4 bounds=p[7], info=p[8];
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
vec2 localUV=(texcoord-p[7].xy)/p[7].zw;
vec4 t=sampleThird(userThirdUV(localUV));
if(p[14].x!=0) t=vec4(1,1,1,t.r);
if(p[14].y!=0) t.rgb=t.a>0?t.rgb/t.a:vec3(0,0,0);
vec4 m=sampleMap(localUV);
if(p[13].x!=0) m=vec4(1,1,1,m.r);
if(p[13].y!=0) m.rgb=m.a>0?m.rgb/m.a:vec3(0,0,0);
vec4 c=sampleRegion(userEffect(localUV,m,t));
if(mode.x!=0) c=vec4(1,1,1,c.r);
if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:vec3(0);
c*=tint;
c=userColour(c,(texcoord-p[7].xy)/p[7].zw,m,t);
c.a=clamp(c.a,0.0,1.0);
if(mode.z!=0 && c.a<0.5) discard;
if(mode.w!=0) c.rgb*=c.a;
result=c;
}
