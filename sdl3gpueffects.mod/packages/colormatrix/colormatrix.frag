#version 450
layout(location=0) in vec4 tint;
layout(location=1) in vec2 texcoord;
layout(location=0) out vec4 result;
layout(set=2,binding=0) uniform sampler2D image;
layout(set=3,binding=0) uniform Modes { vec4 mode; };
layout(set=3,binding=1) uniform Parameters { vec4 p[5]; };
vec4 userEffect(vec4 c) {
    vec4 row0 = p[0];
    vec4 row1 = p[1];
    vec4 row2 = p[2];
    vec4 row3 = p[3];
    vec4 bias = p[4];
return vec4(dot(row0,c), dot(row1,c), dot(row2,c), dot(row3,c)) + bias;
}
void main() {
vec4 c=texture(image,texcoord);
if(mode.x!=0) c=vec4(1,1,1,c.r);
if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:vec3(0);
c*=tint;
c=userEffect(c);
c.a=clamp(c.a,0.0,1.0);
if(mode.z!=0 && c.a<0.5) discard;
if(mode.w!=0) c.rgb*=c.a;
result=c;
}
