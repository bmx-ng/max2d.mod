SuperStrict
Rem
bbdoc: Load LDtk projects and levels as native Max2D tilemaps.
about: Importing this module registers the .ldtk loader. Use TLDTKProject to select a level in a multi-level project. Files, stream URLs and caller-owned streams are supported.
End Rem
Module Max2D.LDTK
ModuleInfo "Version: 0.05"
ModuleInfo "License: zlib/libpng"
Import Max2D.TileMap
Import Text.JSON
Import BRL.FileSystem
Import BRL.PNGLoader
Import BRL.Map

Include "reader.bmx"
Include "artwork.bmx"
Include "fields.bmx"
Include "navigation.bmx"

Rem
bbdoc: Level metadata available before loading artwork. Coordinates describe the LDtk world, not an automatic drawing offset.
End Rem
Type TLDTKLevelInfo

	Rem
	bbdoc: Editor-assigned identifier for the imported level, layer or entity.
	End Rem
	Field identifier:String

	Rem
	bbdoc: Stable LDtk instance identifier.
	End Rem
	Field iid:String

	Rem
	bbdoc: Instance identifier of the owning LDtk world.
	End Rem
	Field worldIID:String

	Rem
	bbdoc: Path of an external LDtk level document, or empty for an embedded level.
	End Rem
	Field externalPath:String

	Rem
	bbdoc: Numeric definition identifier assigned by the editor.
	End Rem
	Field uid:Int

	Rem
	bbdoc: Level width in pixels.
	End Rem
	Field width:Int

	Rem
	bbdoc: Level height in pixels.
	End Rem
	Field height:Int

	Rem
	bbdoc: Level's horizontal placement in the LDtk world; not an automatic drawing offset.
	End Rem
	Field worldX:Int

	Rem
	bbdoc: Level's vertical placement in the LDtk world; not an automatic drawing offset.
	End Rem
	Field worldY:Int

	Rem
	bbdoc: Level's world depth as stored by LDtk.
	End Rem
	Field worldDepth:Int

	Rem
	bbdoc: Neighbouring-level references stored by LDtk.
	End Rem
	Field neighbours:TLDTKNeighbour[]

	Rem
	bbdoc: Retained source document or binary font data owned by this object.
	End Rem
	Field data:TJSONObject
End Type

Rem
bbdoc: An imported LDtk layer with its own grid and IntGrid values. layer refers to the native rendering/query layer.
End Rem
Type TLDTKLayer

	Rem
	bbdoc: Editor-assigned identifier for the imported level, layer or entity.
	End Rem
	Field identifier:String

	Rem
	bbdoc: Stable LDtk instance identifier.
	End Rem
	Field iid:String

	Rem
	bbdoc: Imported layer or definition kind.
	End Rem
	Field kind:String

	Rem
	bbdoc: Grid geometry used for cell placement and picking.
	End Rem
	Field grid:TTileGrid

	Rem
	bbdoc: Native or imported layer containing this object.
	End Rem
	Field layer:TTileLayer

	Rem
	bbdoc: Layer width in cells.
	End Rem
	Field width:Int

	Rem
	bbdoc: Layer height in cells.
	End Rem
	Field height:Int

	Rem
	bbdoc: Row-major LDtk IntGrid values; zero represents an unassigned cell.
	End Rem
	Field intGrid:Int[]

	Rem
	bbdoc: LDtk definitions describing the meaning and appearance of IntGrid values.
	End Rem
	Field intGridDefinitions:TJSONArray

	Rem
	bbdoc: Whether LDtk parallax scaling applies in addition to the layer offset.
	End Rem
	Field parallaxScaling:Int=True

	Rem
	bbdoc: Returns the IntGrid value, or zero outside the layer or when no IntGrid data exists.
	param: Integer grid column.
	param: Integer grid row.
	End Rem
	Method IntValue:Int(column:Int,row:Int)
		If column<0 Or row<0 Or column>=width Or row>=height Or Not intGrid Then Return 0
		Return intGrid[row*width+column]
	End Method

End Type

Rem
bbdoc: An entity's native gameplay rectangle, optional artwork, exported fields and LDtk identifiers.
End Rem
Type TLDTKEntity

	Rem
	bbdoc: Editor-assigned identifier for the imported level, layer or entity.
	End Rem
	Field identifier:String

	Rem
	bbdoc: Stable LDtk instance identifier.
	End Rem
	Field iid:String

	Rem
	bbdoc: Native map object representing the imported entity's geometry.
	End Rem
	Field object:TTileObject

	Rem
	bbdoc: Native or imported layer containing this object.
	End Rem
	Field layer:TLDTKLayer

	Rem
	bbdoc: Imported custom fields retaining their original JSON value types.
	End Rem
	Field fields:TLDTKField[]

	Rem
	bbdoc: Retained source document or binary font data owned by this object.
	End Rem
	Field data:TJSONObject

	Rem
	bbdoc: Optional custom entity artwork or cached artwork definitions.
	End Rem
	Field artwork:TLDTKEntityArtwork

	Rem
	bbdoc: Returns a named imported field, or Null when absent.
	param: Name used to register or look up the item.
	End Rem
	Method GetField:TLDTKField(name:String)
		Return TLDTKField.Find(fields,name)
	End Method

End Type

Rem
bbdoc: A level background using LDtk's exported fractional source crop and display rectangle.
about: Drawn before the level layers. Set visible to False to provide your own background.
End Rem
Type TLDTKBackground

	Rem
	bbdoc: Image or animation supplying this object's artwork.
	End Rem
	Field image:TImage

	Rem
	bbdoc: Whether this artwork, object or layer participates in drawing.
	End Rem
	Field visible:Int=True

	Rem
	bbdoc: Background's left edge in level-local drawing coordinates.
	End Rem
	Field x:Float

	Rem
	bbdoc: Background's top edge in level-local drawing coordinates.
	End Rem
	Field y:Float

	Rem
	bbdoc: Logical width of this object or region.
	End Rem
	Field width:Float

	Rem
	bbdoc: Logical height of this object or region.
	End Rem
	Field height:Float

	Rem
	bbdoc: Horizontal origin of the image region within its shared source.
	End Rem
	Field sourceX:Float

	Rem
	bbdoc: Vertical origin of the image region within its shared source.
	End Rem
	Field sourceY:Float

	Rem
	bbdoc: Width of the source image crop in pixels.
	End Rem
	Field sourceWidth:Float

	Rem
	bbdoc: Height of the source image crop in pixels.
	End Rem
	Field sourceHeight:Float

	Rem
	bbdoc: Whether the background repeats to cover its drawing area.
	End Rem
	Field repeat:Int

	Rem
	bbdoc: Normalized horizontal artwork pivot.
	End Rem
	Field pivotX:Float

	Rem
	bbdoc: Normalized vertical artwork pivot.
	End Rem
	Field pivotY:Float
End Type

Rem
bbdoc: A native tilemap retaining LDtk level, layer, entity and background metadata.
End Rem
Type TLDTKMap Extends TTileMap

	Rem
	bbdoc: Logical source filename used to resolve relative resources.
	End Rem
	Field sourcePath:String

	Rem
	bbdoc: Background colour string retained from the editor document.
	End Rem
	Field backgroundColor:String

	Rem
	bbdoc: Imported background image and placement settings.
	End Rem
	Field background:TLDTKBackground

	Rem
	bbdoc: Internal lookup associating native layers with imported LDtk metadata.
	End Rem
	Field _layerInfo:TMap=New TMap

	Rem
	bbdoc: Calculates the layer offset for the current view, including parallax.
	param: Layer to inspect or draw; Null uses the map's default grid where supported.
	param: Captured drawing transform used for view and map conversion.
	param: Virtual dimensions, presentation and clipping settings.
	param: Receives horizontal offset.
	param: Receives vertical offset.
	End Rem
	Method LayerOffsetForView(layer:TTileLayer,transform:TMax2DDrawTransform,view:TMax2DView,ox:Double Var,oy:Double Var) Override
		Local info:TLDTKLayer=TLDTKLayer(_layerInfo.ValueForKey(layer))
		If Not info Then
			Super.LayerOffsetForView(layer,transform,view,ox,oy)
			Return
		End If
		If IsNan(layer.parallaxX) Or IsInf(layer.parallaxX) Or IsNan(layer.parallaxY) Or IsInf(layer.parallaxY) Then Throw "Max2D.LDTK: invalid layer parallax"
		ox=layer.offsetX*layer.drawScale; oy=layer.offsetY*layer.drawScale
		Local cx:Float,cy:Float
		If Not transform.VirtualToLocal(view.x+view.w/2.0,view.y+view.h/2.0,cx,cy) Then Return
		Local px:Double=1-layer.parallaxX,py:Double=1-layer.parallaxY
		ox:+cx*px; oy:+cy*py
		If Not info.parallaxScaling Then
			ox:-info.width*info.grid.TileWidth()*0.5*px
			oy:-info.height*info.grid.TileHeight()*0.5*py
		End If
	End Method

	Rem
	bbdoc: Draws the level background and visible layers at the supplied position.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	param: Elapsed animation time in milliseconds; negative values are treated as zero.
	End Rem
	Method Draw(x:Float=0,y:Float=0,elapsed:Long=0) Override
		Local count:Int
		If background And background.visible Then
			Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
			PushMax2DState()
			Try
				Local state:TMax2DState=canvas.state
				TransformCoordinates(state.ix,state.iy,state.jx,state.jy,x+state.originX,y+state.originY)
				SetOrigin(0,0); SetHandle(0,0); SetTransform()
				Local bg:TLDTKBackground=background
				If bg.repeat Then
					count=TLDTKImageDrawing.DrawRepeated(canvas,bg.image,0,0,level.width,level.height,bg.sourceX,bg.sourceY,bg.sourceWidth,bg.sourceHeight,bg.width,bg.height,bg.pivotX,bg.pivotY)
				Else
					canvas.DrawImageRegion(bg.image,bg.x,bg.y,bg.width,bg.height,bg.sourceX,bg.sourceY,bg.sourceWidth,bg.sourceHeight,0,0)
					count=1
				End If
			Finally
				PopMax2DState()
			End Try
		End If
		Super.Draw(x,y,elapsed)
		drawnImages:+count
	End Method

	Rem
	bbdoc: Imported metadata describing the selected LDtk level.
	End Rem
	Field level:TLDTKLevelInfo

	Rem
	bbdoc: Shared texture atlas containing artwork or glyph images.
	End Rem
	Field atlas:TTextureAtlas

	Rem
	bbdoc: Editor layer metadata in native drawing order.
	End Rem
	Field importedLayers:TLDTKLayer[]

	Rem
	bbdoc: Imported LDtk entity instances.
	End Rem
	Field entities:TLDTKEntity[]

	Rem
	bbdoc: Imported custom fields retaining their original JSON value types.
	End Rem
	Field fields:TLDTKField[]

	Rem
	bbdoc: Returns a named imported field, or Null when absent.
	param: Name used to register or look up the item.
	End Rem
	Method GetField:TLDTKField(name:String)
		Return TLDTKField.Find(fields,name)
	End Method

	Rem
	bbdoc: Finds an imported layer by identifier or IID, returning Null when absent.
	param: Imported layer identifier or IID.
	End Rem
	Method Layer:TLDTKLayer(identifier:String)
		For Local item:TLDTKLayer=EachIn importedLayers
			If item.identifier=identifier Or item.iid=identifier Then Return item
		Next
	End Method

	Rem
	bbdoc: Finds an imported entity by instance identifier, returning Null when absent.
	param: LDtk instance identifier.
	End Rem
	Method Entity:TLDTKEntity(iid:String)
		For Local item:TLDTKEntity=EachIn entities
			If item.iid=iid Then Return item
		Next
	End Method

	' LDtk layers can use different grid sizes. Native artwork is stored as ordered
	' tile objects, allowing stacked tiles and arbitrary exported pixel offsets.

	Rem
	bbdoc: Converts a virtual screen point to a map cell using the active drawing transform.
	param: Horizontal virtual coordinate.
	param: Vertical virtual coordinate.
	param: Receives integer grid column.
	param: Receives integer grid row.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	param: Layer to inspect or draw; Null uses the map's default grid where supported.
	param: Whether to require the point to be inside the clipping viewport as well as the scene.
	End Rem
	Method Pick:Int(virtualX:Float,virtualY:Float,column:Int Var,row:Int Var,x:Float=0,y:Float=0,layer:TTileLayer=Null,checkViewport:Int=True) Override
		If Not layer Then Return Super.Pick(virtualX,virtualY,column,row,x,y,layer,checkViewport)
		column=0; row=0
		For Local info:TLDTKLayer=EachIn importedLayers
			If info.layer<>layer Then Continue
			Local lx:Float,ly:Float
			If Not VirtualToLayer(layer,virtualX,virtualY,lx,ly,x,y,checkViewport) Then Return False
			Return info.grid.LocalToCell(lx,ly,column,row)
		Next
		Return Super.Pick(virtualX,virtualY,column,row,x,y,layer,checkViewport)
	End Method

End Type

Rem
bbdoc: A parsed project whose levels can be loaded separately. Retain and reuse it to choose levels without reparsing the project.
End Rem
Type TLDTKProject

	Rem
	bbdoc: Logical source filename used to resolve relative resources.
	End Rem
	Field sourcePath:String

	Rem
	bbdoc: LDtk JSON format version declared by the project.
	End Rem
	Field jsonVersion:String

	Rem
	bbdoc: Level metadata available before loading each level's artwork.
	End Rem
	Field levels:TLDTKLevelInfo[]

	Rem
	bbdoc: Retained source document or binary font data owned by this object.
	End Rem
	Field data:TJSONObject

	Rem
	bbdoc: Application-supplied pixmaps for named embedded atlas resources.
	End Rem
	Field embeddedAtlases:TTreeMap<String,TPixmap>=New TTreeMap<String,TPixmap>

	Rem
	bbdoc: Application-supplied source pixmaps indexed by LDtk tileset UID.
	End Rem
	Field tilesetPixmaps:TTreeMap<Int,TPixmap>=New TTreeMap<Int,TPixmap>

	Rem
	bbdoc: Supplies replacement pixels for an LDtk tileset UID before loading levels.
	param: LDtk numeric definition identifier.
	param: Source pixel data.
	about: Use this for exported PNGs when the editor tilesheet uses a format your application does not decode. Source rectangles and project paths remain unchanged. Existing loaded maps are unaffected.
	End Rem
	Method SetTilesetPixmap(uid:Int,pixels:TPixmap)
		If Not pixels Then Throw "Max2D.LDTK: tileset pixels are required"
		If Not data Then Throw "Max2D.LDTK: load a project before supplying tileset pixels"
		Local definitions:TJSONArray=TLDTKReader.Array(TLDTKReader.ObjectValue(data.Get("defs")),"tilesets")
		For Local i:Int=0 Until definitions.Size()
			If TLDTKReader.Integer(TLDTKReader.ObjectValue(definitions.Get(i)),"uid",-1)<>uid Then Continue
			tilesetPixmaps.Put(uid,pixels)
			Return
		Next
		Throw "Max2D.LDTK: unknown tileset UID: "+uid
	End Method

	Rem
	bbdoc: Supplies pixels for an embedded-atlas identifier such as LdtkIcons before loading a level.
	param: Name used to register or look up the item.
	param: Source pixel data.
	about: The importer does not bundle LDtk's editor icons. Load pixels with your usual stream/image APIs; ownership of the supplied pixmap remains with the caller.
	End Rem
	Method SetEmbeddedAtlas(name:String,pixels:TPixmap)
		If Not name Or Not pixels Then Throw "Max2D.LDTK: an atlas name and pixels are required"
		embeddedAtlases.Put(name,pixels)
	End Method

	Rem
	bbdoc: Loads LDtk project metadata from a file, stream URL or caller-owned stream.
	param: Filename, stream URL or caller-owned readable stream.
	param: Logical source filename used to resolve relative resources for stream input.
	End Rem
	Function Load:TLDTKProject(source:Object,sourcePath:String="")
		Local project:TLDTKProject=New TLDTKProject
		If Not sourcePath Then sourcePath=String(source)
		If sourcePath Then project.sourcePath=TLDTKReader.NormalizePath(sourcePath)
		Try
			project.data=TLDTKReader.Document(source)
			project.jsonVersion=TLDTKReader.Text(project.data,"jsonVersion")
			If Not project.jsonVersion Then Throw "expected an LDtk project with jsonVersion"
			TLDTKReader.ObjectValue(project.data.Get("defs"))
			Local worlds:TJSONArray=TLDTKReader.Array(project.data,"worlds")
			If worlds.Size() Then
				For Local i:Int=0 Until worlds.Size()
					Local world:TJSONObject=TLDTKReader.ObjectValue(worlds.Get(i))
					project.AddLevels(TLDTKReader.Array(world,"levels"),TLDTKReader.Text(world,"iid"))
				Next
			Else
				project.AddLevels(TLDTKReader.Array(project.data,"levels"),TLDTKReader.Text(project.data,"dummyWorldIid"))
			End If
			If Not project.levels.Length Then Throw "project has no levels"
			Return project
		Catch error:Object
			Throw "Max2D.LDTK: "+sourcePath+": "+error.ToString()
		End Try
	End Function

	Rem
	bbdoc: Adds level metadata from a project's JSON level array.
	param: Source array of level metadata.
	param: Instance identifier of the world containing the levels.
	End Rem
	Method AddLevels(items:TJSONArray,worldIID:String)
		If levels.Length+Long(items.Size())>65536 Then Throw "too many levels"
		For Local i:Int=0 Until items.Size()
			Local node:TJSONObject=TLDTKReader.ObjectValue(items.Get(i)),info:TLDTKLevelInfo=New TLDTKLevelInfo
			info.data=node; info.worldIID=worldIID
			Local adjacent:TJSONArray=TLDTKReader.Array(node,"__neighbours")
			If adjacent.Size()>65536 Then Throw "too many level neighbours"
			info.neighbours=New TLDTKNeighbour[adjacent.Size()]
			For Local n:Int=0 Until adjacent.Size()
				Local neighbour:TJSONObject=TLDTKReader.ObjectValue(adjacent.Get(n)),entry:TLDTKNeighbour=New TLDTKNeighbour
				entry.direction=TLDTKReader.Text(neighbour,"dir"); entry.levelIID=TLDTKReader.Text(neighbour,"levelIid")
				If Not entry.direction Or Not entry.levelIID Then Throw "neighbour requires direction and levelIid"
				info.neighbours[n]=entry
			Next
			info.identifier=TLDTKReader.Text(node,"identifier"); info.iid=TLDTKReader.Text(node,"iid")
			If Not info.iid Or Not info.identifier Then Throw "level requires identifier and iid"
			For Local other:TLDTKLevelInfo=EachIn levels
				If other.iid=info.iid Then Throw "duplicate level iid"
			Next
			info.uid=TLDTKReader.Integer(node,"uid",0)
			info.width=TLDTKReader.Integer(node,"pxWid",0,1,1000000); info.height=TLDTKReader.Integer(node,"pxHei",0,1,1000000)
			info.worldX=TLDTKReader.Integer(node,"worldX",0); info.worldY=TLDTKReader.Integer(node,"worldY",0)
			info.worldDepth=TLDTKReader.Integer(node,"worldDepth",0)
			Local external:String=TLDTKReader.Text(node,"externalRelPath")
			If external Then info.externalPath=TLDTKReader.Resolve(ExtractDir(sourcePath),external)
			levels=levels[..levels.Length+1]; levels[levels.Length-1]=info
		Next
	End Method

	Rem
	bbdoc: Finds level metadata by IID or unique identifier without loading resources. Unknown selectors return Null; ambiguous names throw.
	param: Level identifier or IID; empty is accepted only for a single-level project.
	End Rem
	Method Level:TLDTKLevelInfo(selector:String="")
		Local selected:TLDTKLevelInfo
		If Not selector Then
			If levels.Length<>1 Then Throw "Max2D.LDTK: select a level identifier or IID from this multi-level project"
			selected=levels[0]
		Else
			For Local info:TLDTKLevelInfo=EachIn levels
				If info.iid=selector Then selected=info; Exit
			Next
			If Not selected Then
				For Local info:TLDTKLevelInfo=EachIn levels
					If info.identifier<>selector Then Continue
					If selected Then Throw "Max2D.LDTK: ambiguous level name; use its IID"
					selected=info
				Next
			End If
		End If
		Return selected
	End Method

	Rem
	bbdoc: Finds level metadata by exact IID only. Returns Null if absent and performs no file access.
	param: LDtk instance identifier.
	End Rem
	Method LevelByIID:TLDTKLevelInfo(iid:String)
		For Local info:TLDTKLevelInfo=EachIn levels
			If info.iid=iid Then Return info
		Next
	End Method

	Rem
	bbdoc: Loads a level by identifier or IID. Omitting the selector is allowed only for a single-level project.
	param: Level identifier or IID; empty is accepted only for a single-level project.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	param: Whether to load entity artwork in addition to gameplay geometry and fields.
	about: Set entityArtwork=False to retain entity metadata and query rectangles without resolving or drawing their images.
	End Rem
	Method LoadLevel:TLDTKMap(selector:String="",flags:Int=FILTEREDIMAGE,entityArtwork:Int=True)
		Local selected:TLDTKLevelInfo=Level(selector)
		If Not selected Then Throw "Max2D.LDTK: level not found: "+selector
		Local reader:TLDTKReader=New TLDTKReader
		Return reader.Read(Self,selected,flags,entityArtwork)
	End Method

End Type

Rem
bbdoc: Loads one LDtk level from a file, stream URL or caller-owned stream.
param: Filename, stream URL or caller-owned readable stream.
param: Level identifier or IID; empty is accepted only for a single-level project.
param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
param: Logical source filename used to resolve relative resources for stream input.
param: Whether to load entity artwork in addition to gameplay geometry and fields.
about: Set sourcePath to the logical project filename for relative resources when supplying a stream. entityArtwork=False skips entity images while retaining their gameplay rectangles and fields.
End Rem
Function LoadLDTKMap:TLDTKMap(source:Object,level:String="",flags:Int=FILTEREDIMAGE,sourcePath:String="",entityArtwork:Int=True)
	Return TLDTKProject.Load(source,sourcePath).LoadLevel(level,flags,entityArtwork)
End Function

Private
Type TLDTKLoader Extends TTileMapLoader
	Method CanLoad:Int(path:String) Override
		Return ExtractExt(path).ToLower()="ldtk"
	End Method

	Method Load:TTileMap(source:Object,flags:Int,sourcePath:String) Override
		Return LoadLDTKMap(source,"",flags,sourcePath)
	End Method

End Type

Global _ldtkLoader:TTileMapLoader=New TLDTKLoader
