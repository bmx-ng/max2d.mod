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

' Deliberately uses ordinary copies: pixel fidelity is covered by scaled_blur
' and bloom_pipeline. This provider exposes deterministic runtime failure points.
Global checks:Int,draws:Int,failAt:Int,reenter:Int
Global nestedBlur:TMax2DScaledBlur
Global nestedSource:TRenderImage,nestedDestination:TRenderImage,nestedScratch:TRenderImage
Global empty:TRenderImage[0]
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
 checks:+1
End Function
Type TProbeBackend Extends TMax2DImageEffectBackend
 Method Handles:Int(context:TMax2DContext,effect:TMax2DImageEffect) Override
  Return True
 End Method
 Method Supports:Int(canvas:TMax2DGraphics,effect:TMax2DImageEffect) Override
  Return True
 End Method
 Method Draw(canvas:TMax2DGraphics,image:TImage,effect:TMax2DImageEffect,x:Float,y:Float,frame:Int) Override
  draws:+1
  If draws=failAt Then Throw "injected processor failure"
  If reenter Then
   reenter=False
   nestedBlur.Apply(nestedSource,nestedDestination,empty,nestedScratch)
  End If
  DrawImage(image,x,y,frame)
 End Method
End Type
Function ConfigureCaller()
 SetVirtualResolution(71,73);SetViewport(2,3,17,19)
 SetColor(17,29,43);SetAlpha(0.4);SetRotation(31);SetBlend(LIGHTBLEND)
 Local camera:TCamera2D=New TCamera2D;camera.x=19
 SetCamera(camera)
End Function
Function CheckCaller(canvas:TMax2DGraphics,target:TRenderImage,state:TMax2DState)
 Check(canvas.state=state And canvas.renderImage=target,"caller state identity and target")
 Check(state.red=17 And state.green=29 And state.blue=43 And Abs(state.alpha-0.4)<0.001,"caller colour")
 Check(state.camera And state.camera.x=19 And state.rotation=31 And state.blend=LIGHTBLEND,"caller camera and transform")
 Check(canvas.context.view.width=71 And canvas.context.view.height=73,"caller virtual size")
 Check(canvas.context.view.x=2 And canvas.context.view.y=3 And canvas.context.view.w=17 And canvas.context.view.h=19,"caller viewport")
 Check(canvas.saved.Count()=1,"enclosing public scope balanced")
End Function
Try
 RegisterMax2DImageEffectBackend(New TProbeBackend)
 Graphics(64,64)
 Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
 Local source:TRenderImage=CreateRenderImage(32,32,FILTEREDIMAGE)
 Local destination:TRenderImage=CreateRenderImage(32,32,FILTEREDIMAGE)
 Local scratch:TRenderImage=CreateRenderImage(32,32,FILTEREDIMAGE)
 Local outer:TMax2DStateScope=ScopedMax2DState()
 Local blur:TMax2DScaledBlur=CreateScaledBlur(2)
 For Local target:TRenderImage=EachIn [source,destination,scratch]
  SetRenderImage(target);ConfigureCaller()
  Local state:TMax2DState=canvas.state
  For Local failure:Int=1 To 2
   draws=0;failAt=failure
   Local failed:Int
   Try
    blur.Apply(source,destination,empty,scratch)
   Catch error:Object
    failed=error.ToString()="injected processor failure"
   End Try
   Check(failed,"blur runtime failure reached")
   CheckCaller(canvas,target,state)
   failAt=0;blur.Apply(source,destination,empty,scratch)
   CheckCaller(canvas,target,state)
  Next
 Next
 ' The same descriptor can be entered again by a provider, on separate images.
 nestedBlur=blur
 nestedSource=CreateRenderImage(32,32,FILTEREDIMAGE)
 nestedDestination=CreateRenderImage(32,32,FILTEREDIMAGE)
 nestedScratch=CreateRenderImage(32,32,FILTEREDIMAGE)
 Local state:TMax2DState=canvas.state
 reenter=True;blur.Apply(source,destination,empty,scratch)
 Check(Not reenter,"provider reentered blur")
 CheckCaller(canvas,scratch,state)
 Local buffers:TMax2DEffectBuffers=New TMax2DEffectBuffers
 buffers.Prepare(32,32,2,-1)
 Local effects:TMax2DImageEffect[]=[TMax2DImageEffect(CreateSaturationEffect()),TMax2DImageEffect(CreateColorizeEffect())]
 For Local target:TRenderImage=EachIn [source,buffers.Image(0),buffers.Image(1)]
  SetRenderImage(target);ConfigureCaller();state=canvas.state
  buffers.ApplyChain(source,0,Null);CheckCaller(canvas,target,state)
  For Local failure:Int=1 To 2
   draws=0;failAt=failure
   Local failed:Int
   Try
    buffers.ApplyChain(source,0,effects)
   Catch error:Object
    failed=error.ToString()="injected processor failure"
   End Try
   Check(failed,"retained chain runtime failure reached")
   CheckCaller(canvas,target,state)
   failAt=0;buffers.ApplyChain(source,0,effects)
   CheckCaller(canvas,target,state)
  Next
 Next
 Local before:SGCStats,after:SGCStats
 GCCollect();GCGetStats(before)
 For Local i:Int=0 Until 1000
  buffers.ApplyChain(source,0,effects)
 Next
 GCGetStats(after)
 Local bytes:Long=Long(after.allocedBytesBeforeGC)+Long(after.bytesAllocedSinceGC)-Long(before.allocedBytesBeforeGC)-Long(before.bytesAllocedSinceGC)
 Check(bytes=0,"warm retained chains allocate zero bytes")
 CheckCaller(canvas,buffers.Image(1),state)
 Local bloom:TMax2DBloom=CreateBloom(0,2)
 bloom.Prepare(32,32,0,PF_RGBA8888)
 bloom.Update(source)
 Local result:TRenderImage=bloom.Result()
 SetRenderImage(result);ConfigureCaller();state=canvas.state
 bloom.ValidateSupport();CheckCaller(canvas,result,state)
 For Local failure:Int=1 To 4
  draws=0;failAt=failure
  Local failed:Int
  Try
   bloom.Update(source)
  Catch error:Object
   failed=error.ToString()="injected processor failure"
  End Try
  Check(failed,"bloom runtime failure reached")
  CheckCaller(canvas,result,state)
  failed=False
  Try
   bloom.Result()
  Catch error:Object
   failed=True
  End Try
  Check(failed,"failed rebuild invalidates cached bloom")
  failAt=0;bloom.Update(source)
  Check(bloom.Result()=result,"retry retains bloom storage")
  CheckCaller(canvas,result,state)
 Next
 outer.Close()
 SetRenderImage(Null);bloom.Release();buffers.Release()
 For Local image:TRenderImage=EachIn [source,destination,scratch,nestedSource,nestedDestination,nestedScratch]
  image.ReleaseFrames()
 Next
 EndGraphics()
 Check(canvas.context.frames.IsEmpty(),"native frame cleanup")
 Print "PASS: "+checks+" effect processor state checks"
Catch error:Object
 Print "FAIL: "+error.ToString()
 EndGraphics();EndWithCode(1)
End Try
