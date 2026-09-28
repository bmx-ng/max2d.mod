SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11 And Not max2d_sdlgpu
Framework Max2D.SDL3RenderMax2D
?
Import BRL.StandardIO
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Function Pixel:Int(x:Int,y:Int)
 Return GrabPixmap(x,y,1,1).ReadPixel(0,0)&$ffffff
End Function
Try
 Graphics(160,120,0,0)
 Local target:TRenderImage=CreateRenderImage(128,128,0)
 SetRenderImage(target);SetClsColor(0,0,0)
 Local font:TImageFont=TImageFont.DefaultFont()
 Local prepared:TPreparedText=PrepareText("ABC DEF GHI",font)
 Local paragraph:TParagraphLayout=prepared.Layout(56,TEXT_ALIGN_RIGHT,20)
 SetRotation(90);SetScale(1,1);SetHandle(2,3);SetOrigin(5,7)
 TranslateCoordinates(4,3)
 Local camera:TCamera2D=New TCamera2D
 camera.zoom=1.1;SetCamera(camera)
 Cls();DrawTextLayout(paragraph,30,25)
 Local actual:TPixmap=ReadRenderImage(target)
 Cls()
 ' Independent reference: the second line is 32 units right and 20 down
 ' before the 90-degree object rotation, hence (-20,+32) at the draw origin.
 DrawTextLayout(font.Layout("ABC DEF"),30,25)
 DrawTextLayout(font.Layout("GHI"),10,57)
 Local expected:TPixmap=ReadRenderImage(target)
 Local lit:Int
 For Local y:Int=0 Until 128
  For Local x:Int=0 Until 128
   Check(actual.ReadPixel(x,y)=expected.ReadPixel(x,y),"Paragraph respects object, parent and camera transforms")
   If (actual.ReadPixel(x,y)&$ffffff)<>0 Then lit:+1
  Next
 Next
 Check(lit>20,"Paragraph renders visible glyphs")
 SetCamera(Null);ResetCoordinates();SetOrigin(0,0);SetHandle(0,0);SetTransform()
 Local boxed:TParagraphLayout=prepared.LayoutBox(56,16,TEXT_ALIGN_RIGHT)
 Cls();DrawTextLayout(boxed,4,4)
 actual=ReadRenderImage(target)
 Cls();DrawTextLayout(font.Layout("ABC..."),12,4)
 expected=ReadRenderImage(target)
 For Local y:Int=0 Until 128
  For Local x:Int=0 Until 128
   Check(actual.ReadPixel(x,y)=expected.ReadPixel(x,y),"Truncated line renders its shaped, aligned marker")
  Next
 Next
 Local bottomBox:TParagraphLayout=prepared.LayoutBox(56,80,TEXT_ALIGN_RIGHT,0,1,"...",TEXT_ALIGN_BOTTOM)
 Cls();DrawTextLayout(bottomBox,4,4)
 actual=ReadRenderImage(target)
 Cls();DrawTextLayout(font.Layout("ABC..."),12,68)
 expected=ReadRenderImage(target)
 For Local y:Int=0 Until 128
  For Local x:Int=0 Until 128
   Check(actual.ReadPixel(x,y)=expected.ReadPixel(x,y),"Bottom-aligned fitted text renders at the expected position")
  Next
 Next
 Local flows:Long=prepared.reflowBuilds,boxes:Long=prepared.boxBuilds
 Local builds:Long=font.layoutBuilds
 For Local i:Int=0 Until 100
  DrawTextLayout(paragraph,30,25)
  DrawTextLayout(boxed,4,4)
 Next
 Check(font.layoutBuilds=builds And prepared.reflowBuilds=flows And prepared.boxBuilds=boxes,"Repeated drawing does not rebuild text")
 EndGraphics()
 Print "Max2D paragraph rendering tests passed"
Catch error:Object
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
