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

Global checks:Int,independent:Int,textureLimit:Int=5,rejectFive:Int,fiveDraws:Int
Extern "C"
 Function m2d_native_lighting_assets_specular:Byte Ptr()
 Function m2d_native_lighting_assets_specular_16:Byte Ptr()
End Extern
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
 checks:+1
End Function
Type TTransport Extends TMax2DShaderPackageBackend
 Field real:TMax2DShaderPackageBackend
 Method Handles:Int(context:TMax2DContext) Override;Return real.Handles(context);End Method
 Method MaximumTextures:Int(context:TMax2DContext) Override;Return textureLimit;End Method
 Method Shader:Byte Ptr(context:TMax2DContext,package:Byte Ptr) Override
  If rejectFive And (package=m2d_native_lighting_assets_specular() Or package=m2d_native_lighting_assets_specular_16()) Then Return Null
  Return real.Shader(context,package)
 End Method
 Method SupportsShader:Int(canvas:TMax2DGraphics,shader:Byte Ptr) Override;Return real.SupportsShader(canvas,shader);End Method
 Method SelectShader(context:TMax2DContext,shader:Byte Ptr,values:Float Ptr,second:TImageFrame) Override;real.SelectShader(context,shader,values,second);End Method
 Method SelectTextures(context:TMax2DContext,shader:Byte Ptr,values:Float Ptr,second:TImageFrame,third:TImageFrame) Override;real.SelectTextures(context,shader,values,second,third);End Method
 Method BindTextureSet(context:TMax2DContext,shader:Byte Ptr,values:Float Ptr,textures:TImageFrame[],count:Int) Override
  If count=4 Then fiveDraws:+1
  real.SelectTextureSet(context,shader,values,textures,count)
 End Method
 Method ClearShader(context:TMax2DContext) Override;real.ClearShader(context);End Method
End Type
Type TRenderer Extends TMax2DLightingRenderer
 Field native:TMax2DLightingRenderer,limits:TMax2DLightingCapabilities
 Method Capabilities:TMax2DLightingCapabilities() Override;Return limits;End Method
 Method Supports:Int(canvas:TMax2DGraphics,draw:TMax2DLightingDraw) Override;Return native.Supports(canvas,draw);End Method
 Method Draw(canvas:TMax2DGraphics,draw:TMax2DLightingDraw) Override;native.Draw(canvas,draw);End Method
 Method Release() Override;native.Release();End Method
End Type
Type TBackend Extends TMax2DLightingBackend
 Method CreateRenderer:TMax2DLightingRenderer(context:TMax2DContext) Override
  Local result:TRenderer=New TRenderer
  result.native=CreateNativeMax2DLightingRenderer(context)
  result.limits=TMax2DLightingCapabilities.Create(1,result.native.Capabilities().MaximumLights(),True,True,True,True,True,True,True,True,True,True,True,independent)
  Return result
 End Method
End Type
Function Solid:TImage(colour:Int,flags:Int=0)
 Local p:TPixmap=CreatePixmap(16,16,PF_RGBA8888);p.ClearPixels(colour)
 Return LoadImage(p,flags)
End Function
Function Render(light:TMax2DLighting,art:TImage,material:TMax2DLightingMaterial,mesh:TMesh2D,geometry:Int)
 If geometry Then light.DrawMesh(mesh,art,16,16,0,-1,1,0,0,1,0,0,material) Else light.DrawImage(art,16,16,0,-1,1,0,0,1,0,0,material)
End Function
Try
 Graphics(64,64)
 Local transport:TTransport=New TTransport
 transport.real=Max2DShaderPackageAdapter(TMax2DGraphics.Current().context)
 RegisterShaderPackageBackend(transport);RegisterMax2DLightingBackend(New TBackend)
 Local art:TImage=Solid($986080a0),normal:TImage=Solid($00a080ef),filteredNormal:TImage=Solid($00a080ef,FILTEREDIMAGE)
 Local p:TPixmap=CreatePixmap(16,16,PF_RGBA8888)
 For Local y:Int=0 Until 16
  For Local x:Int=0 Until 16
   p.WritePixel(x,y,((x*16) Shl 24)|((y*16) Shl 16)|$4080)
  Next
 Next
 Local gloss:TImage=LoadImage(p,0),filtered:TImage=LoadImage(p,FILTEREDIMAGE)
 Local alpha:TImage=TImage.FromPixmap(p.Convert(PF_A8),0,PF_A8)
 Local atlas:TImage=TImage.View(gloss,4,2,8,10),normalAtlas:TImage=TImage.View(normal,4,2,8,10)
 Local emission:TImage=Solid($9080b0ff),pattern:TMax2DLightTexture=TMax2DLightTexture.Create(filtered)
 Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 Local mesh:TMesh2D=TMesh2D.Create([0.0,0.0,16.0,0.0,16.0,16.0,0.0,16.0],[0,1,2,0,2,3],[0.0,0.0,1.0,0.0,1.0,1.0,0.0,1.0])
 Local target:TRenderImage=CreateRenderImage(64,64,0),hdr:TRenderImage
 If Max2DSupportsRenderImage(64,64,0,PF_RGBA16F) Then hdr=CreateRenderImage(64,64,0,PF_RGBA16F)
 For Local variant:Int=0 To 9
  If variant=8 And Not hdr Then Continue
  Local selected:TRenderImage=target
  If variant=8 Then selected=hdr
  SetRenderImage(selected);SetVirtualResolution(64,64);SetViewport(0,0,64,64)
  SetColor(180,210,230);SetAlpha(0.7);SetClsColor(20,30,40,0.3)
  material.SetSpecularMap(Null);material.SetNormalMap(normal);material.SetSpecular(0.4,16);material.SetNormalStrength(1)
  material.SetSpecularFromNormalAlpha(True);material.SetEmission(120,180,240,0.8);material.SetEmissionMap(emission)
  Local selectedGloss:TImage=gloss
  Select variant
   Case 1;selectedGloss=alpha
   Case 2;selectedGloss=atlas;material.SetNormalMap(normalAtlas)
   Case 3;selectedGloss=filtered;material.SetNormalMap(filteredNormal)
   Case 4;selectedGloss=filtered
   Case 5;material.SetNormalMap(Null)
   Case 6;material.SetEmission(120,180,240,0)
   Case 7;material.SetSpecular(0,16)
   Case 8;material.SetEmission(120,180,240,8)
   Case 9;material.SetNormalMap(Null);material.SetNormalStrength(8)
  End Select
  material.SetSpecularMap(selectedGloss)
  For Local geometry:Int=0 To 2
   mesh.xy[4]=16
   If geometry=2 Then mesh.xy[4]=14
   Local reference:TPixmap,referenceHDR:TTextureData
   For Local path:Int=0 To 3
    independent=path<>0;textureLimit=5;rejectFive=path=3
    If path=2 Then textureLimit=4
    Local light:TMax2DLighting=TMax2DLighting.Create(17)
    light.SetLightBatching(True);light.SetAmbient(255,255,255,0.1)
    For Local i:Int=0 Until 17
     light.SetDirectionalLight(i,0.2,0.1,1,200,180,160,0.08)
    Next
    light.SetPointLight(0,32,32,100,200,180,160,0.08);light.SetLightTexture(0,pattern)
    light.SetLightShadows(1,True,32);light.SetDirectionalShadowBounds(1,0,0,64,64)
    light.SetOccluders([TMax2DLightOccluder.Create([24.0,20.0,28.0,20.0,28.0,24.0,24.0,24.0])])
    fiveDraws=0;material.ReleaseResources();Cls;Render(light,art,material,mesh,geometry)
    Local actual:TPixmap
    If variant<>8 Then actual=ReadRenderImage(selected)
    If path=0 Then
     reference=actual
     If variant=8 Then referenceHDR=ReadRenderTextureData(selected)
    Else
     Local difference:Int
     If variant<>8 Then
     For Local y:Int=0 Until 64
      For Local x:Int=0 Until 64
       For Local channel:Int=0 To 24 Step 8
        difference=Max(difference,Abs((actual.ReadPixel(x,y) Shr channel & 255)-(reference.ReadPixel(x,y) Shr channel & 255)))
       Next
      Next
     Next
     End If
     Check(difference<=3,"pixel parity variant "+variant+" geometry "+geometry+" path "+path+" difference "+difference)
     Check((fiveDraws>0)=(path=1 And variant<>4 And variant<>7 And variant<>9),"native five-texture path selection")
     If variant=8 Then
      Local data:TTextureData=ReadRenderTextureData(selected)
      Local a:Float Ptr=Float Ptr(referenceHDR.Level().Data()),b:Float Ptr=Float Ptr(data.Level().Data()),delta:Float,maximum:Float
      For Local i:Int=0 Until 64*64*4
       delta=Max(delta,Abs(a[i]-b[i]));maximum=Max(maximum,b[i])
      Next
      Check(delta<0.015 And maximum>1,"HDR range and parity")
     End If
     ResetMax2DStats();Cls;Render(light,art,material,mesh,geometry);FlushMax2D()
     Check(CaptureMax2DStats().textureCreations=0,"warm native/fallback textures reused")
    End If
    light.Release()
   Next
  Next
 Next
 material.ReleaseResources();SetRenderImage(Null)
 For Local image:TImage=EachIn [art,normal,filteredNormal,gloss,filtered,alpha,atlas,normalAtlas,emission,target,hdr]
  If image Then image.ReleaseFrames()
 Next
 EndGraphics()
 Print "PASS: "+checks+" native specular checks"
Catch error:Object
 Print "FAIL: after "+checks+" checks: "+error.ToString()
 EndWithCode(1)
End Try
