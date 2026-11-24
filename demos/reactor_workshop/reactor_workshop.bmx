SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?Not max2d_gl
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?
Import Max2D.SceneEffects
Import Max2D.ScalableFont
Import BRL.FileSystem
Import BRL.StandardIO
Import Pub.StdC
Include "reactor.bmx"
Include "workshop_tests.bmx"

AppTitle = "Max2D / Reactor Workshop"
Graphics(1100,740)
SetVirtualResolution(1100,740,VIRTUAL_LETTERBOX)
Local path:String
?osx
path = "/System/Library/Fonts/Supplemental/Arial.ttf"
?win32
path = getenv_("WINDIR")+"/Fonts/segoeui.ttf"
?linux
path = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
?
Local font:TImageFont = TImageFont.DefaultFont(), title:TImageFont = font
If FileType(path) = FILETYPE_FILE Then
 font = LoadScalableImageFont(path,16)
 title = LoadScalableImageFont(path,30)
End If
Local housing:TRenderImage = CreateReactorHousing()
Local scene:TScene = TScene.Create()
Local layer:TLayerNode = TLayerNode.Create()
scene.Root().AddChild(layer)
scene.SetStorageLimitBytes(32*1024*1024)
scene.SetInputClip(TSceneRect.Create(0,0,1100,740))
Local reactors:TWorkshopReactor[] = [ ..
 TWorkshopReactor.Create(housing,font,"01 / MOTION",190,295,90,210,255,REACTOR_MOVE), ..
 TWorkshopReactor.Create(housing,font,"02 / ENERGY",550,295,255,170,75,REACTOR_PULSE), ..
 TWorkshopReactor.Create(housing,font,"03 / TURBINE",910,295,200,115,255,REACTOR_SPIN)]
For Local reactor:TWorkshopReactor = EachIn reactors
 layer.AddChild(reactor)
Next
If AppArgs.Length > 1 And AppArgs[1] = "--test" Then
 RunWorkshopTests(scene,layer,reactors)
 scene.Destroy(); housing.ReleaseFrames(); EndGraphics
 End
End If
Local stats:TSceneStats = New TSceneStats
Local selected:Int, previousButton:Int, previousTime:Int = MilliSecs()
Local before:Long[3]
While Not AppTerminate() And Not KeyDown(KEY_ESCAPE)
 Local now:Int = MilliSecs()
 Local dt:Double = Min(0.05,Max(0.0,(now-previousTime)*0.001))
 previousTime = now
 If AppSuspended() Then
  scene.CancelInput(); previousButton = False
 Else
  For Local i:Int = 0 Until 3
   If KeyHit(KEY_1+i) Then selected = i
  Next
  Local mx:Float, my:Float
  Local inside:Int = GetVirtualMouse(mx,my), pressed:Int = MouseDown(1)
  If pressed And Not previousButton Then
   If inside Then scene.DispatchPointer(EScenePointerKind.Down,0,0,mx,my,1,1)
  Else If Not pressed And previousButton Then
   scene.DispatchPointer(EScenePointerKind.Up,0,0,mx,my,1,0)
  Else
   scene.DispatchPointer(EScenePointerKind.Move,0,0,mx,my,0,pressed)
  End If
  previousButton = pressed
  For Local i:Int = 0 Until 3
   If reactors[i].TakeSelection() Then selected = i
  Next
  Local active:TWorkshopReactor = reactors[selected]
  If KeyHit(KEY_M) Then active.SetMode((active.Mode()+1) Mod 4)
  If KeyHit(KEY_SPACE) Then active.SetRunning(Not active.Running())
  If KeyHit(KEY_C) Then active.SetCached(Not active.Cached())
  If KeyHit(KEY_S) Then active.SetResolution(3-active.Resolution())
  If KeyHit(KEY_LEFT) Then active.SetPower(active.Power()-1)
  If KeyHit(KEY_RIGHT) Then active.SetPower(active.Power()+1)
  If KeyHit(KEY_D) Then scene.SetDebugOverlay(Not scene.GetDebugOverlay())
  If KeyHit(KEY_R) Then scene.ReleaseResources()
  If KeyHit(KEY_I) Then Print scene.InspectTree()
  scene.Update(dt)
 End If
 SetClsColor(7,12,22); Cls
 SetBlend(ALPHABLEND); SetAlpha(1); SetColor(17,28,42)
 For Local i:Int = 0 Until 3
  DrawRect(30+i*360,167,320,368)
 Next
 SetColor(65,155,190); DrawRect(30+selected*360,167,320,3)
 For Local i:Int = 0 Until 3
  before[i] = reactors[i].SourceDraws()
 Next
 scene.Render(); scene.CopyStats(stats)
 SetImageFont(title); SetColor(220,238,250); DrawText("REACTOR WORKSHOP",30,26)
 SetImageFont(font); SetColor(135,170,195)
 DrawText("Three independent components. One shared housing image. Three different update costs.",30,75)
 DrawText("Click a reactor or press 1 / 2 / 3 to select it. Controls affect only the selected instance.",30,111)
 For Local i:Int = 0 Until 3
  Local r:TWorkshopReactor = reactors[i]
  SetColor(185,205,220)
  DrawText("Power "+r.Power()+" / 5    Resolution "+r.Resolution()+"x",48+i*360,489)
  DrawText("Cache "+r.Cached()+"    Source draws this frame: "+(r.SourceDraws()-before[i]),48+i*360,511)
 Next
 SetColor(220,238,250)
 DrawText("M  Change animation    SPACE  Pause    C  Cache    S  Resolution    LEFT / RIGHT  Power",30,554)
 SetColor(135,170,195)
 DrawText("D  Bounds overlay    R  Release buffers    I  Print tree    ESC  Exit",30,585)
 SetColor(90,210,235)
 DrawText("Captures: "+stats.Captures()+"    Reused outputs: "+stats.CacheHits()+"    Effect stages: "+stats.StagePasses(),30,624)
 SetColor(135,170,195)
 DrawText("Scene buffers: "+scene.RetainedStorageBytes()+" bytes / "+scene.GetStorageLimitBytes()+" byte budget",30,655)
 DrawText("Move: reuse output    |    Pulse: process saved source    |    Spin: capture and process",30,690)
 Flip
Wend
scene.Destroy()
housing.ReleaseFrames()
EndGraphics
