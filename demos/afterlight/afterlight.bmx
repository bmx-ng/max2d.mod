SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?max2d_d3d11
Framework Max2D.D3D11Max2D
Import Max2D.D3D11Effects
?max2d_d3d9
Framework Max2D.D3D9Max2D
Import Max2D.D3D9Effects
?Not max2d_gl And Not max2d_d3d11 And Not max2d_d3d9
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?
Import Max2D.TileMap
Import Max2D.VirtualJoystick
Import Max2D.ScalableFont
Import BRL.PNGLoader
Import BRL.RamStream
Import BRL.StandardIO
Import BRL.FileSystem
Import BRL.Random
Import Pub.StdC
Incbin "assets/greenhouse.png"
Include "model.bmx"
Include "input.bmx"

Const VW:Int=1120,VH:Int=760,TILE:Int=56,OX:Int=40,OY:Int=142
Global game:TAfterlight=New TAfterlight
Global titleArt:TImage
Global controls:TVirtualJoystick
Global map:TTileMap, floorLayer:TTileLayer, tiles:TTileSet
Global glowSource:TRenderImage, bloom:TMax2DBloom, shadow:TMax2DShadow
Global gauge:TRenderImage,gaugeMask:TRenderImage
Global effects:Int, cachedRevision:Int=-1, touchMode:Int
Global socketArt:TRenderImage, socketShade:TMax2DInnerShadow
Global clockTime:Float, robotX:Float, robotY:Float, revival:Float
Global screen:Int=0,paused:Int, hintTime:Float, toast:String
Global roomNames:String[]=["THE SEED VAULT","THE MIRROR HOUSE","THE HEARTWOOD"]
Global roomStory:String[]=["One small spark can wake a sleeping world.","Sunlight remembers the way. Help it turn.","Two turns. One last tree. A new beginning."]
Global captureDir:String, captureStage:Int, captureFrames:Int
For Local arg:Int=1 Until AppArgs.Length
 If AppArgs[arg]="--capture-dir" And arg+1<AppArgs.Length Then captureDir=AppArgs[arg+1]
Next
AppTitle="Afterlight | A small greenhouse story"
Graphics VW,VH,0
SetVirtualResolution(VW,VH,VIRTUAL_LETTERBOX)
SetVirtualBarColor(8,17,23)
Local fontPath:String
?osx
fontPath="/System/Library/Fonts/Supplemental/Arial.ttf"
?win32
fontPath=getenv_("WINDIR")+"/Fonts/segoeui.ttf"
?linux
fontPath="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
?
If FileType(fontPath)=FILETYPE_FILE Then
 Local font:TScalableImageFont=LoadScalableImageFont(fontPath,18)
 If font Then SetImageFont(font)
End If
titleArt=LoadImage("incbin::assets/greenhouse.png",FILTEREDIMAGE)
controls=TVirtualJoystick.Create(3)
controls.SetButtonLabel(0,"ACT"); controls.SetButtonLabel(1,"UNDO"); controls.SetButtonLabel(2,"MENU")
controls.SetUIScale(0.85)
controls.SetButtonLayout(VIRTUAL_BUTTON_LAYOUT_HORIZONTAL)
PrepareArt()
game.LoadRoom(0); robotX=game.px*TILE; robotY=game.py*TILE
Local previous:Int=MilliSecs(), repeatTime:Float, lastDX:Int,lastDY:Int
While Not AppTerminate()
 Local now:Int=MilliSecs(),dt:Float=Min(0.05,Float(now-previous)/1000.0)
 previous=now; clockTime:+dt; hintTime=Max(0,hintTime-dt)
 Local action:Int=KeyHit(KEY_E) Or KeyHit(KEY_SPACE) Or KeyHit(KEY_ENTER) Or controls.ButtonHit(0)
 Local undo:Int=KeyHit(KEY_Z) Or controls.ButtonHit(1)
 Local menu:Int=KeyHit(KEY_ESCAPE) Or controls.ButtonHit(2)
 Local reset:Int=KeyHit(KEY_R)
 Local mx:Float,my:Float,inside:Int=GetVirtualMouse(mx,my),click:Int=MouseHit(1)
 If inside And click Then
  If screen<>1 Then
   If mx>=70 And mx<=370 And my>=510 And my<=574 Then action=True
  Else If paused Then
   If mx>=400 And mx<=720 Then
    If my>=330 And my<390 Then action=True
    If my>=400 And my<460 Then reset=True
    If my>=470 And my<530 Then screen=0; paused=False
   End If
  Else
   If mx>=820 And mx<1070 Then
    If my>=400 And my<454 Then action=True
    If my>=465 And my<519 Then undo=True
    If my>=530 And my<584 Then menu=True
   End If
  End If
 End If
 If screen=0 Or screen=2 Then
  If action Then game.moves=0; game.turns=0; game.LoadRoom(0); screen=1; paused=False; cachedRevision=-1; robotX=game.px*TILE; robotY=game.py*TILE; revival=0
  If menu Then Exit
 Else
  If menu Then paused=Not paused
  If paused Then
   If action Then paused=False
   If reset Or undo Then game.LoadRoom(game.room); paused=False; toast="Room reset. Every experiment is worth trying."; hintTime=3
  Else
   If reset Then game.LoadRoom(game.room)
   If undo Then game.Undo()
   If action And Not game.Act() Then toast=game.Hint(); hintTime=4
   Local dx:Int=KeyDown(KEY_RIGHT)-KeyDown(KEY_LEFT)+KeyDown(KEY_D)-KeyDown(KEY_A)
   Local dy:Int=KeyDown(KEY_DOWN)-KeyDown(KEY_UP)+KeyDown(KEY_S)-KeyDown(KEY_W)
   ResolveDirection(dx,dy,controls.X(),controls.Y(),dx,dy)
   repeatTime:-dt
   If dx<>lastDX Or dy<>lastDY Then repeatTime=0
   If (dx Or dy) And repeatTime<=0 Then
    Local oldRoom:Int=game.room
    game.Move(dx,dy); repeatTime=0.16
    If oldRoom<>game.room Then robotX=game.px*TILE; robotY=game.py*TILE; revival=0; toast=roomStory[game.room]; hintTime=4
   End If
   lastDX=dx; lastDY=dy
   If game.won Then screen=2
  End If
 End If
 robotX:+(game.px*TILE-robotX)*Min(1.0,dt*18)
 robotY:+(game.py*TILE-robotY)*Min(1.0,dt*18)
 If game.lit Then revival=Min(1,revival+dt*0.6) Else revival=Max(0,revival-dt*1.5)
 SetClsColor(8,17,23); Cls
 If screen=1 Then
  If cachedRevision<>game.revision Then RebuildScene()
  DrawGame()
  If paused Then DrawPause()
 Else
  DrawCover(screen=2)
 End If
If controls.stick.touchId<>-1 Then touchMode=True
For Local button:TVirtualButton=EachIn controls.buttons
 If button.down Then touchMode=True
Next
If touchMode Then controls.Render()
 If captureDir Then
  captureFrames:+1
  If captureFrames>=12 Then
   CreateDir(captureDir,True)
   If Not SavePixmapPNG(GrabPixmap(0,0,NativeResolutionWidth(),NativeResolutionHeight()),captureDir+"/afterlight-"+captureStage+".png") Then Throw "Could not save capture"
   captureStage:+1; captureFrames=0
   Select captureStage
    Case 1; screen=1
    Case 2; game.LoadRoom(1); game.bx=3; game.by=4; game.Trace(); game.revision:+1
    Case 3; game.LoadRoom(2); game.bx=3; game.by=4; game.mirror[0]=1; game.mirror[1]=1; game.Trace(); game.revision:+1; revival=1
    Case 4; screen=2
    Case 5; Exit
   End Select
  End If
 End If
 Flip
Wend
controls.Free()
If bloom Then bloom.Release()
If shadow Then shadow.Release()
If socketShade Then socketShade.Release()
If captureDir Then Print "PASS: Afterlight rendered title, three rooms and ending"
EndGraphics

Function Ink(r:Int,g:Int,b:Int,a:Float=1)
 SetColor(r,g,b); SetAlpha(a)
End Function
Function Label(value:String,x:Float,y:Float,size:Float=1,r:Int=219,g:Int=232,b:Int=227)
 Ink(r,g,b); SetScale(size,size); DrawText(value,x,y); SetScale(1,1)
End Function
Function Panel(x:Float,y:Float,w:Float,h:Float)
 Ink(18,35,42); DrawRect(x,y,w,h)
 Ink(57,83,85); DrawRect(x,y,w,1)
End Function
Function Button(text:String,x:Float,y:Float,w:Float=250)
 Panel(x,y,w,54); Label(text,x+20,y+16,1,239,211,153)
End Function
Function PrepareArt()
 tiles=New TTileSet
 For Local n:Int=0 Until 3
  Local p:TPixmap=CreatePixmap(TILE,TILE,PF_RGBA8888)
  For Local y:Int=0 Until TILE
   For Local x:Int=0 Until TILE
    Local v:Int=((x*7+y*13) Mod 5)
    Local colour:Int=$ff23383e+v*$010101
    If n=1 Then colour=$ff30444a+v*$010101
    If n=2 Then colour=$ff142d33+v*$010101
    If x<2 Or y<2 Then colour=$ff10232b
    If x=3 Or y=3 Then colour=$ff3b5154
    p.WritePixel(x,y,colour)
   Next
  Next
  tiles.Add(LoadImage(p,FILTEREDIMAGE))
 Next
 map=TTileMap.Create(TTileGrid.Rectangular(TILE,TILE),tiles)
 floorLayer=map.AddLayer("greenhouse paving")
 effects=Max2DSupportsImageEffect(CreateBlurEffect()) And Max2DSupportsImageEffect(CreateBrightPassEffect()) And Max2DSupportsImageEffect(CreateColorizeEffect()) And Max2DSupportsLayerAlpha()
 If effects Then
  glowSource=CreateRenderImage(COLS*TILE,ROWS*TILE,FILTEREDIMAGE)
  bloom=CreateBloom(0.35,12,1.1); bloom.Prepare(COLS*TILE,ROWS*TILE,2,PF_RGBA8888)
  Local silhouette:TRenderImage=CreateRenderImage(64,64,FILTEREDIMAGE)
  SetRenderImage(silhouette); SetClsColor(0,0,0,0); Cls
  Ink(255,255,255); DrawOval(13,28,38,19)
  SetRenderImage(Null)
  shadow=CreateShadow(6); shadow.Prepare(64,64,1); shadow.Update(silhouette)
socketArt=CreateRenderImage(56,56,FILTEREDIMAGE)
SetRenderImage(socketArt); SetClsColor(0,0,0,0); Cls
Ink(128,104,62); DrawOval(7,7,42,42)
SetRenderImage(Null)
socketShade=CreateInnerShadow(5,3,3); socketShade.Prepare(56,56,1); socketShade.Update(socketArt)
  gauge=CreateRenderImage(64,64,FILTEREDIMAGE); gaugeMask=CreateRenderImage(64,64,FILTEREDIMAGE)
  SetRenderImage(gaugeMask); SetClsColor(0,0,0,0); Cls
  Ink(255,255,255); DrawOval(7,7,50,50)
  SetRenderImage(Null)
 End If
End Function
Function RebuildScene()
 For Local y:Int=0 Until ROWS
  For Local x:Int=0 Until COLS
   floorLayer.SetCell(x,y,1+(x+y) Mod 2)
  Next
 Next
 If effects Then
  PushMax2DState()
  SetRenderImage(glowSource); SetClsColor(0,0,0,1); Cls
  DrawBeams(0,0)
  If game.lit Then Ink(126,255,188); DrawOval(game.rx*TILE+18,game.ry*TILE+18,20,20)
  SetRenderImage(Null); bloom.Update(glowSource)
  SetRenderImage(gauge); SetClsColor(0,0,0,0); Cls
  Ink(14,37,44); DrawRect(0,0,64,64)
  For Local y:Int=0 Until 64
   Ink(61+y,150+y,146)
   If y>=52-(game.room*16+game.lit*16) Then DrawRect(0,y,64,1)
  Next
  ApplyLayerAlphaMask(gaugeMask)
  SetRenderImage(Null); PopMax2DState()
 End If
 cachedRevision=game.revision
End Function
Function DrawBeams(offsetX:Float,offsetY:Float)
 If game.beamCount<2 Then Return
 For Local i:Int=1 Until game.beamCount
  Local x1:Float=offsetX+game.beamX[i-1]*TILE+28,y1:Float=offsetY+game.beamY[i-1]*TILE+28
  Local x2:Float=offsetX+game.beamX[i]*TILE+28,y2:Float=offsetY+game.beamY[i]*TILE+28
  Ink(236,166,65,0.32); SetLineWidth(12); DrawLine(x1,y1,x2,y2)
  Ink(255,226,148); SetLineWidth(3); DrawLine(x1,y1,x2,y2)
 Next
 SetLineWidth(1)
End Function
Function Plant(x:Float,y:Float,seed:Int,awake:Float)
 Ink(8,21,27,0.65); DrawOval(x-20,y+8,40,15)
 Ink(68,66,54); DrawRect(x-15,y-2,30,19)
 Ink(125,113,78); DrawRect(x-17,y-5,34,5)
 For Local leaf:Int=0 Until 5
  Local angle:Float=leaf*73+seed*29
  Local sway:Float=Sin(clockTime*35+seed*37)*3*awake
  Local lx:Float=x+Cos(angle)*(10+awake*7)+sway,ly:Float=y-14+Sin(angle)*12-awake*5
  Ink(40+Int(awake*25),76+Int(awake*69),70+Int(awake*20))
  DrawOval(lx-9,ly-9,18,19)
  If awake>0.6 And leaf Mod 2=0 Then Ink(233,190,120); DrawOval(lx-3,ly-5,6,6)
 Next
End Function
Function DrawGame()
 Label("AFTERLIGHT",40,27,1.8,238,221,179)
 Label("BOTANICAL RECOVERY PROGRAM",41,71,0.7,118,157,155)
 For Local i:Int=0 Until 3
  Local c:Int=67
  If i<=game.room Then c=202
  Ink(c,180,134); DrawOval(675+i*30,44,9,9)
 Next
 Label("0"+(game.room+1)+" / "+roomNames[game.room],40,110,0.92,146,190,178)
 Ink(255,255,255); map.Draw(OX,OY)
 ' Walls and raised planting beds share the same collision grid as the puzzle.
 For Local y:Int=0 Until ROWS
  For Local x:Int=0 Until COLS
   If game.Wall(x,y) And Not (x=12 And y=4) Then
    Local xx:Float=OX+x*TILE,yy:Float=OY+y*TILE
    Ink(8,22,28,0.7); DrawRect(xx+5,yy+8,56,54)
    Ink(36,58,63); DrawRect(xx+2,yy+2,52,50)
    Ink(70,94,92); DrawRect(xx+2,yy+2,52,5)
    Ink(25,43,49); DrawRect(xx+7,yy+12,42,30)
    If y>0 And y<8 And x>0 And x<12 Then Plant(xx+28,yy+30,x+y,revival)
   End If
  Next
 Next
 ' Socket, receiver and airlock.
 Local sx:Float=OX+3*TILE,sy:Float=OY+4*TILE
 Ink(12,25,30); DrawOval(sx+5,sy+5,46,46)
If socketShade Then
 Ink(255,255,255); DrawImage(socketArt,sx,sy)
 Ink(0,0,0,0.85); DrawImage(socketShade.Result(),sx,sy)
Else
 Ink(188,139,67); DrawOval(sx+9,sy+9,38,38)
End If
 Ink(16,31,36); DrawOval(sx+13,sy+13,30,30)
 Label("+",sx+22,sy+17,1,218,178,102)
 Local rx:Float=OX+game.rx*TILE,ry:Float=OY+game.ry*TILE
 If game.room=2 Then DrawTree(rx+28,ry+28,revival)
 Ink(13,29,33); DrawOval(rx+7,ry+7,42,42)
 Ink(91,138,129); DrawOval(rx+11,ry+11,34,34)
 Ink(25,51,55); DrawOval(rx+16,ry+16,24,24)
 If game.lit Then Ink(164,255,191); DrawOval(rx+19,ry+19,18,18)
 Local doorX:Float=OX+12*TILE,doorY:Float=OY+4*TILE
 Ink(20,39,44); DrawRect(doorX,doorY,56,56)
 If game.lit Then Ink(111,208,158) Else Ink(143,94,66)
 DrawRect(doorX+7,doorY+5,4,46); DrawRect(doorX+46,doorY+5,4,46)
 If game.lit Then Label(">",doorX+21,doorY+15,1.3,180,243,195) Else Label("-",doorX+22,doorY+17)
 DrawBeams(OX,OY)
 If effects Then
  Ink(255,255,255,0.7); SetBlend(LIGHTBLEND); DrawImage(bloom.Result(),OX,OY); SetBlend(ALPHABLEND)
 End If
 For Local i:Int=0 Until game.mirrorCount
  Local x:Float=OX+game.mx[i]*TILE,y:Float=OY+game.my[i]*TILE
  Ink(6,19,25,0.6); DrawOval(x+5,y+15,49,39)
  Ink(57,83,89); DrawOval(x+7,y+7,42,42)
  Ink(137,181,180); SetLineWidth(6)
  If game.mirror[i] Then DrawLine(x+14,y+42,x+42,y+14) Else DrawLine(x+14,y+14,x+42,y+42)
  Ink(218,248,237); SetLineWidth(2)
  If game.mirror[i] Then DrawLine(x+14,y+40,x+40,y+14) Else DrawLine(x+16,y+14,x+42,y+40)
  SetLineWidth(1)
  If Abs(game.px-game.mx[i])+Abs(game.py-game.my[i])=1 Then Label("ACT",x+9,y-14,0.65,246,214,145)
 Next
 DrawBattery(OX+game.bx*TILE,OY+game.by*TILE)
 DrawRobot(OX+robotX,OY+robotY)
 ' Foreground greenery and rising spores respond to restored power.
 For Local i:Int=0 Until 7
  Plant(OX+90+i*84,OY+ROWS*TILE-12,i+20,revival)
 Next
 For Local i:Int=0 Until 22
  Local x:Float=OX+60+((i*107) Mod 590)+Sin(clockTime*17+i*23)*10
  Local y:Float=OY+50+((i*79-Int(clockTime*(5+revival*17))+100000) Mod 390)
  Ink(161,217,173,0.12+revival*0.35); DrawOval(x,y,2+revival*2,2+revival*2)
 Next
 Panel(806,142,274,504)
 Label("RESTORE / 0"+(game.room+1),826,164,0.9,231,207,151)
 Label("GREENHOUSE VITALS",826,211,0.68,123,163,156)
 If effects Then Ink(255,255,255); DrawImage(gauge,825,241)
 Label((game.room+game.lit)+" / 3",910,254,1.5,175,224,194)
 Label("circuits online",910,290,0.7,128,166,159)
 If game.lit Then
  Label("POWER RESTORED",826,341,0.85,166,233,183)
 Else
  Label("AWAITING ENERGY",826,341,0.85,221,180,113)
 End If
 Button("ACT   /   E or Space",820,400)
 Button("UNDO   /   Z",820,465)
 Button("MENU   /   Esc",820,530)
 Label("Moves  "+game.moves,826,611,0.8,131,168,161)
 Local hint:String=game.Hint()
 If hintTime>0 Then hint=toast
 Label(hint,44,668,0.83,219,204,164)
 Label("WASD / arrows to move    -    push cells by walking    -    R resets room",44,706,0.72,116,151,151)
End Function
Function DrawBattery(x:Float,y:Float)
 If shadow Then Ink(0,0,0,0.6); DrawImage(shadow.Result(),x-4,y+2)
 Ink(68,53,35); DrawRect(x+12,y+13,34,35)
 Ink(192,147,76); DrawRect(x+10,y+9,34,34)
 Ink(246,211,137); DrawRect(x+12,y+9,30,5)
 Ink(77,69,45); DrawRect(x+16,y+18,22,18)
 Ink(255,207,99); DrawRect(x+20,y+21,14,12)
 Ink(125,112,78); DrawRect(x+21,y+5,12,5)
End Function
Function DrawRobot(x:Float,y:Float)
 Local bob:Float=Sin(clockTime*180)*1.2
 If shadow Then Ink(0,0,0,0.7); DrawImage(shadow.Result(),x-4,y+5)
 Ink(15,25,31); DrawOval(x+7,y+31,13,19); DrawOval(x+35,y+31,13,19)
 Ink(144,158,146); DrawOval(x+12,y+17+bob,32,29)
 Ink(230,221,187); DrawOval(x+9,y+7+bob,38,32)
 Ink(38,55,55); DrawOval(x+17,y+15+bob,26,17)
 Ink(250,207,112); DrawRect(x+24,y+20+bob,3,7); DrawRect(x+34,y+20+bob,3,7)
 Ink(148,171,155); DrawLine(x+16,y+8+bob,x+13,y+1+bob)
 Ink(175,241,199); DrawOval(x+10,y-2+bob,5,5)
End Function
Function DrawCover(ending:Int)
 If titleArt Then
  Ink(255,255,255); SetScale(Float(VW)/titleArt.width,Float(VH)/titleArt.height); DrawImage(titleArt,0,0); SetScale(1,1)
 End If
 Ink(5,17,24,0.42); DrawRect(0,0,VW,VH)
 Label("A SMALL GREENHOUSE STORY",72,195,0.8,166,199,182)
 If ending Then
  Label("AFTERLIGHT",68,245,3.4,249,230,186)
  Label("The greenhouse breathes again.",72,337,1.1)
  Label("Three circuits. One tree. A little hope.",72,377,0.95)
  Label(game.moves+" moves / thank you for tending this world",72,430,0.8,169,195,180)
  Button("BEGIN AGAIN",70,510,300)
 Else
  Label("AFTERLIGHT",68,245,3.7,249,230,186)
  Label("Wake a sleeping world, one spark at a time.",72,337,1.02)
  Label("Push energy cells. Turn mirrors. Bring life back.",72,377,0.88)
  Label("Three quiet rooms. No timer. Undo freely within each room.",72,430,0.8,169,195,180)
  Button("ENTER THE GREENHOUSE",70,510,300)
 End If
 Label("Enter / Space / ACT to begin",73,594,0.85,191,211,194)
 Label("Keyboard: WASD + E     Touch: drag left + ACT",73,632,0.8,155,190,182)
 Label("MADE WITH BLITZMAX + MAX2D",73,704,0.65,129,162,155)
End Function
Function DrawPause()
 Ink(3,12,18,0.84); DrawRect(0,0,VW,VH)
 Panel(370,220,380,350)
 Label("TAKE A BREATH",410,260,1.5,239,216,173)
 Button("RESUME   /   ACT",400,330,320)
 Button("RESET ROOM   /   UNDO",400,400,320)
 Button("RETURN TO TITLE",400,470,320)
End Function

Function DrawTree(x:Float,y:Float,awake:Float)
 Ink(10,25,28,0.6); DrawOval(x-44,y-10,88,42)
 Ink(86,87,64); DrawOval(x-36,y-15,72,38)
 Ink(142,125,81); DrawOval(x-32,y-18,64,32)
 Ink(37,48,36); DrawOval(x-27,y-15,54,22)
 Ink(108,105,75); SetLineWidth(9); DrawLine(x,y,x-5,y-53)
 SetLineWidth(4)
 DrawLine(x-4,y-37,x-29,y-62); DrawLine(x-3,y-45,x+24,y-70)
 DrawLine(x-4,y-47,x-14,y-81); DrawLine(x-2,y-33,x+29,y-51)
 SetLineWidth(1)
 For Local i:Int=0 Until 11
  Local xx:Float=x+Cos(i*137)*34,yy:Float=y-53+Sin(i*137)*25
  Ink(39+Int(awake*33),70+Int(awake*82),63+Int(awake*34),0.7+awake*0.3)
  DrawOval(xx-13,yy-10,26+awake*7,21+awake*5)
  If awake>0.5 Then
   Ink(245,211,135,awake); DrawOval(xx+Sin(clockTime*30+i)*2,yy,5,5)
  End If
 Next
End Function
