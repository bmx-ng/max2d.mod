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
Import Max2D.Tiled
Import BRL.StandardIO
Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Function Pixel:Int(x:Int,y:Int)
	Return GrabPixmap(x,y,1,1).ReadPixel(0,0)&$ffffff
End Function
Try
	If AppArgs.Length<2 Then Throw "Pass the tests/data/tiled directory"
	Graphics 64,64,0,0
	Local target:TRenderImage=CreateRenderImage(32,32,0)
	SetRenderImage(target); SetClsColor(0,0,0); SetBlend(ALPHABLEND)
	Local map:TTiledMap=TTiledMap(LoadTileMap(AppArgs[1]+"/zlib.tmx",0))
	Cls(); map.Draw(8,8)
	Check(Pixel(8,8)=$ff0000 And Pixel(9,8)=$00ff00,"Tilesheet margin/spacing")
	Check(Pixel(10,8)=$00ff00 And Pixel(11,8)=$ff0000,"Imported horizontal flip")
	Check(Pixel(8,10)=$0000ff And Pixel(10,10)=$ffff00,"Imported vertical and combined flips")
	map.layers[0].Clear(); map.layers[0].SetCell(0,0,map.importedTilesets[0].NativeID(1))
	Cls(); map.Draw(8,8,0)
	Check(Pixel(8,8)=$ff0000,"Animation first frame")
	Cls(); map.Draw(8,8,100)
	Check(Pixel(8,8)=$00ffff,"Animation second frame")
	map=TTiledMap(LoadTileMap(AppArgs[1]+"/iso.tmx",0))
	map.layers[0].Clear(); map.layers[0].SetCell(0,0,1)
	Cls(); map.Draw(8,8)
	Check(Pixel(9,8)=$ff0000 And Pixel(8,8)=0,"Imported isometric origin alignment")
	map=LoadTiledMap(AppArgs[1]+"/objects-render.tmx",0)
	Cls(); map.Draw()
	Check(Pixel(5,6)=$ff0000 And Pixel(9,6)=$00ff00,"Scaled tile object")
	Check(Pixel(15,6)=$00ff00 And Pixel(19,6)=$ff0000,"Flipped tile object")
	Check(Pixel(29,14)=$ff0000 And Pixel(25,14)=$0000ff,"Rotated tile object")
	Cls(); map.Draw(0,0,100)
	Check(Pixel(5,16)=$00ffff,"Animated tile object")
	Local layer:TTileLayer=map.layers[0]
	layer.objects[1].x=layer.objects[0].x; layer.objects[1].y=layer.objects[0].y
	layer.objects[0].sortY=20; layer.objects[1].sortY=10
	Cls(); map.Draw()
	Check(Pixel(5,6)=$00ff00,"Object index order")
	layer.objectTopDown=True
	Cls(); map.Draw()
	Check(Pixel(5,6)=$ff0000,"Object top-down order")
	layer.objects[0].visible=False
	Cls(); map.Draw()
	Check(Pixel(5,6)=$00ff00,"Hidden tile objects")
	Local obj:TTileObject=layer.objects[1]
	layer.objects=[obj]; layer.offsetX=0; layer.offsetY=0
	obj.x=4; obj.y=10; obj.width=8; obj.height=4; obj.flip=ETileFlip.Diagonal
	Cls(); map.Draw()
	Check(Pixel(5,7)=$ff0000 And Pixel(7,7)=$0000ff And Pixel(5,11)=$00ff00,"Nonuniform tile object diagonal after sizing")
	Local pose:STileObjectInstance=obj.Instance(),l:Double,t:Double,r:Double,b:Double
	pose.Bounds(l,t,r,b)
	Check(l=4 And r=8 And t=6 And b=14,"Tile object picking bounds follow diagonal artwork")
	map=LoadTiledMap(AppArgs[1]+"/layer-fx.tmx",0); layer=map.layers[0]
	Check(map.parallaxOriginX=8 And layer.parallaxX=0.25 And layer.offsetX=6 And layer.offsetY=4,"Image layer origin, group offsets and parallax inheritance")
	Check(Abs(layer.tintRed-0.251965)<0.0001 And Abs(layer.tintAlpha-0.251965)<0.0001 And layer.opacity=0.25,"Nested tint and opacity")
	Cls(); map.Draw()
	Local color:Int=Pixel(12,4)
	Check(Abs(((color Shr 16)&255)-4)<=1 And Abs(((color Shr 8)&255)-16)<=1 And Abs((color&255)-8)<=1,"Image tint and alpha multiplication")
	layer.tintRed=1; layer.tintGreen=1; layer.tintBlue=1; layer.tintAlpha=1; layer.opacity=1
	Local camera:TCamera2D=New TCamera2D
	camera.x=24; camera.y=16; camera.offsetX=16; camera.offsetY=16
	SetCamera(camera); Cls(); map.Draw()
	Check(Pixel(10,4)=$ffffff And Pixel(12,4)=0,"Parallax camera movement")
	Local lx:Float,ly:Float
	Check(map.VirtualToLayer(layer,10.5,4.5,lx,ly) And Abs(lx-0.5)<0.001 And Abs(ly-0.5)<0.001,"Parallax coordinate conversion")
	SetCamera(Null); layer.parallaxX=1; layer.offsetX=0; layer.offsetY=0; layer.repeatX=True; layer.repeatY=True
	SetViewport(3,5,8,9); Cls(); map.Draw()
	Check(Pixel(3,5)=$ffffff And Pixel(10,13)=$ffffff And Pixel(2,5)=0,"Repeated image covers offset viewport")
	Check(map.drawnImages=25,"Only visible image copies submitted")
	SetViewport(0,0,32,32)
	camera.x=-8; camera.y=-8; camera.rotation=30; camera.zoom=2
	SetCamera(camera); Cls(); map.Draw()
	Check(Pixel(16,16)=$ffffff,"Repeat under negative camera position, zoom and rotation")
	SetCamera(Null); layer.repeatX=False; layer.repeatY=False
	SetColor(New SColor8(255,255,255,128),0.5); Cls(); map.Draw()
	Check(Abs((Pixel(0,0)&255)-128)<=1 And TMax2DGraphics.Current().state.colorByteAlpha=128,"Caller colour alpha retained: pixel="+(Pixel(0,0)&255)+" alpha="+TMax2DGraphics.Current().state.colorByteAlpha)
	SetColor(255,255,255); SetAlpha(1)
	map=LoadTiledMap(AppArgs[1]+"/subrect.tmx",0)
	Cls(); map.Draw(4,4)
	Check(Pixel(4,4)=$00ff00,"Tileset image subrectangle")
	map=LoadTiledMap(AppArgs[1]+"/template-auto.tmx",0)
	Cls(); map.Draw()
	Check(Pixel(1,1)=$00ff00 And Pixel(6,1)=$ff0000,"Template-only tileset and inherited horizontal flip")
	map=LoadTiledMap(AppArgs[1]+"/json-csv.tmj",0)
	Cls(); map.Draw()
	Check(Pixel(0,0)=$ff0000 And Pixel(2,0)=$00ff00,"JSON tile array and TSJ pixels")
	map=LoadTiledMap(AppArgs[1]+"/json-layer-fx.tmj",0)
	Cls(); map.Draw()
	color=Pixel(12,4)
	Check(Abs(((color Shr 16)&255)-4)<=1 And Abs(((color Shr 8)&255)-16)<=1 And Abs((color&255)-8)<=1,"JSON image layer tint and parallax pixels")
	SetRenderImage(Null); EndGraphics()
	Print "Tiled rendering tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
