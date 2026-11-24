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
Import Max2D.SceneTileMap
Import Max2D.SceneParticles
Import Max2D.SceneEffects
Import BRL.StandardIO
Global checks:Int
Global testTarget:TRenderImage
Function Check(value:Int,message:String)
 If Not value Then Throw message
 checks:+1
End Function
Function Solid:TImage(colour:Int)
 Local pixmap:TPixmap=CreatePixmap(8,8,PF_RGBA8888)
 pixmap.ClearPixels(colour)
 Return TImage.FromPixmap(pixmap)
End Function
Function Render:TPixmap(scene:TScene)
 SetClsColor(0,0,0,0);Cls();scene.Render()
 Return ReadRenderImage(testTarget)
End Function
Try
 Graphics(96,64)
 testTarget=CreateRenderImage(96,64,0);SetRenderImage(testTarget);SetVirtualResolution(96,64)
 Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
 scene.Root().AddChild(layer)
 Local tiles:TTileSet=New TTileSet
 Local red:TImage=Solid($ffff0000),green:TImage=Solid($ff00ff00)
 Local tile:Int=tiles.Add(red),animated:Int=tiles.AddAnimation(TImage.Animation([red,green],[100,100]))
 Local map:TTileMap=TTileMap.Create(TTileGrid.Rectangular(8,8),tiles)
 Local cells:TTileLayer=map.AddLayer();cells.SetCell(0,0,tile)
 Local group:TCompositeNode=TCompositeNode.Create();group.SetCacheMode(ESceneCacheMode.Automatic)
 group.SetPosition(8,8);group.SetScale(2,2);layer.AddChild(group)
 Local node:TTileMapNode=TTileMapNode.Create(map);node.SetSelfBounds(TSceneRect.Create(0,0,8,8));group.AddChild(node)
 Local pixels:TPixmap=Render(scene)
 Check((pixels.ReadPixel(12,12)&$ffffff)=$ff0000,"tilemap inherits scene/composite transforms")
 Render(scene);Check(scene.CaptureStats().CacheHits()=1,"static map capture reused")
 cells.SetCell(0,0,animated);node.InvalidateContent();node.SetElapsedMilliseconds(100)
 pixels=Render(scene)
 Check((pixels.ReadPixel(12,12)&$ffffff)=$00ff00 And scene.CaptureStats().Captures()=1,"external edits and clock invalidate capture")
 node.SetProcessing(True);scene.Update(0.1);pixels=Render(scene)
 Check((pixels.ReadPixel(12,12)&$ffffff)=$ff0000,"animated tile advances through scene update")
 Local image:TImage=Solid($ffffffff);SetImageHandle(image,99,99)
 Local particles:TSceneParticleNode=TSceneParticleNode.Create(4,image)
 particles.SetPosition(50,20);particles.SetTint(255,0,0);particles.SetAlpha(0.5)
 Local particleGroup:TCompositeNode=TCompositeNode.Create();particleGroup.SetCacheMode(ESceneCacheMode.Automatic)
 layer.AddChild(particleGroup);particleGroup.AddChild(particles);particles.Emit(0,0,10,0,2,8)
 pixels=Render(scene)
 Check(Abs(((pixels.ReadPixel(50,20) Shr 24)&255)-128)<=2 And (pixels.ReadPixel(50,20)&$ffffff)=$ff0000,"particle image ignores handle and inherits tint/alpha")
 Render(scene);Check(scene.CaptureStats().CacheHits()=2,"stationary particle capture reused")
 scene.Update(1);pixels=Render(scene)
 Check(Abs(((pixels.ReadPixel(60,20) Shr 24)&255)-64)<=2 And (pixels.ReadPixel(50,20)&$ffffff)=0,"particle movement and lifetime fade")
 scene.Update(1);pixels=Render(scene)
 Check(particles.Count()=0 And (pixels.ReadPixel(60,20)&$ffffff)=0,"expired particles disappear")
 scene.Destroy();EndGraphics()
 Print "PASS: scene adapter rendering "+checks+" checks"
Catch error:Object
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
