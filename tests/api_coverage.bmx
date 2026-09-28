SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
?Not max2d_gl
Framework Max2D.SDL3RenderMax2D
?
Import BRL.StandardIO
?osx And max2d_gl
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
Local graphics:TGraphics=Graphics(160,120,0,0)
?osx And max2d_gl
 max2d_test_gl_lowdpi()
 TMax2DGraphics.Current().context.ApplyView()
?
Check(graphics<>Null,"Create graphics")
Local d:Double=Cos(0)
SetAlpha(d); SetLineWidth(d)
SetOrigin(d,d); SetHandle(d,d)
SetRotation(d); SetScale(d,d); SetTransform(d,d,d)
SetVirtualResolution(160:Double,120:Double)
SetTransform(); SetOrigin(0,0); SetHandle(0,0)
Cls()
Plot(d,d); DrawRect(d,d,4:Double,4:Double)
DrawLine(d,d,10:Double,10:Double)
DrawOval(d,d,8:Double,8:Double)
DrawText("Double coordinates",d,20:Double)
Local image:TImage=CreateImage(4,4,1,0)
SetImageHandle(image,d,d)
ClearImage(image,New SColor8(10,20,30,128))
Local p:TPixmap=LockImage(image,0,True,False)
Check(p.ReadPixel(0,0)=$800a141e,"RGBA ClearImage overload")
UnlockImage(image)
DrawImage(image,d,d)
DrawImageRect(image,d,d,4:Double,4:Double)
DrawSubImageRect(image,d,d,4:Double,4:Double,0:Double,0:Double,4:Double,4:Double)
TileImage(image,d,d)
' Compile cursor-warp overload without moving the user's mouse.
If False Then MoveVirtualMouse(d,d)
ShowMouse(); HideMouse(); ShowMouse()
SetColor(New SColor8(11,22,33,99),0.25)
Local color:SColor8,alpha:Float
GetColor(color,alpha)
Check(color.r=11 And color.g=22 And color.b=33 And color.a=99 And alpha=0.25,"Color and alpha overload")
SetClsColor(New SColor8(44,55,66,88),0.5)
GetClsColor(color,alpha)
Check(color.r=44 And color.g=55 And color.b=66 And color.a=88 And alpha=0.5,"Clear color and alpha overload")

Print "Testing physical pixel transfers"
SetVirtualResolution(40,20,VIRTUAL_LETTERBOX)
SetClsColor(0,0,0); Cls()
SetViewport(2,2,1,1)
SetOrigin(99,88); SetHandle(7,8); SetTransform(45,2,3)
SetColor(0,255,0); SetAlpha(0.2); SetBlend(LIGHTBLEND)
p=CreatePixmap(2,2,PF_RGBA8888); p.ClearPixels($ffff0000)
DrawPixmap(p,3,4)
Check((Pixel(3,4)&$ffffff)=$ff0000,"DrawPixmap uses output pixels even in bars")
Check((Pixel(4,5)&$ffffff)=$ff0000,"DrawPixmap pixel dimensions")
Check((Pixel(5,5)&$ffffff)=0,"DrawPixmap is not virtually scaled")
Check(VirtualResolutionWidth()=40 And GetBlend()=LIGHTBLEND And Abs(GetAlpha()-0.2)<0.0001,"Pixel transfer preserves state")
Local vx:Int,vy:Int,vw:Int,vh:Int
GetViewport(vx,vy,vw,vh)
Check(vx=2 And vy=2 And vw=1 And vh=1,"Pixel transfer restores clip")
Local grabbed:TImage=CreateImage(2,2,1,0)
GrabImage(grabbed,3,4)
p=LockImage(grabbed,0,True,False)
Check(p.ReadPixel(1,1)=$ffff0000,"GrabImage matches physical DrawPixmap")
UnlockImage(grabbed)

Print "Testing render-image defaults and clearing"
AutoImageFlags(0); AutoMidHandle(True)
Local target:TRenderImage=CreateRenderImage(12,8)
Check(target.flags=0 And target.handle_x=6 And target.handle_y=4,"Render images follow automatic flags and handles")
AutoMidHandle(False); AutoImageFlags(MASKEDIMAGE|FILTEREDIMAGE)
SetRenderImage(target)
SetVirtualResolution(3,2,VIRTUAL_INTEGER)
SetViewport(1,0,1,1)
SetRenderImage(Null)
ClearImage(target,New SColor8(0,255,0,128))
p=ReadRenderImage(target)
For Local y:Int=0 Until 8
 For Local x:Int=0 Until 12
  Local pixel:Int=p.ReadPixel(x,y)
  Check(((pixel Shr 8)&255)=255 And Abs(((pixel Shr 24)&255)-128)<=1,"ClearImage clears full render image")
 Next
Next
Check(VirtualResolutionWidth()=40,"ClearImage restores original target view")
SetRenderImage(target)
Check(VirtualResolutionWidth()=3,"ClearImage preserves cleared image's virtual view")
GetViewport(vx,vy,vw,vh)
Check(vx=1 And vy=0 And vw=1 And vh=1,"ClearImage preserves cleared image's clip")
ClearImage(target,New SColor8(0,0,255,255))
Check(VirtualResolutionWidth()=3,"Clearing selected render image restores its view")
p=ReadRenderImage(target)
Check(p.ReadPixel(0,7)=$ff0000ff,"Selected image full clear")
SetRenderImage(Null)
EndGraphics()
Print "Max2D API coverage tests passed"
