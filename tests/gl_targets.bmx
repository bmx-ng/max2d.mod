SuperStrict
Framework Max2D.GLMax2D
Import BRL.StandardIO
?osx
Import "gl_hidpi_mode.m"
Extern "C"
 Function max2d_test_gl_lowdpi()
End Extern
?
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Function Pixel:Int(x:Int,y:Int)
 Return GrabPixmap(x,y,1,1).ReadPixel(0,0)
End Function
Try
 Local a:TGraphics=Graphics(64,64,0,0)
?osx
 max2d_test_gl_lowdpi()
 TMax2DGraphics.Current().context.ApplyView()
?
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
 ' Closing a non-current window must destroy resources in their own context
 ' and leave the selected window usable.
 Local b:TGraphics=CreateGraphics(64,64,0,0,0,-1,-1)
 SetGraphics(b);DrawImage(mask,0,0);FlushMax2D()
?osx
 max2d_test_gl_lowdpi()
 TMax2DGraphics.Current().context.ApplyView()
?
 a.Close()
 SetColor(255,0,255);DrawRect(20,20,4,4)
 Check((Pixel(21,21)&$ffffff)=$ff00ff,"Closing another context preserves selected context")
 b.Close()
 Print "Max2D OpenGL target and blend tests passed"
Catch error:Object
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
