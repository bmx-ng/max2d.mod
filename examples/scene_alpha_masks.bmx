SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
?Not max2d_gl
Framework Max2D.SDL3GPUMax2D
?
Import Max2D.SceneEffects
Import BRL.StandardIO

Type TMaskedPattern Extends TCustomDrawNode
 Method OnDraw(context:TSceneDrawContext)
  For Local row:Int=-1 To 4
   For Local col:Int=-1 To 6
    context.SetColor(55+row*25,145+col*12,230-row*20)
    DrawOval(col*48,row*48,38,38)
   Next
  Next
 End Method
End Type

AppTitle="Max2D Scene / Local alpha masks"
Graphics(900,480)
Local mask:TImage=CreateImage(96,96,1,DYNAMICIMAGE | FILTEREDIMAGE)
Local pixels:TPixmap=LockImage(mask)
For Local y:Int=0 Until 96
 For Local x:Int=0 Until 96
  Local distance:Double=Sqr((x-47.5)*(x-47.5)+(y-47.5)*(y-47.5))
  Local alpha:Int=Int(Max(0.0,Min(1.0,(44-distance)/10))*255)
  pixels.WritePixel(x,y,(alpha Shl 24) | $ffffff)
 Next
Next
Local input:TPixmap=pixels.Copy()
UnlockImage(mask)
Local masks:TSceneAlphaMaskStage[3]
Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(layer);scene.SetInputClip(TSceneRect.Create(0,0,900,480))
Local groups:TCompositeNode[3],patterns:TMaskedPattern[3]
For Local i:Int=0 Until 3
 groups[i]=TCompositeNode.Create();groups[i].SetCacheMode(ESceneCacheMode.Automatic)
 groups[i].SetPosition(65+i*280,165);layer.AddChild(groups[i])
 groups[i].SetClipRect(TSceneRect.Create(0,0,210,150))
 masks[i]=TSceneAlphaMaskStage.Create(mask,TSceneRect.Create(20,-10,170,170),i=1)
 masks[i].SetInputMask(input,128)
 groups[i].SetStages([TSceneEffectStage(masks[i])])
 patterns[i]=New TMaskedPattern;patterns[i].SetName("Panel "+(i+1))
 patterns[i].SetSelfBounds(TSceneRect.Create(-48,-48,374,278));patterns[i].SetInteractive(True)
 groups[i].AddChild(patterns[i])
Next
groups[1].SetTransform(350,155,15)
groups[2].SetTransform(650,165,-10)
Local movingRect:TSceneRect=TSceneRect.Create(20,-10,170,170)
Local moving:Int=True,inputEnabled:Int=True,frames:Int
Local start:Int=MilliSecs(),stats:TSceneStats=New TSceneStats
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
 If KeyHit(KEY_SPACE) Then moving=Not moving
 If KeyHit(KEY_H) Then
  inputEnabled=Not inputEnabled
  For Local i:Int=0 Until 3
   If inputEnabled Then masks[i].SetInputMask(input,128) Else masks[i].SetInputMask(Null)
  Next
 End If
 If moving Then
  Local t:Float=(MilliSecs()-start)*0.001
  For Local i:Int=0 Until 2
   patterns[i].SetPosition(Float(Sin(t*70+i*60)*24),Float(Cos(t*45+i*50)*20))
  Next
  movingRect.x=20+Float(Sin(t*60)*30)
  masks[2].SetMaskRect(movingRect)
 End If
 scene.Update(0)
 Local hovered:TSceneNode2D=scene.Pick(MouseX(),MouseY())
 SetClsColor(17,23,36);Cls;scene.Render();scene.CopyStats(stats)
 SetColor(235,240,255);DrawText("LOCAL ALPHA MASKS",32,30)
 DrawText("Space: pause / reuse caches    H: toggle alpha picking    Escape: close",32,58)
 DrawText("Soft alpha",65,110);DrawText("Inverted cutout",345,110);DrawText("Moving mask + clip",625,110)
 Local status:String="Outside interactive artwork"
 If hovered Then status="Picking: "+hovered.GetName()
 DrawText(status+"   Alpha picking: "+inputEnabled,32,390)
 DrawText("Captures: "+stats.Captures()+"   Cache hits: "+stats.CacheHits(),32,420)
 Flip
 frames:+1
 If AppArgs.Length>1 And AppArgs[1]="--test" And frames=3 Then Exit
Wend
scene.Destroy();EndGraphics()
Print "PASS: scene alpha masks example"
