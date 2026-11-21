#version 120
uniform sampler2D image;
uniform int coverage, sourceTarget, sourcePremult, premultiply, mask;
uniform vec4 p[5];
varying vec4 tint;
varying vec2 texcoord;
vec4 userEffect(vec4 c) {
    vec4 row0 = p[0];
    vec4 row1 = p[1];
    vec4 row2 = p[2];
    vec4 row3 = p[3];
    vec4 bias = p[4];
return vec4(dot(row0,c), dot(row1,c), dot(row2,c), dot(row3,c)) + bias;
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
