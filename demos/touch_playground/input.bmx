' Single-window SDL adapter. Scene identities are separate from native IDs.
' Slots retain full-width IDs and are reused only after release/cancellation.
Type TTouchSlot
 Field active:Int, touch:ULong, finger:ULong
 Field x:Float,y:Float
End Type

Type TPlaygroundInput
 Field scene:TScene
 Field mapping:TMax2DInputMapping
 Field slots:TTouchSlot[16]
 Field enabled:Int=True, mouseHeld:Int, mouseX:Float,mouseY:Float
 Field ignored:Int
 Method Init(scene:TScene)
  Self.scene=scene
  For Local i:Int=0 Until slots.Length
   slots[i]=New TTouchSlot
  Next
 End Method
 Method Cancel()
  scene.CancelInput(); mouseHeld=False
  For Local slot:TTouchSlot=EachIn slots
   slot.active=False
  Next
 End Method
 Method Touch(kind:EScenePointerKind,touch:ULong,finger:ULong,nx:Float,ny:Float)
  If Not enabled Or Not mapping Or Not mapping.valid Then Return
  Local index:Int=-1
  For Local i:Int=0 Until slots.Length
   If slots[i].active And slots[i].touch=touch And slots[i].finger=finger Then index=i; Exit
  Next
  Local x:Float,y:Float
  Local inside:Int=mapping.WindowToVirtual(nx*mapping.windowWidth,ny*mapping.windowHeight,x,y)
  If kind=EScenePointerKind.Down Then
   If Not inside Or index>=0 Then Return
   For Local i:Int=0 Until slots.Length
    If Not slots[i].active Then index=i; Exit
   Next
   If index<0 Then ignored:+1; Return
   slots[index].active=True; slots[index].touch=touch; slots[index].finger=finger
  End If
  If index<0 Then Return
  slots[index].x=x; slots[index].y=y
  scene.DispatchPointer(kind,1,index+1,x,y,1,Int(kind<>EScenePointerKind.Up And kind<>EScenePointerKind.Cancel))
  If kind=EScenePointerKind.Up Or kind=EScenePointerKind.Cancel Then slots[index].active=False
 End Method
 Method Mouse(kind:EScenePointerKind,x:Float,y:Float)
  If Not enabled Or Not mapping Or Not mapping.valid Then Return
  Local inside:Int=mapping.WindowToVirtual(x,y,mouseX,mouseY)
  If kind=EScenePointerKind.Down Then
   If Not inside Then Return
   mouseHeld=True
  End If
  If kind=EScenePointerKind.Up Then mouseHeld=False
  scene.DispatchPointer(kind,0,0,mouseX,mouseY,1,mouseHeld)
 End Method
End Type

Function PlaygroundInputHook:Object(id:Int,data:Object,context:Object)
 Local input:TPlaygroundInput=TPlaygroundInput(context), event:TEvent=TEvent(data)
 If Not event Then Return data
 If event.id=EVENT_APPSUSPEND Then input.Cancel(); input.enabled=False
 If event.id=EVENT_APPRESUME Then input.enabled=True
 Local touch:TSDLTouchEvent=TSDLTouchEvent(event.extra)
 If touch And touch.touchID<>$ffffffffffffffff:ULong Then
  Select event.id
   Case EVENT_TOUCHDOWN
    input.Touch(EScenePointerKind.Down,touch.touchID,touch.fingerID,touch.x,touch.y)
   Case EVENT_TOUCHMOVE
    input.Touch(EScenePointerKind.Move,touch.touchID,touch.fingerID,touch.x,touch.y)
   Case EVENT_TOUCHUP
    If touch.canceled Then
     input.Touch(EScenePointerKind.Cancel,touch.touchID,touch.fingerID,touch.x,touch.y)
    Else
     input.Touch(EScenePointerKind.Up,touch.touchID,touch.fingerID,touch.x,touch.y)
    End If
  End Select
 End If
 Local mouse:TSDLMouseEvent=TSDLMouseEvent(event.extra)
 ' SDL reserves this ID for mouse events synthesized from touches.
 If mouse And mouse.mouseID<>$ffffffff:UInt Then
  Select event.id
   Case EVENT_MOUSEDOWN
    If mouse.button=1 Then input.Mouse(EScenePointerKind.Down,mouse.x,mouse.y)
   Case EVENT_MOUSEUP
    If mouse.button=1 Then input.Mouse(EScenePointerKind.Up,mouse.x,mouse.y)
   Case EVENT_MOUSEMOVE
    input.Mouse(EScenePointerKind.Move,mouse.x,mouse.y)
  End Select
 End If
 ' Observing the event does not consume it for other application hooks.
 Return data
End Function
