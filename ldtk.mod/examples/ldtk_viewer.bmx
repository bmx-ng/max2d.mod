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
Import Max2D.LDTK
Import Max2D.ScalableFont
Import BRL.StandardIO
Import Pub.StdC

Local path:String=AppDir+"/maps/AutoLayers_1_basic.ldtk",selector:String,screenshot:String,test:Int,entityArtwork:Int=True,iconPath:String
For Local arg:String=EachIn AppArgs[1..]
	If arg="--test" Then
		test=True
	Else If arg="--no-entity-art" Then
		entityArtwork=False
	Else If arg.StartsWith("--icons=") Then
		iconPath=arg[8..]
	Else If arg.StartsWith("--screenshot=") Then
		screenshot=arg[13..]
	Else If arg.StartsWith("--level=") Then
		selector=arg[8..]
	Else
		path=arg
	End If
Next
Local project:TLDTKProject,map:TLDTKMap,index:Int
Try
	project=TLDTKProject.Load(path)
	If iconPath Then project.SetEmbeddedAtlas("LdtkIcons",LoadPixmap(iconPath))
	If Not selector Then selector=project.levels[0].iid
	map=project.LoadLevel(selector,0,entityArtwork)
	For Local i:Int=0 Until project.levels.Length
		If project.levels[i].iid=map.level.iid Then index=i
	Next
Catch error:Object
	Print error.ToString()
	EndWithCode(1)
End Try

AppTitle="Max2D — LDtk viewer"
Graphics 1000,700
SetVirtualResolution(1000,700,VIRTUAL_LETTERBOX)
Local fontPath:String
?osx
fontPath="/System/Library/Fonts/Supplemental/Arial.ttf"
?win32
fontPath=getenv_("WINDIR")+"/Fonts/segoeui.ttf"
?linux
fontPath="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
?
If FileType(fontPath)=FILETYPE_FILE Then SetImageFont(LoadScalableImageFont(fontPath,18))
Local camera:TCamera2D=New TCamera2D
FitLevel(map,camera)
Local frames:Int,previous:Int=MilliSecs(),showEntities:Int=True
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
	Local now:Int=MilliSecs(),dt:Float=Min(0.1,Float(now-previous)/1000)
	previous=now
	Local nextIndex:Int=index
	If KeyHit(KEY_RIGHT) Then nextIndex=(index+1) Mod project.levels.Length
	If KeyHit(KEY_LEFT) Then nextIndex=(index+project.levels.Length-1) Mod project.levels.Length
	If nextIndex<>index Then
		Try
			Local nextMap:TLDTKMap=project.LoadLevel(project.levels[nextIndex].iid,0,entityArtwork)
			map=nextMap; index=nextIndex; FitLevel(map,camera)
		Catch error:Object
			Print error.ToString()
		End Try
	End If
	camera.x:+(KeyDown(KEY_D)-KeyDown(KEY_A))*300*dt/camera.zoom
	camera.y:+(KeyDown(KEY_S)-KeyDown(KEY_W))*300*dt/camera.zoom
	camera.zoom=Max(0.1,Min(12.0,camera.zoom*Float(Exp(MouseZSpeed()*0.1+(KeyDown(KEY_E)-KeyDown(KEY_Q))*dt))))
	If KeyHit(KEY_SPACE) Then FitLevel(map,camera)
	If KeyHit(KEY_O) Then showEntities=Not showEntities
	SetClsColor(19,26,35); Cls()
	Local hover:String="Hover over a layer to inspect its grid and IntGrid value"
	Using
		Local scope:TMax2DStateScope=ScopedMax2DState()
	Do
		SetViewport(0,105,1000,535)
		SetCamera(camera)
		SetColor(255,255,255)
		map.Draw()
		If showEntities Then
			SetColor(255,210,95)
			For Local entity:TLDTKEntity=EachIn map.entities
				Local obj:TTileObject=entity.object,layer:TTileLayer=entity.layer.layer
				Local ox:Double,oy:Double
				map.LayerDrawOffset(layer,ox,oy)
				Local x:Float=Float(ox+obj.x*layer.drawScale),y:Float=Float(oy+obj.y*layer.drawScale),w:Float=Float(obj.width*layer.drawScale),h:Float=Float(obj.height*layer.drawScale)
				DrawLine(x,y,x+w,y,False); DrawLine(x+w,y,x+w,y+h,False)
				DrawLine(x+w,y+h,x,y+h,False); DrawLine(x,y+h,x,y,False)
			Next
		End If
		For Local info:TLDTKLayer=EachIn map.importedLayers
			If Not info.layer.visible Then Continue
			Local c:Int,r:Int
			If Not map.MouseCell(c,r,0,0,info.layer) Then Continue
			If c<0 Or r<0 Or c>=info.width Or r>=info.height Then Continue
			hover=info.identifier+" / "+info.kind+" / cell "+c+", "+r
			If info.kind="IntGrid" Then hover:+" / IntGrid value "+info.IntValue(c,r)
			Exit
		Next
	End Using
	SetColor(239,244,250)
	DrawText(StripDir(path)+" / "+map.level.identifier+" / level "+(index+1)+" of "+project.levels.Length,20,18)
	DrawText("A/D/W/S: pan   Wheel/Q/E: zoom   Space: fit   Left/Right: level   O: entity outlines",20,47)
	DrawText("Tiles retain exported stacking and opacity; entity artwork preserves gameplay bounds.",20,76)
	DrawText(hover,20,655)
	frames:+1
	If frames=3 And screenshot Then SavePixmapPNG(GrabPixmap(0,0,NativeResolutionWidth(),NativeResolutionHeight()),screenshot)
	Flip()
	If test And frames>=3 Then Exit
Wend
EndGraphics()

Function FitLevel(map:TLDTKMap,camera:TCamera2D)
	camera.x=Float(map.level.width)/2; camera.y=Float(map.level.height)/2
	camera.offsetX=500; camera.offsetY=372
	camera.zoom=Min(930.0/Max(1,map.level.width),500.0/Max(1,map.level.height))
End Function
