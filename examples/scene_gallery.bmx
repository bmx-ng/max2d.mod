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

' Scene rendering owns no loop or input polling. This application supplies both.
Type TOrbit Extends TSceneNode2D
 Field elapsed:Double
 Method OnUpdate(dt:Double)
  elapsed :+ dt
  SetRotation(Float(elapsed*18))
 End Method
End Type

Type TReactor Extends TCustomDrawNode
 Field elapsed:Double
 Method OnUpdate(dt:Double)
  elapsed :+ dt
 End Method
 Method OnDraw(context:TSceneDrawContext)
  context.SetColor(70,210,230)
  For Local ring:Int=4 To 1 Step -1
   context.SetAlpha(0.035)
   Local radius:Float=58+ring*7+Sin(elapsed*70)*4
   DrawOval(-radius,-radius,radius*2,radius*2)
  Next
  context.SetAlpha(1)
  context.SetColor(20,46,61); DrawOval(-53,-53,106,106)
  context.SetColor(87,229,237); DrawOval(-38,-38,76,76)
  context.SetColor(13,26,42); DrawOval(-29,-29,58,58)
  context.SetColor(223,255,244); DrawOval(-9,-9,18,18)
 End Method
End Type

Type TTracks Extends TCustomDrawNode
 Method OnDraw(context:TSceneDrawContext)
  context.SetColor(42,66,84)
  For Local ring:Int=0 Until 3
   Local radius:Float=125+ring*32
   For Local angle:Int=0 Until 360 Step 4
    DrawLine(Cos(angle)*radius,Sin(angle)*radius,Cos(angle+2)*radius,Sin(angle+2)*radius)
   Next
  Next
 End Method
End Type

AppTitle="Max2D Scene / Orbital assembly"
Graphics 960,640
SetVirtualResolution(960,640,VIRTUAL_LETTERBOX)
Local fontPath:String
?osx
fontPath="/System/Library/Fonts/Supplemental/Arial.ttf"
?win32
fontPath=getenv_("WINDIR")+"/Fonts/segoeui.ttf"
?linux
fontPath="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
?
Local font:TImageFont=TImageFont.DefaultFont()
Local titleFont:TImageFont=font
If FileType(fontPath)=FILETYPE_FILE Then
 font=LoadScalableImageFont(fontPath,18)
 titleFont=LoadScalableImageFont(fontPath,32)
End If
Local scene:TScene=TScene.Create()
Local world:TLayerNode=TLayerNode.Create(), hud:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(world); scene.Root().AddChild(hud)
Local camera:TCamera2D=New TCamera2D
camera.offsetX=480; camera.offsetY=350
world.SetCamera(camera)
world.SetViewport(TSceneRect.Create(40,135,880,430))
Local tracks:TTracks=New TTracks
world.AddChild(tracks)
Local orbit:TOrbit=New TOrbit
orbit.SetProcessing(True)
world.AddChild(orbit)
Local reactor:TReactor=New TReactor
reactor.SetProcessing(True)
world.AddChild(reactor)
' A shared sprite can be referenced by many retained nodes.
Local art:TPixmap=CreatePixmap(32,32,PF_RGBA8888)
For Local y:Int=0 Until 32
 For Local x:Int=0 Until 32
  Local dx:Float=x-15.5,dy:Float=y-15.5
  If Abs(dx)+Abs(dy)<15 Then
   Local shade:Int=Int(225-Abs(dy)*4)
   art.WritePixel(x,y,$ff000000 | (shade Shl 16) | (shade Shl 8) | 255)
  Else
   art.WritePixel(x,y,0)
  End If
 Next
Next
Local image:TImage=LoadImage(art,FILTEREDIMAGE)
SetImageHandle(image,16,16)
For Local i:Int=0 Until 8
 Local group:TSceneNode2D=New TSceneNode2D
 Local angle:Float=i*45
 group.SetTransform(Float(Cos(angle)*157),Float(Sin(angle)*157),angle+45)
 orbit.AddChild(group)
 Local sprite:TSpriteNode=TSpriteNode.Create(image)
 sprite.SetScale(1.4,1.4)
 If i Mod 2 Then group.SetTint(255,176,102) Else group.SetTint(87,222,238)
 group.AddChild(sprite)
 Local trail:TMeshNode=TMeshNode.Create(TMesh2D.Create([-7.0,23.0,7.0,23.0,0.0,48.0]))
 trail.SetAlpha(0.4)
 group.AddChild(trail)
Next
Local title:TTextNode=TTextNode.Create("ORBITAL ASSEMBLY",titleFont)
title.SetPosition(40,32); title.SetTint(224,242,248); hud.AddChild(title)
Local caption:TTextNode=TTextNode.Create("Retained sprites / custom drawing / inherited transforms",font)
caption.SetPosition(42,83); caption.SetTint(129,166,187); hud.AddChild(caption)
Local instructions:TTextNode=TTextNode.Create("SPACE  hide satellites     P  pause     ESC  exit",font)
instructions.SetPosition(42,592); instructions.SetTint(129,166,187); hud.AddChild(instructions)
Local paused:Int,hidden:Int,frames:Int
Local previous:Int=MilliSecs()
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
 Local now:Int=MilliSecs(),dt:Double=Min(0.05,Double(now-previous)/1000)
 previous=now
 If KeyHit(KEY_P) Then paused=Not paused; scene.SetPaused(paused)
 If KeyHit(KEY_SPACE) Then hidden=Not hidden; orbit.SetVisible(Not hidden)
 scene.Update(dt)
 SetClsColor(10,18,29); Cls()
 SetColor(24,39,54); DrawRect(40,120,880,1); DrawRect(40,575,880,1)
 scene.Render()
 Flip()
 frames :+ 1
 If AppArgs.Length>1 And AppArgs[1]="--test" And frames>=3 Then Exit
Wend
scene.Destroy()
EndGraphics()
