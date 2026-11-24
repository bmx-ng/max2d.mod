SuperStrict
Framework BRL.StandardIO
Import Max2D.Scene
Global checks:Int, trail:String, logging:Int=True
Function Check(ok:Int,message:String)
 If Not ok Then Throw "FAIL: "+message
 checks :+ 1
End Function
Type TControl Extends TSceneNode2D
 Field enters:Int,leaves:Int,gained:Int,lost:Int,keys:Int,action:Int
 Field borrowed:TSceneKeyEvent,snapshot:TSceneKeySnapshot,save:Int
 Field focusOther:TSceneNode2D
 Field exitedLost:Int
 Method OnFocusGained()
  gained :+ 1
  If action=8 Then Scene().SetFocus(Self)
 End Method
 Method OnFocusLost()
  lost :+ 1
  If action=9 Then Throw "focus lost error"
 End Method
 Method OnExitScene()
  exitedLost=lost
 End Method
 Method OnPointer(event:TScenePointerEvent)
  Select event.Kind()
   Case EScenePointerKind.Enter
    enters :+ 1
    If action=6 Then Throw "enter error"
   Case EScenePointerKind.Leave
    leaves :+ 1
   Case EScenePointerKind.Down
    event.CapturePointer(Self)
  End Select
 End Method
 Method OnKeyCapture(event:TSceneKeyEvent)
  If logging Then trail :+ GetName()+"c "
  If action=1 Then event.StopPropagation()
  If action=10 Then SetInputEnabled(False)
 End Method
 Method OnKey(event:TSceneKeyEvent)
  keys :+ 1
  If logging Then trail :+ GetName()+"t "
  If save Then borrowed=event; snapshot=event.Copy()
  Select action
   Case 2
    event.Handle()
   Case 3
    Scene().SetFocus(focusOther)
   Case 4
    Destroy()
   Case 5
    Throw "key error"
   Case 7
    Scene().DispatchKey(ESceneKeyKind.Down,1)
  End Select
 End Method
 Method OnKeyBubble(event:TSceneKeyEvent)
  If logging Then trail :+ GetName()+"b "
 End Method
End Type
Function Control:TControl(parent:TSceneNode,name:String,x:Float=0)
 Local node:TControl=New TControl
 node.SetName(name); node.SetPosition(x,0)
 node.SetHitRect(TSceneRect.Create(0,0,100,100)); node.SetInteractive(True); node.SetFocusable(True)
 parent.AddChild(node)
 Return node
End Function
Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(layer); scene.SetInputClip(TSceneRect.Create(0,0,500,500))
Local parent:TControl=Control(layer,"p"),a:TControl=Control(parent,"a"),b:TControl=Control(layer,"b",200)
parent.SetFocusable(False)
scene.DispatchPointer(EScenePointerKind.Move,1,1,20,20)
Check(a.enters=0,"touch/default pointers do not hover")
scene.SetPointerHover(0,0)
scene.DispatchPointer(EScenePointerKind.Move,0,0,20,20)
Check(a.enters=1 And parent.enters=0,"hover targets only picked node")
scene.Update(0)
Check(a.enters=1,"stationary unchanged hover has no duplicate enter")
a.SetPosition(120,0); scene.Update(0)
Check(a.leaves=1 And parent.enters=1,"stationary hover follows moving geometry")
a.SetPosition(0,0); scene.Update(0)
Check(a.enters=2 And parent.leaves=1,"stationary hover returns")
scene.DispatchPointer(EScenePointerKind.Down,0,0,20,20)
scene.DispatchPointer(EScenePointerKind.Move,0,0,220,20)
Check(b.enters=0 And a.leaves=1,"capture suspends hover transitions")
scene.DispatchPointer(EScenePointerKind.Up,0,0,220,20)
Check(b.enters=1 And a.leaves=2,"hover resumes after capture ends")
scene.SetPointerHover(0,0,False)
Check(b.leaves=1,"disable hover sends leave")
scene.SetPointerHover(0,0)
scene.Update(0)
Check(b.enters=1,"newly enabled hover waits for position")
scene.DispatchPointer(EScenePointerKind.Move,0,0,20,20)
parent.SetInputEnabled(False); scene.Update(0)
Check(a.leaves=3 And scene.Pick(20,20)=Null,"input-disabled branch excludes picking and hover")
parent.SetInputEnabled(True); scene.Update(0)
Check(a.enters=4,"reenabled branch restores stationary hover")
scene.SetFocus(a)
Check(scene.FocusedNode()=a And a.gained=1,"explicit focus")
a.SetInteractive(False)
scene.Update(0)
Check(scene.FocusedNode()=a,"keyboard focus independent of pointer interactivity")
trail=""; a.save=True
Check(Not scene.DispatchKey(ESceneKeyKind.Down,65,SCENE_MOD_SHIFT,True),"unhandled key returns false")
Check(trail="pc at pb ","key capture/target/bubble path")
Check(a.snapshot.Key()=65 And a.snapshot.Modifiers()=SCENE_MOD_SHIFT And a.snapshot.Repeated(),"key snapshot data")
Local failed:Int
Try
 a.borrowed.Handle()
Catch error:Object
 failed=True
End Try
Check(failed,"borrowed key event expires")
a.save=False
parent.action=1; trail=""
Check(Not scene.DispatchKey(ESceneKeyKind.Up,65),"stop does not handle")
Check(trail="pc ","stop prevents subsequent key visits")
parent.action=0; a.action=2; trail=""
Check(scene.DispatchKey(ESceneKeyKind.Down,65),"handle reports handled")
Check(trail="pc at ","handle stops key bubbling")
a.action=3; a.focusOther=b; trail=""
scene.DispatchKey(ESceneKeyKind.Down,65)
Check(scene.FocusedNode()=b And trail="pc at pb ","focus change keeps active event path stable")
a.action=0; a.SetInteractive(True)
a.SetFocusOrder(10); b.SetFocusOrder(-10)
scene.SetFocus(Null); scene.FocusNext()
Check(scene.FocusedNode()=b,"navigation starts at lowest order")
scene.FocusNext()
Check(scene.FocusedNode()=a,"navigation advances")
scene.FocusNext()
Check(scene.FocusedNode()=b,"navigation wraps")
scene.FocusNext(True)
Check(scene.FocusedNode()=a,"reverse navigation")
a.SetFocusOrder(0); b.SetFocusOrder(0); layer.SetSortableChildren(True); b.SetZIndex(-100)
scene.SetFocus(Null); scene.FocusNext()
Check(scene.FocusedNode()=a,"equal focus order uses insertion rather than z order")
scene.FocusNext(); Check(scene.FocusedNode()=b,"insertion-order tie advances")
b.SetVisible(False); scene.Update(0)
Check(scene.FocusedNode()=Null,"hidden focus is cleared")
b.SetVisible(True); scene.SetFocus(a)
a.Reparent(layer)
Check(scene.FocusedNode()=a,"same-scene reparent preserves eligible focus")
Local beforeLost:Int=a.lost
layer.RemoveChild(a)
Check(scene.FocusedNode()=Null And a.exitedLost=beforeLost+1,"focus lost before exit")
parent.AddChild(a)
scene.SetFocus(a); parent.SetScale(0,1); scene.Update(0)
Check(scene.FocusedNode()=Null,"singular ancestor loses focus")
parent.SetScale(1,1)
For Local action:Int=4 To 9
 If action=6 Then Continue
 Local temp:TControl=Control(layer,"temp",350)
 temp.action=action; failed=False
 Try
  scene.SetFocus(temp)
  If action=9 Then scene.SetFocus(b) Else scene.DispatchKey(ESceneKeyKind.Down,65)
 Catch error:Object
  failed=True
 End Try
 If action=4 Then
  Check(Not failed And scene.FocusedNode()=Null And temp.exitedLost=1,"destroy inside key callback clears focus before exit")
 Else
  Check(failed,"key/focus callback failure or reentry rejected")
 End If
 temp.action=0
 If action<>4 Then temp.Destroy()
 scene.SetFocus(b)
 Check(scene.DispatchKey(ESceneKeyKind.Up,65)=False,"dispatch recovers after callback failure")
Next
scene.SetFocus(a); parent.action=10
Local oldKeys:Int=a.keys
scene.DispatchKey(ESceneKeyKind.Down,65)
Check(a.keys=oldKeys And scene.FocusedNode()=Null,"ancestor disabling input suppresses remaining key path")
parent.action=0; parent.SetInputEnabled(True)
scene.DispatchPointer(EScenePointerKind.Move,0,0,20,20)
a.action=6
scene.DispatchPointer(EScenePointerKind.Move,0,0,450,450)
failed=False
Try
 scene.DispatchPointer(EScenePointerKind.Move,0,0,20,20)
Catch error:Object
 failed=True
End Try
Check(failed,"hover callback error propagated")
a.action=0
scene.SetFocus(b); scene.CancelInput()
Check(scene.FocusedNode()=Null,"CancelInput clears focus")
Local oldEnters:Int=a.enters
scene.Update(0)
Check(a.enters=oldEnters,"CancelInput forgets hover position")
scene.DispatchPointer(EScenePointerKind.Move,0,0,20,20)
Check(a.enters=oldEnters+1,"configured hover resumes with new input")
scene.SetFocus(a); logging=False
scene.DispatchKey(ESceneKeyKind.Down,65)
Local s0:SGCStats,s1:SGCStats
GCCollect(); GCGetStats(s0)
For Local i:Int=0 Until 1000
 scene.DispatchKey(ESceneKeyKind.Down,65)
 scene.Update(0)
Next
GCGetStats(s1)
Local allocated:ULongInt=(s1.allocedBytesBeforeGC+s1.bytesAllocedSinceGC)-(s0.allocedBytesBeforeGC+s0.bytesAllocedSinceGC)
Print "1,000 key events and stationary-hover updates: "+allocated+" GC bytes"
Check(allocated=0,"warm key and hover traversal allocate zero bytes")
scene.TrimStorage(); scene.Update(0)
Check(scene.FocusedNode()=a,"trim preserves focus")
scene.Destroy()
Check(scene.FocusedNode()=Null,"destroy clears focus")
Print "PASS: "+checks+" scene interaction checks"
