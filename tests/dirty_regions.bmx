SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?max2d_gl
Framework Max2D.GLMax2D
?Not max2d_gl And Not max2d_sdlgpu
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
Try
 Local a:TGraphics=Graphics(80,40,0,0)
?osx And max2d_gl
 max2d_test_gl_lowdpi()
 TMax2DGraphics.Current().context.ApplyView()
?
 SetNativeResolution()
 Local atlas:TTextureAtlas=TTextureAtlas.Create(512,DYNAMICIMAGE|FILTEREDIMAGE)
 Local p:TPixmap=CreatePixmap(16,16,PF_RGBA8888)
 p.ClearPixels($ffffffff)
 Local left:TImage=atlas.AddPixmap(p,"left")
 Local right:TImage=atlas.AddPixmap(p,"right")
 DrawImage(left,0,0); FlushMax2D()
 Local statsA:TMax2DStats=Max2DStats(),beforeA:Long=statsA.uploadedPixels
 Local b:TGraphics=CreateGraphics(80,40,0,0,0,-1,-1)
 SetGraphics(b)
?osx And max2d_gl
 max2d_test_gl_lowdpi()
 TMax2DGraphics.Current().context.ApplyView()
?
 SetNativeResolution()
 DrawImage(left,0,0); FlushMax2D()
 Local statsB:TMax2DStats=Max2DStats(),beforeB:Long=statsB.uploadedPixels
 p.ClearPixels($ffff0000); atlas.UpdatePixmap("left",p)
 p.ClearPixels($ff00ff00); atlas.UpdatePixmap("right",p)
 SetGraphics(a)
?osx And max2d_gl
 max2d_test_gl_lowdpi()
 TMax2DGraphics.Current().context.ApplyView()
?
 DrawImage(left,0,0); DrawImage(right,20,0); FlushMax2D()
 Check(statsA.uploadedPixels-beforeA=36*18,"Two edits upload their padded union")
 p.ClearPixels($ff0000ff); atlas.UpdatePixmap("left",p)
 SetGraphics(b)
?osx And max2d_gl
 max2d_test_gl_lowdpi()
 TMax2DGraphics.Current().context.ApplyView()
?
 DrawImage(left,0,0); DrawImage(right,20,0)
 Local pixels:TPixmap=GrabPixmap(0,0,40,20)
 Check(statsB.uploadedPixels-beforeB=36*18,"Lagging context retains all pending edits")
 Check((pixels.ReadPixel(8,8)&$ffffff)=$0000ff,"Latest left pixel")
 Check((pixels.ReadPixel(28,8)&$ffffff)=$00ff00,"Earlier right edit survives")
 SetGraphics(a)
?osx And max2d_gl
 max2d_test_gl_lowdpi()
 TMax2DGraphics.Current().context.ApplyView()
?
 beforeA=statsA.uploadedPixels
 DrawImage(left,0,0); FlushMax2D()
 Check(statsA.uploadedPixels-beforeA=18*18,"Current context uploads only its remaining edit")
 b.Close(); a.Close()
 Print "Max2D dirty region tests passed"
Catch error:Object
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
