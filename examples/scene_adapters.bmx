SuperStrict
Framework Max2D.SDL3GPUMax2D
Import Max2D.SceneTileMap
Import Max2D.SceneParticles
Import Max2D.SceneEffects
Import BRL.Random

Function Tile:TImage(colour:Int)
 Local pixmap:TPixmap=CreatePixmap(28,28,PF_RGBA8888)
 pixmap.ClearPixels($ff152235)
 For Local y:Int=2 Until 26
  For Local x:Int=2 Until 26
   pixmap.WritePixel(x,y,colour)
  Next
 Next
 Return TImage.FromPixmap(pixmap)
End Function
Function Burst(particles:TSceneParticleNode,x:Float,y:Float)
 For Local i:Int=0 Until 48
  Local angle:Float=Rnd(360),speed:Float=Rnd(35,145)
  particles.Emit(x,y,Float(Cos(angle)*speed),Float(Sin(angle)*speed),Rnd(0.5,1.6),Float(Rnd(3,9)),Rand(120,255),Rand(160,255),255)
 Next
End Function
AppTitle="Max2D Scene / Tilemap and particle adapters"
Graphics(900,620)
SetVirtualResolution(900,620,VIRTUAL_LETTERBOX)
Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(layer)
Local tiles:TTileSet=New TTileSet
Local dark:Int=tiles.Add(Tile($ff20364c)),bright:Int=tiles.Add(Tile($ff315773))
Local map:TTileMap=TTileMap.Create(TTileGrid.Rectangular(28,28),tiles)
Local cells:TTileLayer=map.AddLayer()
For Local y:Int=0 Until 14
 For Local x:Int=0 Until 28
  If (x+y) Mod 2 Then cells.SetCell(x,y,dark) Else cells.SetCell(x,y,bright)
 Next
Next
Local group:TCompositeNode=TCompositeNode.Create()
group.SetPosition(58,150);group.SetCacheMode(ESceneCacheMode.Automatic);layer.AddChild(group)
Local ground:TTileMapNode=TTileMapNode.Create(map)
ground.SetSelfBounds(TSceneRect.Create(0,0,784,392));group.AddChild(ground)
Local particles:TSceneParticleNode=TSceneParticleNode.Create(512)
layer.AddChild(particles)
Local stats:TSceneStats=New TSceneStats
Local previous:Int=MilliSecs(),paused:Int
Burst(particles,450,340)
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
 Local now:Int=MilliSecs(),dt:Double=Min(0.1,Max(0.0,Double(now-previous)/1000))
 previous=now
 If KeyHit(KEY_P) Then paused=Not paused;scene.SetPaused(paused)
 Local x:Float,y:Float
 Local inside:Int=GetVirtualMouse(x,y)
 If inside And MouseHit(1) Then
  Burst(particles,x,y)
  Local column:Int=Int(Floor((x-58)/28)),row:Int=Int(Floor((y-150)/28))
  If column>=0 And column<28 And row>=0 And row<14 Then
   If cells.Cell(column,row)=dark Then cells.SetCell(column,row,bright) Else cells.SetCell(column,row,dark)
   ground.InvalidateContent()
  End If
 End If
 If KeyHit(KEY_SPACE) Then Burst(particles,450,340)
 scene.Update(dt)
 SetClsColor(10,17,29);Cls()
 scene.Render();scene.CopyStats(stats)
 SetColor(230,240,255);DrawText("TILEMAP + RETAINED PARTICLE POOL",40,30)
 SetColor(150,180,210);DrawText("CLICK: edit tile + burst    SPACE: burst    P: pause    ESC: exit",40,60)
 DrawText("Particles: "+particles.Count()+" / "+particles.Capacity()+"    Map cache hits: "+stats.CacheHits(),40,90)
 If paused Then DrawText("PAUSED",760,30)
 Flip(1)
Wend
scene.Destroy();EndGraphics()
