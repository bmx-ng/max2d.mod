SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?max2d_gl
Framework Max2D.GLMax2D
?Not max2d_gl And Not max2d_sdlgpu
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.Atlas
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

Function CheckWindowMapping(pixelX:Float,pixelY:Float,expectedX:Float,expectedY:Float,message:String)
 Local inputWidth:Int,inputHeight:Int,x:Float,y:Float
 TMax2DGraphics.Current().context.NativeInputSize(inputWidth,inputHeight)
 WindowToVirtual(pixelX*inputWidth/NativeResolutionWidth(),pixelY*inputHeight/NativeResolutionHeight(),x,y)
 Check(Abs(x-expectedX)<0.001 And Abs(y-expectedY)<0.001,message)
End Function

Local graphics:TGraphics=Graphics(160,120,0,0)
?osx And max2d_gl
 max2d_test_gl_lowdpi()
 TMax2DGraphics.Current().context.ApplyView()
?
Check(graphics<>Null,"Create graphics")
Local outputWidth:Int=NativeResolutionWidth(),outputHeight:Int=NativeResolutionHeight()
Print "Integration drawable: "+outputWidth+"x"+outputHeight
' Pixel fixtures draw at 1:1; virtual presentation is tested explicitly below.
SetNativeResolution()
SetClsColor(0,0,0)
Cls()
Local atlas:TTextureAtlas=TTextureAtlas.Create(32,0)
Local p:TPixmap=CreatePixmap(4,4,PF_RGBA8888)
p.ClearPixels($ffff0000)
Local red:TImage=atlas.AddPixmap(p,"red")
p.ClearPixels($ff00ff00)
Local green:TImage=atlas.AddPixmap(p,"green")
Check(red.Frame()=green.Frame(),"Atlas views must share a texture")
SetColor(255,255,255)
Local before:Long=Max2DStats().submissions
DrawImage(red,0,0)
DrawImage(green,4,0)
FlushMax2D()
Check(Max2DStats().submissions=before+1,"Atlas sprites should batch")
Check((Pixel(1,1)&$ffffff)=$ff0000,"Red atlas region")
Check((Pixel(5,1)&$ffffff)=$00ff00,"Green atlas region")
Check(atlas.Page(0).sources[0].pixmap.ReadPixel(0,0)=$ffff0000,"Extruded padding")
Local frame:TImageFrame=red.Frame()
p.ClearPixels($ff0000ff)
atlas.AddPixmap(p,"blue")
Check(red.Frame()=frame,"Atlas insertion must preserve texture identity")

Print "Testing batch atlas"
Local builder:TAtlasBuilder=New TAtlasBuilder
builder.pageSize=32
For Local i:Int=0 Until 12
 builder.Add(p,"sprite"+i)
Next
Local packed:TTextureAtlas=builder.Build()
For Local i:Int=0 Until 12
 Check(packed.GetImage("sprite"+i)<>Null,"Batch pack must preserve every entry")
Next

Print "Testing dynamic images"
Local dynamic:TImage=CreateImage(4,4,1,DYNAMICIMAGE)
Local pixels:TPixmap=LockImage(dynamic)
pixels.ClearPixels($ffff0000)
UnlockImage(dynamic)
Local dynamicFrame:TImageFrame=dynamic.Frame()
DrawImage(dynamic,20,0)
pixels=LockImage(dynamic)
pixels.ClearPixels($ff00ff00)
UnlockImage(dynamic)
DrawImage(dynamic,24,0)
Check(dynamic.Frame()=dynamicFrame,"Image update must preserve frame")
Check((Pixel(21,1)&$ffffff)=$ff0000,"Queued draw must use old image pixels")
Check((Pixel(25,1)&$ffffff)=$00ff00,"Next draw must use updated image pixels")

Print "Testing render targets"
Local target:TRenderImage=CreateRenderImage(16,16,0)
SetRenderImage(target)
SetClsColor(0,0,0,0)
Cls()
SetColor(255,0,0)
SetAlpha(0.5)
DrawRect(0,0,16,16)
Print "Reading target"
Local readback:TPixmap=ReadRenderImage(target)
Local color:Int=readback.ReadPixel(8,8)
Check(((color Shr 16)&255)>=250,"Target readback must use straight RGB")
Check(Abs(((color Shr 24)&255)-127)<=1,"Target readback alpha")
SetRenderImage(Null)
SetClsColor(0,0,0)
Cls()
SetColor(255,255,255)
SetAlpha(1)
DrawImage(target,0,0)
Print "Reading composed target"
Check(Abs(((Pixel(8,8) Shr 16)&255)-127)<=2,"Target composition must not multiply alpha twice")

Print "Testing letterboxing"
SetVirtualResolution(160,90,VIRTUAL_LETTERBOX)
SetClsColor(10,20,30)
Cls()
Local nx:Float,ny:Float
VirtualToNative(0,0,nx,ny)
Local letterboxTop:Int=(outputHeight-Int(outputWidth*90.0/160))/2
Check(nx=0 And ny=letterboxTop,"Letterbox offset")
PushMax2DState()
SetNativeResolution()
Check((Pixel(0,0)&$ffffff)=0,"Letterbox top bar")
Check((Pixel(0,letterboxTop+1)&$ffffff)=$0a141e,"Letterbox content")
DrawText("Hello",10,20)
PopMax2DState()
Check(VirtualResolutionHeight()=90,"Restore virtual view")
Local font:TImageFont=GetImageFont()
Local layout:TTextLayout=CreateTextLayout("Hello")
Check(layout=CreateTextLayout("Hello"),"Text layout cache")
Check(TextWidth("Hello")=40,"Shared text metrics")
Check(font.atlas.PageCount()=1,"Bitmap font glyphs share one atlas page")
Print "Testing editable atlas borders"
SetNativeResolution()
SetClsColor(0,0,0); Cls()
p.ClearPixels($ffffff00)
DrawImage(red,0,0)
atlas.UpdatePixmap("red",p)
DrawImage(red,4,0)
Check((Pixel(1,1)&$ffffff)=$ff0000,"Atlas update preserves queued pixels")
Check((Pixel(5,1)&$ffffff)=$ffff00,"Atlas update changes existing view")
Check(red.Frame()=frame,"Atlas update retains texture")
Check(atlas.Page(0).sources[0].pixmap.ReadPixel(0,0)=$ffffff00,"Atlas update refreshes padding")
Local dynamicAtlas:TTextureAtlas=TTextureAtlas.Create(32,DYNAMICIMAGE|FILTEREDIMAGE)
Local editable:TImage=dynamicAtlas.AddPixmap(p,"editable")
Local corner:TImage=CreateImageView(editable,0,0,1,1)
Local cornerPixels:TPixmap=LockImage(corner)
cornerPixels.WritePixel(0,0,$ff00ffff)
UnlockImage(corner)
Check(dynamicAtlas.Page(0).sources[0].pixmap.ReadPixel(0,0)=$ff00ffff,"Subview write refreshes atlas corner")
Local sheet:TPixmap=CreatePixmap(8,4,PF_RGBA8888)
sheet.ClearPixels($ffff0000)
p.ClearPixels($ff00ff00); sheet.Paste(p,4,0)
Local animation:TImage=LoadAnimImage(sheet,4,4,0,2,FILTEREDIMAGE|DYNAMICIMAGE)
Check(animation.Frame(0)=animation.Frame(1),"Padded animation frames share a page")
Check(animation.sourceX[0]>0,"Filtered animation has a border")
Local animPixels:TPixmap=LockImage(animation,0)
animPixels.ClearPixels($ff0000ff); UnlockImage(animation,0)
Check(animation.sources[0].pixmap.ReadPixel(animation.sourceX[0]-1,animation.sourceY[0])=$ff0000ff,"Animation edits update borders")
DrawImageRect(animation,0,20,40,40,0)
Check((Pixel(39,40)&$ffffff)=$0000ff,"Filtered frame edge must not bleed adjacent green")

Print "Testing scaled presentation"
SetVirtualResolution(50,30,VIRTUAL_INTEGER)
SetVirtualBarColor(1,2,3)
SetClsColor(10,20,30); Cls()
VirtualToNative(0,0,nx,ny)
Local integerScale:Int=Min(outputWidth/50,outputHeight/30)
Local integerLeft:Int=(outputWidth-50*integerScale)/2,integerTop:Int=(outputHeight-30*integerScale)/2
Check(nx=integerLeft And ny=integerTop,"Integer presentation offsets")
VirtualToNative(1,1,nx,ny)
Check(nx=integerLeft+integerScale And ny=integerTop+integerScale,"Integer presentation scale")
If integerLeft>0 Then Check((Pixel(integerLeft-1,integerTop+1)&$ffffff)=$010203,"Integer left bar")
Check((Pixel(integerLeft,integerTop)&$ffffff)=$0a141e,"Integer content origin")
Check((Pixel(integerLeft+50*integerScale-1,integerTop+30*integerScale-1)&$ffffff)=$0a141e,"Integer content extent")
If integerLeft+50*integerScale<outputWidth Then Check((Pixel(integerLeft+50*integerScale,integerTop+30*integerScale-1)&$ffffff)=$010203,"Integer right bar")
SetColor(255,0,0); DrawRect(0,0,1,1)
Check((Pixel(integerLeft+integerScale-1,integerTop+integerScale-1)&$ffffff)=$ff0000,"Integer geometry scaling")
Check((Pixel(integerLeft+integerScale,integerTop+integerScale-1)&$ffffff)=$0a141e,"Integer geometry boundary")
CheckWindowMapping(integerLeft+integerScale,integerTop+integerScale,1,1,"Integer mouse mapping")
PushMax2DState()
SetVirtualBarColor(9,9,9)
SetNativeResolution()
PopMax2DState()
Local br:Int,bg:Int,bb:Int
GetVirtualBarColor(br,bg,bb)
Check(br=1 And bg=2 And bb=3,"Bar color state restoration")
SetVirtualResolution(100,50,VIRTUAL_LETTERBOX)
Cls()
VirtualToNative(0,0,nx,ny)
Local fractionalScale:Float=outputWidth/100.0
Local fractionalTop:Int=(outputHeight-Int(50*fractionalScale))/2
Check(nx=0 And ny=fractionalTop,"Fractional presentation offsets")
Check((Pixel(0,fractionalTop-1)&$ffffff)=$010203,"Fractional top bar")
Check((Pixel(0,fractionalTop)&$ffffff)=$0a141e,"Fractional content origin")
SetViewport(10,5,10,10)
DrawRect(0,0,100,50)
Check((Pixel(Int(Ceil(10*fractionalScale))-1,fractionalTop+Int(10*fractionalScale))&$ffffff)=$0a141e,"Fractional clip left")
Check((Pixel(Int(Ceil(10*fractionalScale)),fractionalTop+Int(10*fractionalScale))&$ffffff)=$ff0000,"Fractional clip inside")
Check((Pixel(Int(Ceil(20*fractionalScale)),fractionalTop+Int(10*fractionalScale))&$ffffff)=$0a141e,"Fractional clip right")
SetViewport(1,1,0,20)
DrawRect(0,0,100,50)
Check((Pixel(1,fractionalTop+Int(10*fractionalScale))&$ffffff)=$0a141e,"Zero-width fractional viewport remains empty")
SetNativeResolution()
SetVirtualResolution(outputWidth*2,outputHeight*2,VIRTUAL_INTEGER)
VirtualToNative(outputWidth*2,outputHeight*2,nx,ny)
Check(nx=outputWidth And ny=outputHeight,"Integer mode falls back to fractional fit below 1x")

If graphics.Driver().CanResize() Then
Print "Testing window resize"
SetVirtualResolution(50,30,VIRTUAL_INTEGER)
GraphicsResize(200,140)
PollSystem()
Cls()
Check(GraphicsWidth()=200 And GraphicsHeight()=140,"Resize changes logical window dimensions")
Check(NativeResolutionWidth()=outputWidth*200/160 And NativeResolutionHeight()=outputHeight*140/120,"Resize retains drawable density")
Local resizedScale:Int=Min(NativeResolutionWidth()/50,NativeResolutionHeight()/30)
Local resizedLeft:Int=(NativeResolutionWidth()-50*resizedScale)/2,resizedTop:Int=(NativeResolutionHeight()-30*resizedScale)/2
VirtualToNative(0,0,nx,ny)
Check(nx=resizedLeft And ny=resizedTop,"Resize recomputes integer presentation")
CheckWindowMapping(resizedLeft+resizedScale,resizedTop+resizedScale,1,1,"Resized input mapping")
GraphicsResize(160,120)
PollSystem()
Cls()
Check(NativeResolutionWidth()=outputWidth And NativeResolutionHeight()=outputHeight,"Resize restores drawable dimensions")

End If

Print "Testing context ownership"
SetNativeResolution()
SetColor(255,255,255)
Local second:TGraphics=CreateGraphics(80,60,0,0,0,-1,-1)
Check(second<>Null,"Second context creation")
SetGraphics(second)
?osx And max2d_gl
 max2d_test_gl_lowdpi()
 TMax2DGraphics.Current().context.ApplyView()
?
SetNativeResolution()
Local secondFrame:TImageFrame=red.Frame()
Check(secondFrame<>frame,"Contexts must own distinct textures")
SetClsColor(0,0,0); Cls()
DrawImage(red,0,0)
Check((Pixel(1,1)&$ffffff)=$ffff00,"Second context uploads current pixels")
p.ClearPixels($ff00ffff)
atlas.UpdatePixmap("red",p)
DrawImage(red,4,0)
Check((Pixel(5,1)&$ffffff)=$00ffff,"Second context updates")
Local rejected:Int=False
Try
 SetRenderImage(target)
Catch error:Object
 rejected=True
End Try
Check(rejected,"Cross-context render image must be rejected")
SetGraphics(graphics)
?osx And max2d_gl
 max2d_test_gl_lowdpi()
 TMax2DGraphics.Current().context.ApplyView()
?
Cls()
DrawImage(red,0,0)
Check((Pixel(1,1)&$ffffff)=$00ffff,"First context catches up independently")
CloseGraphics(second)
Check(secondFrame.closed And Not frame.closed,"Closing one context preserves another's resources")
Check(red.Frame()=frame,"First context retains original frame")
SetRenderImage(target)
rejected=False
Try
 DrawImage(target,0,0)
Catch error:Object
 rejected=True
End Try
Check(rejected,"Render target feedback must be rejected")
SetRenderImage(Null)
Print "Testing captured input and draw transforms"
SetNativeResolution()
PushMax2DState()
SetVirtualResolution(50,30,VIRTUAL_INTEGER)
Local sceneInput:TMax2DInputMapping=CaptureWindowInput()
SetNativeResolution()
Local inputWidth:Int,inputHeight:Int
TMax2DGraphics.Current().context.NativeInputSize(inputWidth,inputHeight)
Check(sceneInput.WindowToVirtual(Float(integerLeft+integerScale)*inputWidth/outputWidth,Float(integerTop+integerScale)*inputHeight/outputHeight,nx,ny),"Captured scene mapping survives native overlay")
Check(Abs(nx-1)<0.001 And Abs(ny-1)<0.001,"Captured scene coordinates")
Check(Not sceneInput.WindowToVirtual(0,0,nx,ny),"Captured mapping rejects bars")
PopMax2DState()
PushMax2DState()
SetClsColor(0,0,0); Cls()
SetOrigin(5,7); SetHandle(4,6); SetTransform(90,2,-3)
Local drawTransform:TMax2DDrawTransform=CaptureDrawTransform(100,50)
SetColor(255,0,0); DrawRect(100,50,10,10)
Check((Pixel(111,59)&$ffffff)=$ff0000,"Transformed hit location corresponds to drawn geometry")
Check(drawTransform.VirtualToLocal(111,59,nx,ny),"Captured primitive transform")
Check(Abs(nx-5)<0.001 And Abs(ny-8)<0.001,"Inverse agrees with primitive drawing")
SetImageHandle(red,2,1)
Local imageTransform:TMax2DDrawTransform=CaptureImageTransform(red,100,50)
imageTransform.LocalToVirtual(2,1,nx,ny)
Check(nx=105 And ny=57,"Image mapping uses image handle, not primitive handle")
SetImageHandle(red,0,0)
PopMax2DState()
Print "Testing reselection"
SetGraphics(graphics)
?osx And max2d_gl
 max2d_test_gl_lowdpi()
 TMax2DGraphics.Current().context.ApplyView()
?
Flip(0)
EndGraphics()
Print "Max2D integration tests passed"
