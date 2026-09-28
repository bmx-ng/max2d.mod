' A frame belongs to exactly one live rendering context. Its native release is
' performed by that context, never by a GC finalizer.
Type TImageFrame
	Field owner:TMax2DContext
	Field width:Int, height:Int, flags:Int
	Field target:Int
	Field pixelFormat:Int = PF_RGBA8888
	Field version:Long
	Field dirtyX:Int, dirtyY:Int, dirtyW:Int, dirtyH:Int
	Field closed:Int
	Field releasePending:Int
	Field view:TMax2DView
	Method NativeDestroy() Abstract
	Method Dispose()
		If closed Then Return
		NativeDestroy()
		closed = True
		owner = Null
	End Method
End Type

Type TMax2DView
	Field presentation:Int = VIRTUAL_STRETCH
	Field barRed:Int, barGreen:Int, barBlue:Int
	Field width:Float, height:Float
	Field x:Int, y:Int, w:Int, h:Int
	Field automatic:Int = True
	Field fullClip:Int = True
	Method Reset(width:Float, height:Float)
		Self.width = width; Self.height = height
		x = 0; y = 0; w = Ceil(width); h = Ceil(height)
	End Method
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

Type TMax2DStats
	Field textureCreations:Long
	Field textureUpdates:Long
	Field uploadedPixels:Long
	Field submissions:Long
	Field vertices:Long
	Field readbacks:Long
	Field mipmapGenerations:Long

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

Type TMax2DContext
	Field graphics:TGraphics
	Field frames:TList = New TList
	Field closed:Int
	Field stats:TMax2DStats = New TMax2DStats
	Field target:TImageFrame
	Field windowView:TMax2DView = New TMax2DView
	Field view:TMax2DView
	Field batch:Float[8192 * 8]
	Field batchCount:Int
	Field batchFrame:TImageFrame
	Field batchBlend:Int
	Field uploadImage:TImage
	Field pixelWidth:Int, pixelHeight:Int
	Field pixelScaleX:Float = 1, pixelScaleY:Float = 1
	Field pixelOffsetX:Int, pixelOffsetY:Int
	Field pixelViewportWidth:Int, pixelViewportHeight:Int

	Method SupportsFullscreen:Int()
		Return False
	End Method
	Method SupportsBorderlessFullscreen:Int()
		Return False
	End Method
	Method WindowMode:Int()
		Local width:Int,height:Int,depth:Int,hertz:Int,flags:Long,x:Int,y:Int
		graphics.GetSettings(width,height,depth,hertz,flags,x,y)
		If Not depth Then Return MAX2D_WINDOWED
		If flags & GRAPHICS_FULLSCREEN_DESKTOP Then Return MAX2D_BORDERLESS_FULLSCREEN
		Return MAX2D_FULLSCREEN
	End Method
	Method SetWindowMode(mode:Int,width:Int,height:Int,hertz:Int)
		Throw "Max2D: runtime fullscreen switching is unsupported by this backend"
	End Method
	Method Resize(width:Int,height:Int)
		graphics.Resize(width,height)
	End Method
	Method Position(x:Int,y:Int)
		graphics.Position(x,y)
	End Method
	Method Activate() Abstract
	Method Present:Int(sync:Int) Abstract
	Method NativeCreate:TImageFrame(width:Int, height:Int, flags:Int, target:Int) Abstract
	' The default keeps existing backend implementations compatible.
	Method NativeCreateFormat:TImageFrame(width:Int,height:Int,flags:Int,target:Int,pixelFormat:Int)
		Return NativeCreate(width,height,flags,target)
	End Method
	Method NativeCreateTexture:TImageFrame(data:TTextureData,flags:Int)
		Return NativeCreateFormat(data.Width(),data.Height(),flags,False,data.Format())
	End Method
	' Native upload helpers receive pixels starting at this region, with x/y used only as destination coordinates.
	Method UploadRegion:TPixmap(pixmap:TPixmap,x:Int,y:Int,w:Int,h:Int,pixelFormat:Int=PF_RGBA8888)
		Local region:TPixmap=pixmap.Window(x,y,w,h)
		If region.format<>pixelFormat Then region=region.Convert(pixelFormat)
		Return region
	End Method
	Method NativeUpdate(frame:TImageFrame, pixmap:TPixmap, x:Int, y:Int, w:Int, h:Int) Abstract
	' Legacy/custom drivers receive their original full RGBA source contract.
	Method NativeUpdateSource(frame:TImageFrame,pixmap:TPixmap,x:Int,y:Int,w:Int,h:Int)
		If pixmap.format<>PF_RGBA8888 Then pixmap=pixmap.Convert(PF_RGBA8888)
		NativeUpdate(frame,pixmap,x,y,w,h)
	End Method
	Method NativeSubmit(frame:TImageFrame, blend:Int, vertices:Float Ptr, count:Int) Abstract
	Method NativeView(frame:TImageFrame, view:TMax2DView) Abstract
	' Coordinate extent used by window mouse events; may differ from drawable pixels.
	Method NativeInputSize(width:Int Var,height:Int Var)
		Local depth:Int,hertz:Int,flags:Long,x:Int,y:Int
		graphics.GetSettings(width,height,depth,hertz,flags,x,y)
	End Method
	Method NativeOutputSize(width:Int Var, height:Int Var) Abstract
	Method NativeClear(red:Int, green:Int, blue:Int, alpha:Float) Abstract
	Method NativeRead:TPixmap(frame:TImageFrame, x:Int, y:Int, w:Int, h:Int) Abstract
	Method SupportsBlend:Int(blend:Int) Abstract
	Method SupportsImageFlags:Int(flags:Int) Abstract

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

	Method TextureDataSupport:ETextureFormatSupport(data:TTextureData,flags:Int)
		If Not data Or (flags & DYNAMICIMAGE) Then Return ETextureFormatSupport.Unsupported
		If Not ValidTextureSize(data.Width(),data.Height()) Then Return ETextureFormatSupport.Unsupported
		If data.LevelCount()>1 Then Return ETextureFormatSupport.Unsupported
		Return TextureFormatSupport(data.Format(),flags)
	End Method

	' Zero means the backend has not reported a limit.
	Method TextureSize(width:Int Var,height:Int Var)
		width=0; height=0
	End Method
	Method SupportsRenderImageFormat:Int(width:Int,height:Int,flags:Int,pixelFormat:Int)
		If pixelFormat<>PF_RGBA8888 Then Return False
		Return SupportsRenderImage(width,height,flags)
	End Method
	Method SupportsRenderImage:Int(width:Int,height:Int,flags:Int)
		Return False
	End Method
	Method ValidTextureSize:Int(width:Int,height:Int)
		If width<=0 Or height<=0 Then Return False
		Local maximumWidth:Int,maximumHeight:Int
		TextureSize(maximumWidth,maximumHeight)
		Return (maximumWidth=0 Or width<=maximumWidth) And (maximumHeight=0 Or height<=maximumHeight)
	End Method

	Method CheckOpen()
		If closed Then Throw "Max2D: rendering context is closed"
	End Method

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

	Method UpdateFrame(frame:TImageFrame, pixmap:TPixmap, x:Int, y:Int, w:Int, h:Int)
		CheckOpen()
		Flush()
		NativeUpdateSource(frame, pixmap, x, y, w, h)
		stats.textureUpdates :+ 1
		stats.uploadedPixels :+ Long(w) * h
	End Method

	' Compatibility adapter for existing backends. Storage remains owned by TTextureData.
	' Future non-pixmap formats can override this entry point without changing TPixmap.
	Method NativeUpdateTexture(frame:TImageFrame,data:TTextureData)
		If data.LevelCount()<>1 Or (data.Format()<>PF_RGBA8888 And data.Format()<>PF_A8) Then Throw "Max2D: backend does not implement this texture upload"
		Local level:TTextureLevel=data.Level()
		Local pixels:TPixmap=CreateStaticPixmap(level.Data(),level.Width(),level.Height(),level.Pitch(),level.Format())
		pixels._source=data
		If level.Pitch() Mod BytesPerPixel[level.Format()] Then pixels=pixels.Copy()
		NativeUpdateSource(frame,pixels,0,0,level.Width(),level.Height())
	End Method
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

	Method BeginTriangles(frame:TImageFrame, blend:Int, count:Int)
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

	Method Vertex(x:Float, y:Float, r:Float, g:Float, b:Float, a:Float, u:Float = 0, v:Float = 0)
		Local offset:Int = batchCount * 8
		batch[offset] = x; batch[offset+1] = y
		batch[offset+2] = r; batch[offset+3] = g; batch[offset+4] = b; batch[offset+5] = a
		batch[offset+6] = u; batch[offset+7] = v
		batchCount :+ 1
	End Method

	Method Flush()
		If batchCount Then
			NativeSubmit(batchFrame, batchBlend, batch, batchCount)
			stats.submissions :+ 1
			stats.vertices :+ batchCount
			batchCount = 0
		End If
		batchFrame = Null
		DrainReleases()
	End Method

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

	Method SetTarget(frame:TImageFrame)
		CheckOpen()
		If frame And (frame.closed Or frame.owner <> Self Or Not frame.target) Then Throw "Max2D: invalid render target"
		Flush()
		target = frame
		If target Then view = target.view Else view = windowView
		ApplyView()
	End Method

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

	Method NativeReadTexture:TTextureData(frame:TImageFrame)
		Return TTextureData.FromPixmap(NativeRead(frame,0,0,frame.width,frame.height))
	End Method
	Method ReadTexture:TTextureData(frame:TImageFrame)
		CheckOpen()
		If Not frame Then Throw "Max2D: readback requires a render image"
		If frame.owner<>Self Or frame.closed Or Not frame.target Then Throw "Max2D: invalid readback target"
		Flush()
		Local data:TTextureData=NativeReadTexture(frame)
		stats.readbacks:+1
		Return data
	End Method

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

Type TMax2DDriver Extends TGraphicsDriver
	Field current:TMax2DGraphics
	Method CreateContext:TMax2DContext(width:Int, height:Int, depth:Int, hertz:Int, flags:Long, x:Int, y:Int) Abstract
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
	Method AttachGraphics:TGraphics(widget:Byte Ptr, flags:Long) Override
		Throw "Max2D: native widget attachment is not supported by this backend"
	End Method
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
	Method Flip:Int(sync:Int) Override
		If Not current Then Return 0
		current.context.CheckOpen()
		If current.context.target Then Throw "Max2D: return to the backbuffer before Flip"
		current.context.Flush()
		Return current.context.Present(sync)
	End Method
	Method CanResize:Int() Override
		Return True
	End Method
End Type
