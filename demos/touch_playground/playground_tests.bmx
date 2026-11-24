Function PlaygroundCheck(value:Int,message:String)
 If Not value Then Throw "FAIL: "+message
End Function
Function RunPlaygroundTests(scene:TScene,panel:TSceneNode2D,tiles:TDragTile[],input:TPlaygroundInput)
 Local sx:Float[2],sy:Float[2],px:Float,py:Float
 For Local i:Int=0 Until 2
  scene.LocalToScreen(tiles[i],90,60,sx[i],sy[i])
  scene.DispatchPointer(EScenePointerKind.Down,2,i,sx[i],sy[i],1,1)
  scene.DispatchPointer(EScenePointerKind.Move,2,i,sx[i],sy[i],0,1)
  tiles[i].GetPosition(px,py)
  PlaygroundCheck(Abs(px-(i-1)*210)<0.01 And Abs(py)<0.01,"no jump with pivot and affine parent")
  PlaygroundCheck(tiles[i].dragging,"independent capture")
 Next
 scene.DispatchPointer(EScenePointerKind.Down,3,9,sx[0],sy[0],1,1)
 PlaygroundCheck(tiles[0].device=2 And tiles[0].pointer=0,"second pointer cannot steal tile")
 scene.DispatchPointer(EScenePointerKind.Move,2,0,-100,-100,0,1)
 PlaygroundCheck(tiles[0].dragging And tiles[1].dragging,"capture outside input clip")
 scene.DispatchPointer(EScenePointerKind.Up,2,0,-100,-100,1,0)
 PlaygroundCheck(Not tiles[0].dragging And tiles[1].dragging,"independent release")
 tiles[1].SetVisible(False); scene.Update(0)
 PlaygroundCheck(Not tiles[1].dragging,"hiding cancels")
 tiles[1].SetVisible(True); scene.CancelInput()
 tiles[0].SetPosition(-210,0)
 For Local experiment:Int=0 Until 2
  scene.LocalToScreen(tiles[0],75,50,sx[0],sy[0])
  scene.DispatchPointer(EScenePointerKind.Down,2,0,sx[0],sy[0],1,1)
  If experiment=0 Then
   panel.RemoveChild(tiles[0])
   PlaygroundCheck(Not tiles[0].dragging,"detach cancels")
   panel.AddChild(tiles[0])
  Else
   panel.SetScale(0,0.85)
   scene.Update(0)
   PlaygroundCheck(Not tiles[0].dragging,"singular parent cancels")
   panel.SetScale(1.15,0.85)
  End If
 Next
 ' Exercise the adapter using distinct full-width IDs with identical low bits.
 Local nx:Float[2],ny:Float[2]
 For Local i:Int=0 Until 2
  scene.LocalToScreen(tiles[i],75,50,sx[i],sy[i])
  input.mapping.VirtualToWindow(sx[i],sy[i],nx[i],ny[i])
  nx[i]:/input.mapping.windowWidth; ny[i]:/input.mapping.windowHeight
  input.Touch(EScenePointerKind.Down,ULong(i+1) Shl 32 | 7:ULong,9,nx[i],ny[i])
 Next
 PlaygroundCheck(tiles[0].dragging And tiles[1].dragging,"full-width device IDs remain independent")
 input.Touch(EScenePointerKind.Cancel,$100000007:ULong,9,nx[0],ny[0])
 PlaygroundCheck(Not tiles[0].dragging And tiles[1].dragging,"native cancel only releases its pointer")
 input.Cancel()
 PlaygroundCheck(Not tiles[1].dragging And Not input.slots[1].active,"focus-loss cancellation clears adapter")
 input.Touch(EScenePointerKind.Move,$200000007:ULong,9,nx[1],ny[1])
 PlaygroundCheck(Not tiles[1].dragging,"stale move cannot restart cancelled drag")
 ' Verify the event hook filters synthetic mouse input and routes real metadata.
 Local mouse:TSDLMouseEvent=New TSDLMouseEvent
 input.mapping.VirtualToWindow(sx[0],sy[0],mouse.x,mouse.y)
 mouse.button=1; mouse.mouseID=$ffffffff:UInt
 PlaygroundInputHook(EmitEventHook,TEvent.Create(EVENT_MOUSEDOWN,Null,0,0,0,0,mouse),input)
 PlaygroundCheck(Not tiles[0].dragging,"touch-generated mouse is ignored")
 mouse.mouseID=0
 PlaygroundInputHook(EmitEventHook,TEvent.Create(EVENT_MOUSEDOWN,Null,0,0,0,0,mouse),input)
 PlaygroundCheck(tiles[0].dragging,"native mouse hook dispatches")
 PlaygroundInputHook(EmitEventHook,TEvent.Create(EVENT_APPSUSPEND),input)
 PlaygroundCheck(Not tiles[0].dragging And Not input.enabled,"suspend event cancels")
 PlaygroundInputHook(EmitEventHook,TEvent.Create(EVENT_APPRESUME),input)
 Local touch:TSDLTouchEvent=New TSDLTouchEvent
 touch.touchID=$300000007:ULong; touch.fingerID=$400000009:ULong
 touch.x=nx[0]; touch.y=ny[0]
 PlaygroundInputHook(EmitEventHook,TEvent.Create(EVENT_TOUCHDOWN,Null,0,0,0,0,touch),input)
 PlaygroundCheck(tiles[0].dragging,"native touch hook dispatches")
 touch.canceled=True
 PlaygroundInputHook(EmitEventHook,TEvent.Create(EVENT_TOUCHUP,Null,0,0,0,0,touch),input)
 PlaygroundCheck(Not tiles[0].dragging,"native cancellation payload dispatches")
 scene.Render()
 Print "PASS: Touch Playground affine drags, independent capture, cancellation and native ID mapping"
End Function
