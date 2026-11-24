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
 Local layer:TRenderImage=CreateRenderImage(32,32,0)
 Local mask:TImage=CreateImage(32,32,1,DYNAMICIMAGE)
 LockImage(mask).ClearPixels($ffffffff);UnlockImage(mask)
 SetRenderImage(layer)
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
 For Local mode:Int=0 To 2
  Select mode
   Case 0;ApplyLayerAlphaMask(mask)
   Case 1;ApplyLayerInverseAlphaMask(mask)
   Case 2;ApplyLayerOpacity(0.5)
  End Select
  Verify(canvas,layer,state,before)
 Next
 For Local inverse:Int=0 To 1
  LockImage(mask)
  Local failed:Int
  Try
   If inverse Then ApplyLayerInverseAlphaMask(mask) Else ApplyLayerAlphaMask(mask)
  Catch error:Object
   failed=True
  Finally
   UnlockImage(mask)
  End Try
  Check(failed,"locked mask failure reached")
  Verify(canvas,layer,state,before)
  If inverse Then ApplyLayerInverseAlphaMask(mask) Else ApplyLayerAlphaMask(mask)
  Verify(canvas,layer,state,before)
 Next
 Local start:SGCStats,finish:SGCStats
 GCCollect();GCGetStats(start)
 For Local i:Int=0 Until 1000
  ApplyLayerAlphaMask(mask);ApplyLayerInverseAlphaMask(mask);ApplyLayerOpacity(0.5)
 Next
 GCGetStats(finish)
 Local bytes:Long=Long(finish.allocedBytesBeforeGC)+Long(finish.bytesAllocedSinceGC)-Long(start.allocedBytesBeforeGC)-Long(start.bytesAllocedSinceGC)
 Check(bytes=0,"3000 warmed layer operations allocate zero bytes")
 Verify(canvas,layer,state,before)
 outer.Close();SetRenderImage(Null);layer.ReleaseFrames();mask.ReleaseFrames();EndGraphics()
 Check(canvas.context.frames.IsEmpty(),"native frame cleanup")
 Print "PASS: "+checks+" layer operation state checks; 3000 operations allocated "+bytes+" bytes"
Catch error:Object
 Print "FAIL: "+error.ToString()
 EndGraphics();EndWithCode(1)
End Try
