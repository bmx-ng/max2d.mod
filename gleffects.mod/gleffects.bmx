SuperStrict

Rem
bbdoc: Optional OpenGL 2.1 provider for saturation and colourize image effects.
about: Import alongside Max2D.GLMax2D. Shader programs belong to the graphics context; effects can be reused after graphics recreation. Other shader effects remain unsupported.
End Rem
Module Max2D.GLEffects
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"

Import Max2D.Effects
Import Max2D.GLMax2D

Private

Global saturationKey:Byte
Global colorizeKey:Byte

Const fragmentHeader:String = """
#version 120
uniform sampler2D image;
uniform int coverage, sourceTarget, sourcePremult, premultiply, mask;
uniform vec4 parameters;
varying vec4 tint;
varying vec2 texcoord;
void main() {
	vec2 uv=texcoord;
	if(sourceTarget!=0) uv.y=1.0-uv.y;
	vec4 c=texture2D(image,uv);
	if(coverage!=0) c.rgb=vec3(1.0);
	if(sourcePremult!=0) {
		if(c.a>0.0) c.rgb/=c.a;
		else c.rgb=vec3(0.0);
	}

"""
Const fragmentFooter:String = """
	if(mask!=0 && c.a<0.5) discard;
	if(premultiply!=0) c.rgb*=c.a;
	gl_FragColor=c;
}
"""
Const saturationBody:String = """
	c*=tint;
	float luminance=dot(c.rgb,vec3(0.2126,0.7152,0.0722));
	c.rgb=mix(vec3(luminance),c.rgb,parameters.x);

"""
Const colorizeBody:String = """
	c=vec4(parameters.rgb,c.a)*tint;

"""

Type TGLImageEffectBackend Extends TMax2DImageEffectBackend
	Method Handles:Int(context:TMax2DContext,effect:TMax2DImageEffect) Override
		Return TGLMax2DContext(context)<>Null And (TMax2DSaturationEffect(effect)<>Null Or TMax2DColorizeEffect(effect)<>Null)
	End Method

	Method Supports:Int(canvas:TMax2DGraphics,effect:TMax2DImageEffect) Override
		Local context:TGLMax2DContext=TGLMax2DContext(canvas.context)
		Return GetShader(context,effect)<>Null And context.SupportsBlend(canvas.state.blend)
	End Method

	Method Draw(canvas:TMax2DGraphics,image:TImage,effect:TMax2DImageEffect,x:Float,y:Float,frame:Int) Override
		DrawMany(canvas,image,effect,Null,x,y,frame)
	End Method

	Method DrawBatch(canvas:TMax2DGraphics,image:TImage,effect:TMax2DImageEffect,positions:Float[],frame:Int) Override
		DrawMany(canvas,image,effect,positions,0,0,frame)
	End Method

	Private
	Method GetShader:Byte Ptr(context:TGLMax2DContext,effect:TMax2DImageEffect)
		context.CheckOpen()
		context.Activate()
		Local key:Byte Ptr=Varptr saturationKey
		If TMax2DColorizeEffect(effect) Then key=Varptr colorizeKey
		Local shader:Byte Ptr=m2d_gl_find_image_effect(context.native,key)
		If shader Then Return shader
		Local body:String=saturationBody
		If TMax2DColorizeEffect(effect) Then body=colorizeBody
		Local source:Byte Ptr=(fragmentHeader+body+fragmentFooter).ToUTF8String()
		Try
			Return m2d_gl_create_image_effect(context.native,key,source)
		Finally
			MemFree(source)
		End Try
	End Method

	Method DrawMany(canvas:TMax2DGraphics,image:TImage,effect:TMax2DImageEffect,positions:Float[],x:Float,y:Float,frame:Int)
		Local context:TGLMax2DContext=TGLMax2DContext(canvas.context)
		Local shader:Byte Ptr=GetShader(context,effect)
		context.Require(shader<>Null)
		context.Flush()
		Local saturation:TMax2DSaturationEffect=TMax2DSaturationEffect(effect)
		If saturation Then
			m2d_gl_select_image_effect(context.native,shader,saturation.GetAmount(),0,0,0)
		Else
			Local red:Int,green:Int,blue:Int
			TMax2DColorizeEffect(effect).GetColor(red,green,blue)
			m2d_gl_select_image_effect(context.native,shader,red/255.0,green/255.0,blue/255.0,0)
		End If
		Try
			If positions Then
				For Local i:Int=0 Until positions.Length Step 2
					canvas.DrawImage(image,positions[i],positions[i+1],frame)
				Next
			Else
				canvas.DrawImage(image,x,y,frame)
			End If
			context.Flush()
		Catch error:Object
			context.batchCount=0
			context.batchFrame=Null
			Throw error
		Finally
			m2d_gl_select_image_effect(context.native,Null,0,0,0,0)
		End Try
	End Method
End Type

Extern "C"
	Function m2d_gl_find_image_effect:Byte Ptr(context:Byte Ptr,key:Byte Ptr)
	Function m2d_gl_create_image_effect:Byte Ptr(context:Byte Ptr,key:Byte Ptr,source:Byte Ptr)
	Function m2d_gl_select_image_effect(context:Byte Ptr,shader:Byte Ptr,x:Float,y:Float,z:Float,w:Float)
End Extern

RegisterMax2DImageEffectBackend(New TGLImageEffectBackend)
