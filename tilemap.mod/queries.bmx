Struct STileQueryCell
	Field column:Int,row:Int,tile:Int
	Field flip:ETileFlip
End Struct

Rem
bbdoc: Reusable query output. Only cells[0 Until count] are valid. Results are snapshots in unspecified order.
End Rem
Type TTileQueryResult
	Field cells:STileQueryCell[]
	Field count:Int
	Method Clear()
		count=0
	End Method
	Method Add(column:Int,row:Int,tile:Int,flip:ETileFlip)
		If count=cells.Length Then cells=cells[..Max(16,count*2)]
		cells[count].column=column; cells[count].row=row
		cells[count].tile=tile; cells[count].flip=flip
		count:+1
	End Method
End Type
