
Rem
bbdoc: Prepared atlas pixels and their placement within the original logical canvas.
End Rem
Type TAtlasPixels

	Rem
	bbdoc: CPU pixel storage shared by this image source or atlas entry.
	End Rem
	Field pixmap:TPixmap

	Rem
	bbdoc: Original logical sprite width before trimming.
	End Rem
	Field width:Int

	Rem
	bbdoc: Original logical sprite height before trimming.
	End Rem
	Field height:Int

	Rem
	bbdoc: Trimmed pixel region's left offset within the original sprite.
	End Rem
	Field x:Int

	Rem
	bbdoc: Trimmed pixel region's top offset within the original sprite.
	End Rem
	Field y:Int

	Rem
	bbdoc: Width of stored sprite pixels after transparent-border trimming.
	End Rem
	Field contentWidth:Int

	Rem
	bbdoc: Height of stored sprite pixels after transparent-border trimming.
	End Rem
	Field contentHeight:Int

	Rem
	bbdoc: Finds stored sprite pixels while preserving logical size and optional filtering fringe.
	param: Source pixel data.
	param: Whether to remove transparent borders while retaining logical size and placement.
	param: Whether to preserve a transparent fringe for texture filtering.
	End Rem
	Function Prepare:TAtlasPixels(pixels:TPixmap,trimTransparent:Int,filtered:Int)
		If Not pixels Then Throw "Max2D: atlas input is null"
		Local result:TAtlasPixels=New TAtlasPixels
		result.width=pixels.width; result.height=pixels.height
		result.contentWidth=pixels.width; result.contentHeight=pixels.height
		result.pixmap=pixels
		If Not trimTransparent Then Return result
		If pixels.format<>PF_RGBA8888 And pixels.format<>PF_A8 Then pixels=pixels.Convert(PF_RGBA8888)
		Local left:Int=pixels.width,top:Int=pixels.height,right:Int,bottom:Int
		For Local y:Int=0 Until pixels.height
			For Local x:Int=0 Until pixels.width
				If pixels.ReadPixel(x,y) Shr 24 Then
					left=Min(left,x); top=Min(top,y); right=Max(right,x+1); bottom=Max(bottom,y+1)
				End If
			Next
		Next
		If right<=left Or bottom<=top Then
			result.pixmap=CreatePixmap(1,1,pixels.format)
			result.pixmap.ClearPixels(0)
			result.contentWidth=0; result.contentHeight=0
			Return result
		End If
		' Keep the transparent filtering fringe, separate from atlas extrusion padding.
		If filtered Then
			left=Max(0,left-1); top=Max(0,top-1)
			right=Min(pixels.width,right+1); bottom=Min(pixels.height,bottom+1)
		End If
		result.x=left; result.y=top
		result.contentWidth=right-left; result.contentHeight=bottom-top
		result.pixmap=pixels.Window(left,top,right-left,bottom-top)
		Return result
	End Function

	Rem
	bbdoc: Applies the original dimensions and trimmed placement to an image view.
	param: Image to operate on.
	End Rem
	Method Apply(image:TImage)
		image.width=width; image.height=height
		If x Or y Or contentWidth<>width Or contentHeight<>height Then image.SetTrim(0,x,y,contentWidth,contentHeight)
	End Method

End Type

Rem
bbdoc: Texture atlas pages shared by sprites or glyphs.
about: Insertions never relocate existing images. GetImage returns an ordinary TImage view. Create accepts an optional final pixelFormat: PF_RGBA8888 by default, or PF_A8 for white alpha coverage. Coverage atlases discard input colour.
End Rem
Type TTextureAtlas

	Rem
	bbdoc: Pixel storage format from BRL.PixelFormat.
	End Rem
	Field pixelFormat:Int = PF_RGBA8888

	Rem
	bbdoc: Preferred square atlas-page size in pixels.
	End Rem
	Field pageSize:Int = 512

	Rem
	bbdoc: Number of extruded border pixels surrounding each atlas region.
	End Rem
	Field padding:Int = 1

	Rem
	bbdoc: Image creation and sampling flags.
	End Rem
	Field flags:Int = FILTEREDIMAGE

	Rem
	bbdoc: Atlas page images shared by packed image views.
	End Rem
	Field pages:TImage[] = New TImage[0]

	Rem
	bbdoc: Named image views registered in the atlas.
	End Rem
	Field images:TMap = New TMap

	Rem
	bbdoc: Horizontal insertion position used by the atlas row packer.
	End Rem
	Field nextX:Int

	Rem
	bbdoc: Vertical insertion position used by the atlas row packer.
	End Rem
	Field nextY:Int

	Rem
	bbdoc: Height of the current atlas packing row in pixels.
	End Rem
	Field rowHeight:Int

	Rem
	bbdoc: Atlas page currently receiving row-packed insertions.
	End Rem
	Field current:TImage

	Rem
	bbdoc: Creates a growing atlas with padded RGBA or alpha-coverage pages.
	param: Preferred width and height of new atlas pages in pixels.
	param: Image flags controlling filtering, masking, mipmaps and CPU editing where supported.
	param: Extruded border width in pixels around each packed region.
	param: Pixel storage format from BRL.PixelFormat.
	End Rem
	Function Create:TTextureAtlas(pageSize:Int=512,flags:Int=FILTEREDIMAGE,padding:Int=1,pixelFormat:Int=PF_RGBA8888)
		If flags & MIPMAPPEDIMAGE Then Throw "Max2D: packed atlases do not support mipmaps; use independent images"
		If pageSize<4 Or padding<1 Or padding*2>=pageSize Then Throw "Max2D: invalid atlas dimensions"
		If pixelFormat<>PF_RGBA8888 And pixelFormat<>PF_A8 Then Throw "Max2D: unsupported atlas storage format"
		Local atlas:TTextureAtlas=New TTextureAtlas
		atlas.pixelFormat=pixelFormat
		atlas.pageSize=pageSize; atlas.flags=flags; atlas.padding=padding
		Return atlas
	End Function

	Rem
	bbdoc: Adds a transparent atlas page of the supplied pixel dimensions.
	param: Width of the rectangle or drawing surface.
	param: Height of the rectangle or drawing surface.
	End Rem
	Method AddPage:TImage(width:Int,height:Int)
		Local pixmap:TPixmap=CreatePixmap(width,height,pixelFormat)
		pixmap.ClearPixels(0)
		Local image:TImage=TImage.FromPixmap(pixmap,flags,pixelFormat)
		pages=pages[..pages.Length+1]; pages[pages.Length-1]=image
		Return image
	End Method

	Rem
	bbdoc: Packs pixels into the atlas and returns an ordinary image view.
	param: Source pixel data.
	param: Name used to register or look up the item.
	param: Whether to remove transparent borders while retaining logical size and placement.
	End Rem
	Method AddPixmap:TImage(pixmap:TPixmap,name:String="",trimTransparent:Int=False)
		If Not pixmap Then Throw "Max2D: atlas input is null"
		If name And images.Contains(name) Then Throw "Max2D: duplicate atlas image name"
		Local prepared:TAtlasPixels=TAtlasPixels.Prepare(pixmap,trimTransparent,flags & FILTEREDIMAGE)
		pixmap=prepared.pixmap
		Local paddedW:Int=pixmap.width+2*padding,paddedH:Int=pixmap.height+2*padding
		Local page:TImage
		Local x:Int,y:Int
		If paddedW>pageSize Or paddedH>pageSize Then
			page=AddPage(paddedW,paddedH)
		Else
			If Not current Then
				current=AddPage(pageSize,pageSize)
				nextX=0; nextY=0; rowHeight=0
			End If
			If nextX+paddedW>pageSize Then nextX=0; nextY:+rowHeight; rowHeight=0
			If nextY+paddedH>pageSize Then
				current=AddPage(pageSize,pageSize)
				nextX=0; nextY=0; rowHeight=0
			End If
			page=current; x=nextX; y=nextY
			nextX:+paddedW; rowHeight=Max(rowHeight,paddedH)
		End If
		Local image:TImage=Place(page,pixmap,x,y,padding)
		prepared.Apply(image)
		If name Then images.Insert(name,image)
		Return image
	End Method

	Rem
	bbdoc: Places pixels and extruded padding at a chosen position on an atlas page.
	param: Atlas page image receiving the pixels.
	param: Source pixel data.
	param: Horizontal coordinate.
	param: Vertical coordinate.
	param: Extruded border width in pixels around each packed region.
	End Rem
	Function Place:TImage(page:TImage,pixmap:TPixmap,x:Int,y:Int,padding:Int)
		If page.flags & MIPMAPPEDIMAGE Then Throw "Max2D: cannot pack regions into a mipmapped page"
		Local rgba:TPixmap=pixmap
		Local source:TImageSource=page.sources[0]
		If source.textureData Then Throw "Max2D: cannot insert into a texture-data image"
		If rgba.format<>source.pixmap.format Then rgba=rgba.Convert(source.pixmap.format)
		Local w:Int=rgba.width,h:Int=rgba.height
		If x<0 Or y<0 Or x+w+2*padding>page.width Or y+h+2*padding>page.height Then Throw "Max2D: atlas region out of bounds"
		If source.locked Then Throw "Max2D: unlock the atlas page before inserting images"
		source.pixmap.Paste(rgba,x+padding,y+padding)
		Local region:TImageRegion=New TImageRegion
		region.x=x+padding; region.y=y+padding; region.width=w; region.height=h; region.padding=padding
		source.regions.AddLast(region)
		source.Changed(x,y,w+2*padding,h+2*padding)
		Return TImage.View(page,x+padding,y+padding,w,h)
	End Function

	Rem
	bbdoc: Replaces a named region's pixels without moving it or replacing its texture.
	param: Name used to register or look up the item.
	param: Source pixel data.
	param: Zero-based image frame index.
	about: The replacement dimensions must match. Existing image views see the update.
	End Rem
	Method UpdatePixmap(name:String,pixmap:TPixmap,frame:Int=0)
		Local image:TImage=GetImage(name)
		If Not image Then Throw "Max2D: unknown atlas image name"
		image.CheckIndex(frame)
		If image.sources[frame].locked Then Throw "Max2D: unlock the atlas page before updating images"
		image.ReplacePixels(pixmap,frame)
	End Method

	Rem
	bbdoc: Registers an animation with per-frame timing under an atlas name.
	param: Name used to register or look up the item.
	param: Animation frame images in playback order.
	param: Positive duration of each animation frame in milliseconds.
	End Rem
	Method AddAnimation:TImage(name:String,frames:TImage[],durations:Int[])
		If Not name Or images.Contains(name) Then Throw "Max2D: missing or duplicate atlas image name"
		Local image:TImage=TImage.Animation(frames,durations)
		For Local source:TImageSource=EachIn image.sources
			Local found:Int
			For Local page:TImage=EachIn pages
				If page.sources[0]=source Then found=True; Exit
			Next
			If Not found Then Throw "Max2D: animation frame is not an atlas image"
		Next
		images.Insert(name,image)
		Return image
	End Method

	Rem
	bbdoc: Returns the image registered under a name, or Null when absent.
	param: Name used to register or look up the item.
	End Rem
	Method GetImage:TImage(name:String)
		Return TImage(images.ValueForKey(name))
	End Method

	Rem
	bbdoc: Returns the number of atlas texture pages.
	End Rem
	Method PageCount:Int()
		Return pages.Length
	End Method

	Rem
	bbdoc: Returns the atlas page at a zero-based index.
	param: Zero-based index.
	End Rem
	Method Page:TImage(index:Int)
		If index<0 Or index>=pages.Length Then Throw "Max2D: atlas page index out of range"
		Return pages[index]
	End Method

End Type
