#version 450
layout(location=0) out vec4 tint;
layout(location=1) out vec2 texcoord;
layout(set=1,binding=0) uniform Transform { vec4 transform; };
struct Sprite { vec4 origin_dx; vec4 dy_uv0; vec4 uv1_pad; vec4 colour; };
layout(std140,set=0,binding=0) readonly buffer Sprites { Sprite sprites[]; };
void main() {
	const vec2 corners[6]=vec2[6](vec2(0,0),vec2(1,0),vec2(1,1),vec2(0,0),vec2(1,1),vec2(0,1));
	Sprite s=sprites[gl_VertexIndex/6];
	vec2 corner=corners[gl_VertexIndex%6];
	vec2 p=s.origin_dx.xy+s.origin_dx.zw*corner.x+s.dy_uv0.xy*corner.y;
	gl_Position=vec4(p*transform.xy+transform.zw,0,1);
	tint=s.colour;
	texcoord=mix(s.dy_uv0.zw,s.uv1_pad.xy,corner);
}
