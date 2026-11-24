SuperStrict
Framework BRL.StandardIO
Import Max2D.SceneParticles
Import Max2D.SceneTileMap
Global checks:Int
Function Check(value:Int,message:String)
 If Not value Then Throw message
 checks:+1
End Function
Try
 Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
 scene.Root().AddChild(layer)
 Local particles:TSceneParticleNode=TSceneParticleNode.Create(2)
 layer.AddChild(particles)
 Local rect:TSceneRect=New TSceneRect
 Check(particles.GetOutputBounds(rect) And rect.width=0,"empty bounds")
 Check(particles.Emit(0,0,10,0,1,4),"first emission")
 Check(particles.Emit(20,0,0,10,2,4),"second emission")
 Check(Not particles.Emit(0,0,0,0,1,4) And particles.Count()=2,"full pool rejects without growth")
 Check(particles.GetOutputBounds(rect) And rect.x=-2 And rect.width=24,"combined bounds")
 scene.Update(0.5)
 Check(particles.GetOutputBounds(rect) And rect.x=3 And rect.width=19 And rect.height=9,"moving bounds")
 scene.SetPaused(True);scene.Update(10);Check(particles.Count()=2,"scene pause")
 scene.SetPaused(False);scene.Update(0.5);Check(particles.Count()=1,"expired slot removed")
 Check(particles.Emit(-10,0,0,0,1,4),"pool slot reused")
 layer.RemoveChild(particles);scene.Update(10);Check(particles.Count()=2,"detached batch frozen")
 layer.AddChild(particles);scene.Update(100);Check(particles.Count()=0 And particles.Capacity()=2,"large step expires without reallocating")
 particles.Emit(1,1,0,0,1,2);particles.Clear()
 Check(particles.Count()=0 And particles.Capacity()=2,"clear retains slots")
 Local rejected:Int
 Try
  particles.Emit(0,0,0,0,0,1)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"invalid lifetime")
 Local map:TTileMap=TTileMap.Create(TTileGrid.Rectangular(16,16),New TTileSet)
 Local node:TTileMapNode=TTileMapNode.Create(map)
 layer.AddChild(node)
 rect.x=123
 Check(Not node.GetSelfBounds(rect) And rect.x=123,"map bounds unknown by default")
 node.SetElapsedMilliseconds(250);scene.Update(1)
 Check(node.ElapsedMilliseconds()=250,"map static by default")
 node.SetProcessing(True);scene.Update(0.125)
 Check(node.ElapsedMilliseconds()=375,"map animation clock uses seconds")
 node.SetSelfBounds(TSceneRect.Create(0,0,10,10));node.SetMap(map)
 Check(Not node.GetSelfBounds(rect) And node.ElapsedMilliseconds()=0,"map replacement clears stale bounds and time")
 scene.Destroy()
 Check(particles.Capacity()=0 And node.GetMap()=Null,"destruction releases owned references")
 Print "PASS: scene adapters "+checks+" checks"
Catch error:Object
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
