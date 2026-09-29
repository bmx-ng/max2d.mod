SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3RenderMax2D
?

Function TextureSupportName:String(support:ETextureFormatSupport)
	Select support
		Case ETextureFormatSupport.Native
			Return "native"
		Case ETextureFormatSupport.Converted
			Return "converted"
	End Select
	Return "unsupported"
End Function

Graphics 800,480,0
SetVirtualResolution(800,480,VIRTUAL_LETTERBOX)
Local maximumWidth:Int,maximumHeight:Int
GetMax2DTextureSize(maximumWidth,maximumHeight)
Local cache:TRenderImage
If Max2DSupportsRenderImage(64,64,0) Then
	cache=CreateRenderImage(64,64,0)
	SetRenderImage(cache)
	SetClsColor(25,40,60); Cls()
	SetColor(30,190,230); DrawOval(8,8,48,48)
	SetRenderImage(Null)
End If
Local submissions:Long,vertices:Long,updates:Long
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	ResetMax2DStats()
	SetClsColor(15,20,28); Cls()
	SetColor(255,255,255)
	For Local i:Int=0 Until 48
		Local x:Float=20+(i Mod 12)*64,y:Float=200+(i/12)*64
		If cache Then DrawImage(cache,x,y) Else DrawRect(x,y,48,48)
	Next
	FlushMax2D()
	' Read the live counters before drawing this overlay: no snapshot allocation.
	submissions=Max2DStats().submissions
	vertices=Max2DStats().vertices
	updates=Max2DStats().textureUpdates
	DrawText("Max2D capabilities and rendering statistics",20,20)
	DrawText("Texture limits: "+maximumWidth+" x "+maximumHeight+" (0 = unreported)",20,44)
	DrawText("MASKBLEND: "+Max2DSupportsBlend(MASKBLEND)+"   Mipmaps: "+Max2DSupportsImageFlags(MIPMAPPEDIMAGE),20,68)
	DrawText("64 x 64 render image: "+(cache<>Null),20,92)
	DrawText("Coverage storage: "+TextureSupportName(Max2DTextureFormatSupport(PF_A8,FILTEREDIMAGE)),20,116)
	DrawText("Scene batches: "+submissions+"   Vertices: "+vertices+"   Updates: "+updates,20,140)
	DrawText("Overlay excluded. Escape to exit.",20,164)
	Flip()
Wend
EndGraphics()
