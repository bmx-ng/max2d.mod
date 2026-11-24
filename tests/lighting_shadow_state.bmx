SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3GPUMax2D
?
?max2d_gl
Import Max2D.GLEffects
?max2d_d3d9
Import Max2D.D3D9Effects
?max2d_d3d11
Import Max2D.D3D11Effects
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
Import Max2D.SDL3GPUEffects
?
Import Max2D.Lighting
Import BRL.StandardIO
Global checks:Int
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
 checks:+1
End Function
Function CheckCaller(canvas:TMax2DGraphics,target:TRenderImage,state:TMax2DState)
 Check(canvas.state=state And canvas.renderImage=target,"caller state identity and target restored")
 Check(state.red=17 And state.green=29 And state.blue=43 And Abs(state.alpha-0.4)<0.001,"caller colour untouched")
 Check(state.camera And state.camera.x=19 And state.rotation=31,"caller camera and transform untouched")
 Check(canvas.context.view.width=91 And canvas.context.view.height=73,"caller virtual size untouched")
 Check(canvas.context.view.x=2 And canvas.context.view.y=3 And canvas.context.view.w=40 And canvas.context.view.h=41,"caller clip untouched")
 Check(canvas.saved.Count()=1,"surrounding public scope remains balanced")
End Function
Try
 Graphics(64,64)
 Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
 Local target:TRenderImage=CreateRenderImage(64,64,0)
 Local pixels:TPixmap=CreatePixmap(64,64,PF_RGBA8888);pixels.ClearPixels($ffffffff)
 Local art:TImage=LoadImage(pixels,0),pattern:TImage=LoadImage(pixels,DYNAMICIMAGE)
 SetRenderImage(target)
 Local outer:TMax2DStateScope=ScopedMax2DState()
 SetVirtualResolution(91,73);SetViewport(2,3,40,41)
 Local camera:TCamera2D=New TCamera2D;camera.x=19
 SetCamera(camera);SetRotation(31);SetColor(17,29,43);SetAlpha(0.4)
 Local state:TMax2DState=canvas.state
 For Local directional:Int=0 To 1
  For Local soft:Int=0 To 1
   For Local textured:Int=0 To 1
    If directional And textured Then Continue
    Local lighting:TMax2DLighting=TMax2DLighting.Create(1)
    If directional Then
     lighting.SetDirectionalLight(0,1,1,1)
    Else
     lighting.SetPointLight(0,32,32,100)
    End If
    lighting.SetLightShadows(0,True,32)
    If directional Then lighting.SetDirectionalShadowBounds(0,0,0,64,64)
    lighting.SetLightShadowSoftness(0,soft*2)
    lighting.SetOccluders([TMax2DLightOccluder.Create([24.0,20.0,28.0,20.0,28.0,36.0,24.0,36.0])])
    If textured Then lighting.SetLightTexture(0,TMax2DLightTexture.Create(pattern))
    If textured Then
     LockImage(pattern)
     Local failed:Int
     Try
      lighting.DrawImage(art,0,0)
     Catch error:Object
      failed=True
     Finally
      UnlockImage(pattern)
     End Try
     Check(failed,"locked shadow pattern fails")
     CheckCaller(canvas,target,state)
    End If
    lighting.DrawImage(art,0,0)
    CheckCaller(canvas,target,state)
    lighting.DrawImage(art,0,0)
    CheckCaller(canvas,target,state)
    lighting.Release()
   Next
  Next
 Next
 outer.Close()
 SetRenderImage(Null);target.ReleaseFrames();art.ReleaseFrames();pattern.ReleaseFrames()
 EndGraphics()
 Check(canvas.context.frames.IsEmpty(),"context releases all frames")
 Print "PASS: "+checks+" lighting shadow state checks"
Catch error:Object
 Print "FAIL: "+error.ToString()
 EndGraphics();EndWithCode(1)
End Try
