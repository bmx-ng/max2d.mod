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
Import Max2D.Effects
Import BRL.StandardIO
Global checks:Int
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
 checks:+1
End Function
Function Verify(canvas:TMax2DGraphics,layer:TRenderImage,state:TMax2DState,before:TMax2DState)
 Check(canvas.state=state And canvas.renderImage=layer,"state identity and target preserved")
 Check(canvas.context.view.width=71 And canvas.context.view.height=73 And canvas.context.view.x=2 And canvas.context.view.y=3 And canvas.context.view.w=17 And canvas.context.view.h=19,"view restored")
 Check(canvas.saved.Count()=1,"enclosing scope balanced")
 Check(state.red=before.red And state.green=before.green And state.blue=before.blue And state.colorByteAlpha=before.colorByteAlpha And state.alpha=before.alpha And state.blend=before.blend,"drawing colour and blend")
 Check(state.ix=before.ix And state.iy=before.iy And state.jx=before.jx And state.jy=before.jy And state.originX=before.originX And state.originY=before.originY And state.handleX=before.handleX And state.handleY=before.handleY,"object affine transform, origin and handle")
 Check(state.coordXX=before.coordXX And state.coordXY=before.coordXY And state.coordYX=before.coordYX And state.coordYY=before.coordYY And state.coordTX=before.coordTX And state.coordTY=before.coordTY,"parent coordinates")
 Check(state.camera And state.camera.x=19 And state.cameraXX=before.cameraXX And state.cameraXY=before.cameraXY And state.cameraYX=before.cameraYX And state.cameraYY=before.cameraYY And state.cameraTX=before.cameraTX And state.cameraTY=before.cameraTY,"camera transform")
 Check(state.rotation=before.rotation And state.scaleX=before.scaleX And state.scaleY=before.scaleY And state.lineWidth=before.lineWidth And state.clsRed=before.clsRed And state.clsAlpha=before.clsAlpha And state.clsByteAlpha=before.clsByteAlpha,"untouched drawing settings")
End Function
Try
 Graphics(64,64)
 Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
 Local target:TRenderImage=CreateRenderImage(32,32,0)
 Local layer:TMax2DEffectLayer=New TMax2DEffectLayer
 layer.Prepare(16,16,2,3,4,5,2)
 SetRenderImage(target)
 Local outer:TMax2DStateScope=ScopedMax2DState()
 SetVirtualResolution(71,73);SetViewport(2,3,17,19)
 SetColor(17,29,43);SetAlpha(0.4);SetBlend(LIGHTBLEND)
 SetTransform(31,2,3);SetAffineTransform(2,0.3,-0.2,3)
 TransformCoordinates(1.2,0.5,-0.4,2,13,17);SetOrigin(7,11);SetHandle(3,5)
 Local camera:TCamera2D=New TCamera2D;camera.x=19;camera.zoom=2;camera.rotation=23
 SetCamera(camera);SetClsColor(7,11,13,0.6);SetLineWidth(3)
 Local state:TMax2DState=canvas.state
 state.colorByteAlpha=91;state.clsByteAlpha=123
 Local before:TMax2DState=state.Copy()
 Local old:TMax2DStateScope=layer.Capture(False)
 Check(canvas.state.lineWidth=3 And canvas.state.clsRed=7 And canvas.state.clsGreen=11 And canvas.state.clsBlue=13 And Abs(canvas.state.clsAlpha-0.6)<0.001 And canvas.state.clsByteAlpha=123,"capture inherits line and clear settings")
 SetColor(1,2,3);SetClsColor(4,5,6);SetLineWidth(7)
 old.Close();Verify(canvas,target,state,before)
 Local current:TMax2DStateScope=layer.Capture()
 old.Close()
 Check(canvas.renderImage=layer.Image() And current.entry.active And canvas.saved.Count()=2,"closed old handle cannot close new capture")
 current.Close();Verify(canvas,target,state,before)
 Local enclosing:TMax2DStateScope=ScopedMax2DState()
 old=layer.Capture()
 enclosing.Close()
 state=canvas.state
 Verify(canvas,target,state,before)
 current=layer.Capture(False)
 old.Close()
 Check(canvas.renderImage=layer.Image() And current.entry.active And canvas.saved.Count()=2,"unwound old handle cannot close new capture")
 current.Close();Verify(canvas,target,state,before)
 Local failed:Int
 Try
  current=layer.Capture()
  Try
   Throw "injected capture failure"
  Finally
   current.Close()
  End Try
 Catch error:Object
  failed=True
 End Try
 Check(failed,"capture exception reached")
 Verify(canvas,target,state,before)
 Local start:SGCStats,finish:SGCStats
 GCCollect();GCGetStats(start)
 For Local i:Int=0 Until 1000
  current=layer.Capture(False)
  current.Close()
 Next
 GCGetStats(finish)
 Local bytes:Long=Long(finish.allocedBytesBeforeGC)+Long(finish.bytesAllocedSinceGC)-Long(start.allocedBytesBeforeGC)-Long(start.bytesAllocedSinceGC)
 Check(bytes<368000,"warm captures reduce allocation while retaining fresh handles")
 Verify(canvas,target,state,before)
 outer.Close();SetRenderImage(Null);layer.Release();target.ReleaseFrames();EndGraphics()
 Check(canvas.context.frames.IsEmpty(),"native frame cleanup")
 Print "PASS: "+checks+" capture state checks; 1000 captures allocated "+bytes+" bytes"
Catch error:Object
 Print "FAIL: "+error.ToString()
 EndGraphics();EndWithCode(1)
End Try
