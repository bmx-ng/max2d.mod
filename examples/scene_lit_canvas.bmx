SuperStrict
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
Import Max2D.SceneLighting

' Text, meshes and ordinary drawing share one retained material receiver.
Type TInstrumentPanel Extends TLitCanvasNode
 Field mesh:TMesh2D=TMesh2D.Create([24.0,105.0,60.0,55.0,96.0,105.0])
 Field paints:Int
 Method OnPaint() Override
  paints:+1
  SetColor(85,110,145);DrawRect(0,0,280,170)
  SetColor(180,210,240);DrawText("REACTOR CONTROL",24,20)
  SetColor(70,190,220);DrawMesh(mesh)
  SetColor(220,160,70);DrawOval(126,55,92,64)
  Max2D.Core.SetAlpha(0.65)
  SetColor(235,245,255);DrawText("CAPTURE "+paints,24,138)
 End Method
End Type

Graphics(760,400)
Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(layer)
Local lighting:TSceneLighting=TSceneLighting.Create(layer)
lighting.SetAmbient(125,150,190,0.3);lighting.SetLightBatching(True)
Local light:TPointLightNode=TPointLightNode.Create(360)
light.SetColor(255,200,120);light.SetIntensity(1.6)
layer.AddChild(light);lighting.SetLights([TLightNode2D(light)])
Local panel:TInstrumentPanel=New TInstrumentPanel
panel.InitializeLighting(lighting);panel.SetCanvas(0,0,280,170)
panel.SetPosition(90,110);layer.AddChild(panel)
Local second:TInstrumentPanel=New TInstrumentPanel
second.InitializeLighting(lighting);second.SetCanvas(0,0,280,170)
second.SetPosition(405,110);second.SetRotation(8)
second.GetMaterial().SetSpecular(0.4,24);layer.AddChild(second)
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
 light.SetPosition(MouseX(),MouseY())
 If KeyHit(KEY_SPACE) Then panel.InvalidateCanvas();second.InvalidateCanvas()
 lighting.Prepare()
 SetClsColor(15,21,32);Cls;scene.Render()
 SetColor(235,240,250);SetAlpha(1);SetBlend(ALPHABLEND)
 DrawText("Move the light with the mouse. Space repaints both panels.",60,35)
 DrawText("Text + mesh + shapes                Same artwork with specular",90,325)
 Flip
Wend
scene.Destroy();lighting.ReleaseResources()
EndGraphics
