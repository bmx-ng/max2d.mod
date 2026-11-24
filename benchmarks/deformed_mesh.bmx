SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?Not max2d_gl
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?
Import Max2D.Lighting
Import SDL3.SDL3
Import BRL.StandardIO
Extern "C"
 Function SDL_GetTicksNS:ULong()
End Extern
Global whole:Int
Type TReferenceRenderer Extends TMax2DLightingRenderer
 Field native:TMax2DLightingRenderer,limits:TMax2DLightingCapabilities
 Method Capabilities:TMax2DLightingCapabilities() Override;Return limits;End Method
 Method Supports:Int(canvas:TMax2DGraphics,draw:TMax2DLightingDraw) Override;Return native.Supports(canvas,draw);End Method
 Method Draw(canvas:TMax2DGraphics,draw:TMax2DLightingDraw) Override;native.Draw(canvas,draw);End Method
 Method Release() Override;native.Release();End Method
End Type
Type TReferenceBackend Extends TMax2DLightingBackend
 Method CreateRenderer:TMax2DLightingRenderer(context:TMax2DContext) Override
  Local result:TReferenceRenderer=New TReferenceRenderer
  result.native=CreateNativeMax2DLightingRenderer(context)
  result.limits=TMax2DLightingCapabilities.Create(1,result.native.Capabilities().MaximumLights(),True,True,True,True,True,True,True,True,whole,whole)
  Return result
 End Method
End Type
Function Solid:TImage(colour:Int)
 Local pix:TPixmap=CreatePixmap(64,64,PF_RGBA8888);pix.ClearPixels(colour)
 Return LoadImage(pix,0)
End Function
Function Deform(mesh:TMesh2D,tick:Int)
 For Local y:Int=0 To 8
  For Local x:Int=0 To 8
   Local p:Int=(y*9+x)*2
   mesh.xy[p]=32+x*24;mesh.xy[p+1]=32+y*24
   If x>0 And x<8 And y>0 And y<8 Then mesh.xy[p+1]:+((x+y) Mod 2)*(3+(tick Mod 2))
  Next
 Next
End Function
Try
 Graphics(256,256)
 RegisterMax2DLightingBackend(New TReferenceBackend)
 Local xy:Float[162],uv:Float[162],indices:Int[384]
 For Local y:Int=0 To 8
  For Local x:Int=0 To 8
   Local p:Int=(y*9+x)*2
   xy[p]=32+x*24;xy[p+1]=32+y*24;uv[p]=Float(x)/8;uv[p+1]=Float(y)/8
  Next
 Next
 For Local y:Int=0 Until 8
  For Local x:Int=0 Until 8
   Local a:Int=y*9+x,k:Int=(y*8+x)*6
   indices[k]=a;indices[k+1]=a+1;indices[k+2]=a+10
   indices[k+3]=a;indices[k+4]=a+10;indices[k+5]=a+9
  Next
 Next
 Local mesh:TMesh2D=TMesh2D.Create(xy,indices,uv)
 Local art:TImage=Solid($a0608090),normal:TImage=Solid($ffb080ed),emission:TImage=Solid($8020a0ff)
 Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 material.SetNormalMap(normal);material.SetSpecular(0.4,16);material.SetEmission(100,180,255,0.25);material.SetEmissionMap(emission)
 Local target:TRenderImage=CreateRenderImage(256,256,0)
 SetRenderImage(target);SetVirtualResolution(256,256);SetViewport(0,0,256,256);SetClsColor(20,30,40,0.3)
 Local lights:TMax2DLighting[2]
 For Local path:Int=0 To 1
  whole=path
  lights[path]=TMax2DLighting.Create(17);lights[path].SetLightBatching(True);lights[path].SetAmbient(255,255,255,0.1)
  For Local i:Int=0 Until 17
   lights[path].SetPointLight(i,80+i*6,64,320,255,180,120,0.025,1);lights[path].SetLightHeight(i,48)
  Next
  Deform(mesh,0);Cls;lights[path].DrawMesh(mesh,art,0,0,0,-1,1,0,0,1,0,0,material)
 Next
 Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
 Print "path,edited,trial,triangles,lights,frames,draw_us,drained_us,groups_per_frame,ambient_per_frame"
 For Local edited:Int=0 To 1
  For Local trial:Int=1 To 3
   ' Compare the actual deformed receiver, not a sprite approximation.
   Deform(mesh,trial)
   Cls;lights[0].DrawMesh(mesh,art,0,0,0,-1,1,0,0,1,0,0,material)
   Local reference:TPixmap=ReadRenderImage(target)
   Cls;lights[1].DrawMesh(mesh,art,0,0,0,-1,1,0,0,1,0,0,material)
   Local result:TPixmap=ReadRenderImage(target)
   For Local y:Int=0 Until 256
    For Local x:Int=0 Until 256
     For Local channel:Int=0 To 24 Step 8
      If Abs((reference.ReadPixel(x,y) Shr channel & 255)-(result.ReadPixel(x,y) Shr channel & 255))>2 Then Throw "pixel comparison failed"
     Next
    Next
   Next
   For Local path:Int=0 To 1
    Local drawNS:ULong,drainedNS:ULong,frames:Int=120
    Deform(mesh,0)
    For Local tick:Int=-8 Until frames
     If tick=0 Then lights[path].ResetStats()
     If edited Then Deform(mesh,tick)
     Local start:ULong=SDL_GetTicksNS()
     Cls;lights[path].DrawMesh(mesh,art,0,0,0,-1,1,0,0,1,0,0,material);FlushMax2D()
     Local submitted:ULong=SDL_GetTicksNS()
     canvas.context.Read(canvas.context.target,0,0,1,1)
     If tick>=0 Then drawNS:+submitted-start;drainedNS:+SDL_GetTicksNS()-start
    Next
    Local stats:TMax2DLightingStats=lights[path].CaptureStats(),units:Int=128
    If path Then units=1
    If stats.GroupedPasses()<>Long(frames)*units*((17+stats.MaximumGroupSize()-1)/stats.MaximumGroupSize()) Then Throw "unexpected grouped count"
    If stats.AmbientPasses()<>Long(frames)*units Then Throw "unexpected ambient count"
    Print path+","+edited+","+trial+",128,17,"+frames+","+(Double(drawNS)/frames/1000)+","+(Double(drainedNS)/frames/1000)+","+(Double(stats.GroupedPasses())/frames)+","+(Double(stats.AmbientPasses())/frames)
   Next
  Next
 Next
 For Local light:TMax2DLighting=EachIn lights
  light.Release()
 Next
 material.ReleaseResources();SetRenderImage(Null);target.ReleaseFrames();art.ReleaseFrames();normal.ReleaseFrames();emission.ReleaseFrames()
 EndGraphics
Catch error:Object
 Print "FAIL: "+error.ToString();EndGraphics();EndWithCode(1)
End Try
