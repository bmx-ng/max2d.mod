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
Include "world_nodes.bmx"
Include "world_tests.bmx"

AppTitle="Max2D / Camera World"
Graphics(1100,740)
SetVirtualResolution(1100,740,VIRTUAL_LETTERBOX)
Local path:String
?osx
path="/System/Library/Fonts/Supplemental/Arial.ttf"
?win32
path=getenv_("WINDIR")+"/Fonts/segoeui.ttf"
?linux
path="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
?
Local font:TImageFont=TImageFont.DefaultFont(),title:TImageFont=font
If FileType(path)=FILETYPE_FILE Then
 font=LoadScalableImageFont(path,16); title=LoadScalableImageFont(path,30)
End If
Local scene:TScene=TScene.Create(),world:TLayerNode=TLayerNode.Create(),hud:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(world); scene.Root().AddChild(hud)
scene.SetInputClip(TSceneRect.Create(0,0,1100,740)); scene.SetCulling(True)
scene.SetStorageLimitBytes(16*1024*1024)
world.SetViewport(TSceneRect.Create(30,140,780,510))
Local camera:TCamera2D=New TCamera2D
camera.offsetX=420; camera.offsetY=395
world.SetCamera(camera)
Local grid:TChartGrid=New TChartGrid
grid.SetSelfBounds(TSceneRect.Create(-1200,-900,2400,1800)); world.AddChild(grid)
Local stations:TChartStation[9]
For Local i:Int=0 Until stations.Length
 stations[i]=TChartStation.Create("RELAY 0"+(i+1),(i Mod 3-1)*440,(i/3-1)*330,font)
 world.AddChild(stations[i])
Next
Local ship:TSurveyShip=New TSurveyShip
ship.SetName("Survey ship"); ship.SetSelfBounds(TSceneRect.Create(-14,-21,28,42)); world.AddChild(ship)
Local followButton:TChartButton=TChartButton.Create("F / Follow ship",font,840,166)
Local resetButton:TChartButton=TChartButton.Create("R / Reset camera",font,840,214)
Local zoomIn:TChartButton=TChartButton.Create("+ / Zoom in",font,840,262)
Local zoomOut:TChartButton=TChartButton.Create("- / Zoom out",font,840,310)
hud.AddChild(followButton); hud.AddChild(resetButton); hud.AddChild(zoomIn); hud.AddChild(zoomOut)
Local trackedLabel:TTextNode=TTextNode.Create("SURVEY SHIP",font)
trackedLabel.SetTint(255,205,125); hud.AddChild(trackedLabel)
If AppArgs.Length>1 And AppArgs[1]="--test" Then
 RunWorldTests(scene,world,hud,camera,stations,followButton)
 scene.Destroy(); EndGraphics; End
End If
Local follow:Int=True,paused:Int,mouseHeld:Int,selected:Int=-1,previous:Int=MilliSecs()
Local elapsed:Double
Local stats:TSceneStats=New TSceneStats
Local corners:Float[8]
While Not AppTerminate() And Not KeyDown(KEY_ESCAPE)
 Local now:Int=MilliSecs(), dt:Double=Min(0.05,Max(0.0,(now-previous)*0.001))
 previous=now
 If AppSuspended() Then
  scene.CancelInput(); mouseHeld=False; dt=0
 Else
  Local mx:Float,my:Float,inside:Int=GetVirtualMouse(mx,my),pressed:Int=MouseDown(1)
  If pressed And Not mouseHeld Then
   If inside Then scene.DispatchPointer(EScenePointerKind.Down,0,0,mx,my,1,1)
  Else If Not pressed And mouseHeld Then
   scene.DispatchPointer(EScenePointerKind.Up,0,0,mx,my,1,0)
  Else
   scene.DispatchPointer(EScenePointerKind.Move,0,0,mx,my,0,pressed)
  End If
  mouseHeld=pressed
 End If
 If KeyHit(KEY_SPACE) Then paused=Not paused
 If KeyHit(KEY_D) Then scene.SetDebugOverlay(Not scene.GetDebugOverlay())
 Local followRequest:Int=followButton.TakeRequest(),resetRequest:Int=resetButton.TakeRequest()
 Local inRequest:Int=zoomIn.TakeRequest(),outRequest:Int=zoomOut.TakeRequest()
 If KeyHit(KEY_F) Or followRequest Then follow=Not follow
 If KeyHit(KEY_R) Or resetRequest Then
  camera.x=0; camera.y=0; camera.zoom=1; camera.rotation=0; follow=False; selected=-1
 End If
 For Local i:Int=0 Until stations.Length
  If stations[i].requested Then
   stations[i].requested=False; selected=i; follow=False
   camera.x=stations[i].worldX; camera.y=stations[i].worldY
  End If
 Next
 Local panX:Int=KeyDown(KEY_RIGHT)-KeyDown(KEY_LEFT),panY:Int=KeyDown(KEY_DOWN)-KeyDown(KEY_UP)
 If panX Or panY Then
  follow=False
  camera.x:+Float((Cos(camera.rotation)*panX-Sin(camera.rotation)*panY)*dt*360/camera.zoom)
  camera.y:+Float((Sin(camera.rotation)*panX+Cos(camera.rotation)*panY)*dt*360/camera.zoom)
 End If
 If KeyDown(KEY_Q) Then camera.zoom=Max(0.35,camera.zoom-Float(dt))
 If KeyDown(KEY_E) Then camera.zoom=Min(2.5,camera.zoom+Float(dt))
 If KeyHit(KEY_EQUALS) Or inRequest Then camera.zoom=Min(2.5,camera.zoom+0.2)
 If KeyHit(KEY_MINUS) Or outRequest Then camera.zoom=Max(0.35,camera.zoom-0.2)
 camera.rotation:+Float((KeyDown(KEY_K)-KeyDown(KEY_J))*dt*45)
 If Not paused Then elapsed:+dt
 Local shipX:Float=Float(Cos(elapsed*14)*510),shipY:Float=Float(Sin(elapsed*23)*280)
 ship.SetTransform(shipX,shipY,Float(elapsed*28))
 If follow Then camera.x=shipX; camera.y=shipY
 ' Layer camera setters copy scalar values. Apply before coordinate queries/render.
 world.SetCamera(camera)
 Local labelX:Float,labelY:Float
 scene.LocalToScreen(ship,0,0,labelX,labelY)
 trackedLabel.SetPosition(labelX+20,labelY-35)
 trackedLabel.SetVisible(labelX>=45 And labelX<650 And labelY>=180 And labelY<625)
 scene.Update(dt)
 SetClsColor(7,12,22); Cls
 ' Ordinary Max2D background drawing happens before the retained scene.
 SetColor(12,24,36); DrawRect(30,140,780,510)
 SetColor(16,29,42); DrawRect(830,140,240,510)
 scene.Render(); scene.CopyStats(stats)
 ' Ordinary drawing after Render retains the caller's identity camera/state.
 SetImageFont(title); SetColor(225,240,250); DrawText("CAMERA WORLD",30,25)
 SetImageFont(font); SetColor(145,180,205)
 DrawText("A scrolling star chart, cached relays, a moving survey ship and a fixed interactive HUD.",30,77)
 DrawText("Click a relay to centre it. The sidebar stays in screen space while the world camera changes.",30,108)
 SetColor(225,240,250); DrawText("NAVIGATION",840,145)
 SetColor(145,180,205)
 Local mode:String="FREE CAMERA"
 If follow Then mode="FOLLOWING SHIP"
 DrawText(mode,840,368)
 DrawText("Zoom "+Int(camera.zoom*100)+"% / angle "+Int(camera.rotation),840,398)
 Local selection:String="No relay selected"
 If selected>=0 Then selection=stations[selected].label+" selected"
 DrawText(selection,840,426)
 ' A minimap is immediate-mode Max2D; it has no scene nodes or independent input.
 SetColor(8,18,29); DrawRect(840,462,220,166)
 SetColor(85,165,190)
 For Local station:TChartStation=EachIn stations
  DrawOval(950+station.worldX*0.12-3,545+station.worldY*0.12-3,6,6)
 Next
 SetColor(255,190,90); DrawOval(950+shipX*0.12-3,545+shipY*0.12-3,6,6)
 camera.VirtualToWorld(30,140,corners[0],corners[1])
 camera.VirtualToWorld(810,140,corners[2],corners[3])
 camera.VirtualToWorld(810,650,corners[4],corners[5])
 camera.VirtualToWorld(30,650,corners[6],corners[7])
 Using
  Local scope:TMax2DStateScope=ScopedMax2DState()
 Do
  SetViewport(840,462,220,166)
  SetColor(160,205,225); SetLineWidth(1)
  For Local i:Int=0 Until 4
   Local j:Int=(i+1) Mod 4
   DrawLine(950+corners[i*2]*0.12,545+corners[i*2+1]*0.12,950+corners[j*2]*0.12,545+corners[j*2+1]*0.12)
  Next
 End Using
 SetColor(190,210,225)
 DrawText("Arrows pan    Q / E zoom    J / K rotate    F follow    R reset    SPACE pause ship    D bounds",30,675)
 SetColor(115,180,200)
 DrawText("Captures "+stats.Captures()+"   Reused "+stats.CacheHits()+"   Culled "+stats.CulledSubtrees()+"   Buffers "+scene.RetainedStorageBytes()+" bytes",30,705)
 Flip
Wend
scene.Destroy(); EndGraphics
