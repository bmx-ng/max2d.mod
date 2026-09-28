Rem

Another Oldskool demo thingy, by FlameDuck and Razorien of Binary Therapy

It started as a simple circle scroller example but got somewhat out of hand. :o>

End Rem

Strict

?max2d_gl
Framework Max2D.GLMax2D
?Not max2d_gl
Framework Max2D.SDL3RenderMax2D
?
Import BRL.StandardIO
Import brl.pngloader
Import brl.ramstream
Import brl.oggloader
Import brl.Random
Import BRL.FreeAudioAudio

Incbin "../../../samples/flameduck/oldskool2/circlefont.png"
Incbin "../../../samples/flameduck/oldskool2/oldskool.png"
Incbin "../../../samples/flameduck/oldskool2/bouncy.ogg"
Incbin "../../../samples/flameduck/oldskool2/binarytherapy.png"

' Compatibility port: assets/credits remain in samples/flameduck/oldskool2.
' --test (console) or -ud sample_test (GUI) runs 700 silent test frames.
' Test screenshots default to oldskool2-test.png beside the executable.
Global sampleTest:Int
sampleTest = AppArgs.Length > 1 And AppArgs[1] = "--test"
?sample_test
sampleTest = True
?
Global sampleMaskBlend:Int = MASKBLEND
If sampleTest Then SeedRnd(1) Else SetAudioDriver("FreeAudio")

Global scrollSpeed:Double = .6
Global rotangl:Double = 0
Global osLogo:TImage = LoadImage( "incbin::../../../samples/flameduck/oldskool2/oldskool.png" )
Global myFont:TImage = LoadAnimImage( "incbin::../../../samples/flameduck/oldskool2/circlefont.png",32,32,0,90 )
Global myBT:TImage = LoadImage( "incbin::../../../samples/flameduck/oldskool2/binarytherapy.png" )

MidHandleImage myFont

Global scrollytext$ = " In 2004       Binary Therapy       Proudly Presents       Oldskool 2       Programmed by: FlameDuck       Logo by: Razorien ( http://www.razorien.se/ )       Font courtesy of FONText by: Beaker ( http://www.playerfactory.co.uk/ )       Music by:  Dr Av ( http://www.mentalillusion.co.uk/ )       This demo was written in the beta phase of BlitzMAX development, the source code is 237 lines total including empty lines and comments ....."
Global sp = 0; 'The scrollytext pointer.
Global ld = 0; 'The letter delay counter.
Global muzak:TSound
If Not sampleTest Then muzak = LoadSound( "incbin::../../../samples/flameduck/oldskool2/bouncy.ogg",True )

Type scrollyLetter

	Field rad:Double, angl:Double, letter:Byte, rados:Double
	Field myList:TList

	Function createScrollyLetter:scrollyLetter(myChar:Byte)
		Local myLetter:scrollyLetter = New scrollyLetter
		myLetter.rad = 170
		myLetter.angl = -90
		myLetter.letter = myChar
		Return myLetter
	End Function

	Method setList(aList:TList)
		myList = aList
	End Method

	Method moveScrollyLetter()
		angl :+ scrollSpeed
		rados = Cos(angl*3 + rotangl) * 40
		If angl > 270
			myList.remove(Self)
		End If

	End Method

	Method drawLetter()
		Local x = Cos(angl) * (rad + rados)
		Local y = Sin(angl) * (rad + rados)

		SetRotation Float(ATan2 ( y , x ))

		Local myAlpha:Float = 1
		If angl < -45
			myAlpha = (90.0+angl)/45.0
		Else If angl > 225
			myAlpha = (270.0-angl)/45.0
		End If

		SetAlpha myAlpha
		DrawImage myFont, x + 400 , -y + 240 , letter

	End Method

End Type

Type circleScroller Extends TList

	Method doScroller()
		rotangl :+ scrollSpeed; rotangl :Mod 360

		ld :+ 1
		If  ld > 20
			If scrollytext[sp]-33 > 0 And scrollytext[sp]-33 < 90
				Local myLetter:scrollyLetter = scrollyLetter.createScrollyLetter( Byte(scrollytext[sp]-33) )
				myLetter.setList(Self)
				addLast myLetter
			End If
			sp = (sp+1) Mod Len(scrollytext)
			ld = 0
		End If

		SetBlend ALPHABLEND

		Local cLetter:scrollyLetter
		For cLetter = EachIn Self

			cLetter.moveScrollyLetter
			cLetter.drawLetter


		Next
		SetBlend sampleMaskBlend

		SetRotation 0
		SetAlpha 1

	End Method

End Type

Type star
	Field x:Double, y:Double, z:Double, angl:Double, anglv:Double, zv:Double

	Function createStar:star()
		Local myStar:star = New star
		myStar.x = Rnd(-240,240)
		myStar.y = Rnd(-240,240)
		myStar.z = 100
		myStar.angl = Rnd(0,360)
		myStar.anglv = Rnd(-5,5)
		myStar.zv = Rnd(0.5,2)
		Return myStar
	End Function

	Method moveStar()
		z :- zv
		Local myx = x / z *100
		Local myy = y / z *100

		If myx < -240 Or myx > 240 Or myy < -240 Or myx > 240 Or z < 1
			x = Rnd(-240,240)
			y = Rnd(-240,240)
			z = 100
			angl = Rnd(0,360)
			anglv = Rnd(-5,5)
			zv = Rnd(0.5,3)
		End If

		angl = angl + anglv
	End Method

	Method drawStar()
		Local myx = x / z *100
		Local myy = y / z *100

		Local COLS = 255*(100-z)/100

		SetColor(COLS,COLS,COLS)
		Plot myx+400 , myy+240

	End Method


End Type

Type starField Extends TList

	Method doStarField()

		Local cStar:star
		For cStar = EachIn Self

			cStar.moveStar
			cStar.drawStar

		Next
	 	SetColor 255,255,255

	End Method

End Type

Local myCS:circleScroller = New circleScroller
Local mySF:starField = New starField

Local ba = 0
Local intro = 0
Local i = 0
Local term:Double = 0

?max2d_sdl_gpu
If Not SetSDLRenderMax2DRenderer("gpu") Then Throw "SDL renderer selection overridden"
?
Graphics 640,480,0
If Not Max2DSupportsBlend(MASKBLEND) Then sampleMaskBlend = ALPHABLEND
If Not osLogo Or Not myFont Or Not myBT Then Throw "Oldskool2: image loading failed"
Local sampleFrames:Int
Local sampleLit:Int
If sampleTest Then Print "Oldskool2: " + TMax2DGraphics.Current().driver.ToString() + " mask blend=" + sampleMaskBlend

If Not sampleTest Then HideMouse

Local myChannel:TChannel
If Not sampleTest Then myChannel = PlaySound(muzak)

While term < 1
	PollSystem()
	If AppTerminate() Then Exit

	Cls

	mySF.doStarField

	If intro < 80
		intro :+2
	Else
		myCS.doScroller
		If i < 400
			mySF.addLast star.createStar()
			mySF.addLast star.createStar()
			mySF.addLast star.createStar()
			mySF.addLast star.createStar()
			mySF.addLast star.createStar()
			mySF.addLast star.createStar()
			mySF.addLast star.createStar()
			mySF.addLast star.createStar()
			mySF.addLast star.createStar()
			mySF.addLast star.createStar()
			i :+ 1
		End If
	End If

	SetBlend SOLIDBLEND
	DrawImage osLogo,-160+intro*2,0

	SetBlend sampleMaskBlend
	DrawImage myBT, 640-myBT.width * intro/80.0, Float(480-myBT.height - Sin(ba)*20)

	SetBlend ALPHABLEND
	SetAlpha Float(term)
	If myChannel Then SetChannelVolume myChannel,Float(1-term)
	SetColor 0,0,0
	DrawRect 0,0,640,480
	SetAlpha 1
	SetColor 255,255,255

	If KeyHit(KEY_ESCAPE) Or term > 0
		term :+ 0.01
	End If

	ba :+6; ba :Mod 180
	If sampleTest Then
		sampleFrames :+ 1
		If sampleFrames = 700 Then
			Local pixels:TPixmap = GrabPixmap(0,0,NativeResolutionWidth(),NativeResolutionHeight())
			Local capturePath:String = AppDir + "/oldskool2-test.png"
			If AppArgs.Length > 2 Then capturePath = AppArgs[2]
			If Not SavePixmapPNG(pixels,capturePath) Then Throw "Oldskool2: screenshot save failed"
			Print "capture=" + capturePath + " size=" + pixels.width + "x" + pixels.height
			For Local py:Int = 0 Until pixels.height Step 4
				For Local px:Int = 0 Until pixels.width Step 4
					If pixels.ReadPixel(px,py) & $ffffff Then sampleLit :+ 1
				Next
			Next
		End If
		Flip(0)
		If sampleFrames = 700 Then Exit
	Else
		Flip
	End If

Wend

If sampleTest Then
	Local stats:TMax2DStats = Max2DStats()
	If sampleFrames <> 700 Or sampleLit < 100 Or myCS.Count() = 0 Or mySF.Count() <> 4000 Then Throw "Oldskool2: incomplete or blank test run"
	Print "Oldskool2 passed: frames=" + sampleFrames + " stars=" + mySF.Count() + " letters=" + myCS.Count() + " lit samples=" + sampleLit
	Print "submissions=" + stats.submissions + " textures=" + stats.textureCreations + " uploads=" + stats.textureUpdates
End If
If myChannel Then StopChannel(myChannel)
If Not sampleTest Then ShowMouse
EndGraphics()
