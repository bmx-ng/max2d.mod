SuperStrict
Framework Max2D.D3D11Max2D
Import BRL.StandardIO
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Function Pixel:Int(x:Int,y:Int)
 Return GrabPixmap(x,y,1,1).ReadPixel(0,0)
End Function
Try
 Graphics 64,64,0,0
 Local source:TRenderImage=CreateRenderImage(8,8,0)
 Local dest:TRenderImage=CreateRenderImage(8,8,0)
 SetRenderImage(source)
 SetClsColor(0,0,0,0); Cls
 SetColor(255,0,0); SetAlpha(0.5); DrawRect(0,0,8,4)
 SetColor(0,255,0); SetAlpha(1); DrawRect(0,4,8,4)
 SetRenderImage(dest)
 SetColor(255,255,255); SetBlend(SOLIDBLEND)
 DrawImage(source,0,0)
 Local p:TPixmap=ReadRenderImage(dest)
 Check((p.ReadPixel(2,1)&$ffffff)=$ff0000,"Target-to-target straight readback")
 Check(Abs(((p.ReadPixel(2,1) Shr 24)&255)-128)<=1,"Target-to-target alpha")
 Check(p.ReadPixel(2,6)=$ff00ff00,"Target orientation at lower edge")
 ' Read a different target, then continue writing to the selected one.
 p=ReadRenderImage(source)
 SetColor(0,0,255); DrawRect(0,0,1,1)
 p=ReadRenderImage(dest)
 Check(p.ReadPixel(0,0)=$ff0000ff,"Readback restores framebuffer binding")
 SetRenderImage(Null)
 SetColor(255,255,255); SetClsColor(0,0,0,1); Cls
 DrawImage(source,0,0)
 Check((Pixel(2,1)&$ffffff)=$ff0000,"SOLID unpremultiplies render target in shader")
 Check((Pixel(2,6)&$ffffff)=$00ff00,"Window target orientation")
 SetBlend(ALPHABLEND); Cls; DrawImage(source,0,0)
 Check(Abs(((Pixel(2,1) Shr 16)&255)-128)<=1,"ALPHA applies alpha once")
 SetBlend(LIGHTBLEND); Cls; DrawImage(source,0,0)
 Check(Abs(((Pixel(2,1) Shr 16)&255)-128)<=1,"LIGHT applies alpha once")
 SetClsColor(128,128,128); Cls; SetBlend(SHADEBLEND); DrawImage(source,0,0)
 Check(Abs(((Pixel(2,1) Shr 16)&255)-128)<=1 And (Pixel(2,1)&$ffff)=0,"SHADE uses straight source colour")
 Local mask:TImage=CreateImage(2,1,1,0)
 p=LockImage(mask);p.WritePixel(0,0,$40ff0000);p.WritePixel(1,0,$c000ff00);UnlockImage(mask)
 SetBlend(MASKBLEND);SetClsColor(0,0,255);Cls;DrawImage(mask,0,0)
 Check((Pixel(0,0)&$ffffff)=$0000ff,"MASK discards low alpha")
 Check((Pixel(1,0)&$ffffff)=$00ff00,"MASK writes high alpha")
 ' LIGHT preserves destination alpha; transparent pixels must not leak RGB.
 SetRenderImage(dest)
 SetClsColor(0,0,0,0);Cls
 SetColor(255,0,0);SetBlend(LIGHTBLEND);DrawRect(0,0,8,8)
 SetRenderImage(Null)
 SetBlend(SOLIDBLEND);SetColor(255,255,255);DrawImage(dest,0,0)
 Check((Pixel(0,0)&$ffffff)=0,"Zero-alpha target has zero straight RGB")
 SetRenderImage(source)
 SetBlend(ALPHABLEND)
 SetClsColor(40,80,120,0.5);Cls
 p=ReadRenderImage(source)
 Check(Abs(((p.ReadPixel(0,0) Shr 24)&255)-128)<=1,"Clear alpha")
 Check(Abs(((p.ReadPixel(0,0) Shr 16)&255)-40)<=1,"Premultiplied clear/readback")
 SetRenderImage(Null)
 Flip(0)
 p=ReadRenderImage(source)
 Check(Abs(((p.ReadPixel(0,0) Shr 16)&255)-40)<=1,"Presentation preserves render image contents")
 SetRenderImage(source)
 SetClsColor(0,255,255,1);Cls
 SetRenderImage(Null)
 SetColor(255,255,255);SetAlpha(1);SetBlend(SOLIDBLEND)
 DrawImage(source,0,0)
 Check((Pixel(0,0)&$ffffff)=$00ffff,"Render image redraw after presentation")
 ' Viewport clipping on the target and feedback rejection use the common API.
 SetRenderImage(dest)
 SetClsColor(0,0,0,0);Cls
 SetViewport(2,2,2,2)
 SetColor(255,0,255);DrawRect(0,0,8,8)
 p=ReadRenderImage(dest)
 Check(p.ReadPixel(1,1)=0 And p.ReadPixel(2,2)=$ffff00ff,"Target viewport clipping")
 Local rejected:Int
 Try
  DrawImage(dest,0,0)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,"Target feedback rejected")
 SetRenderImage(Null)
 SetViewport(0,0,8,8)
 ' A sampled image can become the destination on the next pass.
 SetRenderImage(source)
 SetColor(255,255,255);SetBlend(SOLIDBLEND);DrawImage(dest,0,0)
 p=ReadRenderImage(source)
 Check(p.ReadPixel(2,2)=$ffff00ff,"Sampled texture becomes target")
 SetRenderImage(Null)
 GraphicsResize(96,80)
 p=ReadRenderImage(source)
 Check(p.ReadPixel(2,2)=$ffff00ff,"Window resize preserves render image")
 ' Partial clear must preserve premultiplied alpha as well as its clip.
 SetRenderImage(dest)
 SetViewport(3,3,1,1);SetClsColor(40,80,120,0.5);Cls
 p=ReadRenderImage(dest)
 Check(Abs(((p.ReadPixel(3,3) Shr 24)&255)-128)<=1,"Clipped clear alpha")
 Check(Abs(((p.ReadPixel(3,3) Shr 16)&255)-40)<=1,"Clipped clear straight readback")
 Check(p.ReadPixel(2,2)=$ffff00ff,"Clipped clear preserves outside")
 SetRenderImage(Null)
 EndGraphics()
 Print "Max2D D3D11 target and blend tests passed"
Catch error:Object
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
