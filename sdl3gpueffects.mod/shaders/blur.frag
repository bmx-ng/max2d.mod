#version 450
layout(location=0) in vec4 tint;
layout(location=1) in vec2 texcoord;
layout(location=0) out vec4 result;
layout(set=2,binding=0) uniform sampler2D image;
layout(set=3,binding=0) uniform Modes { vec4 mode; };
layout(set=3,binding=1) uniform Parameters { vec4 parameters; };
vec4 samplePremultiplied(vec2 uv) {
	vec4 c=textureLod(image,uv,0);
	if(any(lessThan(uv,vec2(0))) || any(greaterThan(uv,vec2(1)))) c=vec4(0);
	if(mode.x!=0) c=vec4(1,1,1,c.r);
	if(mode.y==0) c.rgb*=c.a;
	return c;
}
void main() {
	const float weights[9]=float[9](1,8,28,56,70,56,28,8,1);
	vec4 c=vec4(0);
	for(int i=0;i<9;++i) c+=samplePremultiplied(texcoord+parameters.xy*float(i-4))*(weights[i]/256.0);
	c.rgb=c.a>0?c.rgb/c.a:vec3(0);
	c*=tint;
	if(mode.z!=0 && c.a<0.5) discard;
	if(mode.w!=0) c.rgb*=c.a;
	result=c;
}
