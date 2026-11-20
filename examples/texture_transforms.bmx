SuperStrict
?max2d_d3d9
Framework Max2D.D3D9Max2D
Import Max2D.D3D9Effects
?max2d_d3d11
Framework Max2D.D3D11Max2D
Import Max2D.D3D11Effects
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?

AppTitle="Max2D independent map transforms"
Graphics(1040,540)
Local source:TRenderImage=CreateRenderImage(300,340,FILTEREDIMAGE,PF_RGBA16F)
SetRenderImage(source)
SetClsColor(0,0,0,0); Cls
For Local y:Int=0 Until 340 Step 20
	For Local x:Int=0 Until 300 Step 20
		If (x/20+y/20) Mod 2 Then SetColor(35,90,130) Else SetColor(20,45,70)
		DrawRect(x,y,20,20)
	Next
Next
SetColor(255,180,65); DrawOval(45,45,210,210)
SetColor(25,40,60); DrawOval(65,65,170,170)
SetColor(100,220,240); DrawRect(135,25,30,250)
SetColor(245,90,140); DrawRect(25,135,250,30)
SetColor(255,255,255); SetScale(4,4); DrawText("Max2D",30,285); SetScale(1,1)
SetRenderImage(Null)
Local pixels:Float[]=New Float[128*128*4]
For Local y:Int=0 Until 128
	For Local x:Int=0 Until 128
		Local i:Int=(y*128+x)*4
		Local u:Float=Float(x)*360/128, v:Float=Float(y)*360/128
		pixels[i]=Float(0.5+0.22*Sin(2*u+v)+0.16*Sin(3*v-u)+0.1*Sin(5*u+4*v))
		pixels[i+1]=Float(0.5+0.3*Sin(2*v+u))
		pixels[i+2]=0
		pixels[i+3]=1
	Next
Next
Local bytes:Byte[]=New Byte[pixels.Length*4]
MemCopy(bytes,pixels,Size_T(bytes.Length))
Local map:TImage=LoadImage(TTextureData.Create([TTextureLevel.Create(128,128,PF_RGBA32F,bytes)]),FILTEREDIMAGE)
Local displacement:TMax2DShaderEffect=CreateDisplacementEffect(map,0.035,0.025)
displacement.SetEdgeMode(MAX2D_EDGE_REPEAT)
displacement.SetTextureEdgeMode(MAX2D_EDGE_REPEAT)
For Local y:Int=0 Until 128
	For Local x:Int=0 Until 128
		Local dx:Float=Float(x-64)/64, dy:Float=Float(y-64)/64
		Local coverage:Float=Float(Max(0,Min(1,(1-Sqr(dx*dx+dy*dy))*4)))
		coverage=coverage*coverage*(3-2*coverage)
		Local i:Int=(y*128+x)*4
		pixels[i]=1; pixels[i+1]=1; pixels[i+2]=1; pixels[i+3]=coverage
	Next
Next
MemCopy(bytes,pixels,Size_T(bytes.Length))
Local softMap:TImage=LoadImage(TTextureData.Create([TTextureLevel.Create(128,128,PF_RGBA32F,bytes)]),FILTEREDIMAGE)
Local mask:TMax2DShaderEffect=CreateTextureMaskEffect(softMap)
Local paused:Int, followMouse:Int, time:Float, size:Float=0.65, edge:Int=MAX2D_EDGE_REPEAT
Local edges:String[]=["Transparent","Clamp","Repeat"]
Local previous:Int=MilliSecs()
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Local now:Int=MilliSecs(), elapsed:Int=now-previous
	previous=now
	If KeyHit(KEY_SPACE) Then paused=Not paused
	If KeyHit(KEY_M) Then followMouse=Not followMouse
	If KeyHit(KEY_E) Then edge=(edge+1) Mod 3
	If KeyHit(KEY_UP) Then size=Float(Min(2,size+0.05))
	If KeyHit(KEY_DOWN) Then size=Float(Max(0.1,size-0.05))
	If Not paused Then time:+Float(Min(elapsed,100))*0.001
	displacement.SetTextureEdgeMode(edge)
	displacement.SetTextureTransform(time*0.08,time*0.03,size,size,Float(20*Sin(time*25)))
	Local x:Float=Float(0.22*Sin(time*40)), y:Float=Float(0.2*Cos(time*30))
	If followMouse Then x=Float(MouseX()-705)/300-0.5; y=Float(MouseY()-60)/340-0.5
	mask.SetTextureTransform(x,y,0.7,0.4,time*25)
	SetClsColor(16,20,30); Cls
	SetColor(255,255,255); SetBlend(ALPHABLEND)
	DrawText("Original",35,25); DrawText("Scrolling displacement map",370,25); DrawText("Moving / rotating mask",705,25)
	DrawImage(source,35,60)
	DrawImageEffect(source,displacement,370,60)
	DrawImageEffect(source,mask,705,60)
	DrawText("Space: pause   M: mouse-controlled mask   E: map edges   Up/down: map size",35,430)
	DrawText("Displacement map edges: "+edges[edge]+"   Size: "+size,35,468)
	DrawText("The maps move independently of the images.",35,500)
	Flip
Wend
EndGraphics
