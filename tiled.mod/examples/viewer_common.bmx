Include "viewer_fonts.bmx"

' Shared viewer implementation; build tiled_examples.bmx or examples/tiled_viewer.bmx.
Function RunTiledViewer(mapPaths:String[],mapHelp:String,projectPath:String="")
	Local path:String=mapPaths[0],test:Int,screenshot:String
	For Local arg:String=EachIn AppArgs[1..]
		If arg="--test" Then
			test=True
		Else If arg.StartsWith("--project=") Then
			projectPath=arg[10..]
		Else If arg.StartsWith("--screenshot=") Then
			screenshot=arg[13..]
		Else
			path=arg
		End If
	Next
	Local fonts:TTiledExampleFonts=New TTiledExampleFonts
	Local map:TTiledMap,project:TTiledProject
	Try
		If projectPath Then project=TTiledProject.Load(projectPath)
		map=LoadTiledMap(path,0,"",project,fonts)
	Catch error:Object
		Print(error.ToString())
		If test Then EndWithCode(1)
		Notify(error.ToString())
		EndWithCode(1)
	End Try
	AppTitle="Max2D — Tiled viewer"
	Graphics 1000,700
	SetVirtualResolution(1000,700,VIRTUAL_LETTERBOX)
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
	If font Then SetImageFont(font)
	Local camera:TCamera2D=New TCamera2D
	camera.offsetX=500; camera.offsetY=390
	FitMap(map,camera)
	Local showObjects:Int=True,objectHits:TTileObjectQueryResult=New TTileObjectQueryResult
	Local started:Int=MilliSecs(),previous:Int=started,frames:Int
	While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
		PollSystem()
		Local now:Int=MilliSecs(),dt:Float=Min(0.1,Float(now-previous)/1000)
		previous=now
		camera.x:+(KeyDown(KEY_RIGHT)-KeyDown(KEY_LEFT))*400*dt/camera.zoom
		camera.y:+(KeyDown(KEY_DOWN)-KeyDown(KEY_UP))*400*dt/camera.zoom
		Local nextPath:String
		For Local index:Int=0 Until mapPaths.Length
			Local key:Int=KEY_1+index
			If index=9 Then key=KEY_0
			If KeyHit(key) Then nextPath=mapPaths[index]
		Next
		If nextPath Then
			Try
				Local nextMap:TTiledMap=LoadTiledMap(nextPath,0,"",project,fonts)
				map=nextMap; path=nextPath; FitMap(map,camera)
			Catch error:Object
				Notify(error.ToString())
			End Try
		End If
		If KeyHit(KEY_O) Then showObjects=Not showObjects
		If KeyHit(KEY_SPACE) Then FitMap(map,camera)
		Local vx:Float,vy:Float
		If GetVirtualMouse(vx,vy) Then camera.ZoomAt(Max(0.1,Min(16,camera.zoom*Float(Exp(MouseZSpeed()*0.1+(KeyDown(KEY_E)-KeyDown(KEY_Q))*dt)))),vx,vy)
		SetClsColor(18,24,32); Cls()
		Local label:String="Hover a tile to inspect it"
		Using
			Local scope:TMax2DStateScope=ScopedMax2DState()
		Do
			SetViewport(0,100,1000,600); SetCamera(camera)
			map.Draw(0,0,Long(UInt(now-started)))
			If showObjects Then
				SetLineWidth(1.5/camera.zoom); SetColor(100,220,255)
				For Local layer:TTileLayer=EachIn map.layers
					If Not layer.visible Then Continue
					Local ox:Double,oy:Double
					map.LayerDrawOffset(layer,ox,oy)
					For Local obj:TTileObject=EachIn layer.objects
						If obj.visible Then DrawObjectOutline(obj.Instance(ox,oy),camera.zoom)
					Next
				Next
			End If
			For Local i:Int=map.layers.Length-1 To 0 Step -1
				Local layer:TTileLayer=map.layers[i],column:Int,row:Int
				Local mx:Float,my:Float,ox:Double,oy:Double
				map.LayerDrawOffset(layer,ox,oy)
				If layer.visible And GetVirtualMouse(vx,vy,True) And map.VirtualToLayer(layer,vx,vy,mx,my) Then
					layer.QueryObjectsAtPoint(mx+layer.offsetX,my+layer.offsetY,4/camera.zoom,objectHits)
					Local selected:Int=-1
					For Local index:Int=0 Until objectHits.count
						Local obj:TTileObject=objectHits.items[index].source
						If Not obj.visible Then Continue
						If selected<0 Or Not layer.objectTopDown Or obj.sortY>=objectHits.items[selected].source.sortY Then selected=index
					Next
					If selected>=0 Then
						Local hit:STileObjectInstance=objectHits.items[selected]
						hit.x:+ox-layer.offsetX; hit.y:+oy-layer.offsetY
						label=layer.name+": object "+hit.source.id+" / "+hit.source.name+" / "+hit.source.className
						SetColor(255,218,105); SetLineWidth(2/camera.zoom)
						DrawObjectOutline(hit,camera.zoom)
						Exit
					End If
				End If
				If Not layer.visible Or Not map.MouseCell(column,row,0,0,layer) Then Continue
				Local id:Int=layer.Cell(column,row)
				If Not id Then Continue
				label=layer.name+": cell "+column+", "+row+" / "+layer.CellFlip(column,row).ToString()
				Local terrain:TTileProperty=layer.Property(column,row,"terrain")
				If terrain And terrain.Kind()=ETilePropertyType.Text Then label:+" / "+terrain.AsString()
				SetColor(255,218,105); SetLineWidth(2/camera.zoom)
				For Local corner:Int=0 Until map.grid.CornerCount()
					Local x:Double,y:Double,nx:Double,ny:Double
					map.grid.CellCorner(column,row,corner,x,y)
					map.grid.CellCorner(column,row,(corner+1) Mod map.grid.CornerCount(),nx,ny)
					DrawLine(Float(x+ox),Float(y+oy),Float(nx+ox),Float(ny+oy),False)
				Next
				Exit
			Next
		End Using
		Using
			Local scope:TMax2DStateScope=ScopedMax2DState()
		Do
			SetNativeResolution()
			Local density:Float=Float(NativeResolutionWidth())/GraphicsWidth()
			If Not font Then density=Max(1,Floor(density+0.5))
			SetScale(density,density); SetColor(240,246,255)
			DrawText(StripDir(path)+"  /  "+map.orientation+"  /  "+map.layers.Length+" layers",20*density,14*density)
			DrawText(mapHelp+"   Arrows: pan   Wheel/Q/E: zoom   Space: fit",20*density,41*density)
			DrawText(label,20*density,68*density)
		End Using
		If screenshot And frames=2 Then SavePixmapPNG(GrabPixmap(0,0,NativeResolutionWidth(),NativeResolutionHeight()),screenshot)
		Flip()
		frames:+1
		If test And frames=3 Then Exit
	Wend
	EndGraphics()
End Function

Function FitMap(map:TTiledMap,camera:TCamera2D)
	Local left:Double,top:Double,right:Double,bottom:Double,found:Int
	For Local layer:TTileLayer=EachIn map.layers
		Local c0:Int,r0:Int,c1:Int,r1:Int
		If Not layer.visible Then Continue
		For Local obj:TTileObject=EachIn layer.objects
			If Not obj.visible Then Continue
			Local instance:STileObjectInstance=obj.Instance(layer.offsetX,layer.offsetY),l:Double,t:Double,r:Double,b:Double
			instance.Bounds(l,t,r,b)
			If Not found Then left=l; top=t; right=r; bottom=b; found=True
			left=Min(left,l); top=Min(top,t); right=Max(right,r); bottom=Max(bottom,b)
		Next
		If layer.image Then
			Local l:Double=layer.offsetX,t:Double=layer.offsetY,r:Double=l+layer.image.width,b:Double=t+layer.image.height
			If Not found Then left=l; top=t; right=r; bottom=b; found=True
			left=Min(left,l); top=Min(top,t); right=Max(right,r); bottom=Max(bottom,b)
		End If
		If Not layer.Bounds(c0,r0,c1,r1) Then Continue
		For Local c:Int=0 Until 2
			For Local r:Int=0 Until 2
				Local x:Double,y:Double
				map.grid.CellOrigin(c0+(c1-c0)*c,r0+(r1-r0)*r,x,y)
				x:+layer.offsetX; y:+layer.offsetY
				If Not found Then left=x; top=y; right=x; bottom=y; found=True
				left=Min(left,x); top=Min(top,y)
				right=Max(right,x+map.grid.TileWidth()); bottom=Max(bottom,y+map.grid.TileHeight())
			Next
		Next
	Next
	camera.x=Float((left+right)/2); camera.y=Float((top+bottom)/2)
	camera.zoom=Float(Min(940/Max(1.0,right-left),540/Max(1.0,bottom-top)))
	camera.zoom=Min(4,camera.zoom)
End Function

Function DrawObjectOutline(item:STileObjectInstance,zoom:Float)
	Local obj:TTileObject=item.source,count:Int=4,closed:Int=True
	Select obj.shape
		Case ETileObjectShape.Point
			Local radius:Float=4/zoom
			DrawLine(Float(item.x)-radius,Float(item.y),Float(item.x)+radius,Float(item.y),False)
			DrawLine(Float(item.x),Float(item.y)-radius,Float(item.x),Float(item.y)+radius,False)
			Return
		Case ETileObjectShape.Ellipse; count=48
		Case ETileObjectShape.Polygon; count=obj.points.Length
		Case ETileObjectShape.Polyline; count=obj.points.Length; closed=False
	End Select
	Local previousX:Double,previousY:Double
	For Local i:Int=0 Until count+Int(closed)
		Local index:Int=i Mod count,px:Double,py:Double,x:Double,y:Double
		Select obj.shape
			Case ETileObjectShape.Rectangle
				If index=1 Or index=2 Then px=obj.width
				If index>=2 Then py=obj.height
			Case ETileObjectShape.Ellipse
				px=obj.width*(1+Cos(index*360.0/count))/2; py=obj.height*(1+Sin(index*360.0/count))/2
			Default; px=obj.points[index].x; py=obj.points[index].y
		End Select
		item.TransformPoint(px,py,x,y)
		If i Then DrawLine(Float(previousX),Float(previousY),Float(x),Float(y),False)
		previousX=x; previousY=y
	Next
End Function
