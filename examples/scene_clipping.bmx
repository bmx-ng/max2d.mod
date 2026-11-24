SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
?Not max2d_gl
Framework Max2D.SDL3GPUMax2D
?
Import Max2D.SceneEffects
Import BRL.StandardIO

Type TClipPattern Extends TCustomDrawNode
 Method OnDraw(context:TSceneDrawContext)
  For Local row:Int=-1 To 4
   For Local col:Int=-1 To 6
    context.SetColor(55+row*25,145+col*12,230-row*20)
    DrawOval(col*48,row*48,38,38)
   Next
  Next
 End Method
End Type

AppTitle="Max2D Scene / Local clipping"
Graphics(900,480)
Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(layer);scene.SetInputClip(TSceneRect.Create(0,0,900,480))
Local groups:TCompositeNode[3],patterns:TClipPattern[3]
For Local i:Int=0 Until 3
 groups[i]=TCompositeNode.Create();groups[i].SetCacheMode(ESceneCacheMode.Automatic)
 groups[i].SetPosition(65+i*280,165);layer.AddChild(groups[i])
 groups[i].SetClipRect(TSceneRect.Create(0,0,210,150))
 patterns[i]=New TClipPattern;patterns[i].SetName("Panel "+(i+1))
 patterns[i].SetSelfBounds(TSceneRect.Create(-48,-48,374,278));patterns[i].SetInteractive(True)
 groups[i].AddChild(patterns[i])
Next
groups[1].SetTransform(350,155,15)
Local nested:TCompositeNode=TCompositeNode.Create()
nested.SetCacheMode(ESceneCacheMode.Automatic)
nested.SetClipRect(TSceneRect.Create(0,0,170,115));nested.SetTransform(30,10,-12)
groups[2].RemoveChild(patterns[2]);nested.AddChild(patterns[2]);groups[2].AddChild(nested)
Local moving:Int=True,clipped:Int=True,frames:Int
Local start:Int=MilliSecs(),stats:TSceneStats=New TSceneStats
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
 If KeyHit(KEY_SPACE) Then moving=Not moving
 If KeyHit(KEY_C) Then
  clipped=Not clipped
  For Local i:Int=0 Until 3
   If clipped Then
    groups[i].SetClipRect(TSceneRect.Create(0,0,210,150))
   Else
    groups[i].ClearCaptureRect()
   End If
  Next
 End If
 If moving Then
  Local t:Float=(MilliSecs()-start)*0.001
  For Local i:Int=0 Until 3
   patterns[i].SetPosition(Float(Sin(t*70+i*60)*24),Float(Cos(t*45+i*50)*20))
  Next
 End If
 scene.Update(0)
 Local hovered:TSceneNode2D=scene.Pick(MouseX(),MouseY())
 SetClsColor(17,23,36);Cls;scene.Render();scene.CopyStats(stats)
 SetColor(235,240,255);DrawText("LOCAL SCENE CLIPPING",32,30)
 DrawText("Space: pause / reuse caches    C: toggle outer clips    Escape: close",32,58)
 DrawText("Rectangle",65,110);DrawText("Rotated rectangle",345,110);DrawText("Nested rectangles",625,110)
 Local status:String="Outside clipped artwork"
 If hovered Then status="Picking: "+hovered.GetName()
 DrawText(status,32,390)
 DrawText("Captures: "+stats.Captures()+"   Cache hits: "+stats.CacheHits(),32,420)
 Flip
 frames:+1
 If AppArgs.Length>1 And AppArgs[1]="--test" And frames=3 Then Exit
Wend
scene.Destroy();EndGraphics()
Print "PASS: scene clipping example"
