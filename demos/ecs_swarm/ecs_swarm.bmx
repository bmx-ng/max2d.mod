SuperStrict
Framework Max2D.SDL3GPUMax2D
Import BRL.Random
Include "swarm.bmx"

AppTitle="Max2D / ECS Swarm"
Graphics(900,620)
SetVirtualResolution(900,620,VIRTUAL_LETTERBOX)
Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(layer)
Local swarm:TSwarm=TSwarm.Create(layer)
Local paused:Int,previous:Int=MilliSecs()
For Local i:Int=0 Until 160
 swarm.Spawn(Float(Rnd(24,876)),Float(Rnd(140,596)),Float(Rnd(-140,140)),Float(Rnd(-140,140)),Float(Rnd(8,24)))
Next
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
 Local now:Int=MilliSecs(),dt:Float=Float(Min(0.1,Max(0.0,Double(now-previous)/1000)))
 previous=now
 If KeyHit(KEY_P) Then paused=Not paused;scene.SetPaused(paused)
 Local x:Float,y:Float
 Local inside:Int=GetVirtualMouse(x,y)
 Local burst:Int=KeyHit(KEY_SPACE)
 If inside And MouseHit(1) Then burst=True Else x=450;y=360
 If burst Then
  For Local i:Int=0 Until 48
   Local angle:Float=Rnd(360),speed:Float=Rnd(60,170)
   swarm.Spawn(x,y,Float(Cos(angle)*speed),Float(Sin(angle)*speed))
  Next
 End If
 If Not paused Then swarm.Step(dt)
 scene.Update(dt)
 SetClsColor(9,17,29);Cls()
 scene.Render()
 SetColor(225,240,255)
 DrawText("ECS SWARM / "+swarm.count+" of 512 retained views",28,26)
 DrawText("Click or Space: spawn 48    P: pause    Esc: quit",28,54)
 DrawText("Flecs owns motion and lifetime. Scene nodes present the result.",28,82)
 If paused Then DrawText("PAUSED",770,26)
 Flip()
Wend
swarm.Close()
scene.Destroy()
EndGraphics()
