SuperStrict
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_d3d11
Framework Max2D.GLMax2D
?

AppTitle="Explicit texture conversion"
Graphics(960,420,0)
SetVirtualResolution(960,420,VIRTUAL_LETTERBOX)

' A linear RGB ramp with values up to 4. No GPU readback is needed here.
Local channels:Float[]=New Float[256*128*4]
For Local y:Int=0 Until 128
	For Local x:Int=0 Until 256
		Local value:Float=4.0*x/255.0
		Local offset:Int=(y*256+x)*4
		channels[offset]=value
		channels[offset+1]=value*0.5
		channels[offset+2]=value*0.2
		channels[offset+3]=1
	Next
Next
Local bytes:Byte[]=New Byte[channels.Length*4]
MemCopy(bytes,channels,Size_T(bytes.Length))
Local data:TTextureData=TTextureData.Create([TTextureLevel.Create(256,128,PF_RGBA32F,bytes)])
Local options:TTexturePixmapOptions=New TTexturePixmapOptions
options.outputEncoding=ETextureEncoding.SRGB
Local clipped:TImage=LoadImage(data.ConvertToPixmap(options))
options.exposureStops=-2
Local exposed:TImage=LoadImage(data.ConvertToPixmap(options))
options.exposureStops=0
options.toneMap=ETextureToneMap.Reinhard
Local mapped:TImage=LoadImage(data.ConvertToPixmap(options))

' Conversion runs once above; the drawing loop uses ordinary cached images.
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	SetClsColor(20,24,36)
	Cls()
	DrawText("One linear float ramp (0 to 4), three explicit conversion policies",24,24)
	DrawText("Clipped",32,100)
	DrawText("Exposure: -2 stops",352,100)
	DrawText("Reinhard",672,100)
	DrawImage(clipped,32,140)
	DrawImage(exposed,352,140)
	DrawImage(mapped,672,140)
	DrawText("All three output sRGB bytes. Alpha is unchanged.",24,320)
	DrawText("Converted pixmaps can also be saved using existing image encoders.",24,350)
	Flip()
Wend
EndGraphics()
