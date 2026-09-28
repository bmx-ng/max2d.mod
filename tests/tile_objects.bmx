SuperStrict
Framework Max2D.Tiled
Import BRL.StandardIO
Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Function Near:Int(a:Double,b:Double)
	Return Abs(a-b)<0.00001
End Function
Try
	Local path:String=AppArgs[1]
	Local map:TTiledMap=LoadTiledMap(path+"/objects.tmx",0)
	Local layer:TTileLayer=map.layers[0]
	Check(map.importedLayers[1].kind="objectgroup" And layer.objects.Length=7,"Object group import")
	Check(layer.offsetX=13 And layer.offsetY=24 And layer.opacity=0.5,"Group offsets and opacity")
	Check(Not layer.objectTopDown And layer.properties.GetString("purpose")="gameplay","Layer order and properties")
	Local spawn:TTileObject=map.ObjectByID(1)
	Check(spawn.name="spawn" And spawn.className="Spawn" And map.ObjectByID(Int(spawn.Property("target").AsLong())).name="trigger","Names, classes and object references")
	Local result:TTileObjectQueryResult=layer.QueryObjectsAtPoint(15,27)
	Check(result.count=1 And result.items[0].source=spawn,"Point in map coordinates")
	Check(layer.QueryObjectsAtPoint(15.5,27,1,result)=result And result.count=1,"Reused result and point tolerance")
	layer.QueryObjectsAtPoint(21,36,0,result)
	Check(result.count=1 And result.items[0].source.id=2,"Rotated rectangle picking")
	Local oval:STileObjectInstance=map.ObjectByID(3).Instance(13,24)
	Local l:Double,t:Double,r:Double,b:Double
	oval.Bounds(l,t,r,b)
	Check(Near(l,29) And Near(r,33) And Near(t,34) And Near(b,42),"Exact rotated ellipse bounds")
	Check(oval.ContainsPoint(31,38) And Not oval.ContainsPoint(29.1,34.1),"Ellipse narrow phase")
	Local concave:STileObjectInstance=map.ObjectByID(4).Instance()
	Check(concave.ContainsPoint(1,25) And Not concave.ContainsPoint(4,24) And concave.ContainsPoint(2,24),"Concave polygon and boundary")
	Local line:STileObjectInstance=map.ObjectByID(5).Instance()
	Check(line.ContainsPoint(30.5,22,0.6) And Not line.ContainsPoint(30.5,22,0.4),"Polyline world-space tolerance")
	Local decoration:TTileObject=map.ObjectByID(6)
	Check(decoration.tile=1 And decoration.flip=ETileFlip.Horizontal And decoration.y=12,"Tile object anchor and flip")
	Check(decoration.Property("solid").AsBool() And decoration.Property("cost").AsDouble()=9,"Tile property inheritance and override")
	layer.QueryObjectsAtPoint(14,25,0,result)
	Check(result.count=1 And Not result.items[0].source.visible,"Hidden geometry remains queryable")
	map=LoadTiledMap(path+"/collision.tmx",0); layer=map.layers[0]
	Check(map.tileset.tiles[1].collisions.Length=2,"Tileset collision import")
	Local item:STileObjectInstance=map.CellCollision(layer,0,0,0)
	item.Bounds(l,t,r,b)
	Check(Near(l,11) And Near(r,12) And Near(t,19) And Near(b,21),"Collision tile and layer offsets")
	item=map.CellCollision(layer,1,0,0); item.Bounds(l,t,r,b)
	Check(Near(l,14) And Near(r,15),"Collision horizontal flip")
	item=map.CellCollision(layer,2,0,0); item.Bounds(l,t,r,b)
	Check(Near(l,15) And Near(r,17) And Near(t,19) And Near(b,20),"Collision diagonal flip")
	map.QueryTileCollisions(layer,6.1,19.1,0.1,0.1,result)
	Check(result.count=1 And result.items[0].source.name="overhang" And result.items[0].column=0,"Query includes collision outside cell bounds")
	Check(result.items[0].ContainsPoint(6.2,19.2),"Collision candidate exact picking")
	map.QueryTileCollisions(layer,100,100,1,1,result)
	Check(result.count=0 And result.items[0].source=Null,"Reusable results release old references")

	map=LoadTiledMap(path+"/objects-iso.tmx",0); layer=map.layers[0]
	item=map.ObjectByID(1).Instance(layer.offsetX,layer.offsetY)
	item.Bounds(l,t,r,b)
	Check(Near(l,106) And Near(r,170) And Near(t,36) And Near(b,68),"Isometric object projection and group offset")
	Check(item.ContainsPoint(138,52) And Not item.ContainsPoint(107,37),"Isometric diamond picking")
	item=map.ObjectByID(2).Instance(layer.offsetX,layer.offsetY)
	item.Bounds(l,t,r,b)
	Check(Near(l,42) And Near(r,74) And Near(t,4) And Near(b,68),"Rotation after isometric projection")
	For Local name:String=EachIn ["duplicate-object","bad-polygon","object-template","negative-object","nonfinite-object"]
		Local rejected:Int
		Try
			LoadTiledMap(path+"/"+name+".tmx",0)
		Catch error:Object
			rejected=True
		End Try
		Check(rejected,"Reject invalid or unsupported object: "+name)
	Next
	' Geometry follows every supported cell transform, including negative hex cells.
	map=LoadTiledMap(path+"/collision.tmx",0); layer=map.layers[0]
	Local flips:ETileFlip[]=[ETileFlip.None,ETileFlip.Horizontal,ETileFlip.Vertical,ETileFlip.Diagonal,ETileFlip.Horizontal|ETileFlip.Diagonal,ETileFlip.Vertical|ETileFlip.Diagonal,ETileFlip.Horizontal|ETileFlip.Vertical|ETileFlip.Diagonal,ETileFlip.Horizontal|ETileFlip.Vertical,ETileFlip.Rotate60,ETileFlip.Rotate120,ETileFlip.Rotate60|ETileFlip.Rotate120,ETileFlip.Rotate60|ETileFlip.Horizontal,ETileFlip.Rotate120|ETileFlip.Vertical]
	map.grid=TTileGrid.Hexagonal(2,2,ETileLayout.PointyHex,ETileStagger.Odd,1)
	For Local flip:ETileFlip=EachIn flips
		layer.Clear(); layer.SetCell(-2,-3,1,flip)
		item=map.CellCollision(layer,-2,-3,0)
		Local px:Double,py:Double
		item.TransformPoint(0.5,1,px,py)
		map.QueryTileCollisions(layer,px,py,0,0,result)
		Local found:Int
		For Local i:Int=0 Until result.count
			If result.items[i].source.name="solid" And result.items[i].ContainsPoint(px,py) Then found=True
		Next
		Check(found,"Transformed collision query: "+flip.ToString())
	Next
	Print "Tile object tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
