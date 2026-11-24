SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?max2d_d3d9
Framework Max2D.D3D9Max2D
Import Max2D.D3D9Effects
?max2d_d3d11
Framework Max2D.D3D11Max2D
Import Max2D.D3D11Effects
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?
Import BRL.StandardIO

Global checks:Int
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
 checks:+1
End Function
Type TProbeFrame Extends TImageFrame
 Method NativeDestroy() Override
 End Method
End Type
Type TLegacyAdapter Extends TMax2DShaderPackageBackend
 Field calls:Int,second:TImageFrame
 Method Handles:Int(context:TMax2DContext) Override;Return context<>Null;End Method
 Method Shader:Byte Ptr(context:TMax2DContext,package:Byte Ptr) Override;Return package;End Method
 Method SelectShader(context:TMax2DContext,shader:Byte Ptr,values:Float Ptr,second:TImageFrame) Override
  calls:+1;Self.second=second
 End Method
 Method ClearShader(context:TMax2DContext) Override;second=Null;End Method
End Type
Type TThreeAdapter Extends TLegacyAdapter
 Field third:TImageFrame
 Method SelectTextures(context:TMax2DContext,shader:Byte Ptr,values:Float Ptr,second:TImageFrame,third:TImageFrame) Override
  calls:+1;Self.second=second;Self.third=third
 End Method
End Type
Type TExtendedAdapter Extends TLegacyAdapter
 Field captured:TImageFrame[4],active:Int
 Method MaximumTextures:Int(context:TMax2DContext) Override;Return 5;End Method
 Method BindTextureSet(context:TMax2DContext,shader:Byte Ptr,values:Float Ptr,textures:TImageFrame[],count:Int) Override
  calls:+1;active=count
  For Local i:Int=0 Until captured.Length
   captured[i]=Null
   If i<count Then captured[i]=textures[i]
  Next
 End Method
End Type
Try
 Graphics(16,16)
 Local context:TMax2DContext=TMax2DGraphics.Current().context
 Local native:TMax2DShaderPackageBackend=Max2DShaderPackageAdapter(context)
 Check(native And native.MaximumTextures(context)=5,"native transport reports five total textures")
 Local a:TProbeFrame=New TProbeFrame,b:TProbeFrame=New TProbeFrame
 a.owner=context;b.owner=context
 Local frames:TImageFrame[]=[a,b,a,b,Null]
 Local legacy:TLegacyAdapter=New TLegacyAdapter,three:TThreeAdapter=New TThreeAdapter,extended:TExtendedAdapter=New TExtendedAdapter
 Local shader:Byte Ptr=Byte Ptr(1)
 legacy.SelectTextureSet(context,shader,Null,frames,0)
 Check(legacy.calls=1 And Not legacy.second,"zero auxiliaries use existing one-texture selection")
 legacy.SelectTextureSet(context,shader,Null,frames,1)
 Check(legacy.calls=2 And legacy.second=a,"one auxiliary uses legacy selection")
 Local rejected:Int
 Try
  legacy.SelectTextureSet(context,shader,Null,frames,2)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And legacy.calls=2 And legacy.second=a,"legacy third-texture rejection leaves selection intact")
 three.SelectTextureSet(context,shader,Null,frames,2)
 Check(three.calls=1 And three.second=a And three.third=b,"existing three-texture override is preserved")
 extended.SelectTextureSet(context,shader,Null,frames,4)
 Check(extended.calls=1 And extended.active=4,"extended adapter receives the full prefix")
 frames[0]=Null
 Check(extended.captured[0]=a,"provider captures array contents before caller reuse")
 frames[0]=a
 For Local invalid:Int=0 Until 7
  rejected=False
  Local count:Int=2,selectedShader:Byte Ptr=shader
  Select invalid
   Case 0;count=-1
   Case 1;count=6
   Case 2;count=3
   Case 3;frames[1]=Null
   Case 4;b.closed=True
   Case 5;b.owner=Null
   Case 6;selectedShader=Null
  End Select
  Try
   three.SelectTextureSet(context,selectedShader,Null,frames,count)
  Catch error:Object
   rejected=True
  End Try
  Check(rejected And three.calls=1 And three.second=a And three.third=b,"invalid binding preserves selection "+invalid)
  frames[1]=b;b.closed=False;b.owner=context
 Next
 Local target:TRenderImage=CreateRenderImage(16,16,0)
 SetRenderImage(target)
 frames[1]=context.target;rejected=False
 Try
  three.SelectTextureSet(context,shader,Null,frames,2)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And three.calls=1,"destination feedback rejected before provider selection")
 frames[1]=b;frames[2]=context.target
 three.SelectTextureSet(context,shader,Null,frames,2)
 Check(three.calls=2,"unused array capacity is ignored")
 frames[1]=a
 three.SelectTextureSet(context,shader,Null,frames,2)
 Check(three.calls=3 And three.second=three.third,"repeated auxiliary images are valid")
 extended.SelectTextureSet(context,shader,Null,Null,0)
 Check(extended.active=0 And Not extended.captured[0],"zero-prefix reuse clears captured bindings")
 SetRenderImage(Null);target.ReleaseFrames();EndGraphics()
 rejected=False
 Try
  three.SelectTextureSet(context,shader,Null,frames,0)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And three.calls=3,"closed context rejected before provider selection")
 Print "PASS: "+checks+" texture binding checks"
Catch error:Object
 Print "FAIL: after "+checks+" checks: "+error.ToString()
 EndWithCode(1)
End Try
