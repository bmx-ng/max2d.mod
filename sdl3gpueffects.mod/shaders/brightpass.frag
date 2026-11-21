#version 450
layout(location=0) in vec4 tint;
layout(location=1) in vec2 texcoord;
layout(location=0) out vec4 result;
layout(set=2,binding=0) uniform sampler2D image;
layout(set=3,binding=0) uniform Modes { vec4 mode; };
layout(set=3,binding=1) uniform Parameters { vec4 parameters; };
void main() {
	vec4 c=texture(image,texcoord);
	if(mode.x!=0) c=vec4(1,1,1,c.r);
	if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:vec3(0);
	c*=tint;
	float luminance=dot(c.rgb,vec3(0.2126,0.7152,0.0722));
	c.a*=luminance>0?max(luminance-parameters.x,0.0)/luminance:0.0;
	if(mode.z!=0 && c.a<0.5) discard;
	if(mode.w!=0) c.rgb*=c.a;
	result=c;
}
