#version 450
layout(location=0) in vec4 tint;
layout(location=1) in vec2 texcoord;
layout(location=0) out vec4 result;
layout(set=2,binding=0) uniform sampler2D image;
layout(set=3,binding=0) uniform Modes { vec4 mode; };
layout(set=3,binding=1) uniform Parameters { vec4 parameters; };
float sampleAlpha(vec2 uv) {
	if(any(lessThan(uv,vec2(0))) || any(greaterThan(uv,vec2(1)))) return 0;
	vec4 c=textureLod(image,uv,0);
	return mode.x!=0?c.r:c.a;
}
void main() {
	float centre=sampleAlpha(texcoord);
	float expanded=centre;
	for(int y=-4;y<=4;++y) for(int x=-4;x<=4;++x) {
		int distance=x*x+y*y;
		if(distance>0 && float(distance)<=parameters.z*parameters.z)
			expanded=max(expanded,sampleAlpha(texcoord+vec2(x,y)*parameters.xy));
	}
	vec4 c=vec4(tint.rgb,max(expanded-centre,0)*tint.a);
	if(mode.z!=0 && c.a<0.5) discard;
	if(mode.w!=0) c.rgb*=c.a;
	result=c;
}
