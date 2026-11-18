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
	c.rgb=max(c.rgb,0.0)*parameters.x;
	if(parameters.z!=0) c.rgb*=parameters.y;
	else {
		c.rgb=1.0-1.0/(1.0+c.rgb);
		c.r=c.r<=0.0031308?12.92*c.r:1.055*pow(abs(c.r),1.0/2.4)-0.055;
		c.g=c.g<=0.0031308?12.92*c.g:1.055*pow(abs(c.g),1.0/2.4)-0.055;
		c.b=c.b<=0.0031308?12.92*c.b:1.055*pow(abs(c.b),1.0/2.4)-0.055;
	}
	if(mode.z!=0 && c.a<0.5) discard;
	if(mode.w!=0) c.rgb*=c.a;
	result=c;
}
