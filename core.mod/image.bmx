' A padded atlas region belongs to the shared source, so edits through any
' subview (or the page itself) can refresh its border before the next upload.
Type TImageRegion
	Field x:Int,y:Int,width:Int,height:Int,padding:Int
	Method Extrude(pixmap:TPixmap)
		For Local py:Int=y-padding Until y+height+padding
			Local cy:Int=Min(y+height-1,Max(y,py))
			For Local border:Int=1 To padding
				pixmap.WritePixel(x-border,py,pixmap.ReadPixel(x,cy))
				pixmap.WritePixel(x+width-1+border,py,pixmap.ReadPixel(x+width-1,cy))
			Next
		Next
		For Local px:Int=x Until x+width
			For Local border:Int=1 To padding
				pixmap.WritePixel(px,y-border,pixmap.ReadPixel(px,y))
				pixmap.WritePixel(px,y+height-1+border,pixmap.ReadPixel(px,y+height-1))
			Next
		Next
	End Method
End Type

Type TImageTrim
	Field x:Int, y:Int, width:Int, height:Int
End Type

Type TImageSource
	Field pixmap:TPixmap
	Field textureData:TTextureData
	Field width:Int, height:Int, flags:Int
	Field renderTarget:Int
	Field targetFormat:Int=PF_RGBA8888
	Field targetOwner:TMax2DContext
	Field version:Long = 1
	Field dirtyX:Int, dirtyY:Int, dirtyW:Int, dirtyH:Int
	Field lockImage:TImage
	Field lockIndex:Int
	Field lockPixels:TPixmap
	Field locked:Int, writing:Int
	Field frames:TList = New TList
	Field regions:TList = New TList
	Field collisionMask:TCollisionMask

	' Existing CPU algorithms can read byte-addressable texture storage through a borrowed view.
	Method ReadPixels:TPixmap()
		If pixmap Then Return pixmap
		If Not textureData Then Throw "Max2D: image has no CPU pixels"
		If textureData.Format()<>PF_RGBA8888 And textureData.Format()<>PF_A8 Then Throw "Max2D: this texture storage has no pixmap view"
		Local level:TTextureLevel=textureData.Level()
		Local pixels:TPixmap=CreateStaticPixmap(level.Data(),level.Width(),level.Height(),level.Pitch(),level.Format())
		pixels._source=textureData
		Return pixels
	End Method

	Method Changed(x:Int, y:Int, w:Int, h:Int)
		Local left:Int=x,top:Int=y,right:Int=x+w,bottom:Int=y+h
		For Local region:TImageRegion=EachIn regions
			Local rx:Int=region.x-region.padding,ry:Int=region.y-region.padding
			Local rw:Int=region.width+region.padding*2,rh:Int=region.height+region.padding*2
			If x<rx+rw And x+w>rx And y<ry+rh And y+h>ry Then
				region.Extrude(pixmap)
				left=Min(left,rx); top=Min(top,ry); right=Max(right,rx+rw); bottom=Max(bottom,ry+rh)
			End If
		Next
		version :+ 1
		dirtyX=left; dirtyY=top; dirtyW=right-left; dirtyH=bottom-top
		' Each context can lag by a different number of edits. Accumulate its
		' pending bounds until that frame uploads; new frames still upload fully.
		For Local frame:TImageFrame=EachIn frames
			If frame.closed Or frame.releasePending Then Continue
			If frame.dirtyW>0 And frame.dirtyH>0 Then
				Local r:Int=Max(frame.dirtyX+frame.dirtyW,right)
				Local b:Int=Max(frame.dirtyY+frame.dirtyH,bottom)
				frame.dirtyX=Min(frame.dirtyX,left); frame.dirtyY=Min(frame.dirtyY,top)
				frame.dirtyW=r-frame.dirtyX; frame.dirtyH=b-frame.dirtyY
			Else
				frame.dirtyX=left; frame.dirtyY=top; frame.dirtyW=right-left; frame.dirtyH=bottom-top
			End If
		Next
	End Method

	Method Frame:TImageFrame(context:TMax2DContext)
		context.CheckOpen()
		If locked And writing Then Throw "Max2D: unlock the image before drawing"
		If renderTarget And targetOwner And targetOwner <> context Then Throw "Max2D: render images belong to their creating context"
		Local result:TImageFrame
		Local link:TLink = frames.FirstLink()
		While link
			Local following:TLink = link.NextLink()
			Local frame:TImageFrame = TImageFrame(link.Value())
			If frame.closed Or frame.releasePending Then
				link.Remove()
			Else If frame.owner = context Then
				result = frame
			End If
			link = following
		Wend
		If Not result Then
			Local pixelFormat:Int=targetFormat
			If pixmap Then pixelFormat=pixmap.format
			If textureData Then pixelFormat=textureData.Format()
			result = context.CreateFrame(width, height, flags, renderTarget, pixelFormat, textureData)
			frames.AddLast(result)
			If renderTarget Then targetOwner = context
		End If
		If Not renderTarget And result.version <> version Then
			If textureData Then
				context.UpdateTextureFrame(result,textureData)
			Else If result.version > 0 And result.dirtyW > 0 And result.dirtyH > 0 Then
				context.UpdateFrame(result, pixmap, result.dirtyX, result.dirtyY, result.dirtyW, result.dirtyH)
			Else
				context.UpdateFrame(result, pixmap, 0, 0, width, height)
			End If
			result.dirtyW=0; result.dirtyH=0
			result.version = version
		End If
		Return result
	End Method

	Method ReleaseFrames()
		For Local frame:TImageFrame = EachIn frames
			frame.releasePending = True
		Next
		frames.Clear()
	End Method

	Method Delete()
		' Managed bookkeeping only. The rendering thread drains the release queue.
		ReleaseFrames()
	End Method
End Type

Rem
bbdoc: A view of one or more image regions. Native resources are context-specific.
End Rem
Type TImage
	Field width:Int, height:Int, flags:Int
	Field handle_x:Float, handle_y:Float
	Field sources:TImageSource[]
	Field sourceX:Int[], sourceY:Int[]
	Field frameDuration:Int[]
	Field trims:TImageTrim[]

	Method Trim:TImageTrim(index:Int=0)
		If trims Then Return trims[index]
		Return Null
	End Method

	Method SetTrim(index:Int,x:Int,y:Int,w:Int,h:Int)
		CheckIndex(index)
		If x<0 Or y<0 Or w<0 Or h<0 Or Long(x)+w>width Or Long(y)+h>height Or ((w=0) <> (h=0)) Then Throw "Max2D: invalid image trim"
		If Not trims Then trims=New TImageTrim[sources.Length]
		Local trim:TImageTrim=New TImageTrim
		trim.x=x; trim.y=y; trim.width=w; trim.height=h
		trims[index]=trim
	End Method

	Rem
	bbdoc: Total duration in milliseconds. Every frame must have positive timing.
	End Rem
	Method AnimationDuration:Long()
		Local total:Long
		For Local duration:Int=EachIn frameDuration
			If duration<=0 Then Throw "Max2D: animation frame timing is unspecified"
			total:+duration
		Next
		If total=0 Then Throw "Max2D: animation has no frames"
		Return total
	End Method

	Method FrameAtTime:Int(elapsed:Long,loop:Int=True)
		Local total:Long=AnimationDuration()
		If elapsed<0 Then elapsed=0
		If loop Then
			elapsed=elapsed Mod total
		Else If elapsed>=total Then
			Return sources.Length-1
		End If
		For Local i:Int=0 Until frameDuration.Length
			If elapsed<frameDuration[i] Then Return i
			elapsed:-frameDuration[i]
		Next
		Return sources.Length-1
	End Method

	Function Animation:TImage(frames:TImage[],durations:Int[])
		If frames.Length=0 Or frames.Length<>durations.Length Then Throw "Max2D: animation frames and durations must match"
		Local result:TImage=New TImage
		result.sources=New TImageSource[frames.Length]
		result.sourceX=New Int[frames.Length]; result.sourceY=New Int[frames.Length]
		result.frameDuration=durations[..]
		For Local i:Int=0 Until frames.Length
			Local frame:TImage=frames[i]
			If Not frame Or frame.sources.Length<>1 Then Throw "Max2D: animation requires single-frame images"
			If durations[i]<0 Or frame.sources[0].renderTarget Then Throw "Max2D: invalid animation frame"
			If i=0 Then
				result.width=frame.width; result.height=frame.height; result.flags=frame.flags
				result.handle_x=frame.handle_x; result.handle_y=frame.handle_y
			Else If frame.width<>result.width Or frame.height<>result.height Or frame.flags<>result.flags Or frame.handle_x<>result.handle_x Or frame.handle_y<>result.handle_y Then
				Throw "Max2D: animation frames must share canvas dimensions, flags and handles"
			End If
			result.sources[i]=frame.sources[0]; result.sourceX[i]=frame.sourceX[0]; result.sourceY[i]=frame.sourceY[0]
			Local trim:TImageTrim=frame.Trim()
			If trim Then result.SetTrim(i,trim.x,trim.y,trim.width,trim.height)
		Next
		Return result
	End Function

	' Validate first, so a failed update leaves both pixels and version unchanged.
	Method ReplacePixels(pixmap:TPixmap,index:Int=0)
		CheckIndex(index)
		If sources[index].textureData Then Throw "Max2D: texture-data images are read-only; create a new image to replace their storage"
		If sources[index].locked Or sources[index].renderTarget Then Throw "Max2D: replacement requires unlocked CPU pixels"
		If Not pixmap Then Throw "Max2D: image pixels are null"
		If pixmap.width<>width Or pixmap.height<>height Then Throw "Max2D: image update dimensions must match"
		Local trim:TImageTrim=Trim(index)
		Local x:Int,y:Int,w:Int=width,h:Int=height
		If trim Then
			x=trim.x; y=trim.y; w=trim.width; h=trim.height
			For Local py:Int=0 Until height
				For Local px:Int=0 Until width
					If px>=x And px<x+w And py>=y And py<y+h Then Continue
					If pixmap.ReadPixel(px,py) Shr 24 Then Throw "Max2D: update exceeds the trimmed footprint; repack the image"
				Next
			Next
		End If
		If w=0 Or h=0 Then Return
		Local source:TImageSource=sources[index]
		Local pixels:TPixmap=pixmap.Window(x,y,w,h)
		If pixels.format<>source.pixmap.format Then pixels=pixels.Convert(source.pixmap.format)
		source.pixmap.Paste(pixels,sourceX[index],sourceY[index])
		source.Changed(sourceX[index],sourceY[index],w,h)
	End Method

	Method CheckIndex(index:Int)
		If index < 0 Or index >= sources.Length Then Throw "Max2D: image frame index out of range"
	End Method

	Method Frame:TImageFrame(index:Int = 0, graphics:TMax2DGraphics = Null)
		CheckIndex(index)
		If Not graphics Then graphics = TMax2DGraphics.Current()
		Return sources[index].Frame(graphics.context)
	End Method

	Method Lock:TPixmap(index:Int = 0, read:Int = True, write:Int = True)
		CheckIndex(index)
		Local source:TImageSource = sources[index]
		If source.locked Then Throw "Max2D: image is already locked"
		If source.renderTarget Then
			If write Then Throw "Max2D: render images support explicit readback, not CPU write locks"
			If Not source.targetOwner Then Throw "Max2D: render image has not been created in a context"
			Local frame:TImageFrame = source.Frame(source.targetOwner)
			Return source.targetOwner.Read(frame, sourceX[index], sourceY[index], width, height)
		End If
		If write And source.textureData Then Throw "Max2D: texture-data images do not support write locks"
		If write And Not (flags & DYNAMICIMAGE) Then Throw "Max2D: write locks require DYNAMICIMAGE"
		Local pixels:TPixmap
		Local readable:TPixmap=source.ReadPixels()
		Local trim:TImageTrim=Trim(index)
		If trim Then
			pixels=CreatePixmap(width,height,readable.format)
			pixels.ClearPixels(0)
			If read And trim.width>0 And trim.height>0 Then pixels.Paste(readable.Window(sourceX[index],sourceY[index],trim.width,trim.height),trim.x,trim.y)
		Else
			pixels=readable.Window(sourceX[index],sourceY[index],width,height)
			If source.textureData Then pixels=pixels.Copy()
		End If
		source.locked=True; source.writing=write
		source.lockImage=Self; source.lockIndex=index
		If trim Then source.lockPixels=pixels
		Return pixels
	End Method

	Method Unlock(index:Int = 0)
		CheckIndex(index)
		Local source:TImageSource = sources[index]
		If source.renderTarget Then Return
		If Not source.locked Then Throw "Max2D: image is not locked"
		If source.lockImage<>Self Or source.lockIndex<>index Then Throw "Max2D: unlock the image frame used for the lock"
		Local pixels:TPixmap=source.lockPixels
		Local writing:Int=source.writing
		source.locked=False; source.writing=False; source.lockImage=Null; source.lockPixels=Null
		If writing Then
			If pixels Then
				ReplacePixels(pixels,index)
			Else
				source.Changed(sourceX[index],sourceY[index],width,height)
			End If
		End If
	End Method

	Method ReleaseFrames()
		For Local source:TImageSource = EachIn sources
			source.ReleaseFrames()
		Next
	End Method

	Rem
	bbdoc: Creates an independent image, optionally storing alpha coverage only.
	about: pixelFormat may be PF_RGBA8888 (the default) or PF_A8. PF_A8 discards colour and draws white modulated by the drawing colour. Unsupported native formats are expanded during upload. Locks expose the selected CPU format.
	End Rem
	Function FromPixmap:TImage(pixmap:TPixmap, flags:Int = 0, pixelFormat:Int=PF_RGBA8888)
		If Not pixmap Then Return Null
		If pixelFormat<>PF_RGBA8888 And pixelFormat<>PF_A8 Then Throw "Max2D: unsupported image storage format"
		Local image:TImage = New TImage
		image.width = pixmap.width; image.height = pixmap.height; image.flags = flags
		image.sources = New TImageSource[1]
		image.sourceX = New Int[1]; image.sourceY = New Int[1]
		image.frameDuration = New Int[1]
		Local source:TImageSource = New TImageSource
		source.width = image.width; source.height = image.height; source.flags = flags
		If pixmap.format <> pixelFormat Then pixmap = pixmap.Convert(pixelFormat)
		source.pixmap = pixmap.Copy()
		image.sources[0] = source
		Return image
	End Function

	Rem
	bbdoc: Creates an image from an independent snapshot of owned texture data.
	about: Accepts RGBA8888, A8, RGBA16F, RGBA32F, BC1_RGBA or BC3_RGBA data, subject to backend support. Multiple levels enable MIPMAPPEDIMAGE automatically and are uploaded unchanged, including partial chains. Supplied levels use straight alpha. DYNAMICIMAGE is rejected. Uncompressed byte formats support read-lock snapshots and collisions; floating-point and compressed formats do not expose pixmap operations. Write locks and ReplacePixels are unavailable. With a single level, MIPMAPPEDIMAGE requests backend-generated mipmaps only for supported byte formats. Use Max2DTextureDataSupport to check the data and flags. Unsupported formats fail explicitly without altering their bytes.
	End Rem
	Function FromTextureData:TImage(data:TTextureData,flags:Int=0)
		If Not data Then Throw "Max2D: texture data is null"
		If data.LevelCount()>1 Then flags:|MIPMAPPEDIMAGE
		If data.Format()<>PF_RGBA8888 And data.Format()<>PF_A8 And data.Format()<>PF_RGBA16F And data.Format()<>PF_RGBA32F And data.Format()<>PF_BC1_RGBA And data.Format()<>PF_BC3_RGBA Then Throw "Max2D: unsupported texture-data format"
		If flags & DYNAMICIMAGE Then Throw "Max2D: texture-data images are read-only"
		Local image:TImage=New TImage
		image.width=data.Width()
		image.height=data.Height()
		image.flags=flags
		image.sources=New TImageSource[1]
		image.sourceX=New Int[1]
		image.sourceY=New Int[1]
		image.frameDuration=New Int[1]
		Local source:TImageSource=New TImageSource
		source.width=image.width
		source.height=image.height
		source.flags=flags
		source.textureData=data.Copy()
		image.sources[0]=source
		Return image
	End Function

	Function View:TImage(image:TImage, x:Int, y:Int, width:Int, height:Int, frame:Int = 0)
		image.CheckIndex(frame)
		If width <= 0 Or height <= 0 Or x < 0 Or y < 0 Or Long(x) + width > image.width Or Long(y) + height > image.height Then Throw "Max2D: image view out of bounds"
		Local result:TImage = New TImage
		result.width = width; result.height = height; result.flags = image.flags
		result.sources = New TImageSource[1]
		result.sourceX = New Int[1]; result.sourceY = New Int[1]
		result.frameDuration = New Int[1]
		result.sources[0] = image.sources[frame]
		result.sourceX[0] = image.sourceX[frame] + x
		result.sourceY[0] = image.sourceY[frame] + y
		result.frameDuration[0]=image.frameDuration[frame]
		Local trim:TImageTrim=image.Trim(frame)
		If trim Then
			Local left:Int=Max(x,trim.x),top:Int=Max(y,trim.y)
			Local right:Int=Min(x+width,trim.x+trim.width),bottom:Int=Min(y+height,trim.y+trim.height)
			If right<=left Or bottom<=top Then
				result.sourceX[0]=image.sourceX[frame]; result.sourceY[0]=image.sourceY[frame]
				result.SetTrim(0,0,0,0,0)
			Else
				result.sourceX[0]=image.sourceX[frame]+left-trim.x; result.sourceY[0]=image.sourceY[frame]+top-trim.y
				result.SetTrim(0,left-x,top-y,right-left,bottom-top)
			End If
		End If
		Return result
	End Function
End Type

Type TRenderImage Extends TImage
	Function Create:TRenderImage(width:Int, height:Int, flags:Int,pixelFormat:Int=PF_RGBA8888)
		If width <= 0 Or height <= 0 Then Throw "Max2D: image dimensions must be positive"
		Local image:TRenderImage = New TRenderImage
		image.width = width; image.height = height; image.flags = flags
		image.sources = New TImageSource[1]
		image.sourceX = New Int[1]; image.sourceY = New Int[1]
		image.frameDuration = New Int[1]
		Local source:TImageSource = New TImageSource
		source.width = width; source.height = height; source.flags = flags
		If pixelFormat<>PF_RGBA8888 And pixelFormat<>PF_RGBA16F And pixelFormat<>PF_RGBA32F Then Throw "Max2D: unsupported render-image format"
		source.targetFormat=pixelFormat
		source.renderTarget = True
		image.sources[0] = source
		Return image
	End Function
End Type
