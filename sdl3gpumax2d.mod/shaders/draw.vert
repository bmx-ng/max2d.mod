#version 450
layout(location=0) in vec2 position;
layout(location=1) in vec4 colour;
layout(location=2) in vec2 uv;
layout(location=0) out vec4 tint;
layout(location=1) out vec2 texcoord;
layout(set=1,binding=0) uniform Transform { vec4 transform; };
void main() {
	gl_Position=vec4(position*transform.xy+transform.zw,0,1);
	tint=colour;
	texcoord=uv;
}
