' A frame belongs to exactly one live rendering context. Its native release is
' performed by that context, never by a GC finalizer.

Rem
bbdoc: A backend texture or render target owned by one graphics context.
End Rem
Type TImageFrame

	Rem
	bbdoc: Rendering context responsible for releasing this frame.
	End Rem
	Field owner:TMax2DContext

	Rem
	bbdoc: Width of native texture storage in pixels.
	End Rem
	Field width:Int

	Rem
	bbdoc: Height of native texture storage in pixels.
	End Rem
	Field height:Int

	Rem
	bbdoc: Image creation and sampling flags.
	End Rem
	Field flags:Int

	Rem
	bbdoc: Whether this native frame can be used as a render target.
	End Rem
	Field target:Int

	Rem
	bbdoc: Pixel storage format from BRL.PixelFormat.
	End Rem
	Field pixelFormat:Int = PF_RGBA8888

	Rem
	bbdoc: Revision used to track cached or uploaded source data.
	End Rem
	Field version:Long

	Rem
	bbdoc: Left edge of the pending pixel upload rectangle.
	End Rem
	Field dirtyX:Int

	Rem
	bbdoc: Top edge of the pending pixel upload rectangle.
	End Rem
	Field dirtyY:Int

	Rem
	bbdoc: Width of the pending pixel upload rectangle; zero means no pending region.
	End Rem
	Field dirtyW:Int

	Rem
	bbdoc: Height of the pending pixel upload rectangle; zero means no pending region.
	End Rem
	Field dirtyH:Int

	Rem
	bbdoc: Whether this native resource or rendering context has been closed.
	End Rem
	Field closed:Int

	Rem
	bbdoc: Whether the owning context should release this frame when safe.
	End Rem
	Field releasePending:Int

	Rem
	bbdoc: Virtual presentation and viewport settings for this drawing destination.
	End Rem
	Field view:TMax2DView

	Rem
	bbdoc: Releases this frame's native graphics resources on the rendering thread.
	End Rem
	Method NativeDestroy() Abstract

	Rem
	bbdoc: Releases the frame's native resources and marks it closed.
	End Rem
	Method Dispose()
		If closed Then Return
		NativeDestroy()
		closed = True
		owner = Null
	End Method

End Type

Rem
bbdoc: Virtual dimensions, presentation mode and clipping for a drawing destination.
End Rem
Type TMax2DView

	Rem
	bbdoc: Virtual presentation mode controlling stretch, aspect fit or native pixels.
	End Rem
	Field presentation:Int = VIRTUAL_STRETCH

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
	bbdoc: Width of the virtual drawing surface.
	End Rem
	Field width:Float

	Rem
	bbdoc: Height of the virtual drawing surface.
	End Rem
	Field height:Float

	Rem
	bbdoc: Left edge of the clipping viewport in virtual screen coordinates.
	End Rem
	Field x:Int

	Rem
	bbdoc: Top edge of the clipping viewport in virtual screen coordinates.
	End Rem
	Field y:Int

	Rem
	bbdoc: Clipping viewport width in virtual screen units.
	End Rem
	Field w:Int

	Rem
	bbdoc: Clipping viewport height in virtual screen units.
	End Rem
	Field h:Int

	Rem
	bbdoc: Whether window-size changes update the virtual dimensions automatically.
	End Rem
	Field automatic:Int = True

	Rem
	bbdoc: Whether the viewport tracks the full drawing surface.
	End Rem
	Field fullClip:Int = True

	Rem
	bbdoc: Sets the virtual dimensions and restores a full-size viewport.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	End Rem
	Method Reset(width:Float, height:Float)
		Self.width = width; Self.height = height
		x = 0; y = 0; w = Ceil(width); h = Ceil(height)
	End Method

	Rem
	bbdoc: Calculates presentation scale, offsets and pixel dimensions for a destination.
	param: Width of the drawable surface in native pixels.
	param: Height of the drawable surface in native pixels.
	param: Receives native pixels per horizontal virtual unit.
	param: Receives native pixels per vertical virtual unit.
	param: Receives horizontal offset.
	param: Receives vertical offset.
	param: Receives width of the displayed scene in native pixels.
	param: Receives height of the displayed scene in native pixels.
	End Rem
	Method MapOutput(pixelWidth:Int,pixelHeight:Int,sx:Float Var,sy:Float Var,ox:Int Var,oy:Int Var,vw:Int Var,vh:Int Var)
		If presentation=VIRTUAL_NATIVE Then
			sx=1; sy=1; ox=0; oy=0; vw=pixelWidth; vh=pixelHeight
			Return
		End If
		sx=pixelWidth/width; sy=pixelHeight/height
		If presentation=VIRTUAL_LETTERBOX Or presentation=VIRTUAL_INTEGER Then
			sx=Min(sx,sy)
			' Below 1x, fit fractionally so the entire scene remains visible.
			If presentation=VIRTUAL_INTEGER And sx>=1 Then sx=Floor(sx)
			sy=sx
		End If
		vw=Floor(width*sx+0.001); vh=Floor(height*sy+0.001)
		ox=(pixelWidth-vw)/2; oy=(pixelHeight-vh)/2
	End Method

End Type

Rem
bbdoc: Cumulative rendering counters for a graphics context.
End Rem
Type TMax2DStats

	Rem
	bbdoc: Cumulative count of native texture allocations.
	End Rem
	Field textureCreations:Long

	Rem
	bbdoc: Cumulative count of texture upload operations.
	End Rem
	Field textureUpdates:Long

	Rem
	bbdoc: Cumulative number of pixel positions uploaded, including mip levels.
	End Rem
	Field uploadedPixels:Long

	Rem
	bbdoc: Cumulative number of submitted geometry batches.
	End Rem
	Field submissions:Long

	Rem
	bbdoc: Cumulative number of submitted vertices.
	End Rem
	Field vertices:Long

	Rem
	bbdoc: Cumulative number of GPU-to-CPU readback operations.
	End Rem
	Field readbacks:Long

	Rem
	bbdoc: Cumulative number of native mipmap-generation operations reported by the backend.
	End Rem
	Field mipmapGenerations:Long

	Rem
	bbdoc: Returns a copy that can be modified independently of this object's scalar settings.
	End Rem
	Method Copy:TMax2DStats()
		Local result:TMax2DStats=New TMax2DStats
		result.textureCreations=textureCreations
		result.textureUpdates=textureUpdates
		result.uploadedPixels=uploadedPixels
		result.submissions=submissions
		result.vertices=vertices
		result.readbacks=readbacks
		result.mipmapGenerations=mipmapGenerations
		Return result
	End Method

	Rem
	bbdoc: Resets all rendering counters to zero.
	End Rem
	Method Reset()
		textureCreations=0
		textureUpdates=0
		uploadedPixels=0
		submissions=0
		vertices=0
		readbacks=0
		mipmapGenerations=0
	End Method

End Type

Rem
bbdoc: Backend contract for texture storage, batched drawing and window presentation.
End Rem
Type TMax2DContext

	Rem
	bbdoc: Underlying native graphics window.
	End Rem
	Field graphics:TGraphics

	Rem
	bbdoc: Native frames associated with this owner.
	End Rem
	Field frames:TList = New TList

	Rem
	bbdoc: Whether this native resource or rendering context has been closed.
	End Rem
	Field closed:Int

	Rem
	bbdoc: Live cumulative rendering counters; use CaptureMax2DStats for a detached copy.
	End Rem
	Field stats:TMax2DStats = New TMax2DStats

	Rem
	bbdoc: Current or saved drawing destination; a Null frame or image denotes the window.
	End Rem
	Field target:TImageFrame

	Rem
	bbdoc: Presentation and viewport settings retained for the window backbuffer.
	End Rem
	Field windowView:TMax2DView = New TMax2DView

	Rem
	bbdoc: Virtual presentation and viewport settings for this drawing destination.
	End Rem
	Field view:TMax2DView

	Rem
	bbdoc: Interleaved vertex buffer: x, y, r, g, b, a, u, v for each vertex.
	End Rem
	Field batch:Float[8192 * 8]

	Rem
	bbdoc: Number of vertices currently buffered for submission.
	End Rem
	Field batchCount:Int

	Rem
	bbdoc: Enables compact rectangle submission on backends that implement NativeSubmitQuads; defaults to False.
	End Rem
	Field compactQuads:Int

	Rem
	bbdoc: Whether the pending batch contains 16-float rectangles instead of 8-float vertices.
	End Rem
	Field batchQuads:Int

	Rem
	bbdoc: Texture used by the current buffered batch, or Null for solid geometry.
	End Rem
	Field batchFrame:TImageFrame

	Rem
	bbdoc: Blend mode used by the current buffered batch.
	End Rem
	Field batchBlend:Int

	Rem
	bbdoc: Temporary image used for pixmap drawing uploads.
	End Rem
	Field uploadImage:TImage

	Rem
	bbdoc: Destination width in native pixels.
	End Rem
	Field pixelWidth:Int

	Rem
	bbdoc: Destination height in native pixels.
	End Rem
	Field pixelHeight:Int

	Rem
	bbdoc: Native pixels per horizontal virtual unit.
	End Rem
	Field pixelScaleX:Float = 1

	Rem
	bbdoc: Native pixels per vertical virtual unit.
	End Rem
	Field pixelScaleY:Float = 1

	Rem
	bbdoc: Horizontal native-pixel offset of the virtual scene.
	End Rem
	Field pixelOffsetX:Int

	Rem
	bbdoc: Vertical native-pixel offset of the virtual scene.
	End Rem
	Field pixelOffsetY:Int

	Rem
	bbdoc: Displayed scene width in native pixels.
	End Rem
	Field pixelViewportWidth:Int

	Rem
	bbdoc: Displayed scene height in native pixels.
	End Rem
	Field pixelViewportHeight:Int

	Rem
	bbdoc: Reports whether runtime exclusive fullscreen switching is implemented.
	End Rem
	Method SupportsFullscreen:Int()
		Return False
	End Method

	Rem
	bbdoc: Reports whether runtime borderless fullscreen switching is implemented.
	End Rem
	Method SupportsBorderlessFullscreen:Int()
		Return False
	End Method

	Rem
	bbdoc: Returns the established windowed, exclusive or borderless fullscreen mode.
	End Rem
	Method WindowMode:Int()
		Local width:Int,height:Int,depth:Int,hertz:Int,flags:Long,x:Int,y:Int
		graphics.GetSettings(width,height,depth,hertz,flags,x,y)
		If Not depth Then Return MAX2D_WINDOWED
		If flags & GRAPHICS_FULLSCREEN_DESKTOP Then Return MAX2D_BORDERLESS_FULLSCREEN
		Return MAX2D_FULLSCREEN
	End Method

	Rem
	bbdoc: Changes the window's presentation mode and refreshes its native resources.
	param: MAX2D_WINDOWED, MAX2D_FULLSCREEN or MAX2D_BORDERLESS_FULLSCREEN.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	param: Refresh rate in hertz; zero selects the backend default.
	End Rem
	Method SetWindowMode(mode:Int,width:Int,height:Int,hertz:Int)
		Throw "Max2D: runtime fullscreen switching is unsupported by this backend"
	End Method

	Rem
	bbdoc: Requests a new window size.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	End Rem
	Method Resize(width:Int,height:Int)
		graphics.Resize(width,height)
	End Method

	Rem
	bbdoc: Requests a new window position.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	End Rem
	Method Position(x:Int,y:Int)
		graphics.Position(x,y)
	End Method

	Rem
	bbdoc: Makes this graphics context current for native rendering operations.
	End Rem
	Method Activate() Abstract

	Rem
	bbdoc: Presents the window backbuffer with the requested synchronization setting.
	param: Presentation synchronization setting; negative uses the backend default.
	End Rem
	Method Present:Int(sync:Int) Abstract

	Rem
	bbdoc: Allocates a native image frame or render target.
	param: Positive image width in pixels.
	param: Positive image height in pixels.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	param: Whether to allocate render-target storage.
	End Rem
	Method NativeCreate:TImageFrame(width:Int, height:Int, flags:Int, target:Int) Abstract
	' The default keeps existing backend implementations compatible.

	Rem
	bbdoc: Allocates a native image frame with the requested storage format.
	param: Positive image width in pixels.
	param: Positive image height in pixels.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	param: Whether to allocate render-target storage.
	param: Pixel storage format from BRL.PixelFormat.
	End Rem
	Method NativeCreateFormat:TImageFrame(width:Int,height:Int,flags:Int,target:Int,pixelFormat:Int)
		Return NativeCreate(width,height,flags,target)
	End Method

	Rem
	bbdoc: Allocates native storage for supplied texture data and mip levels.
	param: Texture storage and mip levels to use.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	End Rem
	Method NativeCreateTexture:TImageFrame(data:TTextureData,flags:Int)
		Return NativeCreateFormat(data.Width(),data.Height(),flags,False,data.Format())
	End Method

	' Native upload helpers receive pixels starting at this region, with x/y used only as destination coordinates.

	Rem
	bbdoc: Returns a pixmap view or converted copy of an upload rectangle.
	param: Source pixel data.
	param: Left edge of the pixel rectangle.
	param: Top edge of the pixel rectangle.
	param: Width of the pixel rectangle.
	param: Height of the pixel rectangle.
	param: Pixel storage format from BRL.PixelFormat.
	End Rem
	Method UploadRegion:TPixmap(pixmap:TPixmap,x:Int,y:Int,w:Int,h:Int,pixelFormat:Int=PF_RGBA8888)
		Local region:TPixmap=pixmap.Window(x,y,w,h)
		If region.format<>pixelFormat Then region=region.Convert(pixelFormat)
		Return region
	End Method

	Rem
	bbdoc: Uploads pixels into a rectangle of a native image frame.
	param: Native image frame owned by this context.
	param: Source pixel data.
	param: Left edge of the pixel rectangle.
	param: Top edge of the pixel rectangle.
	param: Width of the pixel rectangle.
	param: Height of the pixel rectangle.
	End Rem
	Method NativeUpdate(frame:TImageFrame, pixmap:TPixmap, x:Int, y:Int, w:Int, h:Int) Abstract
	' Legacy/custom drivers receive their original full RGBA source contract.

	Rem
	bbdoc: Uploads a rectangle from a full source pixmap into a native frame.
	param: Native image frame owned by this context.
	param: Source pixel data.
	param: Left edge of the pixel rectangle.
	param: Top edge of the pixel rectangle.
	param: Width of the pixel rectangle.
	param: Height of the pixel rectangle.
	End Rem
	Method NativeUpdateSource(frame:TImageFrame,pixmap:TPixmap,x:Int,y:Int,w:Int,h:Int)
		If pixmap.format<>PF_RGBA8888 Then pixmap=pixmap.Convert(PF_RGBA8888)
		NativeUpdate(frame,pixmap,x,y,w,h)
	End Method

	Rem
	bbdoc: Submits an interleaved triangle batch to the native renderer.
	param: Texture frame to sample, or Null for untextured geometry.
	param: Blend mode, such as ALPHABLEND or SOLIDBLEND.
	param: Interleaved vertices, with eight floats per vertex: x, y, r, g, b, a, u, v.
	param: Number of items to process.
	End Rem
	Method NativeSubmit(frame:TImageFrame, blend:Int, vertices:Float Ptr, count:Int) Abstract

	Rem
	bbdoc: Applies the render target, presentation transform and clipping rectangle.
	param: Render-target frame, or Null for the window backbuffer.
	param: Virtual dimensions, presentation and clipping settings.
	End Rem
	Method NativeView(frame:TImageFrame, view:TMax2DView) Abstract
	' Coordinate extent used by window mouse events; may differ from drawable pixels.

	Rem
	bbdoc: Gets the window coordinate extent used by mouse input.
	param: Receives width of the rectangle or drawing surface.
	param: Receives height of the rectangle or drawing surface.
	End Rem
	Method NativeInputSize(width:Int Var,height:Int Var)
		Local depth:Int,hertz:Int,flags:Long,x:Int,y:Int
		graphics.GetSettings(width,height,depth,hertz,flags,x,y)
	End Method

	Rem
	bbdoc: Gets the drawable window dimensions in native pixels.
	param: Receives width of the rectangle or drawing surface.
	param: Receives height of the rectangle or drawing surface.
	End Rem
	Method NativeOutputSize(width:Int Var, height:Int Var) Abstract

	Rem
	bbdoc: Clears the active native target with the supplied colour.
	param: Red component, from 0 to 255.
	param: Green component, from 0 to 255.
	param: Blue component, from 0 to 255.
	param: Opacity multiplier, from 0.0 to 1.0.
	End Rem
	Method NativeClear(red:Int, green:Int, blue:Int, alpha:Float) Abstract

	Rem
	bbdoc: Reads native target pixels into a pixmap.
	param: Render-target frame, or Null for the window backbuffer.
	param: Left edge of the pixel rectangle.
	param: Top edge of the pixel rectangle.
	param: Width of the pixel rectangle.
	param: Height of the pixel rectangle.
	End Rem
	Method NativeRead:TPixmap(frame:TImageFrame, x:Int, y:Int, w:Int, h:Int) Abstract

	Rem
	bbdoc: Reports whether a blend mode is supported by this context.
	param: Blend mode, such as ALPHABLEND or SOLIDBLEND.
	End Rem
	Method SupportsBlend:Int(blend:Int) Abstract

	Rem
	bbdoc: Reports whether an image flag combination is supported by this context.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	End Rem
	Method SupportsImageFlags:Int(flags:Int) Abstract

	Rem
	bbdoc: Reports native, converted or unsupported storage for a texture format.
	param: Pixel storage format from BRL.PixelFormat.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	End Rem
	Method TextureFormatSupport:ETextureFormatSupport(pixelFormat:Int,flags:Int)
		If Not SupportsImageFlags(flags) Then Return ETextureFormatSupport.Unsupported
		Select pixelFormat
			Case PF_RGBA8888
				Return ETextureFormatSupport.Native
			Case PF_A8
				Return ETextureFormatSupport.Converted
		End Select
		Return ETextureFormatSupport.Unsupported
	End Method

	Rem
	bbdoc: Checks whether supplied texture data can be uploaded by this context.
	param: Texture storage and mip levels to use.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	End Rem
	Method TextureDataSupport:ETextureFormatSupport(data:TTextureData,flags:Int)
		If Not data Or (flags & DYNAMICIMAGE) Then Return ETextureFormatSupport.Unsupported
		If Not ValidTextureSize(data.Width(),data.Height()) Then Return ETextureFormatSupport.Unsupported
		If data.LevelCount()>1 Then Return ETextureFormatSupport.Unsupported
		Return TextureFormatSupport(data.Format(),flags)
	End Method

	' Zero means the backend has not reported a limit.

	Rem
	bbdoc: Gets maximum supported texture dimensions, with zero for an unreported limit.
	param: Receives width of the rectangle or drawing surface.
	param: Receives height of the rectangle or drawing surface.
	End Rem
	Method TextureSize(width:Int Var,height:Int Var)
		width=0; height=0
	End Method

	Rem
	bbdoc: Checks render-target support for dimensions, image flags and storage format.
	param: Positive image width in pixels.
	param: Positive image height in pixels.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	param: Pixel storage format from BRL.PixelFormat.
	End Rem
	Method SupportsRenderImageFormat:Int(width:Int,height:Int,flags:Int,pixelFormat:Int)
		If pixelFormat<>PF_RGBA8888 Then Return False
		Return SupportsRenderImage(width,height,flags)
	End Method

	Rem
	bbdoc: Checks render-target support for dimensions and image flags.
	param: Positive image width in pixels.
	param: Positive image height in pixels.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	End Rem
	Method SupportsRenderImage:Int(width:Int,height:Int,flags:Int)
		Return False
	End Method

	Rem
	bbdoc: Checks positive dimensions against the backend's reported texture limits.
	param: Positive image width in pixels.
	param: Positive image height in pixels.
	End Rem
	Method ValidTextureSize:Int(width:Int,height:Int)
		If width<=0 Or height<=0 Then Return False
		Local maximumWidth:Int,maximumHeight:Int
		TextureSize(maximumWidth,maximumHeight)
		Return (maximumWidth=0 Or width<=maximumWidth) And (maximumHeight=0 Or height<=maximumHeight)
	End Method

	Rem
	bbdoc: Throws if the rendering context has been closed.
	End Rem
	Method CheckOpen()
		If closed Then Throw "Max2D: rendering context is closed"
	End Method

	Rem
	bbdoc: Creates and registers an image frame owned by this context.
	param: Positive image width in pixels.
	param: Positive image height in pixels.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	param: Whether the new frame can be used as a drawing destination.
	param: Pixel storage format from BRL.PixelFormat.
	param: Texture storage and mip levels to use.
	End Rem
	Method CreateFrame:TImageFrame(width:Int, height:Int, flags:Int, renderTarget:Int, pixelFormat:Int=PF_RGBA8888,data:TTextureData=Null)
		CheckOpen()
		If renderTarget And pixelFormat<>PF_RGBA8888 And Not SupportsRenderImageFormat(width,height,flags,pixelFormat) Then Throw "Max2D: render-image format unsupported by this backend"
		Local frame:TImageFrame
		If data Then
			If TextureDataSupport(data,flags)=ETextureFormatSupport.Unsupported Then Throw "Max2D: texture data unsupported by this backend"
			frame=NativeCreateTexture(data,flags)
		Else
			If Not SupportsImageFlags(flags) Then Throw "Max2D: image flags unsupported by this backend"
			If TextureFormatSupport(pixelFormat,flags)=ETextureFormatSupport.Unsupported Then Throw "Max2D: texture storage unsupported by this backend"
			frame=NativeCreateFormat(width,height,flags,renderTarget,pixelFormat)
		End If
		If Not frame Then Throw "Max2D: texture creation failed"
		frame.owner = Self; frame.width = width; frame.height = height
		frame.flags = flags; frame.target = renderTarget
		If renderTarget Then
			frame.view = New TMax2DView
			frame.view.Reset(width, height)
		End If
		frames.AddLast(frame)
		stats.textureCreations :+ 1
		Return frame
	End Method

	Rem
	bbdoc: Flushes pending drawing and uploads a changed rectangle of source pixels.
	param: Native image frame owned by this context.
	param: Source pixel data.
	param: Left edge of the pixel rectangle.
	param: Top edge of the pixel rectangle.
	param: Width of the pixel rectangle.
	param: Height of the pixel rectangle.
	End Rem
	Method UpdateFrame(frame:TImageFrame, pixmap:TPixmap, x:Int, y:Int, w:Int, h:Int)
		CheckOpen()
		Flush()
		NativeUpdateSource(frame, pixmap, x, y, w, h)
		stats.textureUpdates :+ 1
		stats.uploadedPixels :+ Long(w) * h
	End Method

	' Compatibility adapter for existing backends. Storage remains owned by TTextureData.
	' Future non-pixmap formats can override this entry point without changing TPixmap.

	Rem
	bbdoc: Uploads the supplied texture levels into an existing native frame.
	param: Native image frame owned by this context.
	param: Texture storage and mip levels to use.
	End Rem
	Method NativeUpdateTexture(frame:TImageFrame,data:TTextureData)
		If data.LevelCount()<>1 Or (data.Format()<>PF_RGBA8888 And data.Format()<>PF_A8) Then Throw "Max2D: backend does not implement this texture upload"
		Local level:TTextureLevel=data.Level()
		Local pixels:TPixmap=CreateStaticPixmap(level.Data(),level.Width(),level.Height(),level.Pitch(),level.Format())
		pixels._source=data
		If level.Pitch() Mod BytesPerPixel[level.Format()] Then pixels=pixels.Copy()
		NativeUpdateSource(frame,pixels,0,0,level.Width(),level.Height())
	End Method

	Rem
	bbdoc: Flushes pending drawing and uploads texture data while updating counters.
	param: Native image frame owned by this context.
	param: Texture storage and mip levels to use.
	End Rem
	Method UpdateTextureFrame(frame:TImageFrame,data:TTextureData)
		CheckOpen()
		Flush()
		NativeUpdateTexture(frame,data)
		stats.textureUpdates:+1
		For Local index:Int=0 Until data.LevelCount()
			Local level:TTextureLevel=data.Level(index)
			stats.uploadedPixels:+Long(level.Width())*level.Height()
		Next
	End Method

	Rem
	bbdoc: Prepares a compatible batch with space for the supplied number of vertices.
	param: Texture frame to sample, or Null for untextured geometry.
	param: Blend mode, such as ALPHABLEND or SOLIDBLEND.
	param: Number of items to process.
	End Rem
	Method BeginTriangles(frame:TImageFrame, blend:Int, count:Int)
		If batchQuads Then Flush()
		batchQuads=False
		CheckOpen()
		If Not SupportsBlend(blend) Then Throw "Max2D: blend mode unsupported by this backend"
		If frame Then
			If frame.closed Or frame.owner <> Self Then Throw "Max2D: texture belongs to another or closed context"
			If frame = target Then Throw "Max2D: cannot sample the current render target"
		End If
		If count > batch.Length / 8 Then Throw "Max2D: geometry chunk exceeds buffer capacity"
		If frame <> batchFrame Or blend <> batchBlend Or batchCount + count > batch.Length / 8 Then Flush()
		batchFrame = frame; batchBlend = blend
	End Method

	Rem
	bbdoc: Prepares one compact rectangle, flushing incompatible triangles and state first.
	param: Texture to sample, or Null for solid geometry.
	param: Blend mode.
	End Rem
	Method BeginQuads(frame:TImageFrame,blend:Int)
		If Not batchQuads Then Flush()
		' Reuse frame validation without discarding a compatible compact batch.
		CheckOpen()
		If Not SupportsBlend(blend) Then Throw "Max2D: blend mode unsupported by this backend"
		If frame Then
			If frame.closed Or frame.owner<>Self Then Throw "Max2D: texture belongs to another or closed context"
			If frame=target Then Throw "Max2D: cannot sample the current render target"
		End If
		If frame<>batchFrame Or blend<>batchBlend Or (batchCount+1)*16>batch.Length Then Flush()
		batchQuads=True
		batchFrame=frame
		batchBlend=blend
	End Method

	Rem
	bbdoc: Submits compact affine rectangles; backends opt in by implementing this method.
	param: Texture to sample, or Null for solid geometry.
	param: Blend mode.
	param: Records of 16 floats: origin.xy, horizontal edge.xy, vertical edge.xy, uv0.xy, uv1.xy, two padding floats, colour.rgba.
	param: Number of rectangle records.
	End Rem
	Method NativeSubmitQuads(frame:TImageFrame,blend:Int,records:Float Ptr,count:Int)
		Throw "Max2D: backend does not support compact rectangles"
	End Method

	Rem
	bbdoc: Appends one position, colour and texture coordinate to the current batch.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	param: Red vertex colour component from 0.0 to 1.0.
	param: Green vertex colour component from 0.0 to 1.0.
	param: Blue vertex colour component from 0.0 to 1.0.
	param: Vertex opacity from 0.0 to 1.0.
	param: Horizontal normalized texture coordinate.
	param: Vertical normalized texture coordinate.
	End Rem
	Method Vertex(x:Float, y:Float, r:Float, g:Float, b:Float, a:Float, u:Float = 0, v:Float = 0)
		Local offset:Int = batchCount * 8
		batch[offset] = x; batch[offset+1] = y
		batch[offset+2] = r; batch[offset+3] = g; batch[offset+4] = b; batch[offset+5] = a
		batch[offset+6] = u; batch[offset+7] = v
		batchCount :+ 1
	End Method

	Rem
	bbdoc: Submits buffered geometry and releases any deferred native resources.
	End Rem
	Method Flush()
		If batchCount Then
			If batchQuads Then
				NativeSubmitQuads(batchFrame,batchBlend,batch,batchCount)
				stats.vertices:+batchCount*6
			Else
				NativeSubmit(batchFrame,batchBlend,batch,batchCount)
				stats.vertices:+batchCount
			End If
			stats.submissions :+ 1
			batchCount = 0
		End If
		batchFrame = Null
		DrainReleases()
	End Method

	Rem
	bbdoc: Releases queued image frames once they are no longer the active target.
	End Rem
	Method DrainReleases()
		Local link:TLink = frames.FirstLink()
		While link
			Local following:TLink = link.NextLink()
			Local frame:TImageFrame = TImageFrame(link.Value())
			If frame.releasePending And frame <> target Then
				frame.Dispose()
				link.Remove()
			End If
			link = following
		Wend
	End Method

	Rem
	bbdoc: Selects an image frame as the target, or Null for the window backbuffer.
	param: Render-target frame, or Null for the window backbuffer.
	End Rem
	Method SetTarget(frame:TImageFrame)
		CheckOpen()
		If frame And (frame.closed Or frame.owner <> Self Or Not frame.target) Then Throw "Max2D: invalid render target"
		Flush()
		target = frame
		If target Then view = target.view Else view = windowView
		ApplyView()
	End Method

	Rem
	bbdoc: Recalculates presentation and applies the current target's viewport.
	End Rem
	Method ApplyView()
		CheckOpen()
		Flush()
		If target Then
			pixelWidth = target.width; pixelHeight = target.height
		Else
			NativeOutputSize(pixelWidth,pixelHeight)
		End If
		If view.presentation = VIRTUAL_NATIVE Then
			view.width = pixelWidth; view.height = pixelHeight
			If view.fullClip Then view.Reset(pixelWidth,pixelHeight)
		End If
		view.MapOutput(pixelWidth,pixelHeight,pixelScaleX,pixelScaleY,pixelOffsetX,pixelOffsetY,pixelViewportWidth,pixelViewportHeight)
		NativeView(target, view)
	End Method

	Rem
	bbdoc: Flushes drawing and reads a native pixel rectangle into a pixmap.
	param: Render-target frame, or Null for the window backbuffer.
	param: Left edge of the pixel rectangle.
	param: Top edge of the pixel rectangle.
	param: Width of the pixel rectangle.
	param: Height of the pixel rectangle.
	End Rem
	Method Read:TPixmap(frame:TImageFrame, x:Int, y:Int, w:Int, h:Int)
		CheckOpen()
		If frame And (frame.pixelFormat=PF_RGBA16F Or frame.pixelFormat=PF_RGBA32F) Then Throw "Max2D: floating-point targets require ReadRenderTextureData"
		If w <= 0 Or h <= 0 Then Throw "Max2D: invalid readback dimensions"
		If frame And (frame.owner <> Self Or frame.closed) Then Throw "Max2D: invalid readback target"
		Flush()
		Local pixmap:TPixmap = NativeRead(frame, x, y, w, h)
		stats.readbacks :+ 1
		Return pixmap
	End Method

	Rem
	bbdoc: Reads native render-target storage without reducing floating-point range.
	param: Native image frame owned by this context.
	End Rem
	Method NativeReadTexture:TTextureData(frame:TImageFrame)
		Return TTextureData.FromPixmap(NativeRead(frame,0,0,frame.width,frame.height))
	End Method

	Rem
	bbdoc: Flushes drawing and reads a render target into owned texture data.
	param: Native image frame owned by this context.
	End Rem
	Method ReadTexture:TTextureData(frame:TImageFrame)
		CheckOpen()
		If Not frame Then Throw "Max2D: readback requires a render image"
		If frame.owner<>Self Or frame.closed Or Not frame.target Then Throw "Max2D: invalid readback target"
		Flush()
		Local data:TTextureData=NativeReadTexture(frame)
		stats.readbacks:+1
		Return data
	End Method

	Rem
	bbdoc: Flushes drawing and releases every frame and the underlying graphics window.
	End Rem
	Method Close()
		If closed Then Return
		Flush()
		target = Null
		While Not frames.IsEmpty()
			TImageFrame(frames.RemoveFirst()).Dispose()
		Wend
		uploadImage = Null
		If graphics Then graphics.Close()
		graphics = Null
		closed = True
	End Method

End Type

Rem
bbdoc: Base graphics driver that connects BRL.Graphics to a Max2D rendering context.
End Rem
Type TMax2DDriver Extends TGraphicsDriver

	Rem
	bbdoc: Canvas currently selected by this graphics driver.
	End Rem
	Field current:TMax2DGraphics

	Rem
	bbdoc: Creates the backend context for a graphics window.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	param: Fullscreen colour depth; zero requests a window.
	param: Refresh rate in hertz; zero selects the backend default.
	param: BRL.Graphics window-creation flags.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	End Rem
	Method CreateContext:TMax2DContext(width:Int, height:Int, depth:Int, hertz:Int, flags:Long, x:Int, y:Int) Abstract

	Rem
	bbdoc: Creates a Max2D canvas backed by a native graphics context.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	param: Fullscreen colour depth; zero requests a window.
	param: Refresh rate in hertz; zero selects the backend default.
	param: BRL.Graphics window-creation flags.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	End Rem
	Method CreateGraphics:TGraphics(width:Int, height:Int, depth:Int, hertz:Int, flags:Long, x:Int, y:Int) Override
		Local context:TMax2DContext = CreateContext(width, height, depth, hertz, flags, x, y)
		If Not context Then Return Null
		context.windowView.Reset(width, height)
		context.view = context.windowView
		Local canvas:TMax2DGraphics = New TMax2DGraphics
		canvas.context = context; canvas.driver = Self
		canvas.imageFont = TImageFont.DefaultFont()
		Return canvas
	End Method

	Rem
	bbdoc: Attaches graphics to a native widget when the backend supports it.
	param: Native widget handle to attach to.
	param: BRL.Graphics flags for the attached graphics surface.
	End Rem
	Method AttachGraphics:TGraphics(widget:Byte Ptr, flags:Long) Override
		Throw "Max2D: native widget attachment is not supported by this backend"
	End Method

	Rem
	bbdoc: Selects the active Max2D canvas and applies its current view.
	param: Graphics canvas or native graphics object to select.
	End Rem
	Method SetGraphics(graphics:TGraphics) Override
		If current And Not current.context.closed Then current.context.Flush()
		current = TMax2DGraphics(graphics)
		TMax2DGraphics.selected = current
		If current Then
			current.context.CheckOpen()
			current.context.Activate()
			current.ValidateSize()
			current.context.ApplyView()
		End If
	End Method

	Rem
	bbdoc: Flushes drawing and presents the current window backbuffer.
	param: Presentation synchronization setting; negative uses the backend default.
	End Rem
	Method Flip:Int(sync:Int) Override
		If Not current Then Return 0
		current.context.CheckOpen()
		If current.context.target Then Throw "Max2D: return to the backbuffer before Flip"
		current.context.Flush()
		Return current.context.Present(sync)
	End Method

	Rem
	bbdoc: Reports whether the driver supports resizing its graphics windows.
	End Rem
	Method CanResize:Int() Override
		Return True
	End Method

End Type
