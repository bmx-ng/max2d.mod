
Rem
bbdoc: A field's exported JSON and optional typed accessors. Treat the JSON and returned cached values as read-only.
about: Structured values and array items are converted lazily and retained. Wrong types throw; structured null values return Null. String/FilePath access returns exported text, not a resolved resource path.
End Rem
Type TLDTKField

	Rem
	bbdoc: Name used to identify this entry.
	End Rem
	Field name:String

	Rem
	bbdoc: Original document's property or field type name.
	End Rem
	Field valueType:String

	Rem
	bbdoc: Imported JSON field value; consult valueType before converting it.
	End Rem
	Field value:TJSON
	Private
	Field _point:TLDTKPoint,_tile:TLDTKTileReference,_reference:TLDTKEntityReference
	Field _items:TLDTKField[]
	Public

	Rem
	bbdoc: Finds a named field in an imported field array, returning Null when absent.
	param: Imported custom fields to search.
	param: Name used to register or look up the item.
	End Rem
	Function Find:TLDTKField(fields:TLDTKField[],name:String)
		For Local item:TLDTKField=EachIn fields
			If item.name=name Then Return item
		Next
	End Function

	Rem
	bbdoc: Reports whether the imported field contains JSON null.
	End Rem
	Method IsNull:Int()
		Return Not value Or TJSONNull(value)<>Null
	End Method

	Rem
	bbdoc: Reads the stored value as a string.
	End Rem
	Method AsString:String()
		If Not TJSONString(value) Then Fail("string")
		Return TJSONString(value).Value()
	End Method

	Rem
	bbdoc: Reads the imported field as an integer.
	End Rem
	Method AsInt:Long()
		If Not TJSONInteger(value) Then Fail("integer")
		Return TJSONInteger(value).Value()
	End Method

	Rem
	bbdoc: Reads the imported field as a floating-point number.
	End Rem
	Method AsFloat:Double()
		If TJSONInteger(value) Then Return Double(TJSONInteger(value).Value())
		If Not TJSONReal(value) Then Fail("number")
		Return TJSONReal(value).Value()
	End Method

	Rem
	bbdoc: Reads the stored value as a Boolean.
	End Rem
	Method AsBool:Int()
		If Not TJSONBool(value) Then Fail("boolean")
		Return TJSONBool(value).isTrue
	End Method

	Rem
	bbdoc: Reads the field as an LDtk grid-point reference.
	End Rem
	Method AsPoint:TLDTKPoint()
		RequireType("Point")
		If IsNull() Then Return Null
		If Not _point Then
			Local node:TJSONObject=TLDTKReader.ObjectValue(value),result:TLDTKPoint=New TLDTKPoint
			result.column=TLDTKReader.IntValue(node.Get("cx")); result.row=TLDTKReader.IntValue(node.Get("cy"))
			_point=result
		End If
		Return _point
	End Method

	Rem
	bbdoc: Reads the field as an LDtk tileset rectangle reference.
	End Rem
	Method AsTile:TLDTKTileReference()
		RequireType("Tile")
		If IsNull() Then Return Null
		If Not _tile Then
			Local node:TJSONObject=TLDTKReader.ObjectValue(value),result:TLDTKTileReference=New TLDTKTileReference
			result.tilesetUID=TLDTKReader.IntValue(node.Get("tilesetUid"),0,2147483647)
			result.x=TLDTKReader.IntValue(node.Get("x"),0); result.y=TLDTKReader.IntValue(node.Get("y"),0)
			result.width=TLDTKReader.IntValue(node.Get("w"),1); result.height=TLDTKReader.IntValue(node.Get("h"),1)
			_tile=result
		End If
		Return _tile
	End Method

	Rem
	bbdoc: Reads the field as an LDtk entity reference.
	End Rem
	Method AsEntityReference:TLDTKEntityReference()
		RequireType("EntityRef")
		If IsNull() Then Return Null
		If Not _reference Then
			Local node:TJSONObject=TLDTKReader.ObjectValue(value),result:TLDTKEntityReference=New TLDTKEntityReference
			result.worldIID=TLDTKReader.Text(node,"worldIid"); result.levelIID=TLDTKReader.Text(node,"levelIid")
			result.layerIID=TLDTKReader.Text(node,"layerIid"); result.entityIID=TLDTKReader.Text(node,"entityIid")
			If Not result.worldIID Or Not result.levelIID Or Not result.layerIID Or Not result.entityIID Then Fail("complete entity reference")
			_reference=result
		End If
		Return _reference
	End Method

	Rem
	bbdoc: Returns the number of array elements, without converting or copying them.
	End Rem
	Method Count:Int()
		If Not valueType.StartsWith("Array<") Or Not valueType.EndsWith(">") Or Not TJSONArray(value) Then Fail("array")
		Return TJSONArray(value).Size()
	End Method

	Rem
	bbdoc: Returns a cached field wrapper for one array element. Use its scalar/structured accessors or IsNull. Out-of-range indices throw.
	param: Zero-based index.
	End Rem
	Method Item:TLDTKField(index:Int)
		Local count:Int=Count()
		If index<0 Or index>=count Then Throw "Max2D.LDTK: field '"+name+"' array index out of range"
		If Not _items Then _items=New TLDTKField[count]
		If Not _items[index] Then
			Local item:TLDTKField=New TLDTKField
			item.name=name+"["+index+"]"; item.valueType=valueType[6..valueType.Length-1]; item.value=TJSONArray(value).Get(index)
			_items[index]=item
		End If
		Return _items[index]
	End Method

	Private
	Method RequireType(expected:String)
		If valueType<>expected Then Fail(expected)
	End Method

	Method Fail(expected:String)
		Throw "Max2D.LDTK: field '"+name+"' expected "+expected+" (exported type: "+valueType+")"
	End Method

End Type

Rem
bbdoc: A Point field's grid coordinates. Convert through the appropriate layer grid; these are not pixel coordinates.
End Rem
Type TLDTKPoint

	Rem
	bbdoc: Integer cell column.
	End Rem
	Field column:Int

	Rem
	bbdoc: Integer cell row.
	End Rem
	Field row:Int
End Type

Rem
bbdoc: A Tile field's source rectangle and LDtk tileset UID. Reading it does not load the tilesheet.
End Rem
Type TLDTKTileReference

	Rem
	bbdoc: Numeric UID of the source LDtk tileset.
	End Rem
	Field tilesetUID:Int

	Rem
	bbdoc: Left edge of the referenced rectangle in tileset pixels.
	End Rem
	Field x:Int

	Rem
	bbdoc: Top edge of the referenced rectangle in tileset pixels.
	End Rem
	Field y:Int

	Rem
	bbdoc: Width of the referenced rectangle in tileset pixels.
	End Rem
	Field width:Int

	Rem
	bbdoc: Height of the referenced rectangle in tileset pixels.
	End Rem
	Field height:Int
End Type
