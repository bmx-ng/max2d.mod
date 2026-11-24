SuperStrict
Framework BRL.StandardIO
Import Max2D.Scene
Global checks:Int, logging:Int=True, trail:String
Function Check(ok:Int,message:String)
 If Not ok Then Throw "FAIL: "+message
 checks :+ 1
End Function
Type TReceiver Extends TSceneNode2D
 Field action:Int, downs:Int,moves:Int,ups:Int,cancels:Int,lost:Int
 Field save:Int, snapshot:TScenePointerSnapshot, borrowed:TScenePointerEvent
 Field exitSawCancel:Int
 Method Note(event:TScenePointerEvent,phase:String)
  If logging Then trail :+ GetName()+phase+Int(event.Kind())+" "
 End Method
 Method OnPointerCapture(event:TScenePointerEvent)
  Note(event,"c")
  If action=10 Then event.StopPropagation()
  If action=11 And event.Kind()=EScenePointerKind.Down Then event.CapturePointer(Self)
 End Method
 Method OnPointerBubble(event:TScenePointerEvent)
  Note(event,"b")
 End Method
 Method OnPointer(event:TScenePointerEvent)
  Note(event,"t")
  Select event.Kind()
   Case EScenePointerKind.Down
    downs :+ 1
    If save Then snapshot=event.Copy(); borrowed=event
    If action=1 Or action>=3 Then event.CapturePointer(Self)
    If action=2 Then event.Handle()
    If action=3 Then Parent().RemoveChild(Self)
    If action=4 Then Destroy()
    If action=5 Then SetVisible(False)
    If action=6 Then Throw "down failure"
    If action=7 Then Scene().DispatchPointer(EScenePointerKind.Move,0,0,0,0)
   Case EScenePointerKind.Move
    moves :+ 1
    If action=8 Then event.ReleasePointer()
   Case EScenePointerKind.Up
    ups :+ 1
   Case EScenePointerKind.Cancel
    cancels :+ 1
    Local x:Float=9,y:Float=8
    Check(Not event.PositionIn(Self,x,y) And x=9 And y=8,"Cancel has no position")
    If action=9 Then Throw "cancel failure"
   Case EScenePointerKind.CaptureLost
    lost :+ 1
  End Select
 End Method
 Method OnExitScene()
  exitSawCancel=cancels
 End Method
End Type
Function Receiver:TReceiver(parent:TSceneNode,name:String,x:Float=0)
 Local node:TReceiver=New TReceiver
 node.SetName(name); node.SetPosition(x,0)
 node.SetHitRect(TSceneRect.Create(0,0,100,100)); node.SetInteractive(True)
 parent.AddChild(node)
 Return node
End Function
Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(layer); scene.SetInputClip(TSceneRect.Create(0,0,500,500))
scene.ReservePointers(8)
Local parent:TReceiver=Receiver(layer,"p"),child:TReceiver=Receiver(parent,"a")
Local second:TReceiver=Receiver(layer,"b",200)
trail=""
Check(Not scene.DispatchPointer(EScenePointerKind.Down,1,1,20,20),"unhandled event returns false")
Check(trail="pc0 at0 pb0 ","capture/target/bubble order")
scene.DispatchPointer(EScenePointerKind.Up,1,1,20,20)
parent.action=10; trail=""
Check(Not scene.DispatchPointer(EScenePointerKind.Down,1,2,20,20),"stop without handle keeps fallback")
Check(trail="pc0 ","stop prevents later visits")
scene.CancelInput(); parent.action=0
child.action=2; trail=""
Check(scene.DispatchPointer(EScenePointerKind.Down,1,3,20,20),"handle suppresses fallback")
Check(trail="pc0 at0 ","handle stops bubbling")
scene.CancelInput()
child.action=1; second.action=1; child.save=True
scene.DispatchPointer(EScenePointerKind.Down,4,7,20,20,1,1)
scene.DispatchPointer(EScenePointerKind.Down,5,7,220,20,1,1)
Check(child.snapshot.DeviceId()=4 And child.snapshot.PointerId()=7 And child.snapshot.Button()=1 And child.snapshot.Buttons()=1,"snapshot preserves IDs and button state")
Check(child.snapshot.Target()=child And child.snapshot.CurrentTarget()=child,"snapshot keeps callback targets")
Local failed:Int
Try
 child.borrowed.Kind()
Catch error:Object
 failed=True
End Try
Check(failed,"borrowed event expires")
scene.DispatchPointer(EScenePointerKind.Move,4,7,900,900)
scene.DispatchPointer(EScenePointerKind.Move,5,7,-100,-100)
Check(child.moves=1 And second.moves=1,"independent device/pointer captures outside clip")
scene.DispatchPointer(EScenePointerKind.Up,4,7,900,900)
Check(child.ups=2 And child.lost=1,"Up reaches capture and releases")
Check(second.lost=0,"other device capture remains")
scene.CancelInput()
Check(second.cancels=1 And second.lost=1,"focus-loss cancellation releases remaining capture")
child.save=False
scene.DispatchPointer(EScenePointerKind.Down,1,1,20,20)
child.action=8
scene.DispatchPointer(EScenePointerKind.Move,1,1,900,900)
Check(child.lost=2,"explicit release sends CaptureLost")
Local oldMoves:Int=child.moves
scene.DispatchPointer(EScenePointerKind.Move,1,1,900,900)
Check(child.moves=oldMoves,"released pointer uses picking")
scene.CancelInput()
child.action=1
scene.DispatchPointer(EScenePointerKind.Down,1,1,20,20)
failed=False
Try
 scene.DispatchPointer(EScenePointerKind.Down,1,1,20,20)
Catch error:Object
 failed=True
End Try
Check(failed,"duplicate active Down rejected")
scene.DispatchPointer(EScenePointerKind.Up,1,1,20,20)
For Local action:Int=3 To 7
 Local node:TReceiver=Receiver(layer,"temporary",350)
 node.action=action
 failed=False
 Try
  scene.DispatchPointer(EScenePointerKind.Down,8,action,360,10)
 Catch error:Object
  failed=True
 End Try
 If action>=6 Then Check(failed,"throwing/nested dispatch fails") Else Check(Not failed,"callback mutation supported")
 Check(node.cancels=1 And node.lost=1,"mutation/error cancels and releases capture")
 If action=3 Or action=4 Then Check(node.exitSawCancel=1,"cancel precedes exit")
 If action<>4 Then node.Destroy()
Next
child.action=1
For Local mode:Int=0 To 4
 scene.DispatchPointer(EScenePointerKind.Down,1,1,20,20)
 Local before:Int=child.cancels
 Select mode
  Case 0
   parent.SetVisible(False)
  Case 1
   parent.SetAlpha(0)
  Case 2
   parent.SetScale(0,1)
  Case 3
   child.SetInteractive(False)
  Case 4
   child.Reparent(layer)
 End Select
 scene.Update(0)
 Check(child.cancels=before+1,"eligibility change or reparent cancels capture")
 parent.SetVisible(True); parent.SetAlpha(1); parent.SetScale(1,1); child.SetInteractive(True)
 If mode=4 Then child.Reparent(parent)
Next
child.action=1; second.action=1
scene.DispatchPointer(EScenePointerKind.Down,1,1,20,20)
scene.DispatchPointer(EScenePointerKind.Down,1,2,220,20)
child.action=9
failed=False
Try
 scene.CancelInput()
Catch error:Object
 failed=True
End Try
Check(failed,"cancel callback error propagated")
Local oldLost:Int=second.lost
scene.CancelInput()
Check(second.lost=oldLost,"all records cleared despite cancel callback failure")
parent.action=11; child.action=0
scene.DispatchPointer(EScenePointerKind.Down,1,9,20,20)
Local parentMoves:Int=parent.moves
scene.DispatchPointer(EScenePointerKind.Move,1,9,800,800)
Check(parent.moves=parentMoves+1,"ancestor can capture during capture phase")
scene.TrimStorage()
scene.DispatchPointer(EScenePointerKind.Up,1,9,800,800)
Check(parent.lost=1,"active capture survives storage trim")
parent.action=11; child.action=1
failed=False
Try
 scene.DispatchPointer(EScenePointerKind.Down,1,10,20,20)
Catch error:Object
 failed=True
End Try
Check(failed And parent.lost=2,"capture cannot be stolen and error clears owner")
parent.action=0
scene.ReservePointers(8)
child.action=1
logging=False
scene.DispatchPointer(EScenePointerKind.Down,1,1,20,20)
Local s0:SGCStats,s1:SGCStats
GCCollect(); GCGetStats(s0)
For Local i:Int=0 Until 10000
 scene.DispatchPointer(EScenePointerKind.Move,1,1,20,20)
Next
GCGetStats(s1)
Local allocated:ULongInt=(s1.allocedBytesBeforeGC+s1.bytesAllocedSinceGC)-(s0.allocedBytesBeforeGC+s0.bytesAllocedSinceGC)
Print "10,000 captured moves: "+allocated+" GC bytes"
Check(allocated=0,"warm pointer routing allocates zero bytes")
scene.DispatchPointer(EScenePointerKind.Up,1,1,20,20)
scene.Destroy()
Print "PASS: "+checks+" scene pointer checks"
