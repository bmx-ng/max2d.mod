Rem
bbdoc: Optional Tiled decompressors register on construction, normally once during module initialization.
about: Decode must fill the supplied output buffer exactly and consume all input, returning False on malformed data or size mismatch. Providers must not resize either array. Registration and map loading are not synchronized.
End Rem
Type TTiledDecompressor Abstract
	Global decompressors:TTiledDecompressor
	Field nextDecompressor:TTiledDecompressor
	Method New()
		nextDecompressor=decompressors; decompressors=Self
	End Method
	Method CanDecode:Int(compression:String) Abstract
	Method Decode:Int(source:Byte[],destination:Byte[]) Abstract
End Type

Function DecodeTiledData:Byte[](compression:String,source:Byte[],expectedSize:Int)
	If expectedSize<0 Then Throw "invalid decompressed tile data size"
	Local decoder:TTiledDecompressor=TTiledDecompressor.decompressors
	While decoder
		If decoder.CanDecode(compression) Then
			Local destination:Byte[]=New Byte[expectedSize]
			If Not decoder.Decode(source,destination) Then Throw "invalid or incorrectly sized compressed tile data: "+compression
			Return destination
		End If
		decoder=decoder.nextDecompressor
	Wend
	Local hint:String
	If compression="zstd" Then hint="; import Max2D.TiledZstd"
	Throw "no registered Tiled decompressor for '"+compression+"'"+hint
End Function

Private
Type TTiledZlibDecompressor Extends TTiledDecompressor
	Field gzip:Int
	Method New(gzip:Int)
		Self.gzip=gzip
	End Method
	Method CanDecode:Int(compression:String) Override
		If gzip Then Return compression="gzip"
		Return compression="zlib"
	End Method
	Method Decode:Int(source:Byte[],destination:Byte[]) Override
		Return max2d_tiled_inflate(source,source.Length,destination,destination.Length,gzip)
	End Method
End Type
Global _tiledZlib:TTiledDecompressor=New TTiledZlibDecompressor(False)
Global _tiledGzip:TTiledDecompressor=New TTiledZlibDecompressor(True)
Public
