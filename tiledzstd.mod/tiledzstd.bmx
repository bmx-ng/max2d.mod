SuperStrict
Rem
bbdoc: Optional zstd decompression for Tiled maps. Import this module to register support.
End Rem
Module Max2D.TiledZstd
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"
Import Max2D.Tiled
Import Archive.Zstd
Import "decode.c"

Private
Extern "C"
	Function max2d_tiled_zstd_decode:Int(source:Byte Ptr,sourceSize:Int,destination:Byte Ptr,destinationSize:Int)
End Extern

Type TTiledZstdDecompressor Extends TTiledDecompressor
	Method CanDecode:Int(compression:String) Override
		Return compression="zstd"
	End Method
	Method Decode:Int(source:Byte[],destination:Byte[]) Override
		Return max2d_tiled_zstd_decode(source,source.Length,destination,destination.Length)
	End Method
End Type

Global _tiledZstd:TTiledDecompressor=New TTiledZstdDecompressor
