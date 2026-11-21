SuperStrict
Framework Max2D.D3D9Max2D
Import Max2D.D3D9Effects
Import BRL.StandardIO
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Try
 Local effect:TMax2DColorizeEffect=CreateColorizeEffect(30,80,160)
 Local grade:TMax2DShaderEffect=CreateColorMatrixEffect()
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
  Local retainedByte:TRenderImage=CreateRenderImage(3,2,0)
  ClearImage(retainedByte,30,80,160,0.5)
  Local retainedFloat:TRenderImage=CreateRenderImage(3,2,0,PF_RGBA32F)
  ClearImage(retainedFloat,80,120,200,0.125)
  For Local sync:Int=0 Until 3
   SetBlend(SOLIDBLEND)
   DrawImageEffect(image,effect,10,10)
   Local result:TPixmap=GrabPixmap(10,10,3,2)
   Check((result.ReadPixel(2,1)&$ffffff)=$1e50a0,"Effect survives reset and preserves non-power-of-two coordinates")
   DrawImageEffect(image,grade,15,10)
   Check((GrabPixmap(15,10,1,1).ReadPixel(0,0)&$ffffff)=$ffffff,"Package survives presentation reset")
   DrawImage(image,20,10)
   Check((GrabPixmap(20,10,1,1).ReadPixel(0,0)&$ffffff)=$ffffff,"Ordinary shader restored")
   Flip(sync Mod 2)
   Local snapshot:TTextureData=ReadRenderTextureData(retainedFloat)
   Local channels:Float Ptr=Float Ptr(snapshot.Level().Data())
   Check(Abs(channels[0]-80.0/255)<0.00001 And Abs(channels[3]-0.125)<0.00001,"Cached float layer survives presentation reset")
   Check(Abs(((ReadRenderImage(retainedByte).ReadPixel(0,0) Shr 24)&255)-128)<=1,"Cached byte layer survives presentation reset")
  Next
  DrawImageEffect(image,CreateToneMapEffect(),30,10)
  Local tone:Int=GrabPixmap(30,10,1,1).ReadPixel(0,0)&255
  Check(Abs(tone-128)<=1,"SDR tone mapping")
  DrawImageEffect(image,CreateLinearOutputEffect(),40,10)
  Local linear:Int=GrabPixmap(40,10,1,1).ReadPixel(0,0)&255
  Check(Abs(linear-188)<=1,"Linear-to-sRGB SDR output")
  Local hdr:TRenderImage=CreateRenderImage(3,2,0,PF_RGBA32F)
  SetRenderImage(hdr);SetClsColor(80,120,200,0.125);Cls
  SetRenderImage(Null)
  TMax2DGraphics.selected.Resize(180,90)
  Local storage:TTextureData=ReadRenderTextureData(hdr)
  Local values:Float Ptr=Float Ptr(storage.Level().Data())
  Check(Abs(values[0]-80.0/255)<0.00001 And Abs(values[3]-0.125)<0.00001,"Float snapshot survives planned reset without alpha quantisation")
  EndGraphics
 Next
 Print "d3d9_effects_reset passed"
Catch error:Object
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
