SuperStrict
?max2d_sdlrender
Framework Max2D.SDL3RenderMax2D
?Not max2d_sdlrender
Framework Max2D.SDL3GPUMax2D
?
Import Max2D.Scene
Import Max2D.ScalableFont
Import SDL3.SDL3System
Import BRL.Hook
Import BRL.Event
Import BRL.StandardIO
Import BRL.FileSystem
Import Pub.StdC
Include "drag_tile.bmx"
Include "input.bmx"
Include "playground_tests.bmx"

AppTitle="Max2D / Touch Playground"
Graphics(1100,740)
SetVirtualResolution(1100,740,VIRTUAL_LETTERBOX)
Local path:String
?osx
path="/System/Library/Fonts/Supplemental/Arial.ttf"
?win32
path=getenv_("WINDIR")+"/Fonts/segoeui.ttf"
?linux
path="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
?
Local font:TImageFont=TImageFont.DefaultFont(),title:TImageFont=font
If FileType(path)=FILETYPE_FILE Then
 font=LoadScalableImageFont(path,16); title=LoadScalableImageFont(path,30)
End If
Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(layer); scene.SetInputClip(TSceneRect.Create(30,155,1040,360)); scene.ReservePointers(20)
Local panel:TSceneNode2D=New TSceneNode2D
panel.SetTransform(550,330,-12,1.15,0.85); layer.AddChild(panel)
Local tiles:TDragTile[]=[TDragTile.Create("01 / CYAN",font,-210,0,95,215,255), ..
 TDragTile.Create("02 / AMBER",font,0,0,255,190,95), ..
 TDragTile.Create("03 / VIOLET",font,210,0,200,145,255)]
For Local tile:TDragTile=EachIn tiles
 panel.AddChild(tile)
Next
Local input:TPlaygroundInput=New TPlaygroundInput
input.Init(scene); input.mapping=CaptureWindowInput()
If AppArgs.Length>1 And AppArgs[1]="--test" Then
 RunPlaygroundTests(scene,panel,tiles,input)
 scene.Destroy(); EndGraphics; End
End If
SetAutoPoll(False)
AddHook(EmitEventHook,PlaygroundInputHook,input)
Local simulated:Int,started:Int,hidden:Int,detached:Int,singular:Int
Local simX:Float[2],simY:Float[2],startX:Float[2],startY:Float[2]
While Not AppTerminate()
 input.mapping=CaptureWindowInput()
 PollSystem()
 If KeyDown(KEY_ESCAPE) Then Exit
 If AppSuspended() Then
  input.Cancel(); input.enabled=False; simulated=False
 Else
  input.enabled=True
 End If
 If KeyHit(KEY_C) Then input.Cancel(); simulated=False
 If KeyHit(KEY_D) Then scene.SetDebugOverlay(Not scene.GetDebugOverlay())
 If KeyHit(KEY_H) Then hidden=Not hidden; tiles[0].SetVisible(Not hidden)
 If KeyHit(KEY_X) Then
  detached=Not detached
  If detached Then panel.RemoveChild(tiles[0]) Else panel.AddChild(tiles[0])
 End If
 If KeyHit(KEY_Z) Then
  singular=Not singular
  If singular Then panel.SetScale(0,0.85) Else panel.SetScale(1.15,0.85)
 End If
 If KeyHit(KEY_R) Then
  input.Cancel(); simulated=False; hidden=False; singular=False
  If detached Then panel.AddChild(tiles[0]); detached=False
  tiles[0].SetVisible(True); panel.SetTransform(550,330,-12,1.15,0.85)
  For Local i:Int=0 Until 3
   tiles[i].SetPosition((i-1)*210,0)
  Next
 End If
 If KeyHit(KEY_T) And input.enabled Then
  input.Cancel(); simulated=Not simulated; started=MilliSecs()
  If simulated Then
   For Local i:Int=0 Until 2
    scene.LocalToScreen(tiles[i],75,50,startX[i],startY[i])
    scene.DispatchPointer(EScenePointerKind.Down,2,i,startX[i],startY[i],1,1)
   Next
  End If
 End If
 If simulated Then
  Local t:Double=(MilliSecs()-started)*0.001
  For Local i:Int=0 Until 2
   simX[i]=startX[i]+Float(Sin(t*65+i*180)*110)
   simY[i]=startY[i]+Float(Sin(t*95)*200)
   scene.DispatchPointer(EScenePointerKind.Move,2,i,simX[i],simY[i],0,1)
  Next
 End If
 scene.Update(0)
 SetClsColor(7,12,22); Cls; SetBlend(ALPHABLEND); SetAlpha(1)
 SetColor(17,28,42); DrawRect(30,155,1040,360)
 scene.Render()
 SetImageFont(title); SetColor(225,240,250); DrawText("TOUCH PLAYGROUND",30,25)
 SetImageFont(font); SetColor(145,180,205)
 DrawText("Drag with multiple fingers or the mouse. Each tile belongs to one pointer until release or cancellation.",30,78)
 DrawText("The panel is rotated and scaled unevenly. Drag offsets are measured in parent coordinates.",30,111)
 SetColor(85,205,240)
 For Local i:Int=0 Until input.slots.Length
  If input.slots[i].active Then PointerMarker(input.slots[i].x,input.slots[i].y,"TOUCH "+(i+1))
 Next
 If input.mouseHeld Then PointerMarker(input.mouseX,input.mouseY,"MOUSE")
 If simulated Then
  For Local i:Int=0 Until 2
   PointerMarker(simX[i],simY[i],"SIM "+i)
  Next
 End If
 SetColor(225,240,250)
 DrawText("T  Toggle two-pointer simulation    C  Cancel all    R  Reset    D  Bounds overlay    ESC  Exit",30,548)
 SetColor(145,180,205)
 DrawText("Cancellation experiments: H  Hide cyan    X  Detach cyan    Z  Make parent singular",30,582)
 For Local i:Int=0 Until 3
  SetColor(190,210,225)
  DrawText("0"+(i+1)+"   Held: "+tiles[i].dragging+"   Releases: "+tiles[i].releases+"   Cancels: "+tiles[i].cancellations,30+i*360,628)
 Next
 SetColor(145,180,205)
 DrawText("Dark region: new presses allowed. Captured drags continue outside it. Focus loss cancels all pointers.",30,675)
 DrawText("Native touch slots: 16    Excess contacts ignored: "+input.ignored,30,703)
 Flip
Wend
RemoveHook(EmitEventHook,PlaygroundInputHook,input)
input.Cancel()
If detached Then tiles[0].Destroy()
scene.Destroy(); EndGraphics

Function PointerMarker(x:Float,y:Float,label:String)
 SetLineWidth(2); DrawLine(x-10,y,x+10,y); DrawLine(x,y-10,x,y+10)
 DrawText(label,x+14,y-8)
End Function
