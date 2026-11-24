SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
?Not max2d_gl
Framework Max2D.SDL3GPUMax2D
?
Import Max2D.LightingNative
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
 Local atlas:TMax2DLightingAtlas=New TMax2DLightingAtlas
 atlas.Prepare(32,32,4)
 Local pixels:TPixmap=CreatePixmap(8,8,PF_RGBA8888);pixels.ClearPixels($ff234567)
 Local image:TImage=LoadImage(pixels,DYNAMICIMAGE),target:TRenderImage=CreateRenderImage(64,64,0)
 Local light:TMax2DLightingDrawLight=New TMax2DLightingDrawLight
 light.map=image;light.mapKey=image;light.mapRevision=1
 SetRenderImage(target)
 Local outer:TMax2DStateScope=ScopedMax2DState()
 SetVirtualResolution(91,73);SetViewport(2,3,40,41)
 Local camera:TCamera2D=New TCamera2D;camera.x=19
 SetCamera(camera);SetRotation(31);SetColor(17,29,43);SetAlpha(0.4)
 Local state:TMax2DState=canvas.state
 Local tile:TMax2DLightingAtlasTile=atlas.Resolve(light)
 Check(tile And tile.valid,"initial atlas copy")
 CheckCaller(canvas,target,state)
 Check((ReadRenderImage(atlas.image).ReadPixel(tile.x+2,tile.y+2)&$ffffff)=$234567,"atlas copy pixels ignore caller tint and transform")
 light.mapRevision:+1
 LockImage(image)
 Local failed:Int
 Try
  atlas.Resolve(light)
 Catch error:Object
  failed=True
 Finally
  UnlockImage(image)
 End Try
 Check(failed And Not tile.valid,"failed copy invalidates tile")
 CheckCaller(canvas,target,state)
 Check(atlas.Resolve(light)=tile And tile.valid,"retry reuses and validates tile")
 CheckCaller(canvas,target,state)
 Local before:SGCStats,after:SGCStats
 GCCollect();GCGetStats(before)
 For Local i:Int=0 Until 1000
  light.mapRevision:+1;atlas.Resolve(light)
 Next
 GCGetStats(after)
 Local bytes:Long=Long(after.allocedBytesBeforeGC)+Long(after.bytesAllocedSinceGC)-Long(before.allocedBytesBeforeGC)-Long(before.bytesAllocedSinceGC)
 Check(bytes=0,"1000 warm atlas copies allocate zero bytes")
 CheckCaller(canvas,target,state)
 outer.Close()
 SetRenderImage(Null);atlas.Release();target.ReleaseFrames();image.ReleaseFrames()
 EndGraphics()
 Check(canvas.context.frames.IsEmpty(),"context releases all frames")
 Print "PASS: "+checks+" lighting atlas state checks; 1000 copies allocated "+bytes+" bytes"
Catch error:Object
 Print "FAIL: "+error.ToString()
 EndGraphics();EndWithCode(1)
End Try
