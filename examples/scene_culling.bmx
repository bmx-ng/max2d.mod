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

Type TTile Extends TCustomDrawNode
 Method OnDraw(context:TSceneDrawContext)
  context.SetColor(255,255,255)
  DrawRect(0,0,32,32)
  context.SetColor(25,40,60)
  DrawRect(4,4,24,24)
  context.SetColor(255,255,255)
  DrawRect(8,21,16,3)
 End Method
End Type

AppTitle="Max2D Scene / Culling and diagnostics"
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
Local font:TImageFont=TImageFont.DefaultFont(),large:TImageFont=font
If FileType(path)=FILETYPE_FILE Then
 font=LoadScalableImageFont(path,18)
 large=LoadScalableImageFont(path,28)
End If
Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(layer)
layer.SetViewport(TSceneRect.Create(20,110,920,420))
' 100 spatial chunks each contain 25 tiles. Cached group bounds let the renderer
' reject an offscreen chunk without visiting its 25 children.
For Local gy:Int=0 Until 10
 For Local gx:Int=0 Until 10
  Local group:TSceneNode2D=New TSceneNode2D
  group.SetPosition(gx*210,gy*210)
  group.ReserveChildren(25); layer.AddChild(group)
  For Local y:Int=0 Until 5
   For Local x:Int=0 Until 5
    Local tile:TTile=New TTile
    tile.SetPosition(x*40,y*40)
    tile.SetSelfBounds(TSceneRect.Create(0,0,32,32))
    tile.SetTint(100+(gx*13 Mod 155),150+(gy*9 Mod 105),220)
    group.AddChild(tile)
   Next
  Next
 Next
Next
Local stats:TSceneStats=New TSceneStats
Local camera:TCamera2D=New TCamera2D
camera.offsetX=20; camera.offsetY=110
Local enabled:Int=True,frames:Int
scene.SetCulling(enabled)
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
 If KeyHit(KEY_C) Then enabled=Not enabled; scene.SetCulling(enabled)
 If KeyDown(KEY_LEFT) Then camera.x :- 5
 If KeyDown(KEY_RIGHT) Then camera.x :+ 5
 If KeyDown(KEY_UP) Then camera.y :- 5
 If KeyDown(KEY_DOWN) Then camera.y :+ 5
 camera.x=Max(-100,Min(1800,camera.x)); camera.y=Max(-100,Min(1800,camera.y))
 layer.SetCamera(camera)
 SetClsColor(10,18,29); Cls()
 scene.Render(); scene.CopyStats(stats)
 ' HUD uses ordinary Max2D drawing after Render, outside scene statistics.
 SetColor(230,240,250); SetImageFont(large)
 DrawText("CULLING / 2,500 TILES",20,24)
 SetImageFont(font); SetColor(150,185,205)
 Local mode:String="OFF"
 If enabled Then mode="ON"
 DrawText("Culling "+mode+"    Visited "+stats.NodesVisited()+"    Draw visits "+stats.DrawVisits()+"    Culled branches "+stats.CulledSubtrees(),20,68)
 DrawText("Bounds rebuilt "+stats.BoundsRebuilds()+"    World matrices rebuilt "+stats.WorldRebuilds(),20,555)
 DrawText("Arrow keys pan the camera    C toggles culling    ESC exits",20,598)
 Flip()
 frames :+ 1
 If AppArgs.Length>1 And AppArgs[1]="--test" And frames>=3 Then Exit
Wend
scene.Destroy(); EndGraphics()
