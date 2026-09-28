SuperStrict
Framework Max2D.SDL3RenderMax2D
Import BRL.StandardIO
Try
	Graphics 32,32,0,0
	If Max2DSupportsImageFlags(MIPMAPPEDIMAGE) Then Throw "SDL must reject mipmap support"
	Local image:TImage=CreateImage(8,8,1,MIPMAPPEDIMAGE)
	Local rejected:Int
	Try
		DrawImage(image,0,0)
	Catch error:Object
		rejected=True
	End Try
	If Not rejected Then Throw "SDL must reject mipmapped draws"
	If Max2DStats().textureCreations<>0 Then Throw "Unsupported request created a native texture"
	EndGraphics()
	Print "Max2D SDL mipmap capability test passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
