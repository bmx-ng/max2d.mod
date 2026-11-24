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
 Method OnDraw(context:TSceneDrawContext)
  context.SetColor(255,255,255)
  DrawRect(0,0,210,145)
  context.SetColor(45,55,70)
  DrawRect(12,12,186,121)
  context.SetColor(255,255,255)
  DrawRect(24,90,100,4)
  context.SetAlpha(0.3)
  DrawRect(24,104,156,3)
  DrawRect(24,115,130,3)
 End Method
 Function Create:TCard(label:String,font:TImageFont,x:Float,y:Float,red:Int,green:Int,blue:Int)
  Local card:TCard=New TCard
  card.SetPosition(x,y); card.SetTint(red,green,blue)
  card.SetSelfBounds(TSceneRect.Create(0,0,210,145))
  Local title:TTextNode=TTextNode.Create(label,font)
  title.SetPosition(24,30)
  card.AddChild(title)
  Return card
 End Function
End Type

AppTitle="Max2D Scene / Bounds and ordering"
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
Local group:TSceneNode2D=New TSceneNode2D
group.SetPosition(265,205); group.SetSortableChildren(True)
layer.AddChild(group)
Local cards:TCard[]=[TCard.Create("01 / AMBER",font,0,0,255,184,99),TCard.Create("02 / CYAN",font,110,75,96,221,240),TCard.Create("03 / VIOLET",font,220,150,197,155,255)]
For Local i:Int=0 Until cards.Length
 group.AddChild(cards[i]); cards[i].SetZIndex(i)
Next
Local title:TTextNode=TTextNode.Create("BOUNDS & DRAW ORDER",large)
title.SetPosition(40,30); layer.AddChild(title)
Local status:TTextNode=TTextNode.Create("",font)
status.SetPosition(40,83); status.SetTint(150,180,200); layer.AddChild(status)
Local help:TTextNode=TTextNode.Create("Z reverse order   S sorting   R rotate cyan   H hide violet   ESC exit",font)
help.SetPosition(40,595); help.SetTint(150,180,200); layer.AddChild(help)
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
scene.Destroy()
EndGraphics()
