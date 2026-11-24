' Included by reactor_workshop.bmx; this component does not select a backend or poll input.
Const REACTOR_STILL:Int = 0
Const REACTOR_MOVE:Int = 1
Const REACTOR_PULSE:Int = 2
Const REACTOR_SPIN:Int = 3

Rem
bbdoc: Reusable reactor subtree with independent animation, cached plasma and shared housing art.
about: The application supplies shared art/font and owns their lifetime. Each instance owns its bloom stage and composite buffers. Status text is outside the capture. Selection requests are application-facing signals; no input polling or sibling lookup occurs here.
End Rem
Type TWorkshopReactor Extends TSceneNode2D
 Private
 Field plasma:TCompositeNode
 Field core:TReactorCore
 Field bloom:TSceneBloomStage
 Field status:TTextNode
 Field elapsed:Double
 Field homeX:Float, homeY:Float
 Field animation:Int, running:Int = True, cached:Int = True, resolution:Int = 1, power:Int = 3
 Field requested:Int
 Public
 Rem
 bbdoc: Builds a detached reactor using borrowed housing art and font; graphics storage is allocated on first render.
 End Rem
 Function Create:TWorkshopReactor(housing:TImage, font:TImageFont, name:String, x:Float, y:Float, red:Int, green:Int, blue:Int, mode:Int)
  Local result:TWorkshopReactor = New TWorkshopReactor
  result.SetName(name); result.homeX = x; result.homeY = y
  result.SetPosition(x,y); result.SetProcessing(True)
  result.SetInteractive(True); result.SetHitRect(TSceneRect.Create(-112,-112,224,224))
  Local shell:TSpriteNode = TSpriteNode.Create(housing)
  shell.SetName("Shared housing"); result.AddChild(shell)
  result.plasma = TCompositeNode.Create()
  result.plasma.SetName(name+" plasma")
  result.plasma.SetCacheMode(ESceneCacheMode.Automatic)
  result.plasma.SetCaptureRect(TSceneRect.Create(-70,-70,140,140))
  result.bloom = TSceneBloomStage.Create(0.28,8,1.05)
  result.plasma.SetStages([TSceneEffectStage(result.bloom)])
  result.AddChild(result.plasma)
  result.core = New TReactorCore
  result.core.SetName("Plasma source"); result.core.SetSelfBounds(TSceneRect.Create(-66,-66,132,132))
  result.core.SetTint(red,green,blue); result.plasma.AddChild(result.core)
  Local title:TTextNode = TTextNode.Create(name,font)
  title.SetPosition(-94,123); result.AddChild(title)
  result.status = TTextNode.Create("",font)
  result.status.SetPosition(-94,151); result.status.SetTint(135,170,195); result.AddChild(result.status)
  result.SetMode(mode)
  Return result
 End Function
 Rem
 bbdoc: Chooses still, whole-subtree motion, bloom-only pulse or captured-core rotation.
 End Rem
 Method SetMode(value:Int)
  If value < REACTOR_STILL Or value > REACTOR_SPIN Then Throw "Invalid reactor mode"
  animation = value; elapsed = 0
  SetPosition(homeX,homeY); SetRotation(0); core.SetRotation(0)
  bloom.SetIntensity(power*0.35)
  RefreshStatus()
 End Method
 Rem
 bbdoc: Returns this instance's animation mode.
 End Rem
 Method Mode:Int()
  Return animation
 End Method
 Rem
 bbdoc: Pauses or resumes this instance without changing its last displayed pose.
 End Rem
 Method SetRunning(value:Int)
  running = value <> 0; RefreshStatus()
 End Method
 Rem
 bbdoc: Returns whether this instance's animation advances.
 End Rem
 Method Running:Int()
  Return running
 End Method
 Rem
 bbdoc: Chooses automatic capture reuse or deliberate recapture each render.
 End Rem
 Method SetCached(value:Int)
  cached = value <> 0
  If cached Then plasma.SetCacheMode(ESceneCacheMode.Automatic) Else plasma.SetCacheMode(ESceneCacheMode.None)
 End Method
 Rem
 bbdoc: Returns whether automatic capture reuse is selected.
 End Rem
 Method Cached:Int()
  Return cached
 End Method
 Rem
 bbdoc: Sets one or two pixels per scene unit for the plasma buffers.
 End Rem
 Method SetResolution(value:Int)
  If value <> 1 And value <> 2 Then Throw "Workshop resolution must be 1 or 2"
  resolution = value; plasma.SetResolutionScale(value)
 End Method
 Rem
 bbdoc: Returns the selected pixels per scene unit.
 End Rem
 Method Resolution:Int()
  Return resolution
 End Method
 Rem
 bbdoc: Sets bloom power from one to five; changes processing without modifying captured geometry.
 End Rem
 Method SetPower(value:Int)
  power = Max(1,Min(5,value)); bloom.SetIntensity(power*0.35); RefreshStatus()
 End Method
 Rem
 bbdoc: Returns the bloom power level.
 End Rem
 Method Power:Int()
  Return power
 End Method
 Rem
 bbdoc: Returns cumulative source drawing visits for demonstrating capture reuse.
 End Rem
 Method SourceDraws:Long()
  Return core.draws
 End Method
 Rem
 bbdoc: Consumes a pending selection request raised by pointer input.
 End Rem
 Method TakeSelection:Int()
  Local value:Int = requested; requested = False; Return value
 End Method
 Rem
 bbdoc: Requests application selection when pressed; input conversion remains application-owned.
 End Rem
 Method OnPointer(event:TScenePointerEvent) Override
  If event.Kind() = EScenePointerKind.Down Then requested = True; event.Handle()
 End Method
 Rem
 bbdoc: Advances only this reactor's selected animation, using caller-supplied elapsed seconds.
 End Rem
 Method OnUpdate(dt:Double) Override
  If Not running Then Return
  elapsed :+ dt
  Select animation
   Case REACTOR_MOVE
    SetTransform(homeX,homeY+Float(Sin(elapsed*65)*14),Float(Sin(elapsed*40)*7))
   Case REACTOR_PULSE
    bloom.SetIntensity(Float(power*0.35*(0.65+0.35*Sin(elapsed*130))))
   Case REACTOR_SPIN
    core.SetRotation(Float(elapsed*55))
  End Select
 End Method
 Private
 Method RefreshStatus()
  Local text:String = "STILL"
  Select animation
   Case REACTOR_MOVE
    text = "MOVE SUBTREE"
   Case REACTOR_PULSE
    text = "PULSE EFFECT"
   Case REACTOR_SPIN
    text = "SPIN SOURCE"
  End Select
  If Not running Then text :+ " / PAUSED"
  status.SetText(text)
 End Method
End Type

' Bounds remain stable while the node rotates. The composite's fixed region
' includes the complete source, and bloom adds its own padding outside it.
Type TReactorCore Extends TCustomDrawNode
 Field draws:Long
 Method OnDraw(context:TSceneDrawContext) Override
  draws :+ 1
  context.SetColor(55,95,115); DrawOval(-54,-54,108,108)
  context.SetColor(110,180,210); SetLineWidth(3)
  For Local i:Int = 0 Until 6
   Local angle:Float = i*60
   Local x:Float = Float(Cos(angle)*44), y:Float = Float(Sin(angle)*44)
   DrawLine(x*0.48,y*0.48,x*1.35,y*1.35)
   DrawOval(x-9,y-9,18,18)
  Next
  context.SetColor(180,230,255); DrawOval(-32,-32,64,64)
  context.SetColor(225,250,255); DrawOval(-21,-21,42,42)
  context.SetColor(255,255,255); DrawOval(-9,-9,18,18)
 End Method
End Type

' One shared render image, generated once at loading time; no external assets.
Function CreateReactorHousing:TRenderImage()
 Local image:TRenderImage = CreateRenderImage(256,256,FILTEREDIMAGE)
 Using
  Local scope:TMax2DStateScope = ScopedMax2DState()
 Do
  SetRenderImage(image); SetVirtualResolution(256,256); SetViewport(0,0,256,256)
  SetCamera(Null); ResetCoordinates(); SetOrigin(0,0); SetHandle(0,0); SetScale(1,1); SetRotation(0)
  SetClsColor(0,0,0,0); Cls; SetBlend(ALPHABLEND); SetAlpha(1)
  SetColor(13,22,34); DrawOval(24,24,208,208)
  SetColor(52,75,90); DrawOval(30,30,196,196)
  SetColor(22,36,49); DrawOval(39,39,178,178)
  SetColor(8,17,28); DrawOval(52,52,152,152)
  SetLineWidth(4)
  For Local i:Int = 0 Until 24
   Local a:Float = i*15
   SetColor(70,110,130)
   DrawLine(Float(128+Cos(a)*85),Float(128+Sin(a)*85),Float(128+Cos(a)*94),Float(128+Sin(a)*94))
  Next
  For Local i:Int = 0 Until 6
   Local a:Float = i*60+30
   Local x:Float = Float(128+Cos(a)*100), y:Float = Float(128+Sin(a)*100)
   SetColor(115,145,158); DrawOval(x-5,y-5,10,10)
   SetColor(25,40,50); DrawLine(x-2,y,x+2,y)
  Next
 End Using
 SetImageHandle(image,128,128)
 Return image
End Function
