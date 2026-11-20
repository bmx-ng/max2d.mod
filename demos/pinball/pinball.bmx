SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?Not max2d_gl
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?
Import Physics.Box2D
Import Max2D.ScalableFont
Import Max2D.VirtualJoystick
Import SDL3.SDL3AudioAudio
Import BRL.StandardIO
Import BRL.FileSystem
Import BRL.PNGLoader
Import Pub.StdC
?osx
Import "macos_input.m"
?
Include "physics.bmx"
Include "input.bmx"
Include "sound.bmx"
Include "visuals.bmx"

Const WIDTH:Int=1000,HEIGHT:Int=820,SCALE:Float=34,TX:Float=80,TY:Float=42
Global table:TPinTable=New TPinTable
Global controls:TPinControls
Global audio:TPinSound,visuals:TPinVisuals
Global tableFont:TImageFont
Global bloom:TMax2DBloom,halo:TMax2DShadow
Global staticLight:TRenderImage,lightSource:TRenderImage
Global paused:Int,leftDown:Int,rightDown:Int,launchDown:Int
Global trailX:Float[36],trailY:Float[36],trailCount:Int,trailHead:Int
Global accumulator:Double,renderAlpha:Float,clockTime:Float
Global lastW:Int,lastH:Int
Local testOverdrive:Int,sawOverdrive:Int
Local testModes:Int,sawTogether:Int,sawMultiball:Int,sawFrenzy:Int,testMode:Int,captureDir:String,testSteps:Int,previousLaunch:Int,frames:Int
For Local a:Int=1 Until AppArgs.Length
 If AppArgs[a]="--test" Then testMode=True
 If AppArgs[a]="--test-overdrive" Then testMode=True; testOverdrive=True
 If AppArgs[a]="--test-modes" Then testMode=True; testModes=True
 If AppArgs[a]="--capture-dir" And a+1<AppArgs.Length Then captureDir=AppArgs[a+1]; testMode=True
Next
AppTitle="Flux Pinball | Max2D + Box2D"
?osx
If Not FluxDisablePressAndHold() Then Throw "Could not disable macOS accent menu"
?
Graphics WIDTH,HEIGHT,0
SetVirtualResolution(WIDTH,HEIGHT,VIRTUAL_LETTERBOX)
SetVirtualBarColor(6,10,22)
Local fontPath:String
?osx
fontPath="/System/Library/Fonts/Supplemental/Arial.ttf"
?win32
fontPath=getenv_("WINDIR")+"/Fonts/segoeui.ttf"
?linux
fontPath="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
?
If FileType(fontPath)=FILETYPE_FILE Then
 Local font:TScalableImageFont=LoadScalableImageFont(fontPath,19)
 If font Then SetImageFont(font)
End If
' Dedicated condensed lettering for the physical table; fall back to the UI font.
tableFont=GetImageFont()
Local tableFontPath:String
?osx
tableFontPath="/System/Library/Fonts/Supplemental/DIN Condensed Bold.ttf"
?win32
tableFontPath=getenv_("WINDIR")+"/Fonts/bahnschrift.ttf"
?linux
tableFontPath="/usr/share/fonts/truetype/dejavu/DejaVuSansCondensed-Bold.ttf"
?
If FileType(tableFontPath)=FILETYPE_FILE Then
 Local loaded:TScalableImageFont=LoadScalableImageFont(tableFontPath,32)
 If loaded Then tableFont=loaded
End If
controls=New TPinControls

controls.SetStickEnabled(False)
SetupLights()
audio=New TPinSound
visuals=New TPinVisuals
Local previous:Int=MilliSecs()
While Not AppTerminate()
 Local now:Int=MilliSecs(),dt:Float=Min(0.05,Float(now-previous)/1000.0)
 previous=now; clockTime:+dt
 LayoutControls()
 Local mouseX:Float,mouseY:Float,inside:Int=GetVirtualMouse(mouseX,mouseY)
 Local mouseHeld:Int=MouseDown(1),mouseTap:Int=MouseHit(1)
 Local launchHit:Int=controls.ButtonHit(2)
 Local launchPressed:Int=KeyHit(KEY_SPACE) Or KeyHit(KEY_DOWN) Or launchHit
 Local pauseHit:Int=KeyHit(KEY_ESCAPE) Or KeyHit(KEY_P) Or controls.ButtonHit(3)
 If controls.suspended Then paused=True; controls.suspended=False; accumulator=0; previousLaunch=False; table.charge=0
 Local soundHit:Int=KeyHit(KEY_M) Or controls.ButtonHit(4)
 If paused Then audio.Silence()
 Local restart:Int=KeyHit(KEY_R)
 If inside And mouseTap Then
  If mouseX>=843 And mouseX<=925 And mouseY>=300 And mouseY<=326 Then soundHit=True
  If mouseX>570 And mouseX<920 And mouseY>722 And mouseY<772 Then pauseHit=True
  If table.gameOver And mouseX>570 And mouseX<920 And mouseY>590 And mouseY<690 Then restart=True
  If mouseX>570 And mouseX<920 And mouseY>590 And mouseY<690 Then launchPressed=True
 End If
 If soundHit Then audio.Toggle()
 If pauseHit Then paused=Not paused; controls.CancelTouches(); previousLaunch=False; accumulator=0; table.charge=0
 If restart Or (table.gameOver And (KeyHit(KEY_ENTER) Or launchHit)) Then
  visuals.Reset(); audio.Silence(); table.Free(); table=New TPinTable; paused=False; accumulator=0; previousLaunch=False; trailCount=0
 End If
 leftDown=KeyDown(KEY_LEFT) Or KeyDown(KEY_A) Or KeyDown(KEY_LSHIFT) Or controls.ButtonDown(0) Or KeyHit(KEY_LEFT) Or KeyHit(KEY_A) Or KeyHit(KEY_LSHIFT) Or controls.ButtonHit(0)
 rightDown=KeyDown(KEY_RIGHT) Or KeyDown(KEY_D) Or KeyDown(KEY_RSHIFT) Or controls.ButtonDown(1) Or KeyHit(KEY_RIGHT) Or KeyHit(KEY_D) Or KeyHit(KEY_RSHIFT) Or controls.ButtonHit(1)
 launchDown=KeyDown(KEY_SPACE) Or KeyDown(KEY_DOWN) Or controls.ButtonDown(2)
 If inside And mouseHeld Then
  If (mouseX-180)^2+(mouseY-776)^2<34^2 Then leftDown=True
  If (mouseX-405)^2+(mouseY-776)^2<34^2 Then rightDown=True
  If mouseX>570 And mouseX<920 And mouseY>590 And mouseY<690 Then launchDown=True
 End If
 If testMode Then
  dt=1.0/60; paused=False
  If table.waiting And Not table.gameOver Then table.charge=0.7; table.Launch()
  If testOverdrive And frames=0 Then
   table.forgeCells=1; table.frenzyCells=1; table.multiCells=1
   table.ball.SetXForm(New b2Vec2.Create(5.6,12),0)
   table.ball.SetLinearVelocity(New b2Vec2.Create(0,-9)); trailCount=0
  End If
  If table.overdriveTime>0 Then sawOverdrive=True
  If testModes And (frames=0 Or frames=30) Then
   Local x:Float=5.6
   If frames=0 Then table.multiCharge=MULTI_CHARGE_HITS; x=8.1 Else table.frenzyCharge=3
   table.ball.SetXForm(New b2Vec2.Create(x,9.9),0)
   table.ball.SetLinearVelocity(New b2Vec2.Create(0,9)); trailCount=0
   If frames=0 Then
    table.ball.SetXForm(New b2Vec2.Create(x,12),0)
    table.ball.SetLinearVelocity(New b2Vec2.Create(0,-9))
   End If
  End If
  If table.extraBall And table.frenzyTime>0 Then sawTogether=True
  If table.extraBall Then sawMultiball=True
  If table.frenzyTime>0 Then sawFrenzy=True
  Local ballPos:b2Vec2=table.ball.GetPosition()

  leftDown=ballPos.GetY()>15 And ballPos.GetX()<6 And (testSteps Mod 100)<35
  rightDown=ballPos.GetY()>15 And ballPos.GetX()>=6 And (testSteps Mod 100)<35
 End If
 If Not paused And Not table.gameOver Then
  If table.waiting And launchDown Then table.charge=Min(1,table.charge+dt*0.8)
  If (previousLaunch Or launchPressed) And Not launchDown Then table.Launch()
  accumulator:+dt
  While accumulator>=PHYSICS_DT
   Local oldBall:b2Body=table.ball
   table.Tick(leftDown,rightDown); accumulator:-PHYSICS_DT; testSteps:+1
   If oldBall<>table.ball Then trailCount=0
   Local p:b2Vec2=table.ball.GetPosition()
   If Not table.waiting And Not table.gameOver Then
    trailX[trailHead]=p.GetX(); trailY[trailHead]=p.GetY(); trailHead=(trailHead+1) Mod 36; trailCount=Min(36,trailCount+1)
   Else
    trailCount=0
   End If
  Wend
 End If
 previousLaunch=launchDown
 renderAlpha=Float(accumulator/PHYSICS_DT)
 audio.UpdateOverdrive(table.overdriveTime,paused Or table.gameOver)
 visuals.Update(dt)
 visuals.BeginScene()
 DrawTable()
 visuals.EndScene()
 DrawInterface()
 Flip
 frames:+1
 If testMode Then
  If captureDir And (frames=1 Or frames=150 Or frames=360 Or (testOverdrive And frames=30)) Then
   CreateDir(captureDir,True)
   If Not SavePixmapPNG(GrabPixmap(0,0,NativeResolutionWidth(),NativeResolutionHeight()),captureDir+"/flux-"+frames+".png") Then Throw "Capture failed"
  End If
  If frames=720 Then Exit
 End If
Wend
If testOverdrive And Not sawOverdrive Then Throw "Overdrive rendering smoke test did not activate"
If testModes And (Not sawMultiball Or Not sawFrenzy Or Not sawTogether) Then Throw "Mode rendering smoke test did not activate both modes"
If testMode Then Print "PASS: Flux runtime, "+testSteps+" physics steps, "+table.hits+" hits, score "+table.score+", peak speed "+table.maxSpeed
audio.Silence()
visuals.Release()
controls.Free()
If bloom Then bloom.Release()
If halo Then halo.Release()
table.Free()
EndGraphics

Function Paint(r:Int,g:Int,b:Int,alpha:Float=1)
 SetColor(r,g,b); SetAlpha(alpha)
End Function
Function Text(value:String,x:Float,y:Float,size:Float=1,r:Int=213,g:Int=228,b:Int=242)
 Paint(r,g,b); SetScale(size,size); DrawText(value,x,y); SetScale(1,1)
End Function
' Centre visible glyph ink, including font bearings, rather than guessed offsets.
' Height and width are logical pixels, independent of the chosen font metrics.
Function TableText(value:String,cx:Float,cy:Float,height:Float,r:Int=213,g:Int=228,b:Int=242,maxWidth:Float=200)
 Local scope:TMax2DStateScope=ScopedMax2DState()
 Try
  SetImageFont(tableFont)
  Local layout:TTextLayout=CreateTextLayout(value)
  If layout.boundsHeight<=0 Or layout.boundsWidth<=0 Then Return
  Local scale:Float=Min(height/layout.boundsHeight,maxWidth/layout.boundsWidth)
  Local x:Float=cx-(layout.boundsX+layout.boundsWidth/2)*scale
  Local y:Float=cy-(layout.boundsY+layout.boundsHeight/2)*scale
  SetScale(scale,scale)
  ' A small engraved shadow and crisp face; the playfield bloom lights the face.
  Paint(1,5,13,0.9); DrawTextLayout(layout,x,y+1)
  Paint(r,g,b); DrawTextLayout(layout,x,y)
 Finally
  scope.Close()
 End Try
End Function
Function Line(x1:Float,y1:Float,x2:Float,y2:Float,width:Float)
 SetLineWidth(width); DrawLine(TX+x1*SCALE,TY+y1*SCALE,TX+x2*SCALE,TY+y2*SCALE); SetLineWidth(1)
End Function
Function Ring(x:Float,y:Float,r:Float,width:Float=2)
 SetLineWidth(width)
 For Local i:Int=0 Until 48
  Local a:Float=i*7.5,b:Float=(i+1)*7.5
  DrawLine(x+Cos(a)*r,y+Sin(a)*r,x+Cos(b)*r,y+Sin(b)*r)
 Next
 SetLineWidth(1)
End Function
Function SetupLights()
 If Not Max2DSupportsImageEffect(CreateBlurEffect()) Or Not Max2DSupportsImageEffect(CreateBrightPassEffect()) Then Return
 lightSource=CreateRenderImage(WIDTH,HEIGHT,FILTEREDIMAGE)
 SetRenderImage(lightSource); SetClsColor(0,0,0,1); Cls
 Paint(64,162,209)
 For Local rail:TPinRail=EachIn table.rails
  If rail.active Then Paint(239,80,146) Else Paint(64,162,209)
  Line(rail.x1,rail.y1,rail.x2,rail.y2,2)
 Next
 For Local i:Int=0 Until 3
  Local t:TPinTarget=table.targets[i]
  Paint(78,213,216); Ring(TX+t.x*SCALE,TY+t.y*SCALE,t.radius*SCALE+4)
 Next
 SetRenderImage(Null)
 bloom=CreateBloom(0.2,12,0.8); bloom.Prepare(WIDTH,HEIGHT,2,PF_RGBA8888)
 staticLight=bloom.Update(lightSource)
 Local source:TRenderImage=CreateRenderImage(64,64,FILTEREDIMAGE)
 SetRenderImage(source); SetClsColor(0,0,0,0); Cls
 Paint(255,255,255); DrawOval(22,22,20,20)
 SetRenderImage(Null)
 halo=CreateShadow(10); halo.Prepare(64,64,2); halo.Update(source)
End Function
Function Glow(x:Float,y:Float,size:Float,r:Int,g:Int,b:Int,alpha:Float=1)
 If Not halo Then Return
 Paint(r,g,b,alpha); SetBlend(LIGHTBLEND); SetScale(size,size)
 DrawImage(halo.Result(),x-32*size,y-32*size)
 SetScale(1,1); SetBlend(ALPHABLEND)
End Function
Function LayoutControls()
 Local w:Int=NativeResolutionWidth(),h:Int=NativeResolutionHeight()
 If w=lastW And h=lastH Then Return
 lastW=w; lastH=h
 controls.Layout(w,h)
End Function
Function DrawTable()
 visuals.DrawDeck()
 For Local rail:TPinRail=EachIn table.rails
  Paint(2,5,14,0.8); Line(rail.x1+0.09,rail.y1+0.16,rail.x2+0.09,rail.y2+0.16,11)
  If rail.active Then Paint(119,48,92) Else Paint(35,83,104)
  Line(rail.x1,rail.y1,rail.x2,rail.y2,8)
  If rail.active Then Paint(242,121,173) Else Paint(129,224,234)
  Line(rail.x1,rail.y1,rail.x2,rail.y2,2)
 Next
 ' The launch gate folds up against the lane wall until the ball clears it.
 Paint(106,235,196)
 If table.gateClosed Then Line(10.5,4,12,3.4,5) Else Line(12,2.6,12,4,5)
 If staticLight Then Paint(255,255,255,0.6); SetBlend(LIGHTBLEND); DrawImage(staticLight,0,0); SetBlend(ALPHABLEND)
 For Local i:Int=0 Until 3
  visuals.DrawCore(i)
 Next
 For Local i:Int=0 Until 3
  Local x:Float=TX+(3.4+i*2.2)*SCALE,y:Float=TY+2.5*SCALE
  Local lit:Int=(table.rolloverMask & (1 Shl i)) Or table.jackpotTime>0
  If lit Then Glow(x,y,1.6,255,196,82,0.7+table.rolloverFlash[i])
  If lit Then Paint(255,217,135) Else Paint(87,115,136)
  Ring(x,y,17,2)
  TableText(String(i+1),x,y,14)
 Next
 Local jackpotX:Float=TX+5.6*SCALE,jackpotY:Float=TY+11*SCALE
 If table.OverdriveReady() Or table.overdriveTime>0 Then
  Glow(jackpotX,jackpotY,2.8,255,210,110,0.65+Float(Sin(clockTime*240))*0.15)
  Paint(255,232,166); Ring(jackpotX,jackpotY,28,2)
  TableText("OVERDRIVE",jackpotX,jackpotY,10,255,240,188,46)
 Else If table.jackpotTime>0 Or table.jackpotFlash>0 Then
  Glow(jackpotX,jackpotY,2.8,255,190,86,0.65+table.jackpotFlash)
  Paint(255,221,143); Ring(jackpotX,jackpotY,27+Float(Sin(clockTime*240))*3,2)
  TableText("1000",jackpotX,jackpotY,14,255,235,179,42)
 Else
  Paint(51,74,93); Ring(jackpotX,jackpotY,27)
  If table.frenzyCharge=3 Then
   Glow(jackpotX,jackpotY,2.2,179,129,255,0.8)
   TableText("FRENZY",jackpotX,jackpotY,10,213,180,255,42)
  Else
   TableText("JACKPOT",jackpotX,jackpotY,10,112,145,166,42)
  End If

 End If
 Local multiX:Float=TX+8.1*SCALE,multiY:Float=TY+10.9*SCALE
 If table.multiCharge=MULTI_CHARGE_HITS Or table.multiActive Then
  Glow(multiX,multiY,2.0,104,165,255,0.7)
  Paint(143,192,255)
 Else
  Paint(62,84,111)
 End If
 Ring(multiX,multiY,22,2)
 TableText("MULTI",multiX,multiY,10,158,190,235,34)
 ' Forge target bay and retracting shutter.

 For Local i:Int=0 Until 3
  Local t:TPinTarget=table.targets[5+i],lit:Int=table.forgeMask & (1 Shl i)
  If table.forgeTime>0 And Not lit Then Glow(TX+t.x*SCALE,TY+t.y*SCALE,1.2,255,148,62,0.6)
  If lit Then Paint(137,250,190) Else Paint(217,133,71)
  Line(t.x+0.12,t.y-0.25,t.x+0.12,t.y+0.25,8)
  Line(0.7,t.y-0.48,t.x+0.12,t.y-0.25,3)
  Line(0.7,t.y+0.48,t.x+0.12,t.y+0.25,3)
 Next
 Paint(232,157,85)
 Local gateLength:Float=1.8*(1-table.forgeAnimation)
 If gateLength>0.01 Then Line(2,7,2,7+gateLength,7); Line(2,10.6-gateLength,2,10.6,7)
 Local outletLength:Float=1-table.forgeAnimation
 If outletLength>0.01 Then
  Local outletX:Float=0.7+0.8*outletLength,outletY:Float=11.4-0.4*outletLength
  Paint(2,5,14,0.8); Line(0.79,11.56,outletX+0.09,outletY+0.16,11)
  Paint(112,68,35); Line(0.7,11.4,outletX,outletY,8)
  Paint(232,157,85); Line(0.7,11.4,outletX,outletY,5)
 End If
 Local forgeX:Float=TX+3.2*SCALE,forgeY:Float=TY+10.9*SCALE
 If table.forgeCharge=3 Then
  Glow(forgeX,forgeY,1.7,255,165,70,Float(0.7+Sin(clockTime*240)*0.2))
  Paint(255,205,112)
 Else
  Paint(91,102,108)
 End If
 Ring(forgeX,forgeY,22,2)
 TableText("FORGE",forgeX,forgeY,10,226,181,128,34)
 If table.forgeTime>0 Then
  Paint(255,195,109,Float(0.5+Sin(clockTime*240)*0.25))
  Line(3.5,9.2,2.5,8.8,2); Line(2.5,8.8,2.9,8.6,2)
 End If
 For Local i:Int=3 Until 5
  Local t:TPinTarget=table.targets[i]
  If t.flash>0 Then Glow(TX+t.impactX*SCALE,TY+t.impactY*SCALE,3,245,68,146,t.flash)
 Next
 For Local i:Int=0 Until 2
  Local p:b2Vec2=table.flipper[i].GetPosition(),angle:Float=table.previousAngle[i]+(table.flipper[i].GetAngle()-table.previousAngle[i])*renderAlpha
  Local x:Float=TX+p.GetX()*SCALE,y:Float=TY+p.GetY()*SCALE,held:Int=leftDown
  If i=1 Then held=rightDown
  Local vx:Float=Cos(angle)*1.05*SCALE,vy:Float=Sin(angle)*1.05*SCALE
  Paint(0,0,0,0.6); SetLineWidth(11); DrawLine(x-vx+3,y-vy+6,x+vx+3,y+vy+6)
  Paint(190,205,215); DrawLine(x-vx,y-vy,x+vx,y+vy)
  DrawOval(x-vx-5,y-vy-5,10,10); DrawOval(x+vx-5,y+vy-5,10,10)
  If held Then Paint(252,194,121) Else Paint(105,158,183)
  SetLineWidth(4); DrawLine(x-vx,y-vy,x+vx,y+vy); SetLineWidth(1)
  Local anchor:Float=3.4
  If i=1 Then anchor=8.4
  Paint(232,242,246); DrawOval(TX+anchor*SCALE-5,TY+17*SCALE-5,10,10)
  visuals.Bolt(TX+anchor*SCALE,TY+17*SCALE)
 Next
 For Local n:Int=0 Until trailCount
  Local idx:Int=(trailHead-1-n+36) Mod 36,fade:Float=1-Float(n)/36
  If n<trailCount-1 Then
   Local nextIdx:Int=(idx-1+36) Mod 36
   If Abs(trailX[idx]-trailX[nextIdx])+Abs(trailY[idx]-trailY[nextIdx])<2 Then
    Paint(90,195,255,fade*fade*0.28); Line(trailX[idx],trailY[idx],trailX[nextIdx],trailY[nextIdx],7*fade)
    Paint(192,239,255,fade*fade*0.65); Line(trailX[idx],trailY[idx],trailX[nextIdx],trailY[nextIdx],2*fade)
   End If
  End If
  Paint(94,211,238,fade*fade*0.22); DrawOval(TX+trailX[idx]*SCALE-4*fade,TY+trailY[idx]*SCALE-4*fade,8*fade,8*fade)
 Next
 If Not table.gameOver Then
  Local p:b2Vec2=table.ball.GetPosition(),x:Float=TX+(table.previousX+(p.GetX()-table.previousX)*renderAlpha)*SCALE
  Local y:Float=TY+(table.previousY+(p.GetY()-table.previousY)*renderAlpha)*SCALE
  Glow(x,y,1.5,109,221,255,0.8)
  Paint(0,0,0,0.6); DrawOval(x-7+3,y-7+4,15,15)
  Paint(112,160,184); DrawOval(x-8,y-8,16,16)
  Paint(223,241,249); DrawOval(x-7,y-7,13,13)
  Paint(255,255,255); DrawOval(x-5,y-5,5,5)
 End If
 If table.extraBall Then
  Local p:b2Vec2=table.extraBall.GetPosition()
  Local x:Float=TX+(table.extraPreviousX+(p.GetX()-table.extraPreviousX)*renderAlpha)*SCALE
  Local y:Float=TY+(table.extraPreviousY+(p.GetY()-table.extraPreviousY)*renderAlpha)*SCALE
  Glow(x,y,1.7,160,153,255,0.9)
  Paint(0,0,0,0.6); DrawOval(x-4,y-3,15,15)
  Paint(137,146,207); DrawOval(x-8,y-8,16,16)
  Paint(235,231,255); DrawOval(x-7,y-7,13,13)
  Paint(255,255,255); DrawOval(x-5,y-5,5,5)
 End If
 Paint(233,94,128,0.5); Line(4.5,20.2,7.2,20.2,2)
 TableText("D R A I N",TX+5.85*SCALE,744,9,160,94,126,90)
 If table.surge>0 Then
  Paint(238,111,191,Float(0.5+Sin(clockTime*240)*0.2)); Ring(TX+5.6*SCALE,TY+7*SCALE,145)
 End If
 DrawFlipperButton(180,776,"L",leftDown)
 DrawFlipperButton(405,776,"R",rightDown)
 TableText("HOLD TO FLIP",292.5,776,8,110,149,170,130)
End Function
Function DrawFlipperButton(x:Float,y:Float,label:String,held:Int)
 Paint(18,39,56); DrawOval(x-33,y-33,66,66)
 If held Then Paint(255,206,142) Else Paint(78,146,171)
 Ring(x,y,32,2)
 TableText(label,x,y,20)
End Function
Function DrawInterface()
 visuals.DrawConsole()
 Text("F L U X",565,64,2.8,229,243,250)
 Text("P I N B A L L",570,132,1,88,203,210)
 Text("POWER THE REACTOR",570,186,0.72,124,158,182)
 Local scoreText:String="00000000"+table.score
 Text(scoreText[scoreText.Length-8..],565,224,2.8,247,217,163)
 Text("BALLS",570,309,0.75,116,151,175)
 For Local i:Int=0 Until 3
  If i<table.balls Then Paint(217,236,246) Else Paint(37,59,76)
  DrawOval(648+i*27,307,12,12)
 Next
 Paint(35,58,77); DrawRect(570,352,350,1)
 If table.overdriveFlash>0 Then
  Text("OVERDRIVE COMPLETE",570,379,1.0,255,225,148)
  Text("+10,000 / REACTOR STABILISED",570,420,0.85,255,239,196)
  Text("Earn another set of cells to play again.",570,448,0.73)
 Else If table.overdriveTime>0 Then
  Text("OVERDRIVE / "+Int(Ceil(table.overdriveTime))+"s",570,379,1.1,255,225,148)
  Text("3x bumper / sling scores. Each core 3 times:",570,420,0.71)
  Text("LEFT "+table.overdriveHits[0]+"/3    CENTRE "+table.overdriveHits[2]+"/3    RIGHT "+table.overdriveHits[1]+"/3",570,448,0.75,255,231,164)
 Else If table.OverdriveReady() Then
  Text("OVERDRIVE READY",570,379,1.1,255,225,148)
  Text("Shoot the gold centre ring to start.",570,420,0.78)
  Text("30 seconds / all three cores / +10,000",570,448,0.75)
 Else If table.frenzyTime>0 Or table.multiActive Then
  Text("CORE CHALLENGES ACTIVE",570,379,0.9,192,180,255)
  If table.frenzyTime>0 Then
   Text("Frenzy: 10 core hits in 25s / +200 per hit",570,420,0.73)
  Else
   Text("Complete a challenge: +2000 and a cell",570,420,0.73)
  End If
  If table.multiActive Then
   Text("Multiball: 8 core hits while both survive",570,448,0.73)
  Else
   Text("Complete a challenge: +2000 and a cell",570,448,0.73)
  End If
 Else If table.surge>0 Then
  Text("REACTOR SURGE",570,379,1.3,248,156,206)
  Text("DOUBLE SCORE / "+Int(Ceil(table.surge))+" seconds",570,419,0.9,198,204,232)
 Else
  Text("CHARGE THE THREE CORES",570,379,0.9,129,221,214)
  Text("Charge cores, then shoot their rings.",570,420,0.75)
  Text("Complete challenges to earn power cells.",570,448,0.75)
 End If
 If table.jackpotFlash>0 Then
  Text("JACKPOT! +1000",570,477,0.85,255,220,142)
 Else If table.jackpotTime>0 Then
  Text("CENTRE JACKPOT / "+Int(Ceil(table.jackpotTime))+"s",570,477,0.85,255,220,142)
 Else
  Text("Top lights 1 + 2 + 3 arm the jackpot",570,477,0.78,218,191,133)
 End If
 If table.forgeFlash>0 Then
  Text("FORGE COMPLETE! +2000 / CELL EARNED",570,506,0.7,155,247,192)
 Else If table.forgeTime>0 Then
  Text("FORGE: clear 3 left targets / "+Int(Ceil(table.forgeTime))+"s",570,506,0.73,255,194,112)
 Else If table.forgeCharge=3 Then
  Text("FORGE READY: shoot the orange ring",570,506,0.73,255,194,112)
 Else
  Text("FORGE: left core "+table.forgeCharge+"/3  |  Cells "+(table.forgeCells-table.overdriveStarts),570,506,0.73,224,174,116)
 End If
 Local frenzyText:String="FRENZY: centre core "+table.frenzyCharge+"/3 | Cells "+(table.frenzyCells-table.overdriveStarts)
 If table.frenzyCharge=3 Then frenzyText="FRENZY READY: shoot centre ring"
 If table.frenzyTime>0 Then frenzyText="FRENZY: "+table.frenzyHits+"/10 hits / "+Int(Ceil(table.frenzyTime))+"s"
 If table.frenzyFlash>0 Then frenzyText="FRENZY COMPLETE! +2000 / CELL EARNED"
 Text(frenzyText,570,536,0.7,202,173,255)
 Local multiText:String="MULTI: right core "+table.multiCharge+"/"+MULTI_CHARGE_HITS+" | Cells "+(table.multiCells-table.overdriveStarts)
 If table.multiCharge=MULTI_CHARGE_HITS Then multiText="MULTI READY: shoot UP through blue ring"
 If table.multiActive Then multiText="MULTIBALL: "+table.multiHits+"/8 core hits"
 If table.multiActive And table.multiHits=8 Then multiText="MULTIBALL: cell earned / keep both alive"
 If table.multiFlash>0 Then multiText="MULTI COMPLETE! +2000 / CELL EARNED"
 Text(multiText,570,560,0.7,150,190,255)

 Paint(19,39,56); DrawRect(570,590,350,100)
 Paint(55,100,120); DrawRect(570,590,350,2)
 If table.gameOver Then
  Text("GAME OVER",592,607,1.2,243,177,161)
  Text("Tap here or press R to play again",592,650,0.78)
 Else If paused Then
  Text("PAUSED",592,608,1.2,243,217,170)
  Text("Press P / Esc or tap RESUME",592,650,0.8)
 Else If table.waiting Then
  Text("HOLD TO CHARGE",592,607,1.1,239,216,161)
  Paint(40,66,84); DrawRect(592,651,306,8)
  Paint(124,229,214); DrawRect(592,651,306*table.charge,8)
 Else
  If table.extraBall Then
   Text("TWO BALLS IN PLAY",592,607,1.0,184,187,255)
  Else
   Text("BALL IN PLAY",592,607,1.1,164,229,217)
  End If

  If table.saveTime>0 Then Text("Launch protection / "+Int(Ceil(table.saveTime))+"s",592,650,0.8) Else Text("Hit the cores. Keep the ball alive.",592,650,0.78)
 End If
 Paint(16,30,45); DrawRect(570,722,350,50)
 If paused Then Text("RESUME",592,737,0.9) Else Text("PAUSE",592,737,0.9)
 Text("P / Esc",820,739,0.7,109,153,177)
 Text("A/D: flip | Space: launch | M: sound",570,792,0.65,116,151,175)
End Function

?osx
Extern "C"
 Function FluxDisablePressAndHold:Int()="flux_disable_press_and_hold"
End Extern
?
