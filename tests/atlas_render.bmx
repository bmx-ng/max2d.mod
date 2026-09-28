SuperStrict
Framework Max2D.SDL3RenderMax2D
Import Max2D.AtlasIO
Import BRL.StandardIO

Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Function Pixel:Int(x:Int,y:Int)
 Return GrabPixmap(x,y,1,1).ReadPixel(0,0)
End Function
If AppArgs.Length<>2 Then Throw "Supply the package produced by atlas_io.bmx"
Local atlas:TTextureAtlas=LoadTextureAtlas(AppArgs[1])
Local graphics:TGraphics=Graphics(80,60,0,0)
Check(graphics<>Null,"Graphics creation")
SetClsColor(0,0,0); Cls()
Local green:TImage=atlas.GetImage("green")
SetImageHandle(green,0,0)
DrawImage(green,0,0)
Local pixels:TPixmap=CreatePixmap(8,8,PF_RGBA8888)
pixels.ClearPixels($ff0000ff)
Local frame:TImageFrame=green.Frame()
atlas.UpdatePixmap("green",pixels)
DrawImage(green,10,0)
DrawImage(atlas.GetImage("hero / Ω ~qtest~q"),20,0)
Check((Pixel(2,2)&$ffffff)=$00ff00,"Loaded image before update")
Check((Pixel(12,2)&$ffffff)=$0000ff,"Loaded image after update")
Check(green.Frame()=frame,"Loaded page texture remains stable")
Check(Abs(((Pixel(22,2) Shr 16)&255)-128)<=2,"Loaded PNG alpha")
EndGraphics()
Print "Max2D loaded atlas rendering tests passed"
