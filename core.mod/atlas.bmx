Rem
bbdoc: Prepared atlas pixels and their placement within the original logical canvas.
End Rem
Type TAtlasPixels
	Field pixmap:TPixmap
	Field width:Int,height:Int,x:Int,y:Int,contentWidth:Int,contentHeight:Int

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
	Field pixelFormat:Int = PF_RGBA8888
	Field pageSize:Int = 512
	Field padding:Int = 1
	Field flags:Int = FILTEREDIMAGE
	Field pages:TImage[] = New TImage[0]
	Field images:TMap = New TMap
	Field nextX:Int, nextY:Int, rowHeight:Int
	Field current:TImage

	Function Create:TTextureAtlas(pageSize:Int=512,flags:Int=FILTEREDIMAGE,padding:Int=1,pixelFormat:Int=PF_RGBA8888)
		If flags & MIPMAPPEDIMAGE Then Throw "Max2D: packed atlases do not support mipmaps; use independent images"
		If pageSize<4 Or padding<1 Or padding*2>=pageSize Then Throw "Max2D: invalid atlas dimensions"
		If pixelFormat<>PF_RGBA8888 And pixelFormat<>PF_A8 Then Throw "Max2D: unsupported atlas storage format"
		Local atlas:TTextureAtlas=New TTextureAtlas
		atlas.pixelFormat=pixelFormat
		atlas.pageSize=pageSize; atlas.flags=flags; atlas.padding=padding
		Return atlas
	End Function
	Method AddPage:TImage(width:Int,height:Int)
		Local pixmap:TPixmap=CreatePixmap(width,height,pixelFormat)
		pixmap.ClearPixels(0)
		Local image:TImage=TImage.FromPixmap(pixmap,flags,pixelFormat)
		pages=pages[..pages.Length+1]; pages[pages.Length-1]=image
		Return image
	End Method
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
	about: The replacement dimensions must match. Existing image views see the update.
	End Rem
	Method UpdatePixmap(name:String,pixmap:TPixmap,frame:Int=0)
		Local image:TImage=GetImage(name)
		If Not image Then Throw "Max2D: unknown atlas image name"
		image.CheckIndex(frame)
		If image.sources[frame].locked Then Throw "Max2D: unlock the atlas page before updating images"
		image.ReplacePixels(pixmap,frame)
	End Method

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

	Method GetImage:TImage(name:String)
		Return TImage(images.ValueForKey(name))
	End Method
	Method PageCount:Int()
		Return pages.Length
	End Method
	Method Page:TImage(index:Int)
		If index<0 Or index>=pages.Length Then Throw "Max2D: atlas page index out of range"
		Return pages[index]
	End Method
End Type
