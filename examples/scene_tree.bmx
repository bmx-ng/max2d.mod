SuperStrict
Framework BRL.StandardIO
Import Max2D.Scene

Type TMovingNode Extends TSceneNode2D
    Field elapsed:Double
    Method OnUpdate(dt:Double)
        elapsed :+ dt
        SetPosition(Float(elapsed * 60), 0)
    End Method
End Type

Local scene:TScene = TScene.Create()
Local layer:TLayerNode = TLayerNode.Create()
scene.Root().AddChild(layer)
Local parent:TMovingNode = New TMovingNode
parent.SetProcessing(True)
layer.AddChild(parent)
Local child:TSceneNode2D = New TSceneNode2D
child.SetPosition(10, 20)
parent.AddChild(child)
scene.Update(0.5)
Local x:Float, y:Float
child.LocalToWorld(0, 0, x, y)
Print x + ", " + y ' 40, 20
scene.Destroy()
