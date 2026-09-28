Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function

Try
	Local path:String=AppArgs[1]
	If ZSTD_ENABLED Then
		For Local file:String=EachIn ["zstd.tmx","zstd.tmj","zstd-chunks.tmj"]
			Local stream:TStream=ReadStream(path+"/"+file)
			Local map:TTiledMap
			Try
				map=TTiledMap(LoadTileMap(stream,0,path+"/"+file))
				Check(stream.Pos()>0,"Caller-owned stream remains open")
			Finally
				stream.Close()
			End Try
			Local layer:TTileLayer=map.layers[0],x:Int,y:Int
			If map.infinite Then x=-2; y=-2
			Check(layer.CellCount()=4 And layer.Cell(x,y)>0,"Decoded cells: "+file)
			Check(layer.CellFlip(x+1,y)=ETileFlip.Horizontal And layer.CellFlip(x,y+1)=ETileFlip.Vertical,"Decoded unsigned GIDs: "+file)
		Next
		For Local suffix:String=EachIn ["truncated","corrupt","trailing","short","excess"]
			Local message:String
			Try
				LoadTiledMap(path+"/zstd-"+suffix+".tmx")
			Catch error:Object
				message=error.ToString()
			End Try
			Check(message.Contains("invalid or incorrectly sized compressed tile data: zstd"),"Reject "+suffix+": "+message)
		Next
		Print "Registered zstd tests passed"
	Else
		Local message:String
		Try
			LoadTiledMap(path+"/zstd.tmx")
		Catch error:Object
			message=error.ToString()
		End Try
		Check(message.Contains("no registered Tiled decompressor for 'zstd'") And message.Contains("Max2D.TiledZstd"),"Missing provider diagnostic: "+message)
		Print "Missing zstd provider test passed"
	End If
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
