' Snowfall by simonh (si@si-design.co.uk)

SuperStrict

?max2d_gl
Framework Max2D.GLMax2D
?Not max2d_gl
Framework Max2D.SDL3RenderMax2D
?
Import BRL.StandardIO
Import BRL.RamStream
Import "sample_clock.c"
Extern "C"
	Function max2d_sample_seconds:Double()
End Extern
?sample_pacing
Include "../benchmarks/snowfall_pacing.bmx"
?

Import brl.pngloader
Import brl.Random

Global width:Int=800
Global height:Int=600

?max2d_sdl_gpu
SetSDLRenderMax2DRenderer("gpu")
?
?sample_test Or sample_pacing
SeedRnd(1)
?
Incbin "../../../samples/simonh/snow/flake.png"
Graphics width,height,0
Local imageFlags:Int=MIPMAPPEDIMAGE
If Not Max2DSupportsImageFlags(imageFlags) Then imageFlags=FILTEREDIMAGE
Print "Snowfall image flags="+imageFlags
?sample_pacing And Not max2d_gl
Print "SDL renderer="+SDLRenderMax2DRendererName()
?
?sample_test
Local testFrames:Int
?

' Load snowflake image
Global flakei:TImage=LoadImage("incbin::../../../samples/simonh/snow/flake.png",imageFlags)

' Set no. of snowflakes to be created
Global no_flakes:Int=1000

' Create a snowflake type
Type flake
	Field x#,y#,size#,speed#,sway#,phase:Int
End Type

' Create snowflake list
Global flake_list:TList=New TList

' Initialise snowflakes

For Local i:Int=1 To no_flakes

	Local fl:flake=New flake
	flake_list.AddLast fl

	fl.size=Rnd!(0.01,0.1)
	fl.speed=Rnd!(1,2)
	fl.sway=Rnd!(1,2)
	fl.phase=Rand(45)
	fl.x=Rand(-10,width+10)
	fl.y=Rand(height)-height-10

Next

' Main loop: the original motion assumes 60 updates per second.
' VSync controls presentation; elapsed time controls animation speed.
Local wind:Float=1
Local lastFrame:Double=max2d_sample_seconds()
Cls

While Not KeyHit(KEY_ESCAPE)


?sample_pacing
	PacingStart()
?
	PollSystem()
	If KeyDown(KEY_ESCAPE) Or AppTerminate() Then Exit

	Local now:Double=max2d_sample_seconds()
	' Clamp long interruptions so restoring a paused window does not jump.
	Local stepSize:Float=Float(Max(0.0,Min(0.1,now-lastFrame))*60.0)
	lastFrame=now
?sample_test Or pacing_legacy
	stepSize=1
?
	' Iterate through our snowflake list

	For Local fl:flake=EachIn flake_list

		' Just update the snowflake position values to try and make them move convincingly!
		fl.y=fl.y+fl.speed*stepSize
		fl.x#=fl.x#+(Sin(wind+(fl.phase)))*fl.sway*stepSize

		' If snowflake has not yet reached the bottom of screen...
		If fl.y<height+10

			' ...then draw snowflake.
			SetBlend LIGHTBLEND
			SetScale fl.size,fl.size
			DrawImage flakei,fl.x,fl.y

		'...else if snowflake has reached bottom of screen...
		Else

			'...reset snowflake values so it appears as new snowflake at top of screen.
			fl.speed=Rnd!(1,2)
			fl.sway=Rnd!(1,2)
			fl.phase=Rand(45)
			fl.x=Rand(-10,width+10)
			fl.y=-10

		EndIf

	Next

	wind=1+(wind-1+5*stepSize) Mod 360

?sample_test
	testFrames:+1
	If testFrames=720 Then
		SampleCheck(flake_list.Count()=1000,"Snowflake population")
		SampleCheck(Max2DStats().textureCreations=1,"Snow texture sharing")
		If imageFlags & MIPMAPPEDIMAGE Then SampleCheck(Max2DStats().mipmapGenerations=1,"Static snow mipmap chain")
		SampleCapture("snowfall")
		Exit
	End If
	Flip(0)
?sample_pacing And Not sample_test
	PacingBeforeFlip()
?Not sample_test And Not pacing_legacy
	Flip(1)
?Not sample_test And pacing_legacy
	Flip
?
	Cls
?sample_pacing
	If PacingEnd() Then Exit
?

	If AppTerminate() Or KeyDown(KEY_ESCAPE) Then Exit
?sample_test
	If testFrames=720 Then Exit
?
Wend
EndGraphics()

?sample_test
Function SampleCheck(condition:Int,message:String)
	If Not condition Then
		Print "FAILED: "+message
		EndWithCode(1)
	End If
End Function
Function SampleCapture(name:String)
	Local p:TPixmap=GrabPixmap(0,0,NativeResolutionWidth(),NativeResolutionHeight())
	Local lit:Int
	For Local y:Int=0 Until p.height Step 4
		For Local x:Int=0 Until p.width Step 4
			If p.ReadPixel(x,y)&$ffffff Then lit:+1
		Next
	Next
	SampleCheck(lit>100,"Blank sample: "+name)
	SampleCheck(SavePixmapPNG(p,AppDir+"/"+name+".png"),"Screenshot save")
	Local stats:TMax2DStats=Max2DStats()
	Print name+" passed: output="+p.width+"x"+p.height+" textures="+stats.textureCreations+" uploads="+stats.textureUpdates+" mipmaps="+stats.mipmapGenerations
End Function
?
