
Rem
bbdoc: Mutable colour, blending and transformation settings for a drawing canvas.
End Rem
Type TMax2DState

	Rem
	bbdoc: Red colour component from 0 to 255.
	End Rem
	Field red:Int = 255

	Rem
	bbdoc: Green colour component from 0 to 255.
	End Rem
	Field green:Int = 255

	Rem
	bbdoc: Blue colour component from 0 to 255.
	End Rem
	Field blue:Int = 255

	Rem
	bbdoc: Byte alpha from the drawing SColor8 colour, multiplied by the separate alpha setting.
	End Rem
	Field colorByteAlpha:Int = 255

	Rem
	bbdoc: Byte alpha from the clear SColor8 colour, multiplied by the clear alpha setting.
	End Rem
	Field clsByteAlpha:Int = 255

	Rem
	bbdoc: Opacity multiplier from 0.0 to 1.0.
	End Rem
	Field alpha:Float = 1

	Rem
	bbdoc: Red clear-colour component from 0 to 255.
	End Rem
	Field clsRed:Int

	Rem
	bbdoc: Green clear-colour component from 0 to 255.
	End Rem
	Field clsGreen:Int

	Rem
	bbdoc: Blue clear-colour component from 0 to 255.
	End Rem
	Field clsBlue:Int

	Rem
	bbdoc: Clear-colour opacity multiplier from 0.0 to 1.0.
	End Rem
	Field clsAlpha:Float = 1

	Rem
	bbdoc: Current drawing blend mode.
	End Rem
	Field blend:Int = ALPHABLEND

	Rem
	bbdoc: Logical width used for drawing lines.
	End Rem
	Field lineWidth:Float = 1

	Rem
	bbdoc: Rotation in degrees.
	End Rem
	Field rotation:Float

	Rem
	bbdoc: Horizontal scale factor.
	End Rem
	Field scaleX:Float = 1

	Rem
	bbdoc: Vertical scale factor.
	End Rem
	Field scaleY:Float = 1

	Rem
	bbdoc: Object transform coefficient mapping local x to output x.
	End Rem
	Field ix:Float = 1

	Rem
	bbdoc: Object transform coefficient mapping local y to output x.
	End Rem
	Field iy:Float

	Rem
	bbdoc: Object transform coefficient mapping local x to output y.
	End Rem
	Field jx:Float

	Rem
	bbdoc: Object transform coefficient mapping local y to output y.
	End Rem
	Field jy:Float = 1

	Rem
	bbdoc: Horizontal drawing-origin offset.
	End Rem
	Field originX:Float

	Rem
	bbdoc: Vertical drawing-origin offset.
	End Rem
	Field originY:Float

	Rem
	bbdoc: Horizontal primitive handle offset in local coordinates.
	End Rem
	Field handleX:Float

	Rem
	bbdoc: Vertical primitive handle offset in local coordinates.
	End Rem
	Field handleY:Float

	Rem
	bbdoc: Parent transform coefficient mapping x to x.
	End Rem
	Field coordXX:Double=1

	Rem
	bbdoc: Parent transform coefficient mapping y to x.
	End Rem
	Field coordXY:Double

	Rem
	bbdoc: Parent transform coefficient mapping x to y.
	End Rem
	Field coordYX:Double

	Rem
	bbdoc: Parent transform coefficient mapping y to y.
	End Rem
	Field coordYY:Double=1

	Rem
	bbdoc: Parent transform horizontal translation.
	End Rem
	Field coordTX:Double

	Rem
	bbdoc: Parent transform vertical translation.
	End Rem
	Field coordTY:Double

	Rem
	bbdoc: Captured camera settings; use SetCamera to apply changes to a canvas.
	End Rem
	Field camera:TCamera2D

	Rem
	bbdoc: Cached camera transform coefficient mapping x to x.
	End Rem
	Field cameraXX:Double=1

	Rem
	bbdoc: Cached camera transform coefficient mapping y to x.
	End Rem
	Field cameraXY:Double

	Rem
	bbdoc: Cached camera transform coefficient mapping x to y.
	End Rem
	Field cameraYX:Double

	Rem
	bbdoc: Cached camera transform coefficient mapping y to y.
	End Rem
	Field cameraYY:Double=1

	Rem
	bbdoc: Cached camera horizontal translation.
	End Rem
	Field cameraTX:Double

	Rem
	bbdoc: Cached camera vertical translation.
	End Rem
	Field cameraTY:Double

	Rem
	bbdoc: Returns a copy that can be modified independently of this object's scalar settings.
	End Rem
	Method Copy:TMax2DState()
		Local result:TMax2DState = New TMax2DState
		result.red = red
		result.green = green
		result.blue = blue
		result.alpha = alpha
		result.colorByteAlpha=colorByteAlpha
		result.clsByteAlpha=clsByteAlpha
		result.clsRed = clsRed
		result.clsGreen = clsGreen
		result.clsBlue = clsBlue
		result.clsAlpha = clsAlpha
		result.blend = blend
		result.lineWidth = lineWidth
		result.rotation = rotation
		result.scaleX = scaleX
		result.scaleY = scaleY
		result.ix = ix
		result.iy = iy
		result.jx = jx
		result.jy = jy
		result.originX = originX
		result.originY = originY
		result.handleX = handleX
		result.handleY = handleY
		result.coordXX=coordXX
		result.coordXY=coordXY
		result.coordYX=coordYX
		result.coordYY=coordYY
		result.coordTX=coordTX
		result.coordTY=coordTY
		If camera Then result.camera=camera.Copy()
		result.cameraXX=cameraXX
		result.cameraXY=cameraXY
		result.cameraYX=cameraYX
		result.cameraYY=cameraYY
		result.cameraTX=cameraTX
		result.cameraTY=cameraTY
		Return result
	End Method

	' Compose the linear drawing matrix without allocating a captured transform.

	Rem
	bbdoc: Gets the combined object, parent-coordinate and camera linear transform.
	param: Receives coefficient mapping input x to output x.
	param: Receives coefficient mapping input y to output x.
	param: Receives coefficient mapping input x to output y.
	param: Receives coefficient mapping input y to output y.
	End Rem
	Method DrawingMatrix(xx:Double Var,xy:Double Var,yx:Double Var,yy:Double Var)
		Local a:Double=coordXX*ix+coordXY*jx,b:Double=coordXX*iy+coordXY*jy
		Local c:Double=coordYX*ix+coordYY*jx,d:Double=coordYX*iy+coordYY*jy
		xx=cameraXX*a+cameraXY*c
		xy=cameraXX*b+cameraXY*d
		yx=cameraYX*a+cameraYY*c
		yy=cameraYX*b+cameraYY*d
	End Method

	Rem
	bbdoc: Recalculates the object matrix from the current rotation and scale.
	End Rem
	Method Transform()
		ix = Cos(rotation) * scaleX
		iy = -Sin(rotation) * scaleY
		jx = Sin(rotation) * scaleX
		jy = Cos(rotation) * scaleY
	End Method

End Type

Rem
bbdoc: A saved canvas state, target, font and view used by the drawing-state stack.
End Rem
Type TMax2DSavedState

	Rem
	bbdoc: Whether this saved entry is still present on the canvas stack.
	End Rem
	Field active:Int=True

	Rem
	bbdoc: Whether a deterministic state scope owns this stack entry.
	End Rem
	Field scoped:Int

	Rem
	bbdoc: Drawing state associated with this canvas or saved entry.
	End Rem
	Field state:TMax2DState

	Rem
	bbdoc: Font used to shape and draw this text.
	End Rem
	Field font:TImageFont

	Rem
	bbdoc: Current or saved drawing destination; a Null frame or image denotes the window.
	End Rem
	Field target:TRenderImage

	Rem
	bbdoc: Red component of the unused virtual-presentation bars, from 0 to 255.
	End Rem
	Field barRed:Int

	Rem
	bbdoc: Green component of the unused virtual-presentation bars, from 0 to 255.
	End Rem
	Field barGreen:Int

	Rem
	bbdoc: Blue component of the unused virtual-presentation bars, from 0 to 255.
	End Rem
	Field barBlue:Int

	Rem
	bbdoc: Logical width of this object or region.
	End Rem
	Field width:Float

	Rem
	bbdoc: Logical height of this object or region.
	End Rem
	Field height:Float

	Rem
	bbdoc: Horizontal position in the coordinate space described by the containing type.
	End Rem
	Field x:Int

	Rem
	bbdoc: Vertical position in the coordinate space described by the containing type.
	End Rem
	Field y:Int

	Rem
	bbdoc: Width of the stored rectangle.
	End Rem
	Field w:Int

	Rem
	bbdoc: Height of the stored rectangle.
	End Rem
	Field h:Int

	Rem
	bbdoc: Whether window-size changes update the virtual dimensions automatically.
	End Rem
	Field automatic:Int

	Rem
	bbdoc: Whether the viewport tracks the full drawing surface.
	End Rem
	Field fullClip:Int

	Rem
	bbdoc: Virtual presentation mode controlling stretch, aspect fit or native pixels.
	End Rem
	Field presentation:Int
End Type

Rem
bbdoc: Reusable polygon vertices and triangle indices for filled drawing.
End Rem
Type TMesh2D

	Rem
	bbdoc: Alternating local x and y coordinates of mesh vertices.
	End Rem
	Field xy:Float[]

	Rem
	bbdoc: Triangle indices referencing the mesh vertex array.
	End Rem
	Field indices:Int[]

	Rem
	bbdoc: Copies vertices and validates supplied triangles, or triangulates a polygon.
	param: Alternating x and y vertex coordinates.
	param: Triangle vertex indices, or Null to triangulate the polygon.
	End Rem
	Function Create:TMesh2D(xy:Float[], indices:Int[] = Null)
		If xy.Length < 6 Or (xy.Length & 1) Then Throw "Max2D: polygon requires at least three coordinate pairs"
		If Not indices Then indices = TriangulatePoly(xy)
		If indices.Length Mod 3 Then Throw "Max2D: indices must describe triangles"
		For Local index:Int = EachIn indices
			If index < 0 Or index >= xy.Length / 2 Then Throw "Max2D: triangle index out of range"
		Next
		Local mesh:TMesh2D = New TMesh2D
		mesh.xy = xy[..]
		mesh.indices = indices[..]
		Return mesh
	End Function

End Type

Rem
bbdoc: A drawing canvas with its own state and native context.
End Rem
Type TMax2DGraphics Extends TGraphics

	Rem
	bbdoc: Currently selected Max2D canvas; maintained by the graphics driver.
	End Rem
	Global selected:TMax2DGraphics

	Rem
	bbdoc: Rendering context owning this canvas's native resources.
	End Rem
	Field context:TMax2DContext

	Rem
	bbdoc: Graphics driver that created this canvas.
	End Rem
	Field driver:TMax2DDriver

	Rem
	bbdoc: Drawing state associated with this canvas or saved entry.
	End Rem
	Field state:TMax2DState = New TMax2DState

	Rem
	bbdoc: Font selected for drawing text on this canvas.
	End Rem
	Field imageFont:TImageFont

	Rem
	bbdoc: Current render image, or Null when drawing into the window.
	End Rem
	Field renderImage:TRenderImage

	Rem
	bbdoc: Drawing-state stack; use PushState and PopState to maintain it.
	End Rem
	Field saved:TList = New TList

	Rem
	bbdoc: Returns the currently selected Max2D canvas, throwing if none is active.
	End Rem
	Function Current:TMax2DGraphics()
		If Not selected Or selected.context.closed Then Throw "Max2D: no current graphics context"
		Return selected
	End Function

	Rem
	bbdoc: Returns the graphics driver that created this canvas.
	End Rem
	Method Driver:TGraphicsDriver() Override
		Return driver
	End Method

	Rem
	bbdoc: Gets the underlying window dimensions, display mode, flags and position.
	param: Receives width of the rectangle or drawing surface.
	param: Receives height of the rectangle or drawing surface.
	param: Receives fullscreen colour depth; zero requests a window.
	param: Receives refresh rate in hertz; zero selects the backend default.
	param: Receives bRL.Graphics flags describing the window.
	param: Receives horizontal coordinate.
	param: Receives vertical coordinate.
	End Rem
	Method GetSettings(width:Int Var, height:Int Var, depth:Int Var, hertz:Int Var, flags:Long Var, x:Int Var, y:Int Var) Override
		context.CheckOpen()
		context.graphics.GetSettings(width, height, depth, hertz, flags, x, y)
	End Method

	Rem
	bbdoc: Closes the graphics resources owned by this object.
	End Rem
	Method Close() Override
		If context.closed Then Return
		context.Close()
		saved.Clear()
		renderImage = Null
		If selected = Self Then selected = Null
		If driver.current = Self Then driver.current = Null
	End Method

	Rem
	bbdoc: Requests a new window size.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	End Rem
	Method Resize(width:Int, height:Int) Override
		context.CheckOpen()
		context.Flush()
		If width<=0 Or height<=0 Then Throw "Max2D: window dimensions must be positive"
		context.Resize(width, height)
		ValidateSize()
		context.ApplyView()
	End Method

	Rem
	bbdoc: Requests a new window position.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	End Rem
	Method Position(x:Int, y:Int) Override
		context.CheckOpen()
		context.Position(x, y)
	End Method

	Rem
	bbdoc: Refreshes window dimensions and automatic virtual presentation after a resize.
	End Rem
	Method ValidateSize()
		Local w:Int, h:Int, d:Int, hz:Int, flags:Long, x:Int, y:Int
		context.graphics.GetSettings(w, h, d, hz, flags, x, y)
		If context.windowView.automatic Then
			context.windowView.width = w
			context.windowView.height = h
			If context.windowView.fullClip Then context.windowView.Reset(w, h)
		End If
	End Method

	Rem
	bbdoc: Selects the blend mode used for subsequent drawing.
	param: Blend mode, such as ALPHABLEND or SOLIDBLEND.
	End Rem
	Method SetBlend(blend:Int)
		If Not context.SupportsBlend(blend) Then Throw "Max2D: blend mode unsupported by this backend"
		state.blend = blend
	End Method

	Rem
	bbdoc: Sets the colour used for subsequent drawing.
	param: Red component, from 0 to 255.
	param: Green component, from 0 to 255.
	param: Blue component, from 0 to 255.
	End Rem
	Method SetColor(red:Int, green:Int, blue:Int)
		state.colorByteAlpha=255
		state.red = Min(255, Max(0, red))
		state.green = Min(255, Max(0, green))
		state.blue = Min(255, Max(0, blue))
	End Method

	Rem
	bbdoc: Sets the opacity multiplier used for subsequent drawing.
	param: Opacity multiplier, from 0.0 to 1.0.
	End Rem
	Method SetAlpha(alpha:Float)
		state.alpha = Min(1.0, Max(0.0, alpha))
	End Method

	Rem
	bbdoc: Sets the colour and opacity used by Cls.
	param: Red component, from 0 to 255.
	param: Green component, from 0 to 255.
	param: Blue component, from 0 to 255.
	param: Opacity multiplier, from 0.0 to 1.0.
	End Rem
	Method SetClsColor(red:Int, green:Int, blue:Int, alpha:Float = 1)
		state.clsByteAlpha=255
		state.clsRed = Min(255, Max(0, red))
		state.clsGreen = Min(255, Max(0, green))
		state.clsBlue = Min(255, Max(0, blue))
		state.clsAlpha = Min(1.0, Max(0.0, alpha))
	End Method

	Rem
	bbdoc: Sets the width used to draw lines.
	param: Positive line width in logical drawing units.
	End Rem
	Method SetLineWidth(width:Float)
		If width <= 0 Then Throw "Max2D: line width must be positive"
		state.lineWidth = width
	End Method

	Rem
	bbdoc: Sets logical drawing dimensions and how they fit the current destination.
	param: Positive virtual drawing width.
	param: Positive virtual drawing height.
	param: VIRTUAL_STRETCH, VIRTUAL_LETTERBOX, VIRTUAL_INTEGER or VIRTUAL_NATIVE.
	End Rem
	Method SetVirtualResolution(width:Float, height:Float, presentation:Int = VIRTUAL_STRETCH)
		If width <= 0 Or height <= 0 Then Throw "Max2D: logical dimensions must be positive"
		If presentation < VIRTUAL_STRETCH Or presentation > VIRTUAL_INTEGER Then Throw "Max2D: invalid presentation mode"
		context.view.presentation = presentation
		context.view.width = width
		context.view.height = height
		context.view.automatic = False
		If context.view.fullClip Then context.view.Reset(width, height)
		context.ApplyView()
	End Method

	Rem
	bbdoc: Sets the clipping rectangle in virtual screen coordinates.
	param: Horizontal virtual screen coordinate.
	param: Vertical virtual screen coordinate.
	param: Width of the pixel rectangle.
	param: Height of the pixel rectangle.
	End Rem
	Method SetViewport(x:Int, y:Int, w:Int, h:Int)
		If w < 0 Or h < 0 Then Throw "Max2D: viewport dimensions cannot be negative"
		context.view.x = x
		context.view.y = y
		context.view.w = w
		context.view.h = h
		context.view.fullClip = False
		context.ApplyView()
	End Method

	Rem
	bbdoc: Selects a render image as the drawing destination, or Null for the window.
	param: Drawing destination, or Null to return to the window.
	End Rem
	Method SetRenderImage(image:TRenderImage)
		Local frame:TImageFrame
		If image Then frame = image.Frame(0, Self)
		context.SetTarget(frame)
		renderImage = image
	End Method

	Rem
	bbdoc: Captures drawing state, font, target and view on the canvas stack.
	End Rem
	Method PushState:TMax2DSavedState()
		Local entry:TMax2DSavedState = New TMax2DSavedState
		entry.state = state.Copy()
		entry.font = imageFont
		entry.target = renderImage
		Local view:TMax2DView = context.view
		entry.width = view.width
		entry.height = view.height
		entry.x = view.x
		entry.y = view.y
		entry.w = view.w
		entry.h = view.h
		entry.automatic = view.automatic
		entry.fullClip = view.fullClip
		entry.presentation = view.presentation
		entry.barRed=view.barRed
		entry.barGreen=view.barGreen
		entry.barBlue=view.barBlue
		saved.AddLast(entry)
		Return entry
	End Method

	Rem
	bbdoc: Restores and removes the most recently saved canvas state.
	End Rem
	Method PopState()
		If saved.IsEmpty() Then Throw "Max2D: state stack is empty"
		Local entry:TMax2DSavedState = TMax2DSavedState(saved.Last())
		If entry.scoped Then Throw "Max2D: close the state scope instead of popping it manually"
		saved.RemoveLast()
		entry.active=False
		RestoreState(entry)
	End Method

	Rem
	bbdoc: Restores a saved target, view, font and drawing state.
	param: Saved canvas state to restore.
	End Rem
	Method RestoreState(entry:TMax2DSavedState)
		SetRenderImage(entry.target)
		state = entry.state
		imageFont = entry.font
		context.view.width = entry.width
		context.view.height = entry.height
		context.view.x = entry.x
		context.view.y = entry.y
		context.view.w = entry.w
		context.view.h = entry.h
		context.view.automatic = entry.automatic
		context.view.fullClip = entry.fullClip
		context.view.presentation = entry.presentation
		context.view.barRed=entry.barRed
		context.view.barGreen=entry.barGreen
		context.view.barBlue=entry.barBlue
		context.ApplyView()
	End Method

	Rem
	bbdoc: Copies camera settings into the canvas state, or disables the camera for Null.
	param: Camera to snapshot; Null disables the camera transform.
	End Rem
	Method SetCamera(camera:TCamera2D)
		If camera Then camera.Validate()
		state.camera=Null
		state.cameraXX=1
		state.cameraXY=0
		state.cameraYX=0
		state.cameraYY=1
		state.cameraTX=0
		state.cameraTY=0
		If Not camera Then Return
		state.camera=camera.Copy()
		Local c:Double=Cos(camera.rotation)*camera.zoom,s:Double=Sin(camera.rotation)*camera.zoom
		state.cameraXX=c
		state.cameraXY=s
		state.cameraYX=-s
		state.cameraYY=c
		state.cameraTX=camera.offsetX-c*camera.x-s*camera.y
		state.cameraTY=camera.offsetY+s*camera.x-c*camera.y
	End Method

	Rem
	bbdoc: Transforms a scene vertex through parent coordinates and camera before batching it.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	param: Horizontal normalized texture coordinate.
	param: Vertical normalized texture coordinate.
	End Rem
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

	Rem
	bbdoc: Clears the current drawing surface using the clear colour and viewport.
	End Rem
	Method Cls()
		context.CheckOpen()
		context.Flush()
		ValidateSize()
		context.ApplyView()
		context.NativeClear(state.clsRed, state.clsGreen, state.clsBlue, state.clsAlpha)
	End Method

	Rem
	bbdoc: Transforms an object vertex and appends it with the current colour and opacity.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	param: Horizontal translation.
	param: Vertical translation.
	param: Horizontal normalized texture coordinate.
	param: Vertical normalized texture coordinate.
	End Rem
	Method AddVertex(x:Float, y:Float, tx:Float, ty:Float, u:Float = 0, v:Float = 0)
		SceneVertex(x * state.ix + y * state.iy + tx, x * state.jx + y * state.jy + ty,u,v)
	End Method

	Rem
	bbdoc: Adds two triangles for a textured or untextured rectangle.
	param: Texture frame to sample, or Null for untextured geometry.
	param: Left coordinate of the local rectangle.
	param: Top coordinate of the local rectangle.
	param: Horizontal coordinate of the first endpoint or rectangle's opposite corner.
	param: Vertical coordinate of the first endpoint or rectangle's opposite corner.
	param: Horizontal translation.
	param: Vertical translation.
	param: Normalized texture coordinate at the left edge.
	param: Normalized texture coordinate at the top edge.
	param: Normalized texture coordinate at the right edge.
	param: Normalized texture coordinate at the bottom edge.
	End Rem
	Method Quad(frame:TImageFrame, x0:Float, y0:Float, x1:Float, y1:Float, tx:Float, ty:Float, u0:Float = 0, v0:Float = 0, u1:Float = 0, v1:Float = 0)
		context.BeginTriangles(frame, state.blend, 6)
		AddVertex(x0,y0,tx,ty,u0,v0)
		AddVertex(x1,y0,tx,ty,u1,v0)
		AddVertex(x1,y1,tx,ty,u1,v1)
		AddVertex(x0,y0,tx,ty,u0,v0)
		AddVertex(x1,y1,tx,ty,u1,v1)
		AddVertex(x0,y1,tx,ty,u0,v1)
	End Method

	Rem
	bbdoc: Draws a point using the current colour, blend mode and transform.
	param: Horizontal drawing position before the active transforms.
	param: Vertical drawing position before the active transforms.
	End Rem
	Method Plot(x:Float, y:Float)
		Local old:TMax2DState = state
		state = state.Copy()
		state.ix = 1
		state.iy = 0
		state.jx = 0
		state.jy = 1
		Quad(Null, 0,0,1,1, x + state.originX, y + state.originY)
		state = old
	End Method

	Rem
	bbdoc: Draws a filled rectangle using the current drawing state.
	param: Horizontal drawing position before the active transforms.
	param: Vertical drawing position before the active transforms.
	param: Destination width in local drawing units.
	param: Destination height in local drawing units.
	End Rem
	Method DrawRect(x:Float, y:Float, width:Float, height:Float)
		If width = 0 Or height = 0 Then Return
		Quad(Null, -state.handleX, -state.handleY, width-state.handleX, height-state.handleY, x+state.originX, y+state.originY)
	End Method

	Rem
	bbdoc: Draws a line using the current colour, line width and transform.
	param: Horizontal drawing position before the active transforms.
	param: Vertical drawing position before the active transforms.
	param: Horizontal coordinate of the second endpoint.
	param: Vertical coordinate of the second endpoint.
	param: Whether to include the final pixel; retained for compatibility with the immediate drawing API.
	End Rem
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
		dx :/ length
		dy :/ length
		sx :- dx*0.5
		sy :- dy*0.5
		If drawLastPixel Then
			ex :+ dx*0.5
			ey :+ dy*0.5
		Else
			ex :- dx*0.5
			ey :- dy*0.5
		End If
		Local nx:Float = -dy * state.lineWidth * 0.5, ny:Float = dx * state.lineWidth * 0.5
		Local points:Float[] = [sx+nx,sy+ny, ex+nx,ey+ny, ex-nx,ey-ny, sx-nx,sy-ny]
		Local order:Int[] = [0,1,2,0,2,3]
		context.BeginTriangles(Null, state.blend, 6)
		For Local index:Int = EachIn order
			SceneVertex(points[index*2],points[index*2+1])
		Next
	End Method

	Rem
	bbdoc: Draws a filled ellipse inside the supplied rectangle.
	param: Horizontal drawing position before the active transforms.
	param: Vertical drawing position before the active transforms.
	param: Destination width in local drawing units.
	param: Destination height in local drawing units.
	End Rem
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

	Rem
	bbdoc: Draws a reusable triangle mesh at the supplied position.
	param: Triangle mesh to draw.
	param: Horizontal drawing position before the active transforms.
	param: Vertical drawing position before the active transforms.
	End Rem
	Method DrawMesh(mesh:TMesh2D, x:Float = 0, y:Float = 0)
		For Local triangle:Int = 0 Until mesh.indices.Length Step 3
			context.BeginTriangles(Null, state.blend, 3)
			For Local corner:Int = 0 Until 3
				Local index:Int = mesh.indices[triangle+corner] * 2
				AddVertex(mesh.xy[index]-state.handleX,mesh.xy[index+1]-state.handleY,x+state.originX,y+state.originY)
			Next
		Next
	End Method

	Rem
	bbdoc: Draws a source image rectangle with explicit destination size and handle.
	param: Image to operate on.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	param: Destination width in local drawing units.
	param: Destination height in local drawing units.
	param: Left edge of the source rectangle in image pixels.
	param: Top edge of the source rectangle in image pixels.
	param: Source rectangle width in image pixels.
	param: Source rectangle height in image pixels.
	param: Horizontal handle offset within the source rectangle.
	param: Vertical handle offset within the source rectangle.
	param: Zero-based image frame index.
	End Rem
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
			ox=trim.x
			oy=trim.y
			left=Max(left,Float(ox))
			top=Max(top,Float(oy))
			right=Min(right,Float(ox+trim.width))
			bottom=Min(bottom,Float(oy+trim.height))
			If right<=left Or bottom<=top Then Return
			x0=-hx+(left-sx)*width/sw
			y0=-hy+(top-sy)*height/sh
			x1=-hx+(right-sx)*width/sw
			y1=-hy+(bottom-sy)*height/sh
		End If
		Local native:TImageFrame=image.Frame(frame,Self)
		Local source:TImageSource=image.sources[frame]
		Local u0:Float=(image.sourceX[frame]+left-ox)/Float(source.width)
		Local v0:Float=(image.sourceY[frame]+top-oy)/Float(source.height)
		Local u1:Float=(image.sourceX[frame]+right-ox)/Float(source.width)
		Local v1:Float=(image.sourceY[frame]+bottom-oy)/Float(source.height)
		Quad(native,x0,y0,x1,y1,x+state.originX,y+state.originY,u0,v0,u1,v1)
	End Method

	Rem
	bbdoc: Draws one image frame using its handle and the current drawing state.
	param: Image to operate on.
	param: Horizontal drawing position before the active transforms.
	param: Vertical drawing position before the active transforms.
	param: Zero-based image frame index.
	End Rem
	Method DrawImage(image:TImage, x:Float, y:Float, frame:Int = 0)
		If image Then DrawImageRegion(image,x,y,image.width,image.height,0,0,image.width,image.height,image.handle_x,image.handle_y,frame)
	End Method

	Rem
	bbdoc: Copies a pixmap to the current drawing surface at native pixel coordinates.
	param: Source pixel data.
	param: Horizontal native-pixel coordinate.
	param: Vertical native-pixel coordinate.
	End Rem
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
			state=originalState
			context.view=originalView
			context.ApplyView()
			Throw error
		End Try
		state=originalState
		context.view=originalView
		context.ApplyView()
	End Method

	Rem
	bbdoc: Draws text with the current image font and drawing state.
	param: Text to lay out, measure or draw.
	param: Horizontal drawing position before the active transforms.
	param: Vertical drawing position before the active transforms.
	End Rem
	Method DrawText(text:String, x:Float, y:Float)
		imageFont.Layout(text).Draw(Self, x, y)
	End Method

End Type
