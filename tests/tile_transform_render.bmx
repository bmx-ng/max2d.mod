SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11 And Not max2d_sdlgpu
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.TileMap
Import BRL.StandardIO
Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Function Flags:ETileFlip(code:Int)
	Local result:ETileFlip=ETileFlip.None
	If code & 1 Then result:|ETileFlip.Horizontal
	If code & 2 Then result:|ETileFlip.Vertical
	If code & 4 Then result:|ETileFlip.Diagonal
	If code & 8 Then result:|ETileFlip.Rotate60
	If code & 16 Then result:|ETileFlip.Rotate120
	Return result
End Function
Function Pattern:TPixmap(trim:Int,alternate:Int=False)
	Local p:TPixmap=CreatePixmap(12,8,PF_RGBA8888)
	Local colors:Int[]=[$ffff0000,$ff00ff00,$ff0000ff,$ffffff00]
	p.ClearPixels(0)
	For Local y:Int=0 Until 8
		For Local x:Int=0 Until 12
			If trim And (x<2 Or x>=10 Or y<1 Or y>=7) Then Continue
			Local index:Int=Int(x>=6)+2*Int(y>=4)
			If alternate Then index=3-index
			p.WritePixel(x,y,colors[index])
		Next
	Next
	Return p
End Function
Function CheckPixels(pixels:TPixmap,flags:ETileFlip,angle:Int,diagonal:Int)
	Local result:TPixmap=GrabPixmap(0,0,128,96)
	Local c:Double=Cos(angle),s:Double=Sin(angle)
	Local checked:Int
	For Local y:Int=28 To 62
		For Local x:Int=28 To 62
			Local u:Double,v:Double
			If diagonal Then
				' Invert bottom-left-anchored dimension swap, then undo output flips.
				Local dx:Double=x+0.5-40,dy:Double=y+0.5-36
				If (flags & ETileFlip.Horizontal)<>ETileFlip.None Then dx=8-dx
				If (flags & ETileFlip.Vertical)<>ETileFlip.None Then dy=12-dy
				u=dy; v=dx
			Else
				Local dx:Double=x+0.5-46,dy:Double=y+0.5-44
				u=c*dx+s*dy+6; v=-s*dx+c*dy+4
				If (flags & ETileFlip.Horizontal)<>ETileFlip.None Then u=12-u
				If (flags & ETileFlip.Vertical)<>ETileFlip.None Then v=8-v
			End If
			' Exclude exact texel/triangle boundaries, where rasterizer tie rules differ.
			If Abs(u-Round(u))<0.08 Or Abs(v-Round(v))<0.08 Then Continue
			If angle Mod 180 Then
				' Software rasterizers may round rotated vertices to device pixels.
				Local nearEdge:Int
				For Local edge:Double=EachIn [0.0,2.0,6.0,10.0,12.0]
					If Abs(u-edge)<1.1 Then nearEdge=True
				Next
				For Local edge:Double=EachIn [0.0,1.0,4.0,7.0,8.0]
					If Abs(v-edge)<1.1 Then nearEdge=True
				Next
				If nearEdge Then Continue
			End If
			Local expected:Int
			If u>0 And u<12 And v>0 And v<8 Then expected=pixels.ReadPixel(Int(Floor(u)),Int(Floor(v)))&$ffffff
			Check((result.ReadPixel(x,y)&$ffffff)=expected,"Transformed pixel flags="+Int(flags)+" at "+x+","+y)
			checked:+1
		Next
	Next
	Check(checked>350,"Enough unambiguous pixels checked")
End Function
Try
	Graphics 128,96,0,0
	Local target:TRenderImage=CreateRenderImage(128,96,0)
	SetRenderImage(target); SetClsColor(0,0,0); SetBlend(ALPHABLEND)
	Local atlas:TTextureAtlas=TTextureAtlas.Create(64,0)
	Local tiles:TTileSet=New TTileSet
	Local map:TTileMap=TTileMap.Create(TTileGrid.Rectangular(16,16),tiles)
	Local layer:TTileLayer=map.AddLayer()
	Local id:Int=tiles.Add(atlas.AddPixmap(Pattern(False)))
	For Local trim:Int=0 To 1
		Local p:TPixmap=Pattern(trim),nextPixels:TPixmap=Pattern(trim,True)
		tiles.tiles[id].image=TImage.Animation([atlas.AddPixmap(p,"",trim),atlas.AddPixmap(nextPixels,"",trim)],[100,100])
		tiles.tiles[id].animated=True
		For Local order:ETileSort=EachIn [ETileSort.Grid,ETileSort.GroundDepth]
			layer.sortMode=order
			For Local code:Int=0 Until 8
				Local flags:ETileFlip=Flags(code)
				layer.SetCell(0,0,id,flags)
				Cls(); map.Draw(40,40,0)
				CheckPixels(p,flags,0,(code & 4)<>0)
			Next
			For Local rotation:Int=0 Until 4
				For Local flips:Int=0 Until 4
					Local flags:ETileFlip=Flags(flips | (rotation Shl 3))
					layer.SetCell(0,0,id,flags)
					Cls(); map.Draw(40,40,100)
					CheckPixels(nextPixels,flags,rotation*60,False)
				Next
			Next
		Next
	Next
	Local wide:TPixmap=CreatePixmap(12,84,PF_RGBA8888)
	wide.ClearPixels($ff00ff00)
	Local tall:Int=tiles.Add(TImage.FromPixmap(wide,0))
	layer.Clear(); layer.SetCell(9,0,tall,ETileFlip.Rotate60)
	Cls(); map.Draw()
	Check(map.drawnTiles=1 And (GrabPixmap(120,59,1,1).ReadPixel(0,0)&$ffffff)=$00ff00,"Rotation culling includes visible overhang beyond untransformed bounds")
	Local hits:TTileQueryResult=map.QueryRegion(layer,119,58,2,2)
	Check(hits.count=0,"Queries use cell geometry rather than rotated artwork")
	layer.Clear()
	Local sprite:TTileSprite=layer.AddSprite(tiles.tiles[tall].image,144,0)
	sprite.anchorX=0; sprite.anchorY=0; sprite.flip=ETileFlip.Rotate60
	Cls(); map.Draw()
	Check(map.drawnSprites=1 And (GrabPixmap(120,59,1,1).ReadPixel(0,0)&$ffffff)=$00ff00,"Sprite transformed bounds")
	layer.ClearSprites(); layer.SetCell(0,0,id,ETileFlip.Diagonal)
	Local camera:TCamera2D=New TCamera2D
	camera.offsetX=30; camera.offsetY=20; camera.zoom=2
	SetCamera(camera); SetTransform(90,1.5,0.75)
	Local before:TMax2DDrawTransform=CaptureDrawTransform()
	Cls(); map.Draw(10,10)
	Local after:TMax2DDrawTransform=CaptureDrawTransform()
	Check(before.xx=after.xx And before.xy=after.xy And before.tx=after.tx And before.ty=after.ty,"Transformed draw restores caller matrix")
	Local rejected:Int
	Try
		layer.SetCell(0,0,id,ETileFlip.Diagonal|ETileFlip.Rotate60)
	Catch error:Object
		rejected=True
	End Try
	Check(rejected,"Ambiguous diagonal plus hex rotation rejected")
	SetRenderImage(Null); EndGraphics()
	Print "Tile transformation rendering tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
