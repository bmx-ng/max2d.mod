
Rem
bbdoc: Optional Tiled decompressors register on construction, normally once during module initialization.
about: Decode must fill the supplied output buffer exactly and consume all input, returning False on malformed data or size mismatch. Providers must not resize either array. Registration and map loading are not synchronized.
End Rem
Type TTiledDecompressor Abstract

	Rem
	bbdoc: Head of the registered Tiled decompressor chain.
	End Rem
	Global decompressors:TTiledDecompressor

	Rem
	bbdoc: Next registered decompressor provider.
	End Rem
	Field nextDecompressor:TTiledDecompressor

	Rem
	bbdoc: Registers this decompressor for subsequent Tiled map loads.
	End Rem
	Method New()
		nextDecompressor=decompressors; decompressors=Self
	End Method

	Rem
	bbdoc: Reports whether this provider handles the named Tiled compression method.
	param: Tiled compression name, such as zlib, gzip or zstd.
	End Rem
	Method CanDecode:Int(compression:String) Abstract

	Rem
	bbdoc: Decodes compressed bytes into the caller's exactly sized destination buffer.
	param: Source data or object to read.
	param: Caller-owned output byte buffer of the required decoded size.
	End Rem
	Method Decode:Int(source:Byte[],destination:Byte[]) Abstract
End Type

Rem
bbdoc: Decodes Tiled layer bytes through the registered compression providers.
param: Tiled compression name, such as zlib, gzip or zstd.
param: Source data or object to read.
param: Exact number of decoded bytes required.
End Rem
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
