SuperStrict
Framework Max2D.D3D11Max2D
Import BRL.StandardIO
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Function Pixel:Int(x:Int,y:Int)
 Return GrabPixmap(x,y,1,1).ReadPixel(0,0)&$ffffff
End Function
Try
 Check(Graphics(64,64,0,0)<>Null,"D3D11 graphics creation")
 Local image:TImage=CreateImage(3,2,1,DYNAMICIMAGE)
 Local p:TPixmap=LockImage(image)
 p.ClearPixels($ffffffff)
 p.WritePixel(0,0,$7fff0000);p.WritePixel(1,0,$8000ff00);p.WritePixel(2,0,$80ff0000)
 UnlockImage(image)
 SetClsColor(0,0,255);Cls;SetBlend(MASKBLEND);DrawImage(image,0,0)
 Check(Pixel(0,0)=$0000ff,"MASK rejects alpha127")
 Check(Pixel(1,0)=$00ff00,"MASK overwrites alpha128")
 SetAlpha(0.5);DrawImage(image,0,2)
 Check(Pixel(1,2)=$0000ff,"MASK includes drawing alpha")
 SetAlpha(1);SetBlend(SOLIDBLEND);DrawImage(image,0,4)
 Check(Pixel(0,4)=$ff0000,"SOLID ignores alpha")
 SetBlend(ALPHABLEND);SetClsColor(0,0,0);Cls;DrawImage(image,0,0)
 Check(Abs(((Pixel(2,0) Shr 16)&255)-128)<=1,"ALPHA once")
 SetBlend(LIGHTBLEND);DrawImage(image,0,0)
 Check(((Pixel(2,0) Shr 16)&255)>=254,"LIGHT adds")
 SetBlend(SHADEBLEND);DrawImage(image,0,0)
 Check(Pixel(1,0)=$008000 Or Pixel(1,0)=$00ff00,"SHADE channel multiplication")
 SetBlend(SOLIDBLEND);p=LockImage(image);p.WritePixel(2,1,$ff00ffff);UnlockImage(image)
 DrawImage(image,10,10)
 Check(Pixel(12,11)=$00ffff,"Dirty edit and non-power-of-two UV")
 ' Change synchronization to exercise both DXGI presentation modes.
 Flip(0)
 SetClsColor(0,0,0);Cls;DrawImage(image,10,10)
 Check(Pixel(12,11)=$00ffff,"Texture survives presentation")
 Flip(1)
 Cls;DrawImage(image,10,10)
 Check(Pixel(12,11)=$00ffff,"Texture survives second presentation")
 EndGraphics()
 Check(Graphics(64,64,0,0)<>Null,"D3D11 graphics creation")
 SetBlend(SOLIDBLEND);DrawImage(image,10,10)
 Check(Pixel(12,11)=$00ffff,"Reopen recreates native frame")
 EndGraphics()
 Print "Max2D D3D11 rendering tests passed"
Catch error:Object
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
