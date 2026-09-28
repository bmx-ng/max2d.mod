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
Import Max2D.LDTK
Import BRL.StandardIO
Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Function Pixel:Int(x:Int,y:Int)
	Return GrabPixmap(x,y,1,1).ReadPixel(0,0)&$ffffff
End Function
Try
	Local map:TLDTKMap=LoadLDTKMap(AppArgs[1]+"/single.ldtk","",0)
	Graphics 64,64
	Local target:TRenderImage=CreateRenderImage(64,64,0)
	SetRenderImage(target); SetClsColor(0,0,0); Cls()
	map.Draw()
	Local color:Int=Pixel(2,2)
	Check(Abs((color Shr 16)-127)<=1 And Abs((color&255)-128)<=1 And ((color Shr 8)&255)=0,"Stacked tiles and per-tile alpha")
	Check(Pixel(6,2)=$00ffff,"Combined horizontal/vertical flip")
	Check(Pixel(2,6)=$0000ff And Pixel(1,1)=0,"Auto-layer tiles and offsets")
	Check(map.drawnSprites=4,"Hidden artwork and entity geometry do not draw")
	Local c:Int,r:Int
	Check(map.Pick(8,12,c,r,0,0,map.Layer("Logic").layer) And c=1 And r=0,"Picking uses layer grid and offset")
	PushMax2DState()
	TranslateCoordinates(10,10)
	Cls(); map.Draw()
	Check(Pixel(16,12)=$00ffff And Pixel(6,2)=0,"Parent transforms and render target")
	Check(map.Pick(18,22,c,r,0,0,map.Layer("Logic").layer) And c=1 And r=0,"Transformed picking")
	PopMax2DState()
	map=LoadLDTKMap(AppArgs[1]+"/visuals.ldtk","",0)
	Cls(); map.Draw()
	DrawSubImageRect(map.background.image,20,40,12,4,0.5,0.5,3,1)
	Check(Pixel(22,5)=Pixel(22,41) And Pixel(26,5)=Pixel(26,41) And Pixel(19,5)=0,"Fractional background crop, scale and position")
	Local backgroundPixel:Int=Pixel(22,5),scaledPixel:Int=Pixel(17,9)
	Check(scaledPixel<>0 And Pixel(14,2)=$0000ff,"Scaled and unscaled parallax pixels")
	Local ox:Double,oy:Double
	map.LayerDrawOffset(map.Layer("Scaled").layer,ox,oy)
	Check(ox=17 And oy=9,"Scaled parallax includes scaled layer offset")
	Check(map.Pick(17.25,9.25,c,r,0,0,map.Layer("Scaled").layer) And c=0 And r=0,"Scaled parallax picking")
	Check(map.Pick(18.25,9.25,c,r,0,0,map.Layer("Scaled").layer) And c=1,"Scaled parallax cell boundary")
	Local camera:TCamera2D=New TCamera2D
	camera.x=40; camera.y=32; camera.offsetX=32; camera.offsetY=32
	SetCamera(camera); Cls(); map.Draw()
	Check(Pixel(13,9)=scaledPixel And Pixel(10,2)=$0000ff,"Camera pan moves parallax at matching rate")
	Check(map.Pick(13.25,9.25,c,r,0,0,map.Layer("Scaled").layer) And c=0 And r=0,"Panned parallax picking")
	SetCamera(Null)
	PushMax2DState(); TranslateCoordinates(4,6); Cls(); map.Draw()
	Check(Pixel(26,11)=backgroundPixel,"Background follows parent transform")
	PopMax2DState()
	map.background.visible=False; Cls(); map.Draw()
	Check(Pixel(22,5)=0,"Background visibility")
	map=LoadLDTKMap(AppArgs[1]+"/entity-art.ldtk","",0)
	Cls(); map.Draw()
	Check(Pixel(4,4)=$ff0000 And Pixel(10,4)=$ffffff,"Stretch artwork")
	Check(Pixel(16,4)=0 And Pixel(16,8)=$ff0000,"FitInside aligns artwork at entity pivot")
	Check(Pixel(28,4)=$0000ff And Pixel(30,4)=$ffffff,"Cover crops around pivot")
	Check(Pixel(36,4)=$ff00ff And Pixel(38,4)=0,"FullSizeCropped source and bounds")
	Check(Pixel(42,3)=$ff0000 And Pixel(44,3)=$0000ff,"FullSizeUncropped extends outside gameplay rectangle")
	Check(Pixel(4,20)=$ff0000 And Pixel(8,20)=$ff0000 And Pixel(10,22)=$0000ff And Pixel(11,20)=0,"Repeated entity partial edges")
	Local pixels:TPixmap=LoadPixmap(AppArgs[1]+"/art.png")
	Check(Pixel(16,20)=(pixels.ReadPixel(0,0)&$ffffff) And Pixel(23,20)=(pixels.ReadPixel(4,0)&$ffffff),"Nine-slice corners")
	Check(Pixel(17,21)=(pixels.ReadPixel(1,1)&$ffffff) And Pixel(20,24)=(pixels.ReadPixel(1,1)&$ffffff) And Pixel(22,25)=(pixels.ReadPixel(3,2)&$ffffff),"Nine-slice repeats centre and crops partial tiles")
	Local entity:TLDTKEntity=map.Entity("Stretch")
	entity.artwork.visible=False; Cls(); map.Draw()
	Check(Pixel(4,4)=0 And entity.layer.layer.QueryObjectsAtPoint(4,4).count=1,"Hide artwork without removing gameplay rectangle")
	entity.artwork.visible=True; entity.artwork.opacity=0.5; entity.object.opacity=0.5; entity.layer.layer.opacity=0.5
	SetAlpha(0.5); Cls(); map.Draw()
	Check(Abs((Pixel(4,4) Shr 16)-16)<=1 And GetAlpha()=0.5,"Artwork alpha multiplies caller/object/layer and restores state")
	SetAlpha(1)
	map=LoadLDTKMap(AppArgs[1]+"/repeat-background.ldtk","",0)
	SetClsColor(1,1,1); Cls(); map.Draw()
	Check(Pixel(0,0)=$00ffff And Pixel(6,4)=0 And Pixel(7,0)=$010101 And Pixel(0,5)=$010101,"Repeated background pivot and level clipping")
	Check(map.drawnImages=6,"Repeated background counts submitted pieces")
	PushMax2DState(); TranslateCoordinates(10,10); Cls(); map.Draw()
	Check(Pixel(10,10)=$00ffff And Pixel(17,10)=$010101,"Repeated background follows parent transform")
	PopMax2DState()
	map.level.width=1000000; map.level.height=1000000; Cls(); map.Draw()
	Check(map.drawnImages<=600,"Repeated backgrounds visit only visible tiles")
	SetRenderImage(Null); EndGraphics()
	Print "LDtk rendering tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
