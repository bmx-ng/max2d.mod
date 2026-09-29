
Rem
bbdoc: Cell coordinates, tile ID and transform flags returned by a tile query.
End Rem
Struct STileQueryCell

	Rem
	bbdoc: Integer cell column.
	End Rem
	Field column:Int

	Rem
	bbdoc: Integer cell row.
	End Rem
	Field row:Int

	Rem
	bbdoc: Native tile identifier; zero means no tile artwork.
	End Rem
	Field tile:Int

	Rem
	bbdoc: Reflection and rotation flags applied to tile artwork.
	End Rem
	Field flip:ETileFlip
End Struct

Rem
bbdoc: Reusable query output. Only cells[0 Until count] are valid. Results are snapshots in unspecified order.
End Rem
Type TTileQueryResult

	Rem
	bbdoc: Reusable result storage; only entries below count are populated.
	End Rem
	Field cells:STileQueryCell[]

	Rem
	bbdoc: Number of populated entries; backing storage may have extra capacity.
	End Rem
	Field count:Int

	Rem
	bbdoc: Clears tile query results while retaining reusable storage.
	End Rem
	Method Clear()
		count=0
	End Method

	Rem
	bbdoc: Appends a cell and its tile metadata to the query result.
	param: Integer grid column.
	param: Integer grid row.
	param: Native tile ID; zero represents an empty cell where supported.
	param: Tile reflection and rotation flags.
	End Rem
	Method Add(column:Int,row:Int,tile:Int,flip:ETileFlip)
		If count=cells.Length Then cells=cells[..Max(16,count*2)]
		cells[count].column=column; cells[count].row=row
		cells[count].tile=tile; cells[count].flip=flip
		count:+1
	End Method

End Type
