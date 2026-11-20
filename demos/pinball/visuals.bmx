' Presentation only: physical silhouettes and the lower table layout stay authoritative.
Type TPinSpark
 Field x:Float,y:Float,vx:Float,vy:Float,life:Float,total:Float,size:Float
 Field r:Int,g:Int,b:Int
End Type
Type TPinWave
 Field x:Float,y:Float,life:Float,r:Int,g:Int,b:Int
End Type
Type TPinVisuals
 Field deck:TRenderImage,housing:TRenderImage,plasma:TRenderImage,mask:TRenderImage,scene:TRenderImage
 Field plasmaResult:TRenderImage,outlineImage:TRenderImage
 Field plasmaBuffers:TMax2DEffectBuffers,outlineBuffers:TMax2DEffectBuffers
 Field distortion:TMax2DShaderEffect,textureMask:TMax2DShaderEffect
 Field plasmaChain:TMax2DImageEffect[]
 Field inner:TMax2DInnerShadow,liveBloom:TMax2DBloom
 Field sparks:TPinSpark[256],waves:TPinWave[12],sparkHead:Int,waveHead:Int
 Field oldFlash:Float[8],oldForge:Int,oldFrenzy:Int,oldMulti:Int,oldCells:Int,oldJackpots:Int,oldRollovers:Int
 Field oldWaiting:Int=True,oldBalls:Int=3,oldLeft:Int,oldRight:Int
 Field celebration:Float,sceneSupported:Int,plasmaSupported:Int
 Field sceneScale:Int=1
 Field clock:Float
 Method New()
  For Local i:Int=0 Until sparks.Length
   sparks[i]=New TPinSpark
  Next
  For Local i:Int=0 Until waves.Length
   waves[i]=New TPinWave
  Next
  Local scope:TMax2DStateScope=ScopedMax2DState()
  Try
   SetBlend(ALPHABLEND); SetScale(1,1)
   deck=CreateRenderImage(430,710,FILTEREDIMAGE)
   SetRenderImage(deck); SetClsColor(0,0,0,0); Cls
   For Local y:Int=0 Until 710
    Local shade:Float=Float(Sin(Float(y)/710*180))
    Paint(Int(10+shade*8),Int(17+shade*12),Int(29+shade*18)); DrawRect(0,y,430,1)
   Next
   ' Etched circuit traces, broken tracks and solder pads.
   For Local i:Int=0 Until 22
    Local x:Float=18+(i*47 Mod 390),y:Float=24+(i*83 Mod 630)
    Paint(38,68,83,0.35); SetLineWidth(1)
    DrawLine(x,y,x+12,y+12); DrawLine(x+12,y+12,x+12,y+42)
    DrawLine(x+12,y+42,x+30,y+60)
    Ring(x,y,2,1); Ring(x+30,y+60,2,1)
   Next
   For Local y:Int=12 Until 700 Step 22
    Paint(73,102,116,0.08); DrawLine(10,y,420,y)
   Next
   Paint(46,78,96); DrawLine(1,1,428,1); DrawLine(1,1,1,708)
   Paint(2,6,13); DrawLine(429,1,429,709); DrawLine(1,709,429,709)
   For Local y:Int=12 To 698 Step 98
    Bolt(9,y); Bolt(420,y)
   Next
   housing=CreateRenderImage(128,128,FILTEREDIMAGE)
   SetRenderImage(housing); SetClsColor(0,0,0,0); Cls
   Paint(0,2,7,0.9); DrawOval(11,16,108,108)
   For Local radius:Int=54 To 31 Step -1
    Local shade:Int=30+Int((54-radius)*1.7)
    Paint(shade,shade+14,shade+25); DrawOval(64-radius,64-radius,radius*2,radius*2)
   Next
   Paint(111,147,163); Ring(64,64,50,2)
   Paint(8,15,28); DrawOval(31,31,66,66)
   Paint(95,144,161); Ring(64,64,33,2)
   For Local i:Int=0 Until 6
    Bolt(Float(64+Cos(i*60+30)*43),Float(64+Sin(i*60+30)*43))
   Next
   mask=CreateRenderImage(128,128,FILTEREDIMAGE)
   SetRenderImage(mask); SetClsColor(0,0,0,0); Cls
   Paint(255,255,255); DrawOval(35,35,58,58)
   plasma=CreateRenderImage(128,128,FILTEREDIMAGE)
   SetRenderImage(plasma); SetClsColor(6,35,53,1); Cls
   For Local y:Int=0 Until 128 Step 2
    For Local x:Int=0 Until 128 Step 2
     Local energy:Float=Float((Sin(x*9+Sin(y*5)*40)+Cos(y*8-x*3)+2)/4)
     Paint(Int(70+energy*185),Int(70+energy*185),Int(70+energy*185)); DrawRect(x,y,2,2)
    Next
   Next
   SetRenderImage(Null)
   distortion=CreateGradedDistortionEffect(0.075,19)
   textureMask=CreateTextureMaskEffect(mask)
   plasmaSupported=Max2DSupportsImageEffect(distortion) And Max2DSupportsImageEffect(textureMask)
   If plasmaSupported Then
    plasmaBuffers=New TMax2DEffectBuffers; plasmaBuffers.Prepare(128,128,2)
    plasmaChain=[TMax2DImageEffect(distortion),TMax2DImageEffect(textureMask)]
   End If
   If Max2DSupportsLayerInverseAlpha() And Max2DSupportsImageEffect(CreateBlurEffect()) Then
    inner=CreateInnerShadow(9,4,6); inner.Prepare(128,128,2); inner.Update(mask)
   End If
   If Max2DSupportsImageEffect(CreateOutlineEffect()) Then
    outlineBuffers=New TMax2DEffectBuffers; outlineBuffers.Prepare(128,128,1)
    outlineImage=outlineBuffers.ApplyChain(mask,0,[TMax2DImageEffect(CreateOutlineEffect(3))])
   End If
   sceneSupported=Max2DSupportsImageEffect(CreateBrightPassEffect()) And Max2DSupportsImageEffect(CreateBlurEffect())
   If sceneSupported Then
    sceneScale=Min(2,Max(1,NativeResolutionWidth()/WIDTH))
    scene=CreateRenderImage(UInt(WIDTH*sceneScale),UInt(HEIGHT*sceneScale),FILTEREDIMAGE)
    liveBloom=CreateBloom(0.72,Float(9*sceneScale),0.42); liveBloom.Prepare(WIDTH*sceneScale,HEIGHT*sceneScale,3,PF_RGBA8888)
   End If
  Finally
   scope.Close()
  End Try
 End Method
 Method Bolt(x:Float,y:Float)
  Paint(1,5,11); DrawOval(x-3,y-2,7,7)
  Paint(76,103,117); DrawOval(x-3,y-3,6,6)
  Paint(14,26,39); DrawLine(x-1,y-1,x+1,y+1)
 End Method
 Method Reset()
  For Local spark:TPinSpark=EachIn sparks
   spark.life=0
  Next
  For Local wave:TPinWave=EachIn waves
   wave.life=0
  Next
  oldFlash=New Float[8]; oldForge=0; oldFrenzy=0; oldMulti=0; oldCells=0
  oldJackpots=0; oldRollovers=0; oldWaiting=True; oldBalls=3; celebration=0
 End Method
 Method Burst(x:Float,y:Float,r:Int,g:Int,b:Int,count:Int=24)
  Local wave:TPinWave=waves[waveHead Mod waves.Length]; waveHead:+1
  wave.x=x; wave.y=y; wave.life=0.7; wave.r=r; wave.g=g; wave.b=b
  For Local i:Int=0 Until count
   Local spark:TPinSpark=sparks[sparkHead Mod sparks.Length]; sparkHead:+1
   Local angle:Float=Float(i*137.508+sparkHead*13),speed:Float=45+(i*31 Mod 150)
   spark.x=x; spark.y=y; spark.vx=Float(Cos(angle)*speed); spark.vy=Float(Sin(angle)*speed)
   spark.total=0.28+Float(i Mod 9)*0.055; spark.life=spark.total; spark.size=1+Float(i Mod 3)*0.6
   spark.r=r; spark.g=g; spark.b=b
  Next
 End Method
 Method Update(dt:Float)
  If paused Then Return
  clock:+dt; celebration=Max(0,celebration-dt)
  For Local spark:TPinSpark=EachIn sparks
   If spark.life<=0 Then Continue
   spark.life=Max(0,spark.life-dt); spark.x:+spark.vx*dt; spark.y:+spark.vy*dt
   spark.vy:+70*dt; spark.vx:*(1-dt*1.6)
  Next
  For Local wave:TPinWave=EachIn waves
   wave.life=Max(0,wave.life-dt)
  Next
  For Local i:Int=0 Until 8
   Local target:TPinTarget=table.targets[i]
   If target.flash>oldFlash[i]+0.02 Then
    Local r:Int=85,g:Int=225,b:Int=255,soundIndex:Int=0
    If i=0 Or i>=5 Then r=255; g=175; b=75
    If i=2 Then r=192; g=142; b=255
    If i=3 Or i=4 Then r=255; g=94; b=173; soundIndex=1
    Burst(TX+target.impactX*SCALE,TY+target.impactY*SCALE,r,g,b)
    audio.Play(soundIndex,target.x,Float(0.9+i*0.055))
   End If
   oldFlash[i]=target.flash
  Next
  If (table.forgeTime>0 And Not oldForge) Or (table.frenzyTime>0 And Not oldFrenzy) Or (table.multiActive And Not oldMulti) Then
   Burst(TX+5.6*SCALE,TY+11*SCALE,168,161,255,48); audio.Play(4)
  End If
  Local cells:Int=table.forgeCells+table.frenzyCells+table.multiCells
  If cells>oldCells Or table.jackpots>oldJackpots Then
   celebration=2; audio.Play(5)
   For Local i:Int=0 Until 3
    Burst(TX+table.targets[i].x*SCALE,TY+table.targets[i].y*SCALE,255,217,126,40)
   Next
  End If
  If table.rolloverMask<>oldRollovers And table.rolloverMask Then audio.Play(7)
  If oldWaiting And Not table.waiting Then audio.Play(3,11)
  If table.balls<oldBalls Then audio.Play(6)
  If leftDown And Not oldLeft Then audio.Play(2,3)
  If rightDown And Not oldRight Then audio.Play(2,8,1.1)
  oldLeft=leftDown; oldRight=rightDown
  oldForge=table.forgeTime>0; oldFrenzy=table.frenzyTime>0; oldMulti=table.multiActive
  oldCells=cells; oldJackpots=table.jackpots; oldRollovers=table.rolloverMask
  oldWaiting=table.waiting; oldBalls=table.balls
 End Method
 Method BeginScene()
  If plasmaSupported Then
   distortion.SetFloat("time",clock*1.5)
   If table.frenzyTime>0 Then distortion.SetFloat4("gradeTint",1,0.85,1,1) Else distortion.SetFloat4("gradeTint",1,1,1,1)
   plasmaResult=plasmaBuffers.ApplyChain(plasma,0,plasmaChain)
  End If
  If sceneSupported Then
   SetRenderImage(scene); SetVirtualResolution(WIDTH,HEIGHT)
  End If
  SetClsColor(5,9,18); Cls
 End Method
 Method EndScene()
  DrawParticles()
  If sceneSupported Then
   SetRenderImage(Null)
   Local result:TRenderImage=liveBloom.Update(scene)
   Paint(255,255,255); SetBlend(SOLIDBLEND); SetScale(1.0/sceneScale,1.0/sceneScale)
   DrawImage(result,0,0); SetScale(1,1); SetBlend(ALPHABLEND)
  End If
 End Method
 Method DrawDeck()
  Paint(255,255,255); DrawImage(deck,80,40)
  ' The reactor's etched orbital tracks lie beneath the physical fixtures.
  Local cx:Float=TX+5.6*SCALE,cy:Float=TY+7*SCALE
  For Local ringIndex:Int=0 Until 4
   Local radius:Float=89+ringIndex*17
   Paint(53,100,120,0.22); Ring(cx,cy,radius,1)
   For Local n:Int=0 Until 4
    Local angle:Float=clock*(3+ringIndex*2)+n*90+ringIndex*27
    Local x:Float=Float(cx+Cos(angle)*radius),y:Float=Float(cy+Sin(angle)*radius)
    Paint(102,197,216,0.35); DrawOval(x-1.5,y-1.5,3,3)
   Next
  Next
  TableText("F L U X",TX+5.6*SCALE,512,25,65,106,127,150)
  TableText("ENERGY REACTOR",TX+5.6*SCALE,539,8,84,117,137,150)
  ' Moving light chases follow the actual rails rather than changing geometry.
  For Local rail:TPinRail=EachIn table.rails
   If rail.active Then Continue
   Local phase:Float=Float((clock*0.15+rail.x1*0.11) Mod 1)
   Local x:Float=TX+(rail.x1+(rail.x2-rail.x1)*phase)*SCALE
   Local y:Float=TY+(rail.y1+(rail.y2-rail.y1)*phase)*SCALE
   Glow(x,y,0.65,68,183,255,0.35)
  Next
  If table.frenzyTime>0 Then
   ' Background filaments connect the three powered cores without obscuring balls.
   For Local link:Int=0 Until 3
    Local a:TPinTarget=table.targets[link],b:TPinTarget=table.targets[(link+1) Mod 3]
    Local px:Float=a.x,py:Float=a.y
    For Local n:Int=1 To 20
     Local t:Float=Float(n)/20,envelope:Float=Float(Sin(t*180))
     Local x:Float=a.x+(b.x-a.x)*t+Float(Sin(clock*370+n*71))*0.10*envelope
     Local y:Float=a.y+(b.y-a.y)*t+Float(Cos(clock*430+n*53))*0.10*envelope
     Paint(113,73,195,0.3); Line(px,py,x,y,3)
     Paint(182,147,255,0.4); Line(px,py,x,y,1)
     px=x; py=y
    Next
   Next
  End If
  If table.multiActive Then
   For Local i:Int=0 Until 2
    Local angle:Float=clock*130+i*180
    Local x:Float=TX+8.1*SCALE+Float(Cos(angle))*24,y:Float=TY+10.9*SCALE+Float(Sin(angle))*24
    Glow(x,y,0.7,127,160,255,0.6)
   Next
  End If
  If table.forgeTime>0 Then
   For Local i:Int=0 Until 12

    Local y:Float=Float(7+(i*0.33+clock*0.7) Mod 3.6)
    Paint(255,153,53,0.12); Line(0.85,y,1.8,y,2)
   Next
   For Local i:Int=0 Until 14
    Local x:Float=TX+(0.9+Float(i Mod 4)*0.23)*SCALE
    Local y:Float=TY+(10.7-Float((clock*0.8+i*0.27) Mod 3.6))*SCALE
    Glow(x,y,0.4,255,142,48,0.45)
   Next
  End If
 End Method
 Method DrawCore(index:Int)
  Local target:TPinTarget=table.targets[index],x:Float=TX+target.x*SCALE,y:Float=TY+target.y*SCALE
  Local r:Int=82,g:Int=200,b:Int=255
  If index=0 Then r=255; g=173; b=76
  If index=2 Then r=187; g=132; b=255
  Local lit:Int=table.litMask & (1 Shl index)
  Glow(x,y,2.7,r,g,b,0.23+target.flash)
  Paint(255,255,255); SetScale(0.55,0.55); DrawImage(housing,x-35.2,y-35.2); SetScale(1,1)
  If plasmaResult Then
   Paint(r,g,b); SetScale(0.55,0.55); DrawImage(plasmaResult,x-35.2,y-35.2); SetScale(1,1)
  Else
   Paint(r,g,b); DrawOval(x-14,y-14,28,28)
  End If
  If inner Then
   Paint(0,3,12,0.55); SetScale(0.55,0.55); DrawImage(inner.Result(),x-35.2,y-35.2); SetScale(1,1)
  End If
  If outlineImage Then
   Paint(r,g,b,0.65+target.flash*0.6); SetScale(0.55,0.55); DrawImage(outlineImage,x-35.2,y-35.2); SetScale(1,1)
  End If
  Paint(225,244,255,0.25); DrawOval(x-10,y-11,11,4)
  Paint(r,g,b,0.7); Ring(x,y,27,1)
  For Local i:Int=0 Until 12
   Local a:Float=i*30+clock*12,b:Float=a+12
   Paint(r,g,255,0.4+target.flash)
   DrawLine(x+Cos(a)*22,y+Sin(a)*22,x+Cos(b)*22,y+Sin(b)*22)
  Next
  If lit Then Paint(245,255,248,0.7); DrawOval(x-3,y-3,6,6)
  If table.frenzyTime>0 Then
   Paint(196,142,255,0.7); Ring(x,y,32+Float(Sin(clock*240))*2,1)
  End If
  Local charge:Int=table.forgeCharge,segments:Int=3,spacing:Float=16
  If index=1 Then charge=table.multiCharge; segments=MULTI_CHARGE_HITS; spacing=8
  If index=2 Then charge=table.frenzyCharge
  For Local i:Int=0 Until segments
   Paint(9,17,28); DrawRect(x-23+i*spacing,y+34,spacing-2,7)
   If i<charge Then Paint(r,g,b) Else Paint(42,62,79)
   DrawRect(x-22+i*spacing,y+35,spacing-4,3)
  Next
 End Method
 Method DrawParticles()
  SetBlend(LIGHTBLEND)
  For Local spark:TPinSpark=EachIn sparks
   If spark.life<=0 Or spark.x<91 Or spark.x>500 Or spark.y<48 Or spark.y>739 Then Continue
   Local alpha:Float=spark.life/spark.total
   Paint(spark.r,spark.g,spark.b,alpha); SetLineWidth(spark.size)
   DrawLine(spark.x,spark.y,spark.x-spark.vx*0.025,spark.y-spark.vy*0.025)
  Next
  SetLineWidth(1)
  For Local wave:TPinWave=EachIn waves
   If wave.life<=0 Then Continue
   Paint(wave.r,wave.g,wave.b,wave.life*0.5)
   Ring(wave.x,wave.y,12+(0.7-wave.life)*110,1)
  Next
  SetBlend(ALPHABLEND)
  If celebration>0 Then
   TableText("POWER COLLECTED",TX+5.6*SCALE,608,14,255,225,160,205)
  End If
 End Method
 Method DrawConsole()
  For Local y:Int=44 Until 780 Step 2
   Paint(10,Int(17+(y Mod 6)),30); DrawRect(550,y,392,2)
  Next
  Paint(39,64,83); DrawLine(550,44,942,44); DrawLine(550,44,550,780)
  Paint(20,36,53); DrawLine(942,44,942,780)
  Bolt(559,53); Bolt(933,53); Bolt(559,780); Bolt(933,780)
  Text("FLUX SYSTEMS / REACTOR CONTROL",570,49,0.44,103,143,163)
  Local status:String="SFX ON"
  If audio.muted Then status="SFX OFF"
  If Not audio.ready Then status="NO AUDIO"
  Paint(25,43,61); DrawRect(843,300,82,26)
  Text(status+" / M",850,308,0.48,146,187,210)
 End Method
 Method Release()
  If plasmaBuffers Then plasmaBuffers.Release()
  If outlineBuffers Then outlineBuffers.Release()
  If inner Then inner.Release()
  If liveBloom Then liveBloom.Release()
  If deck Then deck.ReleaseFrames()
  If housing Then housing.ReleaseFrames()
  If plasma Then plasma.ReleaseFrames()
  If mask Then mask.ReleaseFrames()
  If scene Then scene.ReleaseFrames()
 End Method
End Type
