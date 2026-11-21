#version 120
uniform sampler2D image;
uniform int coverage, sourceTarget, sourcePremult, premultiply, mask;
uniform vec4 p[2];
varying vec4 tint;
varying vec2 texcoord;
vec4 userEffect(vec4 c) {
    float gain = p[0].x;
    vec4 bias = p[1];
return c*gain + bias;
}
void main() {
vec2 uv=texcoord;
if(sourceTarget!=0) uv.y=1.0-uv.y;
vec4 c=texture2D(image,uv);
if(coverage!=0) c.rgb=vec3(1.0);
if(sourcePremult!=0) c.rgb=c.a>0.0?c.rgb/c.a:vec3(0.0);
c*=tint;
c=userEffect(c);
c.a=clamp(c.a,0.0,1.0);
if(mask!=0 && c.a<0.5) discard;
if(premultiply!=0) c.rgb*=c.a;
gl_FragColor=c;
}
