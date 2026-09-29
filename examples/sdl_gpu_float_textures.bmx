SuperStrict
Framework Max2D.SDL3GPUMax2D

AppTitle = "Max2D native SDL GPU floating-point textures"
If Not Graphics(900,420,0) Then End
SetVirtualResolution(900,420,VIRTUAL_LETTERBOX)

' Store a brightness ramp from zero to four, without quantising its highlights.
Local values:Float[256*4]
Local bytes:Byte[256*16]
Local pixmap:TPixmap = CreatePixmap(256,1,PF_RGBA8888)
For Local x:Int = 0 Until 256
	Local brightness:Float = 4.0*x/255.0
	For Local channel:Int = 0 Until 3
		values[x*4+channel] = brightness
	Next
	values[x*4+3] = 1
	Local grey:Int = Int(Min(1.0,brightness)*255)
	pixmap.WritePixel(x,0,$ff000000 | (grey Shl 16) | (grey Shl 8) | grey)
Next
MemCopy(Varptr bytes[0],Varptr values[0],Size_T(bytes.Length))
Local data:TTextureData = TTextureData.Create([TTextureLevel.Create(256,1,PF_RGBA32F,bytes)])
Local supported:Int = Max2DTextureDataSupport(data,FILTEREDIMAGE) = ETextureFormatSupport.Native
Local precise:TImage
If supported Then precise = LoadImage(data,FILTEREDIMAGE)
Local quantised:TImage = LoadImage(pixmap,FILTEREDIMAGE)
Local gain:Float = 0.25

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	If KeyHit(KEY_LEFT) Then gain = Max(0.05,gain-0.05)
	If KeyHit(KEY_RIGHT) Then gain = Min(1.0,gain+0.05)
	SetClsColor(20,24,36)
	Cls()
	SetColor(Int(gain*255),Int(gain*255),Int(gain*255))
	SetScale(1.5,120)
	DrawImage(quantised,40,130)
	If precise Then DrawImage(precise,476,130)
	SetScale(1,1)
	SetColor(255,255,255)
	DrawText("8-bit: highlights clipped before drawing",40,95)
	DrawText("Float: original brightness retained",476,95)
	DrawText("Both source ramps contain brightness from 0 to 4.",40,290)
	DrawText("Left/Right: drawing gain ("+gain+")   Escape: exit",40,325)
	DrawText("GPU driver: "+SDLGPUMax2DDriverName(),40,365)
	If Not supported Then DrawText("RGBA32F unsupported on this device",476,180)
	Flip()
Wend
EndGraphics()
