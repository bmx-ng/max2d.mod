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
Import Max2D.SceneEffects
Import BRL.StandardIO

Type TRevealArtwork Extends TCustomDrawNode
 Method OnDraw(context:TSceneDrawContext)
  context.SetColor(35,60,95);DrawRect(0,0,320,220)
  For Local row:Int=0 Until 5
   For Local col:Int=0 Until 7
    context.SetColor(65+row*30,200-col*12,225-row*18)
    DrawOval(10+col*45,10+row*43,30,30)
   Next
  Next
 End Method
End Type
Type TSoftSpot Extends TCustomDrawNode
 Method OnDraw(context:TSceneDrawContext)
  context.SetColor(255,255,255)
  For Local i:Int=0 Until 16
   context.SetAlpha(0.12)
   Local radius:Float=88-i*3
   DrawOval(-radius,-radius,radius*2,radius*2)
  Next
 End Method
End Type

AppTitle="Max2D Scene / Live subtree masks"
Graphics(820,480)
Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(layer);scene.SetInputClip(TSceneRect.Create(0,0,820,480))
' Hide only the source's parent: explicit subtree capture ignores ancestors.
Local sources:TSceneNode2D=New TSceneNode2D
sources.SetVisible(False);layer.AddChild(sources)
Local source:TSceneNode2D=New TSceneNode2D
sources.AddChild(source)
Local spot:TSoftSpot=New TSoftSpot
spot.SetSelfBounds(TSceneRect.Create(-88,-88,176,176));source.AddChild(spot)
Local satellite:TSoftSpot=New TSoftSpot
satellite.SetSelfBounds(TSceneRect.Create(-88,-88,176,176))
satellite.SetTransform(95,0,0,0.42,0.42);source.AddChild(satellite)
Local panels:TCompositeNode[2],masks:TSceneSubtreeMaskStage[2]
For Local i:Int=0 Until 2
 ' The enclosing cache tests propagation beyond the masked composite itself.
 Local outer:TCompositeNode=TCompositeNode.Create()
 outer.SetCacheMode(ESceneCacheMode.Automatic);outer.SetPosition(50+i*400,145);layer.AddChild(outer)
 panels[i]=TCompositeNode.Create();panels[i].SetCacheMode(ESceneCacheMode.Automatic)
 panels[i].SetClipRect(TSceneRect.Create(0,0,320,220));outer.AddChild(panels[i])
 Local artwork:TRevealArtwork=New TRevealArtwork
 artwork.SetSelfBounds(TSceneRect.Create(0,0,320,220));artwork.SetInteractive(True)
 artwork.SetName("Panel "+(i+1));panels[i].AddChild(artwork)
 masks[i]=TSceneSubtreeMaskStage.Create(source,i=1)
 panels[i].SetStages([TSceneEffectStage(masks[i])])
Next
Local moving:Int=True,attached:Int=True,frames:Int
Local time:Float,start:Int=MilliSecs(),last:Int=start
Local stats:TSceneStats=New TSceneStats
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
 Local now:Int=MilliSecs(),dt:Float=(now-last)*0.001
 last=now
 If KeyHit(KEY_SPACE) Then moving=Not moving
 If KeyHit(KEY_D) Then
  attached=Not attached
  If attached Then sources.AddChild(source) Else sources.RemoveChild(source)
 End If
 If KeyHit(KEY_R) Then scene.ReleaseResources()
 If moving Then time:+dt
 source.SetTransform(155+Float(Sin(time*50)*55),110+Float(Cos(time*65)*22),time*35)
 scene.Update(dt)
 Local hovered:TSceneNode2D=scene.Pick(MouseX(),MouseY())
 SetClsColor(15,21,34);Cls
 SetColor(42,53,72);DrawRect(48,143,324,224);DrawRect(448,143,324,224)
 scene.Render();scene.CopyStats(stats)
 SetColor(235,242,255);DrawText("LIVE SUBTREE MASKS",40,28)
 DrawText("One animated source, two cached consumers",40,57)
 DrawText("Space: pause    D: detach / attach source    R: release buffers    Esc: close",40,85)
 DrawText("Reveal",50,119);DrawText("Inverse cutout",450,119)
 DrawText("Visual masking leaves picking unchanged; no pixel readback.",40,391)
 Local hover:String="No panel under pointer"
 If hovered Then hover="Picking: "+hovered.GetName()+" (including visually masked areas)"
 DrawText(hover,40,419)
 DrawText("Captures: "+stats.Captures()+"   Stage updates: "+stats.StagePasses()+"   Source attached: "+attached,40,447)
 Flip
 frames:+1
 If AppArgs.Length>1 And AppArgs[1]="--test" And frames=3 Then Exit
Wend
scene.Destroy()
If Not attached Then source.Destroy()
EndGraphics()
Print "PASS: live subtree masks example"
