SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?max2d_gl
Framework Max2D.GLMax2D
?Not max2d_gl And Not max2d_sdlgpu
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.Scene
Import Max2D.ScalableFont
Import BRL.FileSystem
Import Pub.StdC

Type TCard Extends TCustomDrawNode
 Field dragging:Int, dragDevice:Long, dragPointer:Long
 Field offsetX:Float, offsetY:Float
 Field hovered:Int, focused:Int, activated:Int
 Method OnPointer(event:TScenePointerEvent)
  Select event.Kind()
   Case EScenePointerKind.Enter
    hovered=True
   Case EScenePointerKind.Leave
    hovered=False
   Case EScenePointerKind.Down
    If dragging Then Return
    Local x:Float,y:Float,px:Float,py:Float
    If Not event.PositionIn(Parent(),x,y) Then Return
    GetPosition(px,py); offsetX=x-px; offsetY=y-py
    dragging=True; dragDevice=event.DeviceId(); dragPointer=event.PointerId()
    Scene().SetFocus(Self)
    event.CapturePointer(Self); event.Handle()
   Case EScenePointerKind.Move
    If Not dragging Or event.DeviceId()<>dragDevice Or event.PointerId()<>dragPointer Then Return
    Local x:Float,y:Float
    If event.PositionIn(Parent(),x,y) Then SetPosition(x-offsetX,y-offsetY)
    event.Handle()
   Case EScenePointerKind.Up,EScenePointerKind.Cancel,EScenePointerKind.CaptureLost
    If event.DeviceId()=dragDevice And event.PointerId()=dragPointer Then
     dragging=False
    End If
  End Select
 End Method
 Method OnFocusGained()
  focused=True
 End Method
 Method OnFocusLost()
  focused=False
 End Method
 Method OnKey(event:TSceneKeyEvent)
  If event.Kind()<>ESceneKeyKind.Down Then Return
  Local x:Float,y:Float
  GetPosition(x,y)
  Select event.Key()
   Case KEY_LEFT
    SetPosition(x-15,y)
   Case KEY_RIGHT
    SetPosition(x+15,y)
   Case KEY_UP
    SetPosition(x,y-15)
   Case KEY_DOWN
    SetPosition(x,y+15)
   Case KEY_SPACE,KEY_ENTER
    activated=Not activated
   Default
    Return
  End Select
  event.Handle()
 End Method
 Method OnDraw(context:TSceneDrawContext)
  context.SetColor(255,255,255)
  DrawRect(0,0,210,145)
  context.SetColor(45,55,70)
  DrawRect(12,12,186,121)
  If focused Then
   context.SetColor(255,255,255)
   DrawLine(17,17,193,17); DrawLine(193,17,193,128)
   DrawLine(193,128,17,128); DrawLine(17,128,17,17)
  End If
  context.SetColor(255,255,255)
  DrawRect(24,90,100,4)
  If dragging Or hovered Then DrawRect(24,72,156,5)
  If activated Then DrawOval(174,93,12,12)
  context.SetAlpha(0.3)
  DrawRect(24,104,156,3)
  DrawRect(24,115,130,3)
 End Method
 Function Create:TCard(label:String,font:TImageFont,x:Float,y:Float,red:Int,green:Int,blue:Int)
  Local card:TCard=New TCard
  card.SetPosition(x,y); card.SetTint(red,green,blue)
  card.SetSelfBounds(TSceneRect.Create(0,0,210,145))
  card.SetFocusable(True); card.SetInteractive(True); card.SetName(label)
  Local title:TTextNode=TTextNode.Create(label,font)
  title.SetPosition(24,30)
  card.AddChild(title)
  Return card
 End Function
End Type

AppTitle="Max2D Scene / Hover and keyboard focus"
Graphics 960,640
SetVirtualResolution(960,640,VIRTUAL_LETTERBOX)
Local path:String
?osx
path="/System/Library/Fonts/Supplemental/Arial.ttf"
?win32
path=getenv_("WINDIR")+"/Fonts/segoeui.ttf"
?linux
path="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
?
Local font:TImageFont=TImageFont.DefaultFont(), large:TImageFont=font
If FileType(path)=FILETYPE_FILE Then
 font=LoadScalableImageFont(path,18)
 large=LoadScalableImageFont(path,30)
End If
Local scene:TScene=TScene.Create(), layer:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(layer)
scene.SetInputClip(TSceneRect.Create(0,0,960,640))
scene.ReservePointers(8)
scene.SetPointerHover(0,0)
Local group:TSceneNode2D=New TSceneNode2D
group.SetPosition(265,205); group.SetSortableChildren(True)
layer.AddChild(group)
Local cards:TCard[]=[TCard.Create("01 / AMBER",font,0,0,255,184,99),TCard.Create("02 / CYAN",font,110,75,96,221,240),TCard.Create("03 / VIOLET",font,220,150,197,155,255)]
For Local i:Int=0 Until cards.Length
 group.AddChild(cards[i]); cards[i].SetZIndex(i)
Next
Local title:TTextNode=TTextNode.Create("HOVER & KEYBOARD FOCUS",large)
title.SetPosition(40,30); layer.AddChild(title)
Local status:TTextNode=TTextNode.Create("",font)
status.SetPosition(40,83); status.SetTint(150,180,200); layer.AddChild(status)
Local help:TTextNode=TTextNode.Create("Z reverse order   S sorting   R rotate cyan   H hide violet   ESC exit",font)
help.SetPosition(40,595); help.SetTint(150,180,200); layer.AddChild(help)
Local hover:TTextNode=TTextNode.Create("Tab / Shift+Tab focus    Arrows move    Space activates    Click or drag",font)
hover.SetPosition(40,120); layer.AddChild(hover)
Local mousePressed:Int, wasSuspended:Int
Local routedKeys:Int[]=[KEY_TAB,KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_SPACE,KEY_ENTER]
Local previousKeys:Int[]=New Int[routedKeys.Length]
Local bounds:TSceneRect=New TSceneRect
Local sorted:Int=True, reversed:Int, rotated:Int, hidden:Int, frames:Int
Local refresh:Int=True
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
 If KeyHit(KEY_Z) Then
  reversed=Not reversed
  For Local i:Int=0 Until cards.Length
   If reversed Then cards[i].SetZIndex(2-i) Else cards[i].SetZIndex(i)
  Next
  refresh=True
 End If
 If KeyHit(KEY_S) Then sorted=Not sorted; group.SetSortableChildren(sorted); refresh=True
 If KeyHit(KEY_R) Then
  rotated=Not rotated
  If rotated Then cards[1].SetRotation(-25) Else cards[1].SetRotation(0)
 End If
 If KeyHit(KEY_H) Then hidden=Not hidden; cards[2].SetVisible(Not hidden)
 If refresh Then
  Local message:String="Insertion order (sorting disabled)"
  If sorted Then
   message="Sorted by z-index / violet above cyan above amber"
   If reversed Then message="Sorted by z-index / amber above cyan above violet"
  End If
  status.SetText(message); refresh=False
 End If
 Local suspended:Int=AppSuspended()
 If suspended And Not wasSuspended Then scene.CancelInput(); mousePressed=False
 wasSuspended=suspended
 If Not suspended Then
  Local mx:Float,my:Float
  Local inside:Int=GetVirtualMouse(mx,my)
  Local pressed:Int=MouseDown(1) Or MouseHit(1)
  If KeyHit(KEY_C) Then scene.CancelInput()
  If pressed And Not mousePressed Then
   If inside Then scene.DispatchPointer(EScenePointerKind.Down,0,0,mx,my,1,1)
  Else If Not pressed And mousePressed Then
   scene.DispatchPointer(EScenePointerKind.Up,0,0,mx,my,1,0)
  Else
   ' Always forward unclipped coordinates so captured drags can leave the table.
   scene.DispatchPointer(EScenePointerKind.Move,0,0,mx,my,0,pressed)
  End If
  mousePressed=pressed
  Local modifiers:Int
  If KeyDown(KEY_LSHIFT) Or KeyDown(KEY_RSHIFT) Then modifiers :| SCENE_MOD_SHIFT
  For Local i:Int=0 Until routedKeys.Length
   Local key:Int=routedKeys[i], held:Int=KeyDown(key), hits:Int=KeyHit(key)
   For Local hit:Int=0 Until hits
    If Not scene.DispatchKey(ESceneKeyKind.Down,key,modifiers) Then
     If key=KEY_TAB Then scene.FocusNext((modifiers & SCENE_MOD_SHIFT)<>0)
    End If
    ' Preserve quick taps which started and ended between frames.
    If Not held Then scene.DispatchKey(ESceneKeyKind.Up,key,modifiers)
   Next
   If hits=0 And Not held And previousKeys[i] Then scene.DispatchKey(ESceneKeyKind.Up,key,modifiers)
   previousKeys[i]=held
  Next
 End If
 scene.Update(0)
 SetClsColor(10,18,29); Cls()
 scene.Render()
 ' This group's own transform is only translation, so its local AABB can be
 ' drawn in the same coordinates without needing an inverse world transform.
 If group.GetContentBounds(bounds) And bounds.width>0 And bounds.height>0 Then
  SetColor(225,240,245)
  Local x:Float=265+bounds.x-6,y:Float=205+bounds.y-6,w:Float=bounds.width+12,h:Float=bounds.height+12
  DrawLine(x,y,x+w,y); DrawLine(x+w,y,x+w,y+h)
  DrawLine(x+w,y+h,x,y+h); DrawLine(x,y+h,x,y)
 End If
 Flip()
 frames :+ 1
 If AppArgs.Length>1 And AppArgs[1]="--test" And frames>=3 Then Exit
Wend
scene.CancelInput()
scene.Destroy()
EndGraphics()
