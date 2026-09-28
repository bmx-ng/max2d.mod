Private
Global _autoImageFlags:Int = MASKEDIMAGE | FILTEREDIMAGE
Global _autoMidHandle:Int
Global _maskRed:Int, _maskGreen:Int, _maskBlue:Int
Public

Function Cls()
	TMax2DGraphics.Current().Cls()
End Function
Function Plot(x:Float,y:Float)
	TMax2DGraphics.Current().Plot(x,y)
End Function
Function DrawRect(x:Float,y:Float,width:Float,height:Float)
	TMax2DGraphics.Current().DrawRect(x,y,width,height)
End Function
Function DrawLine(x:Float,y:Float,x2:Float,y2:Float,draw_last_pixel:Int = True)
	TMax2DGraphics.Current().DrawLine(x,y,x2,y2,draw_last_pixel)
End Function
Function DrawOval(x:Float,y:Float,width:Float,height:Float)
	TMax2DGraphics.Current().DrawOval(x,y,width,height)
End Function
Function DrawPoly(xy:Float[],indices:Int[] = Null)
	TMax2DGraphics.Current().DrawMesh(TMesh2D.Create(xy,indices))
End Function
Function DrawMesh(mesh:TMesh2D,x:Float=0,y:Float=0)
	TMax2DGraphics.Current().DrawMesh(mesh,x,y)
End Function
Function DrawImage(image:TImage,x:Float,y:Float,frame:Int=0)
	TMax2DGraphics.Current().DrawImage(image,x,y,frame)
End Function
Function DrawImageRect(image:TImage,x:Float,y:Float,width:Float,height:Float,frame:Int=0)
	If image Then TMax2DGraphics.Current().DrawImageRegion(image,x,y,width,height,0,0,image.width,image.height,image.handle_x,image.handle_y,frame)
End Function
Function DrawSubImageRect(image:TImage,x:Float,y:Float,width:Float,height:Float,sx:Float,sy:Float,swidth:Float,sheight:Float,hx:Float=0,hy:Float=0,frame:Int=0)
	If swidth <= 0 Or sheight <= 0 Then Return
	TMax2DGraphics.Current().DrawImageRegion(image,x,y,width,height,sx,sy,swidth,sheight,hx*width/swidth,hy*height/sheight,frame)
End Function
Function DrawPixmap(pixmap:TPixmap,x:Int,y:Int)
	TMax2DGraphics.Current().DrawPixmap(pixmap,x,y)
End Function
Function GrabPixmap:TPixmap(x:Int,y:Int,width:Int,height:Int)
	Local context:TMax2DContext = TMax2DGraphics.Current().context
	Return context.Read(context.target,x,y,width,height)
End Function
Function FlushMax2D()
	TMax2DGraphics.Current().context.Flush()
End Function
Rem
bbdoc: Returns a detached copy of the current context's rendering counters.
about: By default submits pending geometry first. Pass False to observe completed submissions without disturbing batching. This does not wait for the GPU.
End Rem
Function CaptureMax2DStats:TMax2DStats(flush:Int=True)
	Local context:TMax2DContext=TMax2DGraphics.Current().context
	If flush Then context.Flush()
	Return context.stats.Copy()
End Function
Rem
bbdoc: Submits pending geometry and resets the current context's counters to zero.
about: Call before the section you want to measure. Counters are not reset automatically by Flip.
End Rem
Function ResetMax2DStats()
	Local context:TMax2DContext=TMax2DGraphics.Current().context
	context.Flush()
	context.stats.Reset()
End Function
Rem
bbdoc: Returns the current context's live cumulative counters without flushing.
about: Use CaptureMax2DStats for a snapshot that will not change as drawing continues.
End Rem
Function Max2DStats:TMax2DStats()
	Return TMax2DGraphics.Current().context.stats
End Function
Function Max2DSupportsBlend:Int(blend:Int)
	Return TMax2DGraphics.Current().context.SupportsBlend(blend)
End Function
Rem
bbdoc: Reports the active context's maximum texture width and height in pixels.
about: Zero means no limit was reported, not unlimited memory. These are hardware bounds, not a guarantee that an allocation will succeed. Render images may have additional shape constraints.
End Rem
Function GetMax2DTextureSize(width:Int Var,height:Int Var)
	TMax2DGraphics.Current().context.TextureSize(width,height)
End Function
Rem
bbdoc: Whether this context supports a render image with the given dimensions, flags and pixel format.
about: Uses the same default image flags as CreateRenderImage. pixelFormat defaults to PF_RGBA8888; PF_RGBA16F and PF_RGBA32F require floating-point rendering and blending support. Checks known limits and format support without creating an image. Available memory and device loss can still cause creation to fail.
End Rem
Function Max2DSupportsRenderImage:Int(width:Int,height:Int,flags:Int=-1,pixelFormat:Int=PF_RGBA8888)
	If flags=-1 Then flags=_autoImageFlags
	Return TMax2DGraphics.Current().context.SupportsRenderImageFormat(width,height,flags,pixelFormat)
End Function
Rem
bbdoc: Reports native, converted or unsupported storage for a sampled image texture.
about: Queries the active backend without allocating an image. pixelFormat is the final storage argument to TImage.FromPixmap or TTextureAtlas.Create, not an input pixmap's format. flags defaults to zero, matching TImage.FromPixmap. Native refers to channel storage and precision, not zero-copy upload or byte order. Converted preserves drawing semantics using another representation (currently A8 to RGBA). Unsupported does not prevent loading a pixmap through ordinary RGBA conversion. This query does not check dimensions or available memory and does not describe render targets; use GetMax2DTextureSize and Max2DSupportsRenderImage for those. Requery after graphics-context or device changes.
End Rem
Function Max2DTextureFormatSupport:ETextureFormatSupport(pixelFormat:Int,flags:Int=0)
	Return TMax2DGraphics.Current().context.TextureFormatSupport(pixelFormat,flags)
End Function
Rem
bbdoc: Reports support for supplied texture data without allocating an image.
about: Checks format, dimensions and flags, including supplied mip levels. Multiple levels enable mip sampling automatically; partial chains are allowed. DYNAMICIMAGE is unsupported. A single level with MIPMAPPEDIMAGE requests automatic generation, as in Max2DTextureFormatSupport. Available memory and device loss may still prevent allocation. Requery after context or device changes.
End Rem
Function Max2DTextureDataSupport:ETextureFormatSupport(data:TTextureData,flags:Int=0)
	Return TMax2DGraphics.Current().context.TextureDataSupport(data,flags)
End Function
Function Max2DSupportsImageFlags:Int(flags:Int)
	Return TMax2DGraphics.Current().context.SupportsImageFlags(flags)
End Function
Rem
bbdoc: Whether the current backend implements runtime exclusive fullscreen switching.
about: Individual display modes or transitions may still be rejected by the window system.
End Rem
Function Max2DSupportsFullscreen:Int()
	Return TMax2DGraphics.Current().context.SupportsFullscreen()
End Function
Function Max2DSupportsBorderlessFullscreen:Int()
	Return TMax2DGraphics.Current().context.SupportsBorderlessFullscreen()
End Function
Rem
bbdoc: Returns MAX2D_WINDOWED, MAX2D_FULLSCREEN or MAX2D_BORDERLESS_FULLSCREEN.
about: Describes the established application mode, including exclusive mode temporarily suspended by focus loss.
End Rem
Function GetWindowMode:Int()
	Return TMax2DGraphics.Current().context.WindowMode()
End Function
Rem
bbdoc: Switches the current window into exclusive fullscreen, or restores windowed mode.
about: Zero dimensions use the current drawing size; zero hertz selects the backend's preferred refresh rate.
Select the window render target first. Disabling also leaves borderless fullscreen.
End Rem
Function SetFullscreen(enabled:Int,width:Int=0,height:Int=0,hertz:Int=0)
	Local mode:Int=MAX2D_WINDOWED
	If enabled Then mode=MAX2D_FULLSCREEN
	_SetMax2DWindowMode(mode,width,height,hertz)
End Function
Rem
bbdoc: Fills the current display without changing its desktop display mode.
about: Disabling restores the saved window only when currently borderless fullscreen.
End Rem
Function SetBorderlessFullscreen(enabled:Int)
	If Not enabled And GetWindowMode()<>MAX2D_BORDERLESS_FULLSCREEN Then Return
	Local mode:Int=MAX2D_WINDOWED
	If enabled Then mode=MAX2D_BORDERLESS_FULLSCREEN
	_SetMax2DWindowMode(mode,0,0,0)
End Function
Private
Function _SetMax2DWindowMode(mode:Int,width:Int,height:Int,hertz:Int)
	Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
	Local context:TMax2DContext=canvas.context
	If context.target Then Throw "Max2D: select the window before changing fullscreen"
	If mode=MAX2D_WINDOWED And context.WindowMode()=MAX2D_WINDOWED Then Return
	If mode=MAX2D_FULLSCREEN And (width<0 Or height<0 Or hertz<0) Then Throw "Max2D: fullscreen dimensions and hertz must not be negative"
	context.Flush()
	Try
		context.SetWindowMode(mode,width,height,hertz)
	Catch error:Object
		' A failed native transition may have changed the window. Refresh cached settings.
		SetGraphics(canvas)
		Throw error
	End Try
	SetGraphics(canvas)
End Function
Public

Function PushMax2DState()
	TMax2DGraphics.Current().PushState()
End Function
Function PopMax2DState()
	TMax2DGraphics.Current().PopState()
End Function
Rem
bbdoc: Saves drawing state for deterministic restoration with Using/ICloseable.
End Rem
Function ScopedMax2DState:TMax2DStateScope()
 Local result:TMax2DStateScope=New TMax2DStateScope
 result.canvas=TMax2DGraphics.Current()
 result.entry=result.canvas.PushState()
 result.entry.scoped=True
 Return result
End Function
Rem
bbdoc: Applies a snapshot of the camera, or identity for Null. Does not change viewport or presentation.
End Rem
Function SetCamera(camera:TCamera2D)
 TMax2DGraphics.Current().SetCamera(camera)
End Function
Rem
bbdoc: Returns a detached copy of the applied camera, or Null when disabled.
End Rem
Function GetCamera:TCamera2D()
 Local camera:TCamera2D=TMax2DGraphics.Current().state.camera
 If camera Then Return camera.Copy()
 Return Null
End Function
Function WorldToVirtual(x:Float,y:Float,viewX:Float Var,viewY:Float Var)
 Local camera:TCamera2D=TMax2DGraphics.Current().state.camera
 If camera Then
  camera.WorldToVirtual(x,y,viewX,viewY)
 Else
  viewX=x; viewY=y
 End If
End Function
Function VirtualToWorld(x:Float,y:Float,worldX:Float Var,worldY:Float Var)
 Local camera:TCamera2D=TMax2DGraphics.Current().state.camera
 If camera Then
  camera.VirtualToWorld(x,y,worldX,worldY)
 Else
  worldX=x; worldY=y
 End If
End Function
Rem
bbdoc: Captures window presentation and camera for stable world picking across overlays.
about: Select the window and its camera before capturing. Render-image presentation requires its own additional mapping.
End Rem
Function CaptureCameraInput:TMax2DCameraInput()
 If TMax2DGraphics.Current().renderImage Then Throw "Max2D: capture camera input with the window selected"
 Local result:TMax2DCameraInput=New TMax2DCameraInput
 result.mapping=CaptureWindowInput()
 result.camera=GetCamera()
 If Not result.camera Then result.camera=New TCamera2D
 Return result
End Function
Function WindowToWorld:Int(x:Float,y:Float,worldX:Float Var,worldY:Float Var,checkViewport:Int=False)
 Return CaptureCameraInput().WindowToWorld(x,y,worldX,worldY,checkViewport)
End Function
Function WorldToWindow:Int(x:Float,y:Float,windowX:Float Var,windowY:Float Var)
 Return CaptureCameraInput().WorldToWindow(x,y,windowX,windowY)
End Function
Function GetWorldMouse:Int(x:Float Var,y:Float Var,checkViewport:Int=False)
 Return WindowToWorld(MouseX(),MouseY(),x,y,checkViewport)
End Function

Function SetColor(red:Int,green:Int,blue:Int)
	TMax2DGraphics.Current().SetColor(red,green,blue)
End Function
Function SetColor(red:Int,green:Int,blue:Int,alpha:Float)
	SetColor(red,green,blue); SetAlpha(alpha)
End Function
Function SetColor(color:SColor8)
	SetColor(color.r,color.g,color.b)
	TMax2DGraphics.Current().state.colorByteAlpha=color.a
End Function
Function SetColor(color:SColor8,alpha:Float)
	SetColor(color); SetAlpha(alpha)
End Function
Function GetColor(red:Int Var,green:Int Var,blue:Int Var)
	Local state:TMax2DState = TMax2DGraphics.Current().state
	red=state.red; green=state.green; blue=state.blue
End Function
Function GetColor(red:Int Var,green:Int Var,blue:Int Var,alpha:Float Var)
	GetColor(red,green,blue); alpha=GetAlpha()
End Function
Rem
bbdoc: Draws paragraph lines intersecting a local vertical band; use a viewport to clip the edges.
about: For vertical scrolling, draw at (x, y-scrollY), with top=scrollY and bottom=scrollY+viewportHeight. Test input against the viewport before calling HitTest(localX, localY+scrollY).
End Rem
Function DrawTextLayoutVisible(layout:TParagraphLayout,x:Float,y:Float,top:Float,bottom:Float,backgrounds:Int=True)
	If Not layout Then Throw "Max2D: text layout is null"
	layout.DrawVisible(TMax2DGraphics.Current(),x,y,top,bottom,backgrounds)
End Function

Function GetColor(color:SColor8 Var)
	Local r:Int,g:Int,b:Int
	GetColor(r,g,b); color=New SColor8(r,g,b,TMax2DGraphics.Current().state.colorByteAlpha)
End Function
Function SetAlpha(alpha:Float)
	TMax2DGraphics.Current().SetAlpha(alpha)
End Function
Function GetAlpha:Float()
	Return TMax2DGraphics.Current().state.alpha
End Function
Function SetBlend(blend:Int)
	TMax2DGraphics.Current().SetBlend(blend)
End Function
Function GetBlend:Int()
	Return TMax2DGraphics.Current().state.blend
End Function
Function SetClsColor(red:Int,green:Int,blue:Int,alpha:Float=1)
	TMax2DGraphics.Current().SetClsColor(red,green,blue,alpha)
End Function
Function SetClsColor(color:SColor8,alpha:Float=1)
	SetClsColor(color.r,color.g,color.b,alpha)
	TMax2DGraphics.Current().state.clsByteAlpha=color.a
End Function
Function GetClsColor(red:Int Var,green:Int Var,blue:Int Var)
	Local state:TMax2DState = TMax2DGraphics.Current().state
	red=state.clsRed; green=state.clsGreen; blue=state.clsBlue
End Function
Function GetClsColor(red:Int Var,green:Int Var,blue:Int Var,alpha:Float Var)
	GetClsColor(red,green,blue); alpha=TMax2DGraphics.Current().state.clsAlpha
End Function
Function SetLineWidth(width:Float)
	TMax2DGraphics.Current().SetLineWidth(width)
End Function
Function GetLineWidth:Float()
	Return TMax2DGraphics.Current().state.lineWidth
End Function
Function SetOrigin(x:Float,y:Float)
	Local state:TMax2DState=TMax2DGraphics.Current().state
	state.originX=x; state.originY=y
End Function
Function GetOrigin(x:Float Var,y:Float Var)
	Local state:TMax2DState=TMax2DGraphics.Current().state
	x=state.originX; y=state.originY
End Function
Function SetHandle(x:Float,y:Float)
	Local state:TMax2DState=TMax2DGraphics.Current().state
	state.handleX=x; state.handleY=y
End Function
Function GetHandle(x:Float Var,y:Float Var)
	Local state:TMax2DState=TMax2DGraphics.Current().state
	x=state.handleX; y=state.handleY
End Function
Function SetRotation(rotation:Float)
	Local state:TMax2DState=TMax2DGraphics.Current().state
	state.rotation=rotation; state.Transform()
End Function
Function GetRotation:Float()
	Return TMax2DGraphics.Current().state.rotation
End Function
Function SetScale(x:Float,y:Float)
	Local state:TMax2DState=TMax2DGraphics.Current().state
	state.scaleX=x; state.scaleY=y; state.Transform()
End Function
Function GetScale(x:Float Var,y:Float Var)
	Local state:TMax2DState=TMax2DGraphics.Current().state
	x=state.scaleX; y=state.scaleY
End Function
Function SetTransform(rotation:Float=0,scale_x:Float=1,scale_y:Float=1)
	Local state:TMax2DState=TMax2DGraphics.Current().state
	state.rotation=rotation; state.scaleX=scale_x; state.scaleY=scale_y; state.Transform()
End Function
Function SetAffineTransform(xx:Float,xy:Float,yx:Float,yy:Float)
	Local state:TMax2DState=TMax2DGraphics.Current().state
	state.ix=xx; state.iy=xy; state.jx=yx; state.jy=yy
End Function
Rem
bbdoc: Resets the parent coordinate transform, leaving the object transform and camera unchanged.
End Rem
Function ResetCoordinates()
	Local state:TMax2DState=TMax2DGraphics.Current().state
	state.coordXX=1;state.coordXY=0;state.coordYX=0;state.coordYY=1;state.coordTX=0;state.coordTY=0
End Function

Rem
bbdoc: Composes a local affine coordinate transform with the current parent transform.
about: New coordinates pass through this transform first, then the previous parent. PushMax2DState or ScopedMax2DState restores the parent.
End Rem
Function TransformCoordinates(xx:Double,xy:Double,yx:Double,yy:Double,tx:Double=0,ty:Double=0)
	Local state:TMax2DState=TMax2DGraphics.Current().state
	Local a:Double=state.coordXX*xx+state.coordXY*yx,b:Double=state.coordXX*xy+state.coordXY*yy
	Local c:Double=state.coordYX*xx+state.coordYY*yx,d:Double=state.coordYX*xy+state.coordYY*yy
	Local x:Double=state.coordXX*tx+state.coordXY*ty+state.coordTX,y:Double=state.coordYX*tx+state.coordYY*ty+state.coordTY
	If IsNan(a) Or IsInf(a) Or IsNan(b) Or IsInf(b) Or IsNan(c) Or IsInf(c) Or IsNan(d) Or IsInf(d) Or IsNan(x) Or IsInf(x) Or IsNan(y) Or IsInf(y) Then Throw "Max2D: coordinate transform must be finite"
	state.coordXX=a;state.coordXY=b;state.coordYX=c;state.coordYY=d;state.coordTX=x;state.coordTY=y
End Function
Function TranslateCoordinates(x:Double,y:Double)
	TransformCoordinates(1,0,0,1,x,y)
End Function
Function RotateCoordinates(angle:Double)
	TransformCoordinates(Cos(angle),-Sin(angle),Sin(angle),Cos(angle))
End Function
Function ScaleCoordinates(x:Double,y:Double)
	TransformCoordinates(x,0,0,y)
End Function

Rem
bbdoc: Intersects the current viewport with a rectangle in virtual screen coordinates.
about: Coordinate transforms and cameras do not move the clip. Empty intersections remain empty; negative sizes are rejected.
End Rem
Function IntersectViewport(x:Int,y:Int,width:Int,height:Int)
	If width<0 Or height<0 Then Throw "Max2D: viewport dimensions must not be negative"
	Local view:TMax2DView=TMax2DGraphics.Current().context.view
	Local left:Long=Max(Long(x),Long(view.x)),top:Long=Max(Long(y),Long(view.y))
	Local right:Long=Min(Long(x)+width,Long(view.x)+view.w),bottom:Long=Min(Long(y)+height,Long(view.y)+view.h)
	SetViewport(Int(left),Int(top),Int(Max(0:Long,right-left)),Int(Max(0:Long,bottom-top)))
End Function

Function SetViewport(x:Int,y:Int,width:Int,height:Int)
	TMax2DGraphics.Current().SetViewport(x,y,width,height)
End Function
Function GetViewport(x:Int Var,y:Int Var,width:Int Var,height:Int Var)
	Local view:TMax2DView=TMax2DGraphics.Current().context.view
	x=view.x; y=view.y; width=view.w; height=view.h
End Function

Function LoadImage:TImage(url:Object,flags:Int=-1)
	If flags=-1 Then flags=_autoImageFlags
	Local data:TTextureData=TTextureData(url)
	Local pixmap:TPixmap=TPixmap(url)
	If Not data And Not pixmap And HasTextureDataLoaders() Then
		Local stream:TStream=ReadStream(url)
		If Not stream Then Return Null
		Try
			data=LoadTextureData(stream)
			If Not data Then pixmap=LoadPixmap(stream)
		Catch error:Object
			stream.Close()
			Throw error
		End Try
		stream.Close()
		If Not data And Not pixmap Then Return Null
	End If
	If data Then
		Local image:TImage=TImage.FromTextureData(data,flags)
		If _autoMidHandle Then MidHandleImage(image)
		Return image
	End If
	If Not pixmap Then pixmap=LoadPixmap(url)
	If Not pixmap Then Return Null
	If (flags & MASKEDIMAGE) And AlphaBitsPerPixel[pixmap.format]=0 Then pixmap=MaskPixmap(pixmap,_maskRed,_maskGreen,_maskBlue)
	Local image:TImage=TImage.FromPixmap(pixmap,flags)
	If _autoMidHandle Then MidHandleImage(image)
	Return image
End Function
Function CreateImage:TImage(width:Int,height:Int,frames:Int=1,flags:Int=-1)
	If width<=0 Or height<=0 Or frames<=0 Then Throw "Max2D: image dimensions and frame count must be positive"
	If flags=-1 Then flags=_autoImageFlags
	flags :| DYNAMICIMAGE
	Local image:TImage=New TImage
	image.width=width; image.height=height; image.flags=flags
	image.sources=New TImageSource[frames]
	image.sourceX=New Int[frames]; image.sourceY=New Int[frames]; image.frameDuration=New Int[frames]
	For Local i:Int=0 Until frames
		Local source:TImageSource=New TImageSource
		source.width=width; source.height=height; source.flags=flags
		source.pixmap=CreatePixmap(width,height,PF_RGBA8888); source.pixmap.ClearPixels(0)
		image.sources[i]=source
	Next
	If _autoMidHandle Then MidHandleImage(image)
	Return image
End Function
Function LoadAnimImage:TImage(url:Object,cell_width:Int,cell_height:Int,first_cell:Int,cell_count:Int,flags:Int=-1)
	If cell_width<=0 Or cell_height<=0 Or first_cell<0 Or cell_count<=0 Then Throw "Max2D: invalid animation dimensions"
	Local sheet:TImage=LoadImage(url,flags)
	If Not sheet Then Return Null
	Local columns:Int=sheet.width/cell_width, rows:Int=sheet.height/cell_height
	If first_cell+cell_count>columns*rows Then Throw "Max2D: animation cells outside source image"
	Local image:TImage=New TImage
	image.width=cell_width; image.height=cell_height; image.flags=sheet.flags
	image.sources=New TImageSource[cell_count]
	image.sourceX=New Int[cell_count]; image.sourceY=New Int[cell_count]; image.frameDuration=New Int[cell_count]
	Local suppliedViews:Int=sheet.sources[0].textureData And (sheet.sources[0].textureData.LevelCount()>1 Or sheet.sources[0].textureData.Format()>=PF_RGBA16F)
	Local atlas:TTextureAtlas
	If Not suppliedViews And (sheet.flags & FILTEREDIMAGE) And Not (sheet.flags & MIPMAPPEDIMAGE) Then atlas=TTextureAtlas.Create(1024,sheet.flags)
	For Local i:Int=0 Until cell_count
		Local x:Int=((first_cell+i) Mod columns)*cell_width,y:Int=((first_cell+i)/columns)*cell_height
		If suppliedViews Then
			' Preserve the caller's supplied chain; cells remain views of the sheet.
			image.sources[i]=sheet.sources[0]
			image.sourceX[i]=x
			image.sourceY[i]=y
		Else If sheet.flags & MIPMAPPEDIMAGE Then
			Local cell:TImage=TImage.FromPixmap(sheet.sources[0].ReadPixels().Window(x,y,cell_width,cell_height),sheet.flags)
			image.sources[i]=cell.sources[0]
		Else If atlas Then
			Local view:TImage=atlas.AddPixmap(sheet.sources[0].ReadPixels().Window(x,y,cell_width,cell_height))
			image.sources[i]=view.sources[0]; image.sourceX[i]=view.sourceX[0]; image.sourceY[i]=view.sourceY[0]
		Else
			image.sources[i]=sheet.sources[0]; image.sourceX[i]=x; image.sourceY[i]=y
		End If
	Next
	If _autoMidHandle Then MidHandleImage(image)
	Return image
End Function
Function CreateImageView:TImage(image:TImage,x:Int,y:Int,width:Int,height:Int,frame:Int=0)
	Return TImage.View(image,x,y,width,height,frame)
End Function
Rem
bbdoc: Creates an image that can be used as a drawing destination.
about: pixelFormat defaults to PF_RGBA8888. PF_RGBA16F and PF_RGBA32F preserve colour values outside 0–1 on supported OpenGL and D3D11 devices. Query Max2DSupportsRenderImage first. Floating-point targets do not support automatic mipmaps or pixmap readback; use ReadRenderTextureData. Native storage is allocated when first used.
End Rem
Function CreateRenderImage:TRenderImage(width:UInt,height:UInt,flags:Int=-1,pixelFormat:Int=PF_RGBA8888)
	If flags=-1 Then flags=_autoImageFlags
	Local image:TRenderImage=TRenderImage.Create(Int(width),Int(height),flags,pixelFormat)
	If _autoMidHandle Then MidHandleImage(image)
	Return image
End Function
Function SetRenderImage(image:TRenderImage)
	TMax2DGraphics.Current().SetRenderImage(image)
End Function
Function LockImage:TPixmap(image:TImage,frame:Int=0,read_lock:Int=True,write_lock:Int=True)
	Return image.Lock(frame,read_lock,write_lock)
End Function
Function UnlockImage(image:TImage,frame:Int=0)
	image.Unlock(frame)
End Function
Function ReadRenderImage:TPixmap(image:TRenderImage)
	Local context:TMax2DContext=TMax2DGraphics.Current().context
	Return context.Read(image.Frame(0),0,0,image.width,image.height)
End Function
Rem
bbdoc: Reads a render image into owned texture data without reducing floating-point range.
about: Returns RGBA8888 for ordinary targets and RGBA32F for floating-point targets, with top-left row order and straight alpha. RGBA16F is widened to RGBA32F. This synchronises with the GPU; avoid per-frame readback when the result can remain on the GPU. Zero-alpha RGB is returned as zero. ReadRenderImage and pixmap operations reject floating-point targets.
End Rem
Function ReadRenderTextureData:TTextureData(image:TRenderImage)
	If Not image Then Throw "Max2D: render image is null"
	Return TMax2DGraphics.Current().context.ReadTexture(image.Frame())
End Function
Function GrabImage(image:TImage,x:Int,y:Int,frame:Int=0)
	Local pixmap:TPixmap=GrabPixmap(x,y,image.width,image.height)
	Local destination:TPixmap=LockImage(image,frame,False,True)
	destination.Paste(pixmap,0,0)
	UnlockImage(image,frame)
End Function
Function ClearImage(image:TImage,r:UInt=0,g:UInt=0,b:UInt=0,a:Float=0,frameIndex:Int=-1)
	If Not image Then Throw "Max2D: image is null"
	If frameIndex < -1 Or frameIndex >= image.sources.Length Then Throw "Max2D: image frame index out of range"
	If TRenderImage(image) Then
		Local frame:TImageFrame=image.Frame()
		Local savedView:TMax2DView=frame.view
		PushMax2DState()
		frame.view=New TMax2DView
		frame.view.Reset(image.width,image.height)
		Try
			SetRenderImage(TRenderImage(image)); SetClsColor(Int(r),Int(g),Int(b),a); Cls()
		Catch error:Object
			frame.view=savedView
			PopMax2DState()
			Throw error
		End Try
		frame.view=savedView
		PopMax2DState()
		Return
	End If
	Local first:Int=frameIndex,last:Int=frameIndex
	If frameIndex<0 Then first=0; last=image.sources.Length-1
	For Local frame:Int=first To last
		Local pixmap:TPixmap=LockImage(image,frame,False,True)
		pixmap.ClearPixels((Int(Max(0.0,Min(1.0,a))*255) Shl 24) | ((r & 255) Shl 16) | ((g & 255) Shl 8) | (b & 255))
		UnlockImage(image,frame)
	Next
End Function
Function SetImageHandle(image:TImage,x:Float,y:Float)
	image.handle_x=x; image.handle_y=y
End Function
Function MidHandleImage(image:TImage)
	image.handle_x=image.width*0.5; image.handle_y=image.height*0.5
End Function
Function ImageWidth:Int(image:TImage)
	Return image.width
End Function
Function ImageHeight:Int(image:TImage)
	Return image.height
End Function
Function AutoMidHandle(enable:Int)
	_autoMidHandle=enable
End Function
Function AutoImageFlags(flags:Int)
	_autoImageFlags=flags
End Function
Function GetAutoImageFlags:Int()
	Return _autoImageFlags
End Function
Function SetMaskColor(red:Int,green:Int,blue:Int)
	_maskRed=red; _maskGreen=green; _maskBlue=blue
End Function
Function GetMaskColor(red:Int Var,green:Int Var,blue:Int Var)
	red=_maskRed; green=_maskGreen; blue=_maskBlue
End Function
Function LoadImageFont:TImageFont(url:Object,size:Int,style:Int=SMOOTHFONT)
	Return TImageFont.Load(url,size,style)
End Function
Function SetImageFont(font:TImageFont)
	If Not font Then font=TImageFont.DefaultFont()
	TMax2DGraphics.Current().imageFont=font
End Function
Function GetImageFont:TImageFont()
	Return TMax2DGraphics.Current().imageFont
End Function
Function DrawText(text:String,x:Float,y:Float)
	TMax2DGraphics.Current().DrawText(text,x,y)
End Function
Function TextWidth:Int(text:String)
	Return Ceil(GetImageFont().Layout(text).width)
End Function
Function TextHeight:Int(text:String)
	Return Ceil(GetImageFont().Layout(text).height)
End Function
Function CreateTextLayout:TTextLayout(text:String,font:TImageFont=Null)
	If Not font Then font=GetImageFont()
	Return font.Layout(text)
End Function
Function SetVirtualResolution(width:Float,height:Float,presentation:Int=VIRTUAL_STRETCH)
	TMax2DGraphics.Current().SetVirtualResolution(width,height,presentation)
End Function
Function SetNativeResolution()
	Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
	canvas.context.view.fullClip=True
	canvas.SetVirtualResolution(canvas.context.pixelWidth,canvas.context.pixelHeight,VIRTUAL_NATIVE)
End Function
Function VirtualResolutionWidth:Float()
	Return TMax2DGraphics.Current().context.view.width
End Function
Function VirtualResolutionHeight:Float()
	Return TMax2DGraphics.Current().context.view.height
End Function
Function NativeResolutionWidth:Int()
	Return TMax2DGraphics.Current().context.pixelWidth
End Function
Function NativeResolutionHeight:Int()
	Return TMax2DGraphics.Current().context.pixelHeight
End Function
Function VirtualToNative(x:Float,y:Float,nativeX:Float Var,nativeY:Float Var)
	Local context:TMax2DContext=TMax2DGraphics.Current().context
	nativeX=context.pixelOffsetX+x*context.pixelScaleX
	nativeY=context.pixelOffsetY+y*context.pixelScaleY
End Function
Function NativeToVirtual(x:Float,y:Float,virtualX:Float Var,virtualY:Float Var)
	Local context:TMax2DContext=TMax2DGraphics.Current().context
	virtualX=(x-context.pixelOffsetX)/context.pixelScaleX
	virtualY=(y-context.pixelOffsetY)/context.pixelScaleY
End Function
Rem
bbdoc: Captures the current window presentation for input conversion, including high-DPI scaling.
End Rem
Function CaptureWindowInput:TMax2DInputMapping()
 Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
 Local w:Int,h:Int,pw:Int,ph:Int
 canvas.context.NativeInputSize(w,h)
 canvas.context.NativeOutputSize(pw,ph)
 Return TMax2DInputMapping.Create(canvas.context.windowView,w,h,pw,ph)
End Function
Function WindowToVirtual:Int(x:Float,y:Float,virtualX:Float Var,virtualY:Float Var,checkViewport:Int=False)
 Return CaptureWindowInput().WindowToVirtual(x,y,virtualX,virtualY,checkViewport)
End Function
Function VirtualToWindow:Int(x:Float,y:Float,windowX:Float Var,windowY:Float Var)
 Return CaptureWindowInput().VirtualToWindow(x,y,windowX,windowY)
End Function
Rem
bbdoc: Gets virtual mouse coordinates and returns whether the pointer is inside the scene.
End Rem
Function GetVirtualMouse:Int(x:Float Var,y:Float Var,checkViewport:Int=False)
 Return WindowToVirtual(MouseX(),MouseY(),x,y,checkViewport)
End Function
Function VirtualMouseInside:Int(checkViewport:Int=False)
 Local x:Float,y:Float
 Return GetVirtualMouse(x,y,checkViewport)
End Function
Function VirtualMouseX:Float()
 Local x:Float,y:Float
 GetVirtualMouse(x,y)
 Return x
End Function
Function VirtualMouseY:Float()
 Local x:Float,y:Float
 GetVirtualMouse(x,y)
 Return y
End Function
Function VirtualMouseXSpeed:Float()
 Local dx:Float,dy:Float
 CaptureWindowInput().WindowDeltaToVirtual(MouseXSpeed(),0,dx,dy)
 Return dx
End Function
Function VirtualMouseYSpeed:Float()
 Local dx:Float,dy:Float
 CaptureWindowInput().WindowDeltaToVirtual(0,MouseYSpeed(),dx,dy)
 Return dy
End Function
Function MoveVirtualMouse(x:Float,y:Float)
 Local wx:Float,wy:Float
 If VirtualToWindow(x,y,wx,wy) Then MoveMouse(Int(wx),Int(wy))
End Function
Rem
bbdoc: Captures the current transform and primitive handle for a draw at the supplied position.
End Rem
Function CaptureDrawTransform:TMax2DDrawTransform(drawX:Float=0,drawY:Float=0)
 Local state:TMax2DState=TMax2DGraphics.Current().state
 Return TMax2DDrawTransform.Create(state,drawX,drawY,state.handleX,state.handleY)
End Function
Rem
bbdoc: Captures the transform for DrawImage, using that image's handle.
about: For DrawImageRect or DrawSubImageRect also account for destination dimensions when testing source pixel coordinates.
End Rem
Function CaptureImageTransform:TMax2DDrawTransform(image:TImage,drawX:Float,drawY:Float)
 If Not image Then Throw "Max2D: image is null"
 Return TMax2DDrawTransform.Create(TMax2DGraphics.Current().state,drawX,drawY,image.handle_x,image.handle_y)
End Function
Function TileImage(image:TImage,x:Float=0,y:Float=0,frame:Int=0)
	If Not image Then Return
	Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
	PushMax2DState()
	SetTransform()
	Local view:TMax2DView=canvas.context.view
	Local left:Float=view.x,top:Float=view.y,right:Float=view.x+view.w,bottom:Float=view.y+view.h
	Local tileState:TMax2DState=canvas.state.Copy()
	tileState.originX=0;tileState.originY=0
	Local tileTransform:TMax2DDrawTransform=TMax2DDrawTransform.Create(tileState,0,0,0,0)
	If tileTransform.xx*tileTransform.yy-tileTransform.xy*tileTransform.yx=0 Then
		PopMax2DState()
		Return
	End If
	Local corners:Float[]=[left,top,right,top,right,bottom,left,bottom]
	For Local i:Int=0 Until 8 Step 2
		Local wx:Float,wy:Float
		tileTransform.VirtualToLocal(corners[i],corners[i+1],wx,wy)
		If i=0 Then
			left=wx;right=wx;top=wy;bottom=wy
		Else
			left=Min(left,wx);right=Max(right,wx);top=Min(top,wy);bottom=Max(bottom,wy)
		End If
	Next
	Local startX:Float=x+canvas.state.originX-image.handle_x
	Local startY:Float=y+canvas.state.originY-image.handle_y
	startX:-Floor((startX-left)/image.width)*image.width
	startY:-Floor((startY-top)/image.height)*image.height
	SetOrigin(0,0)
	For Local py:Float=startY-image.height Until bottom Step image.height
		For Local px:Float=startX-image.width Until right Step image.width
			canvas.DrawImageRegion(image,px,py,image.width,image.height,0,0,image.width,image.height,0,0,frame)
		Next
	Next
	PopMax2DState()
End Function

Rem
bbdoc: Sets the color used by Cls for unused space around the current virtual view.
End Rem
Function SetVirtualBarColor(red:Int,green:Int,blue:Int)
	Local view:TMax2DView=TMax2DGraphics.Current().context.view
	view.barRed=Min(255,Max(0,red)); view.barGreen=Min(255,Max(0,green)); view.barBlue=Min(255,Max(0,blue))
End Function
Function GetVirtualBarColor(red:Int Var,green:Int Var,blue:Int Var)
	Local view:TMax2DView=TMax2DGraphics.Current().context.view
	red=view.barRed; green=view.barGreen; blue=view.barBlue
End Function

Rem
bbdoc: Returns untransformed glyph bitmap bounds relative to the text origin.
about: Includes glyph bearings and overhangs; advance-based TextWidth is unchanged.
End Rem
Function TextBounds(text:String,x:Float Var,y:Float Var,width:Float Var,height:Float Var)
	Local layout:TTextLayout=CreateTextLayout(text)
	x=layout.boundsX; y=layout.boundsY; width=layout.boundsWidth; height=layout.boundsHeight
End Function
Rem
bbdoc: Draws an existing layout using the current drawing state.
End Rem
Function DrawTextLayout(layout:TTextLayout,x:Float,y:Float)
	If Not layout Then Throw "Max2D: text layout is null"
	layout.Draw(TMax2DGraphics.Current(),x,y)
End Function

Function GetColor(color:SColor8 Var,alpha:Float Var)
 GetColor(color); alpha=GetAlpha()
End Function
Function GetClsColor(color:SColor8 Var)
 Local r:Int,g:Int,b:Int
 GetClsColor(r,g,b); color=New SColor8(r,g,b,TMax2DGraphics.Current().state.clsByteAlpha)
End Function
Function GetClsColor(color:SColor8 Var,alpha:Float Var)
 GetClsColor(color); alpha=TMax2DGraphics.Current().state.clsAlpha
End Function
Function ClearImage(image:TImage,color:SColor8,frameIndex:Int=-1)
 ClearImage(image,UInt(color.r),UInt(color.g),UInt(color.b),color.a/255.0,frameIndex)
End Function

Rem
bbdoc: Draws span backgrounds separately, allowing selection highlights between backgrounds and glyphs.
about: Follow with DrawTextLayoutVisible(..., False) to avoid drawing backgrounds twice.
End Rem
Function DrawTextBackgroundsVisible(layout:TParagraphLayout,x:Float,y:Float,top:Float,bottom:Float)
	If Not layout Then Throw "Max2D: text layout is null"
	layout.DrawBackgroundsVisible(TMax2DGraphics.Current(),x,y,top,bottom)
End Function
