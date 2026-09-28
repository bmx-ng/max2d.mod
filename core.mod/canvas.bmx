Type TMax2DState
	Field red:Int = 255, green:Int = 255, blue:Int = 255
	Field colorByteAlpha:Int = 255, clsByteAlpha:Int = 255
	Field alpha:Float = 1
	Field clsRed:Int, clsGreen:Int, clsBlue:Int
	Field clsAlpha:Float = 1
	Field blend:Int = ALPHABLEND
	Field lineWidth:Float = 1
	Field rotation:Float, scaleX:Float = 1, scaleY:Float = 1
	Field ix:Float = 1, iy:Float, jx:Float, jy:Float = 1
	Field originX:Float, originY:Float, handleX:Float, handleY:Float
	Field coordXX:Double=1,coordXY:Double,coordYX:Double,coordYY:Double=1,coordTX:Double,coordTY:Double
	Field camera:TCamera2D
	Field cameraXX:Double=1,cameraXY:Double,cameraYX:Double,cameraYY:Double=1,cameraTX:Double,cameraTY:Double
	Method Copy:TMax2DState()
		Local result:TMax2DState = New TMax2DState
		result.red = red; result.green = green; result.blue = blue; result.alpha = alpha
		result.colorByteAlpha=colorByteAlpha; result.clsByteAlpha=clsByteAlpha
		result.clsRed = clsRed; result.clsGreen = clsGreen; result.clsBlue = clsBlue; result.clsAlpha = clsAlpha
		result.blend = blend; result.lineWidth = lineWidth
		result.rotation = rotation; result.scaleX = scaleX; result.scaleY = scaleY
		result.ix = ix; result.iy = iy; result.jx = jx; result.jy = jy
		result.originX = originX; result.originY = originY; result.handleX = handleX; result.handleY = handleY
		result.coordXX=coordXX; result.coordXY=coordXY; result.coordYX=coordYX; result.coordYY=coordYY
		result.coordTX=coordTX; result.coordTY=coordTY
		If camera Then result.camera=camera.Copy()
		result.cameraXX=cameraXX; result.cameraXY=cameraXY; result.cameraYX=cameraYX; result.cameraYY=cameraYY
		result.cameraTX=cameraTX; result.cameraTY=cameraTY
		Return result
	End Method
	' Compose the linear drawing matrix without allocating a captured transform.
	Method DrawingMatrix(xx:Double Var,xy:Double Var,yx:Double Var,yy:Double Var)
		Local a:Double=coordXX*ix+coordXY*jx,b:Double=coordXX*iy+coordXY*jy
		Local c:Double=coordYX*ix+coordYY*jx,d:Double=coordYX*iy+coordYY*jy
		xx=cameraXX*a+cameraXY*c;xy=cameraXX*b+cameraXY*d
		yx=cameraYX*a+cameraYY*c;yy=cameraYX*b+cameraYY*d
	End Method
	Method Transform()
		ix = Cos(rotation) * scaleX; iy = -Sin(rotation) * scaleY
		jx = Sin(rotation) * scaleX; jy = Cos(rotation) * scaleY
	End Method
End Type

Type TMax2DSavedState
	Field active:Int=True,scoped:Int
	Field state:TMax2DState
	Field font:TImageFont
	Field target:TRenderImage
	Field barRed:Int, barGreen:Int, barBlue:Int
	Field width:Float, height:Float
	Field x:Int, y:Int, w:Int, h:Int, automatic:Int, fullClip:Int, presentation:Int
End Type

Type TMesh2D
	Field xy:Float[]
	Field indices:Int[]
	Function Create:TMesh2D(xy:Float[], indices:Int[] = Null)
		If xy.Length < 6 Or (xy.Length & 1) Then Throw "Max2D: polygon requires at least three coordinate pairs"
		If Not indices Then indices = TriangulatePoly(xy)
		If indices.Length Mod 3 Then Throw "Max2D: indices must describe triangles"
		For Local index:Int = EachIn indices
			If index < 0 Or index >= xy.Length / 2 Then Throw "Max2D: triangle index out of range"
		Next
		Local mesh:TMesh2D = New TMesh2D
		mesh.xy = xy[..]; mesh.indices = indices[..]
		Return mesh
	End Function
End Type

Rem
bbdoc: A drawing canvas with its own state and native context.
End Rem
Type TMax2DGraphics Extends TGraphics
	Global selected:TMax2DGraphics
	Field context:TMax2DContext
	Field driver:TMax2DDriver
	Field state:TMax2DState = New TMax2DState
	Field imageFont:TImageFont
	Field renderImage:TRenderImage
	Field saved:TList = New TList

	Function Current:TMax2DGraphics()
		If Not selected Or selected.context.closed Then Throw "Max2D: no current graphics context"
		Return selected
	End Function
	Method Driver:TGraphicsDriver() Override
		Return driver
	End Method
	Method GetSettings(width:Int Var, height:Int Var, depth:Int Var, hertz:Int Var, flags:Long Var, x:Int Var, y:Int Var) Override
		context.CheckOpen()
		context.graphics.GetSettings(width, height, depth, hertz, flags, x, y)
	End Method
	Method Close() Override
		If context.closed Then Return
		context.Close()
		saved.Clear(); renderImage = Null
		If selected = Self Then selected = Null
		If driver.current = Self Then driver.current = Null
	End Method
	Method Resize(width:Int, height:Int) Override
		context.CheckOpen()
		context.Flush()
		If width<=0 Or height<=0 Then Throw "Max2D: window dimensions must be positive"
		context.Resize(width, height)
		ValidateSize()
		context.ApplyView()
	End Method
	Method Position(x:Int, y:Int) Override
		context.CheckOpen()
		context.Position(x, y)
	End Method
	Method ValidateSize()
		Local w:Int, h:Int, d:Int, hz:Int, flags:Long, x:Int, y:Int
		context.graphics.GetSettings(w, h, d, hz, flags, x, y)
		If context.windowView.automatic Then
			context.windowView.width = w; context.windowView.height = h
			If context.windowView.fullClip Then context.windowView.Reset(w, h)
		End If
	End Method

	Method SetBlend(blend:Int)
		If Not context.SupportsBlend(blend) Then Throw "Max2D: blend mode unsupported by this backend"
		state.blend = blend
	End Method
	Method SetColor(red:Int, green:Int, blue:Int)
		state.colorByteAlpha=255
		state.red = Min(255, Max(0, red)); state.green = Min(255, Max(0, green)); state.blue = Min(255, Max(0, blue))
	End Method
	Method SetAlpha(alpha:Float)
		state.alpha = Min(1.0, Max(0.0, alpha))
	End Method
	Method SetClsColor(red:Int, green:Int, blue:Int, alpha:Float = 1)
		state.clsByteAlpha=255
		state.clsRed = Min(255, Max(0, red)); state.clsGreen = Min(255, Max(0, green)); state.clsBlue = Min(255, Max(0, blue))
		state.clsAlpha = Min(1.0, Max(0.0, alpha))
	End Method
	Method SetLineWidth(width:Float)
		If width <= 0 Then Throw "Max2D: line width must be positive"
		state.lineWidth = width
	End Method
	Method SetVirtualResolution(width:Float, height:Float, presentation:Int = VIRTUAL_STRETCH)
		If width <= 0 Or height <= 0 Then Throw "Max2D: logical dimensions must be positive"
		If presentation < VIRTUAL_STRETCH Or presentation > VIRTUAL_INTEGER Then Throw "Max2D: invalid presentation mode"
		context.view.presentation = presentation
		context.view.width = width; context.view.height = height
		context.view.automatic = False
		If context.view.fullClip Then context.view.Reset(width, height)
		context.ApplyView()
	End Method
	Method SetViewport(x:Int, y:Int, w:Int, h:Int)
		If w < 0 Or h < 0 Then Throw "Max2D: viewport dimensions cannot be negative"
		context.view.x = x; context.view.y = y; context.view.w = w; context.view.h = h
		context.view.fullClip = False
		context.ApplyView()
	End Method
	Method SetRenderImage(image:TRenderImage)
		Local frame:TImageFrame
		If image Then frame = image.Frame(0, Self)
		context.SetTarget(frame)
		renderImage = image
	End Method
	Method PushState:TMax2DSavedState()
		Local entry:TMax2DSavedState = New TMax2DSavedState
		entry.state = state.Copy(); entry.font = imageFont; entry.target = renderImage
		Local view:TMax2DView = context.view
		entry.width = view.width; entry.height = view.height
		entry.x = view.x; entry.y = view.y; entry.w = view.w; entry.h = view.h
		entry.automatic = view.automatic; entry.fullClip = view.fullClip
		entry.presentation = view.presentation
		entry.barRed=view.barRed; entry.barGreen=view.barGreen; entry.barBlue=view.barBlue
		saved.AddLast(entry)
		Return entry
	End Method
	Method PopState()
		If saved.IsEmpty() Then Throw "Max2D: state stack is empty"
		Local entry:TMax2DSavedState = TMax2DSavedState(saved.Last())
		If entry.scoped Then Throw "Max2D: close the state scope instead of popping it manually"
		saved.RemoveLast(); entry.active=False
		RestoreState(entry)
	End Method
	Method RestoreState(entry:TMax2DSavedState)
		SetRenderImage(entry.target)
		state = entry.state; imageFont = entry.font
		context.view.width = entry.width; context.view.height = entry.height
		context.view.x = entry.x; context.view.y = entry.y; context.view.w = entry.w; context.view.h = entry.h
		context.view.automatic = entry.automatic; context.view.fullClip = entry.fullClip
		context.view.presentation = entry.presentation
		context.view.barRed=entry.barRed; context.view.barGreen=entry.barGreen; context.view.barBlue=entry.barBlue
		context.ApplyView()
	End Method

	Method SetCamera(camera:TCamera2D)
		If camera Then camera.Validate()
		state.camera=Null
		state.cameraXX=1; state.cameraXY=0; state.cameraYX=0; state.cameraYY=1; state.cameraTX=0; state.cameraTY=0
		If Not camera Then Return
		state.camera=camera.Copy()
		Local c:Double=Cos(camera.rotation)*camera.zoom,s:Double=Sin(camera.rotation)*camera.zoom
		state.cameraXX=c; state.cameraXY=s; state.cameraYX=-s; state.cameraYY=c
		state.cameraTX=camera.offsetX-c*camera.x-s*camera.y
		state.cameraTY=camera.offsetY+s*camera.x-c*camera.y
	End Method
	Method SceneVertex(x:Float,y:Float,u:Float=0,v:Float=0)
		Local localX:Double=x,localY:Double=y
		x=Float(state.coordXX*localX+state.coordXY*localY+state.coordTX)
		y=Float(state.coordYX*localX+state.coordYY*localY+state.coordTY)
		If state.camera Then
			Local worldX:Double=x,worldY:Double=y
			x=Float(state.cameraXX*worldX+state.cameraXY*worldY+state.cameraTX)
			y=Float(state.cameraYX*worldX+state.cameraYY*worldY+state.cameraTY)
		End If
		context.Vertex(x,y,state.red/255.0,state.green/255.0,state.blue/255.0,state.alpha,u,v)
	End Method
	Method Cls()
		context.CheckOpen(); context.Flush()
		ValidateSize()
		context.ApplyView()
		context.NativeClear(state.clsRed, state.clsGreen, state.clsBlue, state.clsAlpha)
	End Method
	Method AddVertex(x:Float, y:Float, tx:Float, ty:Float, u:Float = 0, v:Float = 0)
		SceneVertex(x * state.ix + y * state.iy + tx, x * state.jx + y * state.jy + ty,u,v)
	End Method
	Method Quad(frame:TImageFrame, x0:Float, y0:Float, x1:Float, y1:Float, tx:Float, ty:Float, u0:Float = 0, v0:Float = 0, u1:Float = 0, v1:Float = 0)
		context.BeginTriangles(frame, state.blend, 6)
		AddVertex(x0,y0,tx,ty,u0,v0); AddVertex(x1,y0,tx,ty,u1,v0); AddVertex(x1,y1,tx,ty,u1,v1)
		AddVertex(x0,y0,tx,ty,u0,v0); AddVertex(x1,y1,tx,ty,u1,v1); AddVertex(x0,y1,tx,ty,u0,v1)
	End Method
	Method Plot(x:Float, y:Float)
		Local old:TMax2DState = state
		state = state.Copy(); state.ix = 1; state.iy = 0; state.jx = 0; state.jy = 1
		Quad(Null, 0,0,1,1, x + state.originX, y + state.originY)
		state = old
	End Method
	Method DrawRect(x:Float, y:Float, width:Float, height:Float)
		If width = 0 Or height = 0 Then Return
		Quad(Null, -state.handleX, -state.handleY, width-state.handleX, height-state.handleY, x+state.originX, y+state.originY)
	End Method
	Method DrawLine(x:Float, y:Float, x2:Float, y2:Float, drawLastPixel:Int = True)
		Local ax:Float = -state.handleX, ay:Float = -state.handleY
		Local bx:Float = ax + x2 - x, by:Float = ay + y2 - y
		Local sx:Float = ax*state.ix + ay*state.iy + x + state.originX + 0.5
		Local sy:Float = ax*state.jx + ay*state.jy + y + state.originY + 0.5
		Local ex:Float = bx*state.ix + by*state.iy + x + state.originX + 0.5
		Local ey:Float = bx*state.jx + by*state.jy + y + state.originY + 0.5
		Local dx:Float = ex-sx, dy:Float = ey-sy
		Local length:Float = Sqr(dx*dx + dy*dy)
		If length = 0 Then
			If drawLastPixel Then Plot(x, y)
			Return
		End If
		dx :/ length; dy :/ length
		sx :- dx*0.5; sy :- dy*0.5
		If drawLastPixel Then ex :+ dx*0.5; ey :+ dy*0.5 Else ex :- dx*0.5; ey :- dy*0.5
		Local nx:Float = -dy * state.lineWidth * 0.5, ny:Float = dx * state.lineWidth * 0.5
		Local points:Float[] = [sx+nx,sy+ny, ex+nx,ey+ny, ex-nx,ey-ny, sx-nx,sy-ny]
		Local order:Int[] = [0,1,2,0,2,3]
		context.BeginTriangles(Null, state.blend, 6)
		For Local index:Int = EachIn order
			SceneVertex(points[index*2],points[index*2+1])
		Next
	End Method
	Method DrawOval(x:Float, y:Float, width:Float, height:Float)
		If width = 0 Or height = 0 Then Return
		Local rx:Float = width*0.5, ry:Float = height*0.5
		Local xx:Double,xy:Double,yx:Double,yy:Double
		state.DrawingMatrix(xx,xy,yx,yy)
		Local radius:Float = Float(Max(Abs(rx)*Sqr(xx*xx+yx*yx), Abs(ry)*Sqr(xy*xy+yy*yy)))
		If radius <= 0 Then Return
		Local segments:Int = Min(4096, Max(12, Ceil(180.0 / ACos(Max(-1.0, 1.0 - 0.25 / radius)))))
		Local cx:Float = rx-state.handleX, cy:Float = ry-state.handleY
		For Local i:Int = 0 Until segments
			Local a:Float = i * 360.0 / segments, b:Float = (i+1) * 360.0 / segments
			context.BeginTriangles(Null, state.blend, 3)
			AddVertex(cx,cy,x+state.originX,y+state.originY)
			AddVertex(Float(cx+Cos(a)*rx),Float(cy+Sin(a)*ry),x+state.originX,y+state.originY)
			AddVertex(Float(cx+Cos(b)*rx),Float(cy+Sin(b)*ry),x+state.originX,y+state.originY)
		Next
	End Method
	Method DrawMesh(mesh:TMesh2D, x:Float = 0, y:Float = 0)
		For Local triangle:Int = 0 Until mesh.indices.Length Step 3
			context.BeginTriangles(Null, state.blend, 3)
			For Local corner:Int = 0 Until 3
				Local index:Int = mesh.indices[triangle+corner] * 2
				AddVertex(mesh.xy[index]-state.handleX,mesh.xy[index+1]-state.handleY,x+state.originX,y+state.originY)
			Next
		Next
	End Method
	Method DrawImageRegion(image:TImage, x:Float, y:Float, width:Float, height:Float, sx:Float, sy:Float, sw:Float, sh:Float, hx:Float, hy:Float, frame:Int = 0)
		If Not image Then Return
		If sw <= 0 Or sh <= 0 Or width = 0 Or height = 0 Then Return
		If sx < 0 Or sy < 0 Or sx+sw > image.width Or sy+sh > image.height Then Throw "Max2D: image source rectangle out of bounds"
		image.CheckIndex(frame)
		Local left:Float=sx,top:Float=sy,right:Float=sx+sw,bottom:Float=sy+sh
		Local x0:Float=-hx,y0:Float=-hy,x1:Float=width-hx,y1:Float=height-hy
		Local ox:Int,oy:Int
		Local trim:TImageTrim=image.Trim(frame)
		If trim Then
			ox=trim.x; oy=trim.y
			left=Max(left,Float(ox)); top=Max(top,Float(oy))
			right=Min(right,Float(ox+trim.width)); bottom=Min(bottom,Float(oy+trim.height))
			If right<=left Or bottom<=top Then Return
			x0=-hx+(left-sx)*width/sw; y0=-hy+(top-sy)*height/sh
			x1=-hx+(right-sx)*width/sw; y1=-hy+(bottom-sy)*height/sh
		End If
		Local native:TImageFrame=image.Frame(frame,Self)
		Local source:TImageSource=image.sources[frame]
		Local u0:Float=(image.sourceX[frame]+left-ox)/Float(source.width)
		Local v0:Float=(image.sourceY[frame]+top-oy)/Float(source.height)
		Local u1:Float=(image.sourceX[frame]+right-ox)/Float(source.width)
		Local v1:Float=(image.sourceY[frame]+bottom-oy)/Float(source.height)
		Quad(native,x0,y0,x1,y1,x+state.originX,y+state.originY,u0,v0,u1,v1)
	End Method
	Method DrawImage(image:TImage, x:Float, y:Float, frame:Int = 0)
		If image Then DrawImageRegion(image,x,y,image.width,image.height,0,0,image.width,image.height,image.handle_x,image.handle_y,frame)
	End Method
	Method DrawPixmap(pixmap:TPixmap, x:Int, y:Int)
		If Not pixmap Then Return
		context.Flush()
		Local rgba:TPixmap = pixmap
		If rgba.format <> PF_RGBA8888 Then rgba = rgba.Convert(PF_RGBA8888)
		Local image:TImage = context.uploadImage
		If Not image Or image.width <> rgba.width Or image.height <> rgba.height Then
			If image Then image.ReleaseFrames()
			image = TImage.FromPixmap(rgba, DYNAMICIMAGE)
			context.uploadImage = image
		Else
			Local source:TImageSource = image.sources[0]
			source.pixmap.Paste(rgba,0,0)
			source.Changed(0,0,image.width,image.height)
		End If
		' Pixel transfers address the complete output surface, like readbacks.
		' Use a temporary view so neither target-local clipping nor layout is changed.
		Local originalView:TMax2DView=context.view
		Local originalState:TMax2DState=state
		context.view=New TMax2DView
		context.view.presentation=VIRTUAL_NATIVE
		context.view.Reset(context.pixelWidth,context.pixelHeight)
		state=New TMax2DState
		state.blend=SOLIDBLEND
		Try
			context.ApplyView()
			DrawImage(image,x,y)
			context.Flush()
		Catch error:Object
			state=originalState; context.view=originalView
			context.ApplyView()
			Throw error
		End Try
		state=originalState; context.view=originalView
		context.ApplyView()
	End Method
	Method DrawText(text:String, x:Float, y:Float)
		imageFont.Layout(text).Draw(Self, x, y)
	End Method
End Type
