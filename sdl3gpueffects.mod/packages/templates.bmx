' Fixed colour (ABI 1), coordinate (ABI 2), and two-texture (ABI 3/4) shader wrappers.
Const HEAD_metal:String = """
#include <metal_stdlib>
using namespace metal;
struct Output { float4 position [[position]]; float4 colour; float2 uv; };

"""

Const TAIL_metal:String = """
fragment float4 m2dEffectMain(Output input [[stage_in]], texture2d<float> image [[texture(0)]], sampler sampleState [[sampler(0)]], constant float4 &mode [[buffer(0)]], constant float4 *p [[buffer(1)]]) {
float4 c=image.sample(sampleState,input.uv);
if(mode.x!=0) c=float4(1,1,1,c.r);
if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:float3(0,0,0);
c*=input.colour;
c=userEffect(c,p);
c.a=clamp(c.a,0.0,1.0);
if(mode.z!=0 && c.a<0.5) discard_fragment();
if(mode.w!=0) c.rgb*=c.a;
return c;
}

"""

Const HEAD_glsl:String = """
#version 450
layout(location=0) in vec4 tint;
layout(location=1) in vec2 texcoord;
layout(location=0) out vec4 result;
layout(set=2,binding=0) uniform sampler2D image;
layout(set=3,binding=0) uniform Modes { vec4 mode; };
layout(set=3,binding=1) uniform Parameters { vec4 p[@COUNT@]; };

"""

Const TAIL_glsl:String = """
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

"""

Const HEAD_hlsl:String = """
cbuffer Modes : register(b0, space3) { float4 mode; };
cbuffer Parameters : register(b1, space3) { float4 p[@COUNT@]; };
Texture2D image : register(t0, space2);
SamplerState sampleState : register(s0, space2);
struct Output { float4 position: SV_Position; float4 colour: TEXCOORD0; float2 uv: TEXCOORD1; };

"""

Const TAIL_hlsl:String = """
float4 m2dEffectMain(Output input): SV_Target0 {
float4 c=image.Sample(sampleState,input.uv);
if(mode.x!=0) c=float4(1,1,1,c.r);
if(mode.y!=0) c.rgb=c.a>0?c.rgb/c.a:float3(0,0,0);
c*=input.colour;
c=userEffect(c);
c.a=clamp(c.a,0.0,1.0);
if(mode.z!=0 && c.a<0.5) discard;
if(mode.w!=0) c.rgb*=c.a;
return c;
}

"""


Const BMX_WRAPPER:String = """
' Generated package wrapper. Run embed after compiling shader assets.
' Import @PREFIX@@NAME@_assets.c alongside your application imports.
Function @FACTORY@:TMax2DShaderPackage()
	Return TMax2DShaderPackage.Create("@NAME@", [@NAMES@], [@KINDS@], @ARGUMENTS@@ABI_ARGUMENT@)
End Function
Private
Extern "C"
	Function @FACTORY@Asset:Byte Ptr(index:Int)
	Function @FACTORY@Size:Int(index:Int)
End Extern
Function @FACTORY@Data:Byte[](source:Byte Ptr, length:Int)
	Local data:Byte[] = New Byte[length]
	MemCopy(data, source, Size_T(data.Length))
	Return data
End Function
Public

"""

Const C_ASSET_FOOTER:String = """
static const unsigned char *assets[] = {asset0,asset1,asset2};
static const int sizes[] = {@SIZES@};
const unsigned char *@FACTORY@Asset(int i) { return i>=0 && i<3?assets[i]:0; }
int @FACTORY@Size(int i) { return i>=0 && i<3?sizes[i]:0; }

"""

' Coordinate packages use normalized image-local UVs and explicit LOD zero.
' @SAMPLE@ / @ARG@ adapt the fixed sampler binding to each shader language.
Const UV_SAMPLE:String = """
@VEC4@ sampleRegion(@VEC2@ uv@SAMPLER_ARGS@) {
@VEC4@ bounds=p[@SLOTS@], info=p[@INFO@];
@VEC2@ origin=floor(bounds.xy/info.xy+0.5);
@VEC2@ size=floor(bounds.zw/info.xy+0.5);
@VEC4@ sampled=@VEC4@(0,0,0,0);
bool outside=uv.x<0.0 || uv.y<0.0 || uv.x>=1.0 || uv.y>=1.0;
if(info.z>=0.5 || !outside) {
    if(info.z>1.5) uv=uv-floor(uv);
    else uv=clamp(uv,@VEC2@(0,0),@VEC2@(1,1));
    if(info.w>0.5) {
        @VEC2@ pixel=uv*size-0.5;
        @VEC2@ lo=floor(pixel), weight=pixel-lo;
        @VEC2@ a=lo, b=lo+1.0;
        if(info.z>1.5) {
            a-=floor(a/size)*size;
            b-=floor(b/size)*size;
        } else {
            a=clamp(a,@VEC2@(0,0),size-1.0);
            b=clamp(b,@VEC2@(0,0),size-1.0);
        }
        @VEC2@ q=origin+a;
        @VEC4@ c00=@SAMPLE@;
        q=origin+@VEC2@(b.x,a.y);
        @VEC4@ c10=@SAMPLE@;
        q=origin+@VEC2@(a.x,b.y);
        @VEC4@ c01=@SAMPLE@;
        q=origin+b;
        @VEC4@ c11=@SAMPLE@;
        sampled=@MIX@(@MIX@(c00,c10,weight.x),@MIX@(c01,c11,weight.x),weight.y);
    } else {
        @VEC2@ q=origin+clamp(floor(uv*size),@VEC2@(0,0),size-1.0);
        sampled=@SAMPLE@;
    }
}
return sampled;
}

"""

' Desktop OpenGL package wrapper. User bodies use GLSL 1.20 syntax.
Const HEAD_gl120:String = """
#version 120
uniform sampler2D image;
uniform int coverage, sourceTarget, sourcePremult, premultiply, mask;
uniform vec4 p[@COUNT@];
varying vec4 tint;
varying vec2 texcoord;

"""
Const TAIL_gl120:String = """
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

"""

' Coordinate taps use nearest filtering and mip level zero, selected by the provider.
Const GL120_TEXEL:String = """
vec4 m2dTexel(vec2 pixel, vec2 texelSize) {
vec2 uv=(pixel+0.5)*texelSize;
if(sourceTarget!=0) uv.y=1.0-uv.y;
return texture2D(image,uv);
}

"""
