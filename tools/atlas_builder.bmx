SuperStrict
Framework Max2D.AtlasIO
Import Max2D.Atlas
Import BRL.StandardIO

Try
	If AppArgs.Length<3 Then
		Print "Usage: atlas_builder [--size N] [--padding N] [--nearest] [--trim] OUTPUT_DIRECTORY IMAGE.png [IMAGE.png ...]"
		Print "Names are input filenames without their extensions. Output must not exist."
		EndWithCode(1)
	End If
	Local builder:TAtlasBuilder=New TAtlasBuilder
	Local output:String
	Local i:Int=1
	While i<AppArgs.Length
		Local argument:String=AppArgs[i]
		Select argument
			Case "--size","--padding"
				i:+1
				If i>=AppArgs.Length Then Throw "Missing value for "+argument
				Local value:String=AppArgs[i]
				If Not value Or value.Length>5 Then Throw "Invalid value for "+argument
				For Local ch:Int=EachIn value
					If ch<48 Or ch>57 Then Throw "Invalid value for "+argument
				Next
				Local number:Long=value.ToLong()
				If number<1 Or number>16384 Then Throw "Value out of range for "+argument
				If argument="--size" Then builder.pageSize=Int(number) Else builder.padding=Int(number)
			Case "--trim"
				builder.trimTransparent=True
			Case "--nearest"
				builder.flags=0
			Default
				If argument.StartsWith("--") Then Throw "Unknown option: "+argument
				If Not output Then
					output=argument
				Else
					Local pixmap:TPixmap=LoadPixmapPNG(argument)
					If Not pixmap Then Throw "Cannot load PNG: "+argument
					builder.Add(pixmap,StripExt(StripDir(argument)))
				End If
		End Select
		i:+1
	Wend
	If Not output Or Not builder.inputs.Length Then Throw "An output directory and at least one PNG are required"
	Local atlas:TTextureAtlas=builder.Build()
	SaveTextureAtlas(atlas,output)
	Print "Saved "+builder.inputs.Length+" images on "+atlas.PageCount()+" pages to "+output
Catch error:Object
	Print error.ToString()
	EndWithCode(1)
End Try
