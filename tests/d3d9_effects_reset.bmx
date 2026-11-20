SuperStrict
Framework Max2D.D3D9Max2D
Import Max2D.D3D9Effects
Import BRL.StandardIO
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Try
 Local effect:TMax2DColorizeEffect=CreateColorizeEffect(30,80,160)
 Local image:TImage
 For Local lifetime:Int=0 Until 2
  Graphics(160,80,0,0)
  If Not image Then
   image=CreateImage(3,2,1,DYNAMICIMAGE)
   Local pixels:TPixmap=LockImage(image)
   pixels.ClearPixels($ffffffff)
   UnlockImage(image)
  End If
  Check(Max2DSupportsImageEffect(effect),"Shader 3 effects required for this regression")
  For Local sync:Int=0 Until 3
   SetBlend(SOLIDBLEND)
   DrawImageEffect(image,effect,10,10)
   Local result:TPixmap=GrabPixmap(10,10,3,2)
   Check((result.ReadPixel(2,1)&$ffffff)=$1e50a0,"Effect survives reset and preserves non-power-of-two coordinates")
   DrawImage(image,20,10)
   Check((GrabPixmap(20,10,1,1).ReadPixel(0,0)&$ffffff)=$ffffff,"Ordinary shader restored")
   Flip(sync Mod 2)
  Next
  DrawImageEffect(image,CreateToneMapEffect(),30,10)
  Local tone:Int=GrabPixmap(30,10,1,1).ReadPixel(0,0)&255
  Check(Abs(tone-128)<=1,"SDR tone mapping")
  DrawImageEffect(image,CreateLinearOutputEffect(),40,10)
  Local linear:Int=GrabPixmap(40,10,1,1).ReadPixel(0,0)&255
  Check(Abs(linear-188)<=1,"Linear-to-sRGB SDR output")
  EndGraphics
 Next
 Print "d3d9_effects_reset passed"
Catch error:Object
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
