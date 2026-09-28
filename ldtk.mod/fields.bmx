Rem
bbdoc: A field's exported JSON and optional typed accessors. Treat the JSON and returned cached values as read-only.
about: Structured values and array items are converted lazily and retained. Wrong types throw; structured null values return Null. String/FilePath access returns exported text, not a resolved resource path.
End Rem
Type TLDTKField
	Field name:String,valueType:String,value:TJSON
	Private
	Field _point:TLDTKPoint,_tile:TLDTKTileReference,_reference:TLDTKEntityReference
	Field _items:TLDTKField[]
	Public
	Function Find:TLDTKField(fields:TLDTKField[],name:String)
		For Local item:TLDTKField=EachIn fields
			If item.name=name Then Return item
		Next
	End Function
	Method IsNull:Int()
		Return Not value Or TJSONNull(value)<>Null
	End Method
	Method AsString:String()
		If Not TJSONString(value) Then Fail("string")
		Return TJSONString(value).Value()
	End Method
	Method AsInt:Long()
		If Not TJSONInteger(value) Then Fail("integer")
		Return TJSONInteger(value).Value()
	End Method
	Method AsFloat:Double()
		If TJSONInteger(value) Then Return Double(TJSONInteger(value).Value())
		If Not TJSONReal(value) Then Fail("number")
		Return TJSONReal(value).Value()
	End Method
	Method AsBool:Int()
		If Not TJSONBool(value) Then Fail("boolean")
		Return TJSONBool(value).isTrue
	End Method
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
	Field column:Int,row:Int
End Type

Rem
bbdoc: A Tile field's source rectangle and LDtk tileset UID. Reading it does not load the tilesheet.
End Rem
Type TLDTKTileReference
	Field tilesetUID:Int,x:Int,y:Int,width:Int,height:Int
End Type
