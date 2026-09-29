
Rem
bbdoc: Native value kind stored in a tilemap property.
End Rem
Enum ETilePropertyType

	Rem
	bbdoc: Boolean property value.
	End Rem
	Boolean

	Rem
	bbdoc: Signed integer property value.
	End Rem
	Integer

	Rem
	bbdoc: Floating-point property value.
	End Rem
	Number

	Rem
	bbdoc: String property value.
	End Rem
	Text

	Rem
	bbdoc: Named class containing nested property members.
	End Rem
	ClassValue
End Enum

Rem
bbdoc: Typed scalar or class property. Getters reject a mismatched type; class members are mutable.
End Rem
Type TTileProperty
	Private
	Field _kind:ETilePropertyType
	Field _integer:Long
	Field _number:Double
	Field _className:String
	Field _members:TTileProperties
	Field _text:String
	Field _valueType:String,_customType:String
	Public

	Rem
	bbdoc: Serialized storage type, when supplied by an importer (for example file or object).
	End Rem
	Method ValueType:String()
		Return _valueType
	End Method

	Rem
	bbdoc: Custom schema or enum name, when supplied by an importer.
	End Rem
	Method CustomType:String()
		Return _customType
	End Method

	Rem
	bbdoc: Returns a property copy carrying imported value-type and custom-type metadata.
	param: Original format's property type name.
	param: Original format's custom class or enum name.
	End Rem
	Method WithMetadata:TTileProperty(valueType:String,customType:String)
		Local result:TTileProperty=New TTileProperty
		result._kind=_kind; result._integer=_integer; result._number=_number; result._text=_text
		result._className=_className
		If _members Then result._members=_members.Copy()
		result._valueType=valueType; result._customType=customType
		Return result
	End Method

	Rem
	bbdoc: Creates a Boolean tile property.
	param: Value to read, convert or store.
	End Rem
	Function FromBool:TTileProperty(value:Int)
		Local entry:TTileProperty=New TTileProperty
		entry._kind=ETilePropertyType.Boolean; entry._integer=value<>0
		Return entry
	End Function

	Rem
	bbdoc: Creates an integer tile property.
	param: Value to read, convert or store.
	End Rem
	Function FromLong:TTileProperty(value:Long)
		Local entry:TTileProperty=New TTileProperty
		entry._kind=ETilePropertyType.Integer; entry._integer=value
		Return entry
	End Function

	Rem
	bbdoc: Creates a floating-point tile property.
	param: Value to read, convert or store.
	End Rem
	Function FromDouble:TTileProperty(value:Double)
		Local entry:TTileProperty=New TTileProperty
		entry._kind=ETilePropertyType.Number; entry._number=value
		Return entry
	End Function

	Rem
	bbdoc: Creates a string tile property.
	param: Value to read, convert or store.
	End Rem
	Function FromString:TTileProperty(value:String)
		Local entry:TTileProperty=New TTileProperty
		entry._kind=ETilePropertyType.Text; entry._text=value
		Return entry
	End Function

	Rem
	bbdoc: Creates a class-valued property with named members.
	param: Name of the imported custom class.
	param: Named members of the class-valued property.
	End Rem
	Function FromClass:TTileProperty(className:String,members:TTileProperties)
		' An empty name represents a structured value whose schema name is unavailable.
		If Not members Then Throw "Max2D tilemap: class members are required"
		Local entry:TTileProperty=New TTileProperty
		entry._kind=ETilePropertyType.ClassValue; entry._className=className; entry._members=members.Copy()
		Return entry
	End Function

	Rem
	bbdoc: Returns the class name of a class-valued property.
	End Rem
	Method ClassName:String()
		If _kind<>ETilePropertyType.ClassValue Then Throw "Max2D tilemap: property type mismatch"
		Return _className
	End Method

	Rem
	bbdoc: Returns the members of a class-valued property.
	End Rem
	Method AsClass:TTileProperties()
		If _kind<>ETilePropertyType.ClassValue Then Throw "Max2D tilemap: property type mismatch"
		Return _members
	End Method

	Rem
	bbdoc: Returns a copy that can be modified independently of this object's scalar settings.
	param: Fullscreen colour depth; zero requests a window.
	End Rem
	Method Copy:TTileProperty(depth:Int=0)
		If _kind<>ETilePropertyType.ClassValue Then Return Self
		Local result:TTileProperty=New TTileProperty
		result._kind=_kind; result._className=_className; result._members=_members.Copy(depth+1)
		result._valueType=_valueType; result._customType=_customType
		Return result
	End Method

	Rem
	bbdoc: Merges compatible class values recursively, applying the supplied overrides.
	param: Property values that take precedence over existing values.
	param: Current nested-class depth, checked against recursion limits.
	End Rem
	Method WithOverrides:TTileProperty(overrides:TTileProperty,depth:Int=0)
		If _kind<>ETilePropertyType.ClassValue Or overrides._kind<>ETilePropertyType.ClassValue Or _className<>overrides._className Then Return overrides.Copy(depth)
		Local result:TTileProperty=Copy(depth)
		result._members.Overlay(overrides._members,depth+1)
		Return result
	End Method

	Rem
	bbdoc: Returns this property's native value kind.
	End Rem
	Method Kind:ETilePropertyType()
		Return _kind
	End Method

	Rem
	bbdoc: Reads the stored value as a Boolean.
	End Rem
	Method AsBool:Int()
		If _kind<>ETilePropertyType.Boolean Then Throw "Max2D tilemap: property type mismatch"
		Return Int(_integer)
	End Method

	Rem
	bbdoc: Reads the property as an integer.
	End Rem
	Method AsLong:Long()
		If _kind<>ETilePropertyType.Integer Then Throw "Max2D tilemap: property type mismatch"
		Return Long(_integer)
	End Method

	Rem
	bbdoc: Reads the property as a floating-point number.
	End Rem
	Method AsDouble:Double()
		If _kind<>ETilePropertyType.Number Then Throw "Max2D tilemap: property type mismatch"
		Return Double(_number)
	End Method

	Rem
	bbdoc: Reads the stored value as a string.
	End Rem
	Method AsString:String()
		If _kind<>ETilePropertyType.Text Then Throw "Max2D tilemap: property type mismatch"
		Return String(_text)
	End Method

End Type

Rem
bbdoc: Case-sensitive application metadata. Storage is allocated on the first write.
End Rem
Type TTileProperties
	Private
	Field _values:TTreeMap<String,TTileProperty>
	Public

	Rem
	bbdoc: Stores an independent snapshot of a named structured value.
	param: Name used to register or look up the item.
	param: Name of the imported custom class.
	param: Named members of the class-valued property.
	End Rem
	Method SetClass(name:String,className:String,members:TTileProperties)
		If Not name Then Throw "Max2D tilemap: empty property name"
		Local entry:TTileProperty=TTileProperty.FromClass(className,members)
		If Not _values Then _values=New TTreeMap<String,TTileProperty>
		_values.Put(name,entry)
	End Method

	Rem
	bbdoc: Gets the members of a named class-valued property.
	param: Name used to register or look up the item.
	End Rem
	Method GetClass:TTileProperties(name:String)
		Local entry:TTileProperty=Get(name)
		If entry Then Return entry.AsClass()
		Return Null
	End Method

	Rem
	bbdoc: Returns a deep copy of nested class members. Scalar values are immutable and shared.
	param: Fullscreen colour depth; zero requests a window.
	End Rem
	Method Copy:TTileProperties(depth:Int=0)
		If depth>64 Then Throw "Max2D tilemap: properties nested too deeply"
		Local result:TTileProperties=New TTileProperties
		If Not _values Then Return result
		result._values=New TTreeMap<String,TTileProperty>
		For Local name:String=EachIn _values.Keys()
			Local value:TTileProperty=Get(name)
			value=value.Copy(depth)
			result._values.Put(name,value)
		Next
		Return result
	End Method

	Rem
	bbdoc: Copies overrides into this collection, recursively merging class values with matching class names.
	param: Property values that take precedence over existing values.
	param: Fullscreen colour depth; zero requests a window.
	End Rem
	Method Overlay(overrides:TTileProperties,depth:Int=0)
		If depth>64 Then Throw "Max2D tilemap: properties nested too deeply"
		If Not overrides Or Not overrides._values Then Return
		If Not _values Then _values=New TTreeMap<String,TTileProperty>
		For Local name:String=EachIn overrides._values.Keys()
			Local incoming:TTileProperty=overrides.Get(name),existing:TTileProperty=Get(name)
			If existing Then
				_values.Put(name,existing.WithOverrides(incoming,depth))
			Else
				_values.Put(name,incoming.Copy(depth))
			End If
		Next
	End Method

	Rem
	bbdoc: Materializes independent class defaults, leaving scalar inheritance to the owning object.
	param: Class defaults inherited when no instance override is supplied.
	End Rem
	Method InheritClasses(defaults:TTileProperties)
		If Not defaults Or Not defaults._values Then Return
		For Local name:String=EachIn defaults._values.Keys()
			Local fallback:TTileProperty=defaults.Get(name),existing:TTileProperty=Get(name)
			If fallback.Kind()<>ETilePropertyType.ClassValue Then Continue
			If Not _values Then _values=New TTreeMap<String,TTileProperty>
			If existing Then
				_values.Put(name,fallback.WithOverrides(existing))
			Else
				_values.Put(name,fallback.Copy())
			End If
		Next
	End Method

	Rem
	bbdoc: Returns a snapshot of the property names; intended for metadata processing.
	End Rem
	Method Names:String[]()
		If Not _values Then Return New String[0]
		Local result:String[]=New String[_values.Count()],index:Int
		For Local name:String=EachIn _values.Keys()
			result[index]=name; index:+1
		Next
		Return result
	End Method

	Rem
	bbdoc: Stores a typed property under a name.
	param: Name used to register or look up the item.
	param: Value to read, convert or store.
	End Rem
	Method SetValue(name:String,value:TTileProperty)
		If Not name Or Not value Then Throw "Max2D tilemap: property name and value are required"
		If Not _values Then _values=New TTreeMap<String,TTileProperty>
		_values.Put(name,value.Copy())
	End Method

	Rem
	bbdoc: Gets a named typed property, or Null when absent.
	param: Name used to register or look up the item.
	End Rem
	Method Get:TTileProperty(name:String)
		Local value:TTileProperty
		If _values Then _values.TryGetValue(name,value)
		Return value
	End Method

	Rem
	bbdoc: Reports whether a property name exists.
	param: Name used to register or look up the item.
	End Rem
	Method Contains:Int(name:String)
		Return Get(name)<>Null
	End Method

	Rem
	bbdoc: Removes a named property and reports whether it existed.
	param: Name used to register or look up the item.
	End Rem
	Method Remove:Int(name:String)
		If _values Then Return _values.Remove(name)
		Return False
	End Method

	Rem
	bbdoc: Removes every property from this collection.
	End Rem
	Method Clear()
		_values=Null
	End Method

	Rem
	bbdoc: Stores a named Boolean property.
	param: Name used to register or look up the item.
	param: Value to read, convert or store.
	End Rem
	Method SetBool(name:String,value:Int)
		If Not name Then Throw "Max2D tilemap: empty property name"
		Local entry:TTileProperty=TTileProperty.FromBool(value)
		If Not _values Then _values=New TTreeMap<String,TTileProperty>
		_values.Put(name,entry)
	End Method

	Rem
	bbdoc: Gets a Boolean property or the supplied fallback when absent.
	param: Name used to register or look up the item.
	param: Value to return when the requested item is absent.
	End Rem
	Method GetBool:Int(name:String,fallback:Int=False)
		Local value:TTileProperty=Get(name)
		If value Then Return value.AsBool()
		Return fallback
	End Method

	Rem
	bbdoc: Stores a named integer property.
	param: Name used to register or look up the item.
	param: Value to read, convert or store.
	End Rem
	Method SetLong(name:String,value:Long)
		If Not name Then Throw "Max2D tilemap: empty property name"
		Local entry:TTileProperty=TTileProperty.FromLong(value)
		If Not _values Then _values=New TTreeMap<String,TTileProperty>
		_values.Put(name,entry)
	End Method

	Rem
	bbdoc: Gets an integer property or the supplied fallback when absent.
	param: Name used to register or look up the item.
	param: Value to return when the requested item is absent.
	End Rem
	Method GetLong:Long(name:String,fallback:Long=0)
		Local value:TTileProperty=Get(name)
		If value Then Return value.AsLong()
		Return fallback
	End Method

	Rem
	bbdoc: Stores a named floating-point property.
	param: Name used to register or look up the item.
	param: Value to read, convert or store.
	End Rem
	Method SetDouble(name:String,value:Double)
		If Not name Then Throw "Max2D tilemap: empty property name"
		Local entry:TTileProperty=TTileProperty.FromDouble(value)
		If Not _values Then _values=New TTreeMap<String,TTileProperty>
		_values.Put(name,entry)
	End Method

	Rem
	bbdoc: Gets a floating-point property or the supplied fallback when absent.
	param: Name used to register or look up the item.
	param: Value to return when the requested item is absent.
	End Rem
	Method GetDouble:Double(name:String,fallback:Double=0)
		Local value:TTileProperty=Get(name)
		If value Then Return value.AsDouble()
		Return fallback
	End Method

	Rem
	bbdoc: Stores a named string property.
	param: Name used to register or look up the item.
	param: Value to read, convert or store.
	End Rem
	Method SetString(name:String,value:String)
		If Not name Then Throw "Max2D tilemap: empty property name"
		Local entry:TTileProperty=TTileProperty.FromString(value)
		If Not _values Then _values=New TTreeMap<String,TTileProperty>
		_values.Put(name,entry)
	End Method

	Rem
	bbdoc: Gets a string property or the supplied fallback when absent.
	param: Name used to register or look up the item.
	param: Value to return when the requested item is absent.
	End Rem
	Method GetString:String(name:String,fallback:String="")
		Local value:TTileProperty=Get(name)
		If value Then Return value.AsString()
		Return fallback
	End Method

End Type
