Function WorldCheck(value:Int,message:String)
 If Not value Then Throw "FAIL: "+message
End Function
Function RunWorldTests(scene:TScene,world:TLayerNode,hud:TLayerNode,camera:TCamera2D,stations:TChartStation[],button:TChartButton)
 Local stats:TSceneStats=New TSceneStats
 scene.SetCulling(False); scene.Render()
 Local draws:Long[9]
 For Local i:Int=0 Until stations.Length
  draws[i]=stations[i].art.draws
 Next
 For Local pose:Int=0 Until 4
  camera.x=pose*20; camera.y=pose*-15; camera.zoom=0.7+pose*0.25; camera.rotation=pose*23
  world.SetCamera(camera)
  Local sx:Float,sy:Float
  scene.LocalToScreen(stations[4],0,0,sx,sy)
  WorldCheck(scene.Pick(sx,sy)=stations[4],"world picking follows camera")
  WorldCheck(scene.Pick(850,180)=button,"HUD picking ignores world camera")
  scene.DispatchPointer(EScenePointerKind.Down,0,0,sx,sy,1,1)
  scene.DispatchPointer(EScenePointerKind.Up,0,0,sx,sy,1,0)
  WorldCheck(stations[4].requested,"world selection routes through transformed layer")
  stations[4].requested=False
  scene.Render(); scene.CopyStats(stats)
  WorldCheck(stats.Captures()=0,"camera changes reuse local captures")
  For Local i:Int=0 Until stations.Length
   WorldCheck(stations[i].art.draws=draws[i],"camera never redraws warmed relay source")
  Next
 Next
 Local view:TMax2DView=New TMax2DView
 view.Reset(1100,740); view.presentation=VIRTUAL_LETTERBOX
 For Local density:Int=1 To 2
  Local mapping:TMax2DInputMapping=TMax2DInputMapping.Create(view,1200,900,1200*density,900*density)
  Local sx:Float,sy:Float,wx:Float,wy:Float,vx:Float,vy:Float
  scene.LocalToScreen(stations[4],0,0,sx,sy)
  mapping.VirtualToWindow(sx,sy,wx,wy)
  WorldCheck(mapping.WindowToVirtual(wx,wy,vx,vy),"letterboxed point maps inside")
  WorldCheck(scene.Pick(vx,vy)=stations[4],"letterbox and density preserve camera picking")
  WorldCheck(Not mapping.WindowToVirtual(1,1,vx,vy),"letterbox bar rejects new presses")
 Next
 scene.DispatchPointer(EScenePointerKind.Down,0,0,850,180,1,1)
 scene.DispatchPointer(EScenePointerKind.Up,0,0,850,180,1,0)
 WorldCheck(button.TakeRequest(),"HUD button dispatch")
 camera.x=0; camera.y=0; camera.zoom=1; camera.rotation=0; world.SetCamera(camera)
 ' Put the centre station outside the world viewport but inside the outer scene.
 stations[4].SetPosition(405,0)
 WorldCheck(scene.Pick(825,395)=Null,"world viewport excludes picking")
 stations[4].SetPosition(0,0)
 ' A separate render target does not change the scene's explicit input clip.
 Local target:TRenderImage=CreateRenderImage(1100,740,FILTEREDIMAGE)
 Using
  Local scope:TMax2DStateScope=ScopedMax2DState()
 Do
  SetRenderImage(target); SetVirtualResolution(1100,740); SetViewport(0,0,1100,740)
  SetClsColor(3,5,7); Cls
  SetColor(12,34,56); SetAlpha(0.25); SetScale(2,3); SetOrigin(7,9); SetRotation(31)
  Local caller:TCamera2D=New TCamera2D
  caller.x=999; SetCamera(caller)
  scene.Render()
  Local r:Int,g:Int,b:Int,sx:Float,sy:Float,ox:Float,oy:Float
  GetColor(r,g,b); GetScale(sx,sy); GetOrigin(ox,oy)
  WorldCheck(r=12 And g=34 And b=56 And GetAlpha()=0.25,"caller tint restored")
  WorldCheck(sx=2 And sy=3 And ox=7 And oy=9 And GetRotation()=31 And GetCamera().x=999,"caller transform and camera restored")
  WorldCheck(TMax2DGraphics.Current().renderImage=target,"caller render target restored")
  WorldCheck(scene.Pick(850,180)=button,"offscreen render leaves window input unchanged")
 End Using
 ' The grid would cover this pixel without the layer's drawing viewport.
 Local pixels:TPixmap=ReadRenderImage(target)
 WorldCheck(pixels.ReadPixel(20,395)=$ff030507,"world drawing is clipped")
 target.ReleaseFrames()
 scene.SetCulling(True); scene.Render(); scene.CopyStats(stats)
 WorldCheck(stats.CulledSubtrees()>0,"world view culls distant relays")
 Print "PASS: Camera World camera picking, fixed HUD, capture reuse, viewport and caller state"
End Function
