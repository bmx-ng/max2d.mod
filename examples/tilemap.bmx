SuperStrict

?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.TileMap
Import Max2D.ScalableFont
Import BRL.FileSystem
Import Pub.StdC

AppTitle="Max2D tilemaps — rectangular, hexagonal and isometric worlds"
Local fontPath:String
?osx
fontPath="/System/Library/Fonts/Supplemental/Arial.ttf"
?win32
fontPath=getenv_("WINDIR")+"/Fonts/segoeui.ttf"
?linux
fontPath="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
?
Local font:TScalableImageFont
If FileType(fontPath)=FILETYPE_FILE Then font=LoadScalableImageFont(fontPath,18)
Graphics 1000,700
SetVirtualResolution(1000,700,VIRTUAL_LETTERBOX)
If font Then SetImageFont(font)

Local choice:Int=6,customSide:Int
Local scene:TTileDemo=TTileDemo.Create(choice,customSide)
Local camera:TCamera2D=New TCamera2D
camera.offsetX=500; camera.offsetY=390
Local previous:Int=MilliSecs(),started:Int=previous,frames:Int
Local selected:Int,selectedColumn:Int,selectedRow:Int
Local range:STileCell[]
Local nearby:TTileQueryResult=New TTileQueryResult
Local showRegion:Int=True
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	PollSystem()
	Local now:Int=MilliSecs(),dt:Float=Min(0.1,Float(now-previous)/1000)
	previous=now
	Local changed:Int
	For Local key:Int=KEY_1 To KEY_9
		If KeyHit(key) Then choice=key-KEY_1+1; changed=True
	Next
	If KeyHit(KEY_0) Then choice=10; changed=True
	If KeyHit(KEY_H) And scene.map.grid.IsHex() Then customSide=Not customSide; changed=True
	If changed Then
		scene.Release()
		scene=TTileDemo.Create(choice,customSide)
		If selected Then range=scene.map.grid.Range(selectedColumn,selectedRow,3)
	End If
	If KeyHit(KEY_F) Then
		If scene.objects.sortMode=ETileSort.Grid Then scene.objects.sortMode=ETileSort.GroundDepth Else scene.objects.sortMode=ETileSort.Grid
	End If
	Local moveX:Float=KeyDown(KEY_D)-KeyDown(KEY_A),moveY:Float=KeyDown(KEY_S)-KeyDown(KEY_W)
	Local length:Float=Sqr(moveX*moveX+moveY*moveY)
	If length>0 Then
		scene.actor.x:+moveX/length*160*dt; scene.actor.y:+moveY/length*160*dt
	End If
	camera.x:+(KeyDown(KEY_RIGHT)-KeyDown(KEY_LEFT))*300*dt/camera.zoom
	camera.y:+(KeyDown(KEY_DOWN)-KeyDown(KEY_UP))*300*dt/camera.zoom
	camera.rotation:+(KeyDown(KEY_X)-KeyDown(KEY_Z))*45*dt
	If KeyHit(KEY_B) Then showRegion=Not showRegion
	If KeyHit(KEY_SPACE) Then camera.x=0; camera.y=0; camera.zoom=1; camera.rotation=0
	Local vx:Float,vy:Float,inside:Int=GetVirtualMouse(vx,vy)
	Local zoom:Float=Max(0.35,Min(3.0,camera.zoom*Float(Exp(MouseZSpeed()*0.1+(KeyDown(KEY_E)-KeyDown(KEY_Q))*dt))))
	If inside Then camera.ZoomAt(zoom,vx,vy)
	SetClsColor(16,23,32); Cls()
	Local column:Int,row:Int,hover:Int
	Using
		Local scope:TMax2DStateScope=ScopedMax2DState()
	Do
		SetViewport(0,112,1000,534)
		SetCamera(camera)
		hover=scene.map.MouseCell(column,row)
		If hover And MouseHit(1) Then
			selected=True; selectedColumn=column; selectedRow=row
			range=scene.map.grid.Range(column,row,3)
		End If
		If hover And MouseHit(2) Then
			Local tile:Int=scene.ground.Cell(column,row)
			If tile=scene.grass Then tile=scene.water Else tile=scene.grass
			scene.ground.SetCell(column,row,tile)
		End If
		SetColor(255,255,255)
		scene.map.Draw(0,0,Long(UInt(now-started)))
		SetLineWidth(1.5/camera.zoom)
		If showRegion Then
			Local qx:Float=scene.actor.x-48,qy:Float=scene.actor.y-24
			scene.map.QueryRegion(scene.ground,qx,qy,96,48,nearby)
			SetColor(223,136,250)
			For Local i:Int=0 Until nearby.count
				Outline(scene.map.grid,nearby.cells[i].column,nearby.cells[i].row)
			Next
			SetColor(255,178,76)
			DrawLine(qx,qy,qx+96,qy,False); DrawLine(qx+96,qy,qx+96,qy+48,False)
			DrawLine(qx+96,qy+48,qx,qy+48,False); DrawLine(qx,qy+48,qx,qy,False)
		Else
			nearby.Clear()
		End If
		If selected Then
			SetColor(244,193,73)
			For Local cell:STileCell=EachIn range
				Outline(scene.map.grid,cell.column,cell.row)
			Next
		End If
		If hover Then
			SetColor(82,220,236)
			For Local direction:Int=0 Until scene.map.grid.NeighbourCount()
				Local c:Int,r:Int
				scene.map.grid.Neighbour(column,row,direction,c,r)
				Outline(scene.map.grid,c,r)
			Next
			SetColor(255,255,255); SetLineWidth(3/camera.zoom)
			Outline(scene.map.grid,column,row)
		End If
	End Using
	Using
		Local hud:TMax2DStateScope=ScopedMax2DState()
	Do
		SetNativeResolution()
		Local density:Float=Float(NativeResolutionWidth())/GraphicsWidth()
		If Not font Then density=Max(1,Floor(density+0.5))
		SetScale(density,density)
		SetColor(240,246,255)
		DrawText("NATIVE TILEMAPS    "+scene.title+"    Sorting: "+scene.objects.sortMode.ToString()+" (F)",20*density,16*density)
		DrawText("1 Rect   2/3 Pointy hex   4/5 Flat hex   6 Iso   7/8 Stagger Y   9/0 Stagger X",20*density,43*density)
		DrawText("Arrows: pan   WASD: move actor   Wheel/Q/E: zoom   Z/X: rotate   H: hex sides   Space: reset",20*density,70*density)
		Local label:String="Move the mouse over the map"
		If hover Then
			label="Cell "+column+", "+row
			Local terrain:TTileProperty=scene.ground.Property(column,row,"terrain")
			If terrain Then label:+" / "+terrain.AsString()
		End If
		If selected And hover Then label:+"    Grid distance: "+scene.map.grid.Distance(selectedColumn,selectedRow,column,row)
		DrawText(label+"    Nearby: "+nearby.count+" (B)    Drawn: "+scene.map.drawnTiles,20*density,NativeResolutionHeight()-48*density)
		DrawText("Left click: show range 3 (ignores obstacles)    Right click: paint grass/water, including empty cells",20*density,NativeResolutionHeight()-25*density)
	End Using
	Flip()
	frames:+1
	If AppArgs.Length>1 And AppArgs[1]="--test" And frames=3 Then Exit
Wend
scene.Release()
EndGraphics()

Function Outline(grid:TTileGrid,column:Int,row:Int)
	For Local corner:Int=0 Until grid.CornerCount()
		Local x:Double,y:Double,nx:Double,ny:Double
		grid.CellCorner(column,row,corner,x,y)
		grid.CellCorner(column,row,(corner+1) Mod grid.CornerCount(),nx,ny)
		DrawLine(Float(x),Float(y),Float(nx),Float(ny),False)
	Next
End Function

Type TTileDemo
	Field map:TTileMap,atlas:TTextureAtlas,ground:TTileLayer,objects:TTileLayer
	Field actor:TTileSprite
	Field grass:Int,water:Int
	Field title:String
	Function Create:TTileDemo(choice:Int,customSide:Int)
		Local demo:TTileDemo=New TTileDemo
		Local grid:TTileGrid
		Select choice
			Case 1
				grid=TTileGrid.Rectangular(56,56); demo.title="Rectangular"
			Case 2,3
				Local stagger:ETileStagger=ETileStagger.Odd
				If choice=3 Then stagger=ETileStagger.Even
				Local side:Double=36
				If customSide Then side=18
				grid=TTileGrid.Hexagonal(64,72,ETileLayout.PointyHex,stagger,side)
				demo.title="Pointy hex / "+stagger.ToString()
			Case 4,5
				Local stagger:ETileStagger=ETileStagger.Odd
				If choice=5 Then stagger=ETileStagger.Even
				Local side:Double=36
				If customSide Then side=18
				grid=TTileGrid.Hexagonal(72,64,ETileLayout.FlatHex,stagger,side)
				demo.title="Flat hex / "+stagger.ToString()
			Case 6
				grid=TTileGrid.Isometric(80,40); demo.title="Isometric"
			Case 7,8,9,10
				Local axis:ETileAxis=ETileAxis.Y,stagger:ETileStagger=ETileStagger.Odd
				If choice>=9 Then axis=ETileAxis.X
				If choice=8 Or choice=10 Then stagger=ETileStagger.Even
				grid=TTileGrid.StaggeredIsometric(80,40,axis,stagger)
				demo.title="Staggered "+axis.ToString()+" / "+stagger.ToString()
		End Select
		If customSide And grid.IsHex() Then demo.title:+" / short sides"
		demo.atlas=TTextureAtlas.Create(512,FILTEREDIMAGE)
		Local tiles:TTileSet=New TTileSet
		demo.grass=tiles.Add(demo.atlas.AddPixmap(Terrain(grid,$ff467b57),"grass",True))
		Local stone:Int=tiles.Add(demo.atlas.AddPixmap(Terrain(grid,$ff7d8791),"stone",True))
		Local waterA:TImage=demo.atlas.AddPixmap(Terrain(grid,$ff285b80),"water-a",True)
		Local waterB:TImage=demo.atlas.AddPixmap(Terrain(grid,$ff30678e),"water-b",True)
		demo.water=tiles.AddAnimation(demo.atlas.AddAnimation("water",[waterA,waterB],[600,600]))
		tiles.Properties(demo.grass).SetString("terrain","grass")
		tiles.Properties(demo.grass).SetDouble("moveCost",1.0)
		tiles.Properties(stone).SetString("terrain","stone")
		tiles.Properties(stone).SetDouble("moveCost",1.25)
		tiles.Properties(demo.water).SetString("terrain","water")
		tiles.Properties(demo.water).SetBool("swimmable",True)
		tiles.Properties(demo.water).SetDouble("moveCost",2.0)
		Local tree:TPixmap=CreatePixmap(40,64,PF_RGBA8888)
		tree.ClearPixels(0)
		For Local y:Int=0 Until 64
			For Local x:Int=0 Until 40
				If y>=44 And x>=17 And x<23 Then tree.WritePixel(x,y,$ff8d6344)
				If ((x-20.0)/18)^2+((y-25.0)/25)^2<1 Then tree.WritePixel(x,y,$ff183e32)
				If ((x-17.0)/13)^2+((y-21.0)/20)^2<1 Then tree.WritePixel(x,y,$ff2c6146)
			Next
		Next
		Local treeID:Int=tiles.Add(demo.atlas.AddPixmap(tree,"tree",True),0,Float((grid.TileWidth()-40)/2),Float(grid.TileHeight()-64))
		demo.map=TTileMap.Create(grid,tiles)
		demo.ground=demo.map.AddLayer("terrain")
		demo.objects=demo.map.AddLayer("trees and actor")
		demo.objects.sortMode=ETileSort.GroundDepth
		For Local row:Int=-12 To 12
			For Local column:Int=-16 To 16
				Local value:Int=(column*17+row*31) & 15
				Local tile:Int=demo.grass
				If value<3 Then tile=demo.water
				If value>13 Then tile=stone
				demo.ground.SetCell(column,row,tile)
				If value=8 Then demo.objects.SetCell(column,row,treeID)
			Next
		Next
		Local person:TPixmap=CreatePixmap(24,40,PF_RGBA8888)
		person.ClearPixels(0)
		For Local y:Int=0 Until 40
			For Local x:Int=0 Until 24
				If (x-12)*(x-12)+(y-8)*(y-8)<49 Then person.WritePixel(x,y,$ffffd181)
				If y>=16 And y<33 And x>=5 And x<19 Then person.WritePixel(x,y,$ffed9b35)
				If y>=33 And ((x>=5 And x<10) Or (x>=14 And x<19)) Then person.WritePixel(x,y,$ff222937)
			Next
		Next
		demo.actor=demo.objects.AddSprite(demo.atlas.AddPixmap(person,"actor",True),-30,40)
		demo.objects.SetCell(0,0,treeID)
		Return demo
	End Function
	Function Terrain:TPixmap(grid:TTileGrid,color:Int)
		Local pixels:TPixmap=CreatePixmap(Int(grid.TileWidth()),Int(grid.TileHeight()),PF_RGBA8888)
		pixels.ClearPixels(0)
		Local ox:Double,oy:Double
		grid.CellOrigin(0,0,ox,oy)
		For Local y:Int=0 Until pixels.height
			For Local x:Int=0 Until pixels.width
				Local px:Double=(x+0.5-pixels.width/2.0)/0.95+pixels.width/2.0
				Local py:Double=(y+0.5-pixels.height/2.0)/0.95+pixels.height/2.0
				If grid.Contains(0,0,px+ox,py+oy) Then pixels.WritePixel(x,y,color)
			Next
		Next
		Return pixels
	End Function
	Method Release()
		For Local page:TImage=EachIn atlas.pages
			page.ReleaseFrames()
		Next
	End Method
End Type
