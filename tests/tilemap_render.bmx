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
Import Max2D.TileMap
Import BRL.StandardIO

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Function Pixel:Int(x:Int,y:Int)
	Return GrabPixmap(x,y,1,1).ReadPixel(0,0)&$ffffff
End Function
Function Solid:TImage(w:Int,h:Int,color:Int)
	Local p:TPixmap=CreatePixmap(w,h,PF_RGBA8888)
	p.ClearPixels(color)
	Return TImage.FromPixmap(p)
End Function
Try
	Local graphics:TGraphics=Graphics(128,96,0,0)
	Check(graphics<>Null,"Graphics creation")
	Local target:TRenderImage=CreateRenderImage(128,96,0)
	SetRenderImage(target)
	SetClsColor(0,0,0); SetBlend(ALPHABLEND)
	Local tiles:TTileSet=New TTileSet
	Local red:Int=tiles.Add(Solid(16,16,$ffff0000))
	Local green:Int=tiles.Add(Solid(16,16,$ff00ff00))
	Local blue:Int=tiles.Add(Solid(16,80,$ff0000ff),0,0,-64)
	Local anim:TImage=TImage.Animation([Solid(16,16,$ffff0000),Solid(16,16,$ff00ff00)],[100,200])
	Local moving:Int=tiles.AddAnimation(anim)
	Local p:TPixmap=CreatePixmap(16,16,PF_RGBA8888)
	p.ClearPixels(0)
	For Local y:Int=2 Until 6
		For Local x:Int=1 Until 5
			p.WritePixel(x,y,$ffffffff)
		Next
	Next
	Local atlas:TTextureAtlas=TTextureAtlas.Create(32,0)
	Local image:TImage=atlas.AddPixmap(p,"trim",True)
	SetImageHandle(image,99,99)
	Local trimmed:Int=tiles.Add(image)
	Local map:TTileMap=TTileMap.Create(TTileGrid.Rectangular(16,16),tiles)
	Local layer:TTileLayer=map.AddLayer()
	layer.SetCell(0,0,red); layer.SetCell(2,1,green)
	layer.SetCell(100000,100000,red)
	Cls(); map.Draw(8,4)
	Check(Pixel(9,5)=$ff0000 And Pixel(41,21)=$00ff00,"Rectangular drawing")
	Check(map.drawnTiles=2 And map.chunkLookups<40,"Visible chunk queries exclude distant tiles")
	layer.SetCell(0,0,moving)
	Cls(); map.Draw(8,4,100)
	Check(Pixel(9,5)=$00ff00,"Shared animation clock")
	layer.Clear(); layer.SetCell(0,4,blue)
	Cls(); map.Draw()
	Check(Pixel(2,2)=$0000ff,"Tall artwork drawn when its cell is outside the viewport region it covers")
	layer.Clear(); layer.SetCell(0,0,trimmed,ETileFlip.Horizontal|ETileFlip.Vertical)
	Cls(); map.Draw()
	Check(Pixel(12,12)=$ffffff And Pixel(2,3)=0,"Trimmed artwork flips around original canvas; image handles ignored")
	layer.Clear(); layer.SetCell(1,1,red)
	Local upper:TTileLayer=map.AddLayer()
	upper.SetCell(1,1,green); upper.opacity=0.5
	Cls(); map.Draw()
	Local color:Int=Pixel(18,18)
	Check(Abs(((color Shr 16)&255)-127)<=2 And Abs(((color Shr 8)&255)-128)<=2,"Layer order and opacity")
	upper.visible=False
	Local camera:TCamera2D=New TCamera2D
	camera.x=3; camera.y=5; camera.zoom=2; camera.offsetX=30; camera.offsetY=-40
	SetCamera(camera)
	SetOrigin(2,4); SetTransform(90,1.5,0.75); TranslateCoordinates(10,8)
	Local transform:TMax2DDrawTransform=TMax2DDrawTransform.Create(TMax2DGraphics.Current().state,7,9,0,0)
	Local vx:Float,vy:Float,c:Int,r:Int
	transform.LocalToVirtual(24,24,vx,vy)
	Check(map.Pick(vx,vy,c,r,7,9,Null,False) And c=1 And r=1,"Picking through camera, origin, parent and object transforms")
	Local saved:TMax2DDrawTransform=CaptureDrawTransform()
	Cls(); map.Draw(7,9)
	Check(Pixel(Int(vx),Int(vy))=$ff0000,"Rendered cell agrees with transformed picking")
	Local restored:TMax2DDrawTransform=CaptureDrawTransform()
	Check(saved.xx=restored.xx And saved.xy=restored.xy And saved.tx=restored.tx And saved.ty=restored.ty,"Draw restores caller state")
	SetCamera(Null); SetTransform(); SetOrigin(0,0)
	' Restore the parent separately, as the above deliberately changed it.
	TranslateCoordinates(-10,-8)
	For Local orientation:ETileLayout=EachIn [ETileLayout.PointyHex,ETileLayout.FlatHex]
		For Local stagger:ETileStagger=EachIn [ETileStagger.Odd,ETileStagger.Even]
			map.grid=TTileGrid.Hexagonal(20,20,orientation,stagger,8)
			layer.Clear(); layer.SetCell(1,1,red)
			layer.offsetX=7; layer.offsetY=5
			Local x:Double,y:Double
			map.grid.CellOrigin(1,1,x,y)
			Cls(); map.Draw(4,3)
			Check(Pixel(Int(x)+12,Int(y)+9)=$ff0000,"Hex tile placement")
			map.grid.CellCenter(1,1,x,y)
			Check(map.Pick(Float(x+11),Float(y+8),c,r,4,3,layer) And c=1 And r=1,"Hex picking with layer offsets")
		Next
	Next
	' Flat hexes need two column passes per row to preserve top-to-bottom overlap.
	map.grid=TTileGrid.Hexagonal(20,20,ETileLayout.FlatHex,ETileStagger.Odd)
	layer.Clear(); layer.offsetX=0; layer.offsetY=0
	layer.SetCell(1,0,green); layer.SetCell(2,0,red)
	Cls(); map.Draw()
	Check(Pixel(30,12)=$00ff00,"Flat hex staggered drawing order")
	For Local layout:TTileGrid=EachIn [TTileGrid.Isometric(32,16), ..
		TTileGrid.StaggeredIsometric(32,16,ETileAxis.X,ETileStagger.Odd), ..
		TTileGrid.StaggeredIsometric(32,16,ETileAxis.X,ETileStagger.Even), ..
		TTileGrid.StaggeredIsometric(32,16,ETileAxis.Y,ETileStagger.Odd), ..
		TTileGrid.StaggeredIsometric(32,16,ETileAxis.Y,ETileStagger.Even)]
		map.grid=layout; layer.Clear(); layer.SetCell(1,1,red)
		Local px:Double,py:Double
		layout.CellOrigin(1,1,px,py)
		Cls(); map.Draw(16,8)
		Check(Pixel(Int(px)+18,Int(py)+10)=$ff0000,"Diamond tile placement and culling")
		layout.CellCenter(1,1,px,py)
		Check(map.Pick(Float(px+16),Float(py+8),c,r,16,8) And c=1 And r=1,"Diamond picking")
	Next
	Local wideRed:Int=tiles.Add(Solid(64,48,$ffff0000),0,-16,-32)
	Local wideGreen:Int=tiles.Add(Solid(64,48,$ff00ff00),0,-16,-32)
	map.grid=TTileGrid.Isometric(32,16); layer.Clear()
	layer.SetCell(2,0,wideRed); layer.SetCell(0,1,wideGreen)
	Cls(); map.Draw(32,40)
	Check(Pixel(50,30)=$ff0000 And map.sortedItems=2,"Isometric diagonal painter order")
	Local prop:Int=tiles.Add(Solid(32,32,$ffff0000),0,-8,-16)
	map.grid=TTileGrid.Rectangular(16,16); layer.Clear(); layer.SetCell(2,2,prop)
	layer.sortMode=ETileSort.GroundDepth
	Local actor:TTileSprite=layer.AddSprite(Solid(32,32,$ff00ff00),40,47)
	Cls(); map.Draw()
	Check(Pixel(30,30)=$ff0000,"Actor behind scenery by feet")
	actor.y=49
	Cls(); map.Draw()
	Check(Pixel(30,30)=$00ff00,"Actor in front of scenery by feet")
	tiles.SetDepth(prop,10)
	Cls(); map.Draw()
	Check(Pixel(30,30)=$ff0000,"Explicit tile ground-contact offset")
	tiles.SetDepth(prop)
	actor.y=48; actor.sortOrder=-1
	Cls(); map.Draw()
	Check(Pixel(30,30)=$ff0000,"Explicit equal-depth order")
	actor.sortOrder=1
	Cls(); map.Draw()
	Check(Pixel(30,30)=$00ff00,"Explicit equal-depth foreground order")
	Local second:TTileSprite=layer.AddSprite(Solid(32,32,$ffffff00),40,48)
	second.sortOrder=1
	Cls(); map.Draw()
	Check(Pixel(30,30)=$ffff00,"Stable sprite insertion ties")
	Check(layer.RemoveSprite(second),"Remove sprite")
	layer.Clear()
	Cls(); map.Draw()
	Check(Pixel(30,30)=$00ff00 And map.drawnSprites=1 And map.drawnTiles=0,"Sprite-only layers render")
	actor.visible=False
	Cls(); map.Draw()
	Check(Pixel(30,30)=0 And map.drawnSprites=0,"Hidden sprite")
	layer.ClearSprites()
	Local orderTiles:TTileSet=New TTileSet
	Local nw:Int=orderTiles.Add(Solid(24,24,$ffff0000),0,0,-8)
	Local ne:Int=orderTiles.Add(Solid(24,24,$ff00ff00),0,0,-8)
	Local sw:Int=orderTiles.Add(Solid(24,24,$ff0000ff),0,0,-8)
	Local se:Int=orderTiles.Add(Solid(24,24,$ffffff00),0,0,-8)
	Local orderMap:TTileMap=TTileMap.Create(TTileGrid.Rectangular(16,16),orderTiles)
	Local orderLayer:TTileLayer=orderMap.AddLayer()
	Local orders:ETileRenderOrder[]=[ETileRenderOrder.RightDown,ETileRenderOrder.RightUp,ETileRenderOrder.LeftDown,ETileRenderOrder.LeftUp]
	Local expected:Int[]=[$ffff00,$00ff00,$0000ff,$ff0000]
	For Local base:Int=EachIn [0,31,-1,-33]
		orderLayer.Clear()
		orderLayer.SetCell(base,base,nw); orderLayer.SetCell(base+1,base,ne)
		orderLayer.SetCell(base,base+1,sw); orderLayer.SetCell(base+1,base+1,se)
		For Local i:Int=0 Until orders.Length
			orderLayer.renderOrder=orders[i]
			orderLayer.sortMode=ETileSort.Grid
			Cls(); orderMap.Draw(8-base*16,8-base*16)
			Check(Pixel(25,17)=expected[i],"Grid render order across chunks: base="+base+" order="+i)
			Check(orderMap.drawnTiles=4 And orderMap.chunkLookups<=4,"Render order retains visible chunk traversal")
			orderLayer.sortMode=ETileSort.GroundDepth
			Cls(); orderMap.Draw(8-base*16,8-base*16)
			Check(Pixel(25,17)=$ffff00,"GroundDepth takes precedence over grid render order")
		Next
	Next
	SetRenderImage(Null); EndGraphics()
	Print "Max2D tilemap rendering and picking tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
