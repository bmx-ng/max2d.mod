' Reusable scene component. It neither polls native input nor owns the frame loop.
Type TDragTile Extends TCustomDrawNode
 Field dragging:Int, device:Long, pointer:Long
 Field offsetX:Float, offsetY:Float
 Field releases:Int, cancellations:Int
 Field status:TTextNode
 Function Create:TDragTile(label:String,font:TImageFont,x:Float,y:Float,r:Int,g:Int,b:Int)
  Local tile:TDragTile = New TDragTile
  tile.SetName(label); tile.SetPosition(x,y); tile.SetTint(r,g,b)
  tile.SetPivot(75,50)
  tile.SetSelfBounds(TSceneRect.Create(0,0,150,100))
  tile.SetHitRect(TSceneRect.Create(0,0,150,100)); tile.SetInteractive(True)
  Local title:TTextNode = TTextNode.Create(label,font)
  title.SetPosition(13,18); tile.AddChild(title)
  tile.status = TTextNode.Create("READY",font)
  tile.status.SetPosition(13,59); tile.AddChild(tile.status)
  Return tile
 End Function
 Method OnPointer(event:TScenePointerEvent) Override
  Select event.Kind()
   Case EScenePointerKind.Down
    ' A second finger must not replace the current owner's drag offset.
    If dragging Then Return
    Local x:Float,y:Float,px:Float,py:Float
    If Not event.PositionIn(Parent(),x,y) Then Return
    GetPosition(px,py); offsetX=x-px; offsetY=y-py
    device=event.DeviceId(); pointer=event.PointerId(); dragging=True
    status.SetText("HELD "+device+":"+pointer)
    event.CapturePointer(Self); event.Handle()
   Case EScenePointerKind.Move
    If Not Owns(event) Then Return
    Local x:Float,y:Float
    If event.PositionIn(Parent(),x,y) Then SetPosition(x-offsetX,y-offsetY)
    event.Handle()
   Case EScenePointerKind.Up, EScenePointerKind.Cancel, EScenePointerKind.CaptureLost
    If Not Owns(event) Then Return
    dragging=False
    If event.Kind()=EScenePointerKind.Up Then
     releases:+1; status.SetText("RELEASED")
    Else
     cancellations:+1; status.SetText("CANCELLED")
    End If
    event.Handle()
  End Select
 End Method
 Method Owns:Int(event:TScenePointerEvent)
  Return dragging And device=event.DeviceId() And pointer=event.PointerId()
 End Method
 Method OnDraw(context:TSceneDrawContext) Override
  context.SetColor(150,190,220); DrawRect(0,0,150,100)
  context.SetColor(20,30,48); DrawRect(3,3,144,94)
  context.SetColor(200,225,255); DrawRect(13,45,124,2)
  If dragging Then DrawOval(125,15,12,12)
 End Method
End Type
