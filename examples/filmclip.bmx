' Adapted from samples/birdie/misc/filmclip/main.bmx.
Strict

?max2d_gl
Framework Max2D.GLMax2D
?Not max2d_gl
Framework Max2D.SDL3RenderMax2D
?
Import BRL.StandardIO
Import BRL.RamStream

Import brl.Random
Import brl.pngloader

?max2d_sdl_gpu
SetSDLRenderMax2DRenderer("gpu")
?
?sample_test
SeedRnd(1)
?
Incbin "../../../samples/birdie/misc/filmclip/media/B-Max.png"
Incbin "../../../samples/birdie/misc/filmclip/media/flmstp.png"
Graphics 640,480,0
Local maskBlend:Int=MASKBLEND
If Not Max2DSupportsBlend(MASKBLEND) Then maskBlend=ALPHABLEND
?sample_test
Local testFrames:Int
?

AutoMidHandle True
Global BMX01IMG:TImage = LoadImage("incbin::../../../samples/birdie/misc/filmclip/media/B-Max.png",FILTEREDIMAGE|DYNAMICIMAGE)
ConvertToBW BMX01IMG,0
Global FLM01IMG:TImage = LoadAnimImage("incbin::../../../samples/birdie/misc/filmclip/media/flmstp.png",126,66,0,10)

?sample_test
Local checked:TPixmap=LockImage(BMX01IMG,0,True,False)
For Local cy:Int=0 Until checked.height
	For Local cx:Int=0 Until checked.width
		Local pixel:Int=checked.ReadPixel(cx,cy)
		SampleCheck(((pixel Shr 16)&255)=((pixel Shr 8)&255) And ((pixel Shr 8)&255)=(pixel&255),"Grayscale conversion")
	Next
Next
UnlockImage(BMX01IMG)
SampleCheck(FLM01IMG<>Null,"Filmstrip loading")
?
Local a:Int
While Not KeyDown(KEY_ESCAPE)
  PollSystem()
  If AppTerminate() Then Exit
  Cls

  SetColor 255,255,255
  SetBlend ALPHABLEND          
  SetScale 1,1
  SetAlpha Float(Rnd(0.75,0.95))
  DrawImage bmx01img,Float(320+Rnd(-1,1)),Float(240+Rnd(-1,1)),0
  If Rand(40)=5
    SetColor 128,128,128
    SetBlend SOLIDBLEND
    Local x:Float=Rnd(640)
    DrawLine x,0,Float(x+Rnd(-5,5)),Float(Rnd(400,480))
    EndIf
  SetBlend maskBlend
  SetColor 255,255,255
  SetScale 6.5,7.5
  DrawImage FLM01IMG,320,240,a
  a:+1
  a=a Mod 10
?sample_test
  testFrames:+1
  If testFrames=120 Then
    SampleCheck(Max2DStats().textureCreations=2,"Filmclip should share animation texture")
    SampleCapture("filmclip")
    Exit
  End If
  Flip(0)
?Not sample_test
  Flip
?
Wend

EndGraphics()

Function ConvertToBW(i:TImage,frame)
  Local col,a,r,g,b,cc,x=0,y=0
  Local pix:TPixmap
  
  pix=LockImage(i,frame)
  While y<i.height
    x=0
    While x<i.width
      col = ReadPixel( pix, x, y )
      a = ( col & $ff000000)
      r = ( col & $ff0000 ) Shr 16
      g = ( col & $ff00 ) Shr 8
      b = ( col & $ff )
      cc= (r+g+b)/3
      col = a | (cc Shl 16) | (cc Shl 8) | cc
      WritePixel( pix, x, y, col )
      x=x+1
    Wend
    y=y+1
  Wend
  UnlockImage i,frame
EndFunction


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
