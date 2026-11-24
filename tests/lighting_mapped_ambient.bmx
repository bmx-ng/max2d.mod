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
Import Max2D.Lighting
Import BRL.StandardIO

Global checks:Int,combined:Int,textureLimit:Int=5,rejectExtended:Int
Extern "C"
 Function m2d_native_lighting_assets_material:Byte Ptr()
 Function m2d_native_lighting_assets_material_16:Byte Ptr()
End Extern
Type TLimitedTextureBackend Extends TMax2DShaderPackageBackend
 Field real:TMax2DShaderPackageBackend
 Method Handles:Int(context:TMax2DContext) Override;Return real.Handles(context);End Method
 Method MaximumTextures:Int(context:TMax2DContext) Override;Return textureLimit;End Method
 Method Shader:Byte Ptr(context:TMax2DContext,package:Byte Ptr) Override
  If rejectExtended And (package=m2d_native_lighting_assets_material() Or package=m2d_native_lighting_assets_material_16()) Then Return Null
  Return real.Shader(context,package)
 End Method
 Method SupportsShader:Int(canvas:TMax2DGraphics,shader:Byte Ptr) Override;Return real.SupportsShader(canvas,shader);End Method
 Method SelectShader(context:TMax2DContext,shader:Byte Ptr,values:Float Ptr,second:TImageFrame) Override;real.SelectShader(context,shader,values,second);End Method
 Method SelectTextures(context:TMax2DContext,shader:Byte Ptr,values:Float Ptr,second:TImageFrame,third:TImageFrame) Override;real.SelectTextures(context,shader,values,second,third);End Method
 Method BindTextureSet(context:TMax2DContext,shader:Byte Ptr,values:Float Ptr,textures:TImageFrame[],count:Int) Override;real.SelectTextureSet(context,shader,values,textures,count);End Method
 Method ClearShader(context:TMax2DContext) Override;real.ClearShader(context);End Method
End Type
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
 checks:+1
End Function
Type TEmissionRenderer Extends TMax2DLightingRenderer
 Field native:TMax2DLightingRenderer,limits:TMax2DLightingCapabilities
 Method Capabilities:TMax2DLightingCapabilities() Override;Return limits;End Method
 Method Supports:Int(canvas:TMax2DGraphics,draw:TMax2DLightingDraw) Override;Return native.Supports(canvas,draw);End Method
 Method Draw(canvas:TMax2DGraphics,draw:TMax2DLightingDraw) Override;native.Draw(canvas,draw);End Method
 Method Release() Override;native.Release();End Method
End Type
Type TEmissionBackend Extends TMax2DLightingBackend
 Method CreateRenderer:TMax2DLightingRenderer(context:TMax2DContext) Override
  Local result:TEmissionRenderer=New TEmissionRenderer
  result.native=CreateNativeMax2DLightingRenderer(context)
  result.limits=TMax2DLightingCapabilities.Create(1,result.native.Capabilities().MaximumLights(),True,True,True,True,True,True,True,True,True,True,combined)
  Return result
 End Method
End Type
Function Solid:TImage(colour:Int,flags:Int=0)
 Local pixels:TPixmap=CreatePixmap(16,16,PF_RGBA8888);pixels.ClearPixels(colour)
 Return LoadImage(pixels,flags)
End Function
Function RenderReceiver(light:TMax2DLighting,art:TImage,material:TMax2DLightingMaterial,mesh:TMesh2D,geometry:Int)
 If geometry Then light.DrawMesh(mesh,art,16,16,0,-1,1,0,0,1,0,0,material) Else light.DrawImage(art,16,16,0,-1,1,0,0,1,0,0,material)
End Function
Function Compare(a:TPixmap,b:TPixmap,label:String)
 Local difference:Int
 For Local y:Int=0 Until a.height
  For Local x:Int=0 Until a.width
   For Local channel:Int=0 To 24 Step 8
    difference=Max(difference,Abs((a.ReadPixel(x,y) Shr channel & 255)-(b.ReadPixel(x,y) Shr channel & 255)))
   Next
  Next
 Next
 Check(difference<=3,label+": maximum channel difference "+difference)
End Function
Try
 Graphics(64,64)
 Local adapter:TLimitedTextureBackend=New TLimitedTextureBackend
 adapter.real=Max2DShaderPackageAdapter(TMax2DGraphics.Current().context)
 RegisterShaderPackageBackend(adapter)
 Check(Not TMax2DLightingCapabilities.Create(1,8).MappedEmission(),"legacy providers default to separate emission")
 Local rejected:Int
 Try
  TMax2DLightingCapabilities.Create(1,8,False,False,False,False,False,False,False,False,False,False,True)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"mapped emission requires ambient composition")
 RegisterMax2DLightingBackend(New TEmissionBackend)
 Local art:TImage=Solid($986080a0),normal:TImage=Solid($80a080ef),gloss:TImage=Solid($ff800000)
 Local pixels:TPixmap=CreatePixmap(16,16,PF_RGBA8888)
 For Local y:Int=0 Until 16
  For Local x:Int=0 Until 16
   pixels.WritePixel(x,y,((32+x*12) Shl 24)|((x*16) Shl 16)|((y*16) Shl 8)|128)
  Next
 Next
 Local emission:TImage=LoadImage(pixels,0),filtered:TImage=LoadImage(pixels,FILTEREDIMAGE)
 Local alpha:TImage=TImage.FromPixmap(pixels.Convert(PF_A8),FILTEREDIMAGE,PF_A8)
 Local signedPixels:Float[]=[-0.8,-0.2,0.1,1.0],signedBytes:Byte[16]
 MemCopy(signedBytes,signedPixels,16)
 Local signedEmission:TImage=LoadImage(TTextureData.Create([TTextureLevel.Create(1,1,PF_RGBA32F,signedBytes)]),0)
 Local atlas:TImage=TImage.View(filtered,4,2,8,10),trimmed:TImage=TImage.View(filtered,4,2,8,10)
 trimmed.SetTrim(0,2,1,4,8)
 Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 material.SetNormalMap(normal);material.SetSpecular(0.2,16);material.SetSpecularMap(gloss)
 Local mesh:TMesh2D=TMesh2D.Create([0.0,0.0,16.0,0.0,16.0,16.0,0.0,16.0],[0,1,2,0,2,3],[0.0,0.0,1.0,0.0,1.0,1.0,0.0,1.0])
 Local pattern:TMax2DLightTexture=TMax2DLightTexture.Create(filtered)
 Local target:TRenderImage=CreateRenderImage(64,64,0),hdr:TRenderImage
 If Max2DSupportsRenderImage(64,64,0,PF_RGBA16F) Then hdr=CreateRenderImage(64,64,0,PF_RGBA16F)
 Local rendered:TRenderImage=CreateRenderImage(16,16,FILTEREDIMAGE)
 SetRenderImage(rendered);SetVirtualResolution(16,16);SetViewport(0,0,16,16)
 SetClsColor(20,80,160,0.4);Cls
 For Local variant:Int=0 To 19
  Local hdrVariant:Int=variant=6 Or variant=18
  If hdrVariant And Not hdr Then Continue
  Local selected:TRenderImage=target
  If hdrVariant Then selected=hdr
  SetRenderImage(selected);SetVirtualResolution(64,64);SetViewport(0,0,64,64)
  SetClsColor(20,30,40,0.3);SetColor(180,210,230);SetAlpha(0.7)
  material.SetEmission(120,180,240,0.8);material.SetEmissionMap(emission)
  Select variant
   Case 1;material.SetEmissionMap(filtered)
   Case 2;material.SetEmissionMap(alpha)
   Case 3;material.SetEmissionMap(atlas)
   Case 4;material.SetEmissionMap(trimmed)
   Case 5;material.SetEmissionMap(rendered)
   Case 6,12,18,19;material.SetEmission(120,180,240,8)
   Case 13;material.SetEmission(120,180,240,0)
   Case 14;material.SetEmissionMap(signedEmission)
   Case 15;material.SetEmissionMap(alpha)
   Case 16;material.SetEmissionMap(rendered)
   Case 17;material.SetEmissionMap(trimmed)
  End Select
  For Local geometry:Int=0 To 2
   mesh.xy[4]=16
   If geometry=2 Then mesh.xy[4]=13
   Local reference:TPixmap,referenceHDR:TTextureData,referencePasses:Long
   For Local path:Int=0 To 3
    combined=path<>0
    textureLimit=5;rejectExtended=path=3
    If path=2 Then textureLimit=3
    Local light:TMax2DLighting=TMax2DLighting.Create(17)
    light.SetLightBatching(True);light.SetAmbient(160,180,200,0.2)
    For Local i:Int=0 Until 17
     light.SetDirectionalLight(i,0.2,0.1,1,200,180,160,0.015)
    Next
    If variant=7 Or variant=15 Or variant=17 Or variant=18 Or variant=19 Then light.SetPointLight(0,32,32,100,200,180,160,0.015);light.SetLightTexture(0,pattern)
    If variant=8 Then light.SetPointLight(16,32,32,100,200,180,160,0.015);light.SetLightTexture(16,pattern)
    If variant=9 Or variant=16 Then light.SetLightShadows(0,True,32);light.SetDirectionalShadowBounds(0,0,0,64,64)
    If variant=19 Then
     light.SetLightShadows(1,True,32);light.SetDirectionalShadowBounds(1,0,0,64,64)
     light.SetOccluders([TMax2DLightOccluder.Create([24.0,20.0,32.0,20.0,32.0,32.0,24.0,32.0])])
    End If
    If variant=10 Then light.SetLightCount(0)
    If variant=11 Then material.SetReceiverMask(0) Else material.SetReceiverMask(-1)
    Cls;RenderReceiver(light,art,material,mesh,geometry)
    Local actual:TPixmap
    If Not hdrVariant Then actual=ReadRenderImage(selected)
    If Not path Then
     reference=actual
     referencePasses=light.CaptureStats().LightPasses()+light.CaptureStats().AmbientPasses()-light.CaptureStats().CombinedAmbientPasses()
     If hdrVariant Then referenceHDR=ReadRenderTextureData(selected)
    Else
     If Not hdrVariant Then Compare(reference,actual,"emission variant "+variant+" geometry "+geometry)
     Local expected:Int=variant<>10 And variant<>11 And variant<>14
     If path>=2 And (variant=7 Or variant=9 Or variant>=15) Then expected=False
     Check(light.CaptureStats().CombinedAmbientPasses()=expected,"combined emission pass selection variant "+variant)
     Local saving:Int=expected And variant<>13
     Check(referencePasses-(light.CaptureStats().LightPasses()+light.CaptureStats().AmbientPasses()-light.CaptureStats().CombinedAmbientPasses())=saving,"eligible emission saves exactly one submission")
     If hdrVariant Then
      Local data:TTextureData=ReadRenderTextureData(selected)
      Local a:Float Ptr=Float Ptr(referenceHDR.Level().Data()),b:Float Ptr=Float Ptr(data.Level().Data())
      Local difference:Float,maximum:Float
      For Local i:Int=0 Until 64*64*4
       difference=Max(difference,Abs(a[i]-b[i]));maximum=Max(maximum,b[i])
      Next
      Check(difference<0.015 And maximum>1,"HDR emission range and pixel parity")
     End If
     ResetMax2DStats();Cls;RenderReceiver(light,art,material,mesh,geometry);FlushMax2D()
     Check(CaptureMax2DStats().textureCreations=0,"warm combined/fallback emission reuses textures")
    End If
    light.Release()
   Next
  Next
 Next
 ' A rejected feedback source must not corrupt subsequent bindings or blending.
 textureLimit=5;rejectExtended=False
 SetRenderImage(target);SetColor(255,255,255);SetAlpha(1);combined=True
 Local light:TMax2DLighting=TMax2DLighting.Create(1)
 light.SetLightBatching(True);light.SetDirectionalLight(0,0,0,1,255,255,255,0.1)
 material.SetEmission(255,255,255,1);material.SetEmissionMap(target)
 rejected=False;SetBlend(SOLIDBLEND)
 Try
  RenderReceiver(light,art,material,mesh,2)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected And GetBlend()=SOLIDBLEND,"feedback rejected with drawing state restored")
 material.SetEmissionMap(emission);Cls;RenderReceiver(light,art,material,mesh,2);ReadRenderImage(target)
 Check(light.CaptureStats().CombinedAmbientPasses()=1,"combined emission recovers after feedback rejection")
 light.Release();material.ReleaseResources()
 SetRenderImage(Null)
 For Local image:TImage=EachIn [art,normal,gloss,emission,filtered,alpha,atlas,trimmed,rendered,target,hdr,signedEmission]
  If image Then image.ReleaseFrames()
 Next
 EndGraphics()
 Print "PASS: "+checks+" mapped emission checks"
Catch error:Object
 Print "FAIL: after "+checks+" checks: "+error.ToString()
 EndWithCode(1)
End Try
