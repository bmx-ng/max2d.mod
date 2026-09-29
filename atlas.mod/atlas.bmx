SuperStrict
Rem
bbdoc: Batch atlas construction using BRL.RectPacker.
End Rem
Module Max2D.Atlas
ModuleInfo "Version: 0.03"
ModuleInfo "License: zlib/libpng"
Import Max2D.Core
Import BRL.RectPacker

Rem
bbdoc: Named animation frames and durations waiting to be packed by an atlas builder.
End Rem
Type TAtlasAnimationInput

	Rem
	bbdoc: Name used to identify this entry.
	End Rem
	Field name:String

	Rem
	bbdoc: Zero-based starting index in the associated source array.
	End Rem
	Field start:Int

	Rem
	bbdoc: Number of populated entries; backing storage may have extra capacity.
	End Rem
	Field count:Int

	Rem
	bbdoc: Per-frame animation durations in milliseconds.
	End Rem
	Field durations:Int[]
End Type

Rem
bbdoc: Collects sprites and animations for rectangle-packed atlas construction.
End Rem
Type TAtlasBuilder

	Rem
	bbdoc: Source pixmaps collected for the next atlas build.
	End Rem
	Field inputs:TPixmap[] = New TPixmap[0]

	Rem
	bbdoc: Names corresponding to collected atlas input images.
	End Rem
	Field names:String[] = New String[0]

	Rem
	bbdoc: Animation definitions waiting for atlas construction.
	End Rem
	Field animations:TList=New TList

	Rem
	bbdoc: Whether atlas construction removes transparent borders while preserving logical placement.
	End Rem
	Field trimTransparent:Int=False

	Rem
	bbdoc: Preferred square atlas-page size in pixels.
	End Rem
	Field pageSize:Int = 1024

	Rem
	bbdoc: Number of extruded border pixels surrounding each atlas region.
	End Rem
	Field padding:Int = 1

	Rem
	bbdoc: Image creation and sampling flags.
	End Rem
	Field flags:Int = FILTEREDIMAGE

	Rem
	bbdoc: Adds named source pixels to the next atlas build.
	param: Source pixel data.
	param: Name used to register or look up the item.
	End Rem
	Method Add(pixmap:TPixmap,name:String)
		If Not pixmap Or Not name Then Throw "Max2D atlas: each input needs pixels and a name"
		CheckName(name)
		inputs=inputs[..inputs.Length+1]; names=names[..names.Length+1]
		inputs[inputs.Length-1]=pixmap.Copy(); names[names.Length-1]=name
	End Method

	Rem
	bbdoc: Rejects an empty or duplicate atlas entry name.
	param: Name used to register or look up the item.
	End Rem
	Method CheckName(name:String)
		If Not name Then Throw "Max2D atlas: image name is empty"
		For Local existing:String=EachIn names
			If existing=name Then Throw "Max2D atlas: duplicate image name"
		Next
		For Local animation:TAtlasAnimationInput=EachIn animations
			If animation.name=name Then Throw "Max2D atlas: duplicate image name"
		Next
	End Method

	Rem
	bbdoc: Adds animation frames with a common logical canvas and positive durations in milliseconds.
	param: Unique nonempty name for the packed animation.
	param: Source frame pixmaps in playback order.
	param: Positive duration of each animation frame in milliseconds.
	End Rem
	Method AddAnimation(name:String,frames:TPixmap[],durations:Int[])
		CheckName(name)
		If frames.Length=0 Or frames.Length<>durations.Length Then Throw "Max2D atlas: animation frames and durations must match"
		For Local i:Int=0 Until frames.Length
			If Not frames[i] Or durations[i]<=0 Then Throw "Max2D atlas: animation requires pixels and positive durations"
			If frames[i].width<>frames[0].width Or frames[i].height<>frames[0].height Then Throw "Max2D atlas: animation canvas dimensions must match"
		Next
		Local animation:TAtlasAnimationInput=New TAtlasAnimationInput
		animation.name=name; animation.start=inputs.Length; animation.count=frames.Length
		animation.durations=durations[..]
		inputs=inputs[..inputs.Length+frames.Length]; names=names[..inputs.Length]
		For Local i:Int=0 Until frames.Length
			inputs[animation.start+i]=frames[i].Copy()
		Next
		animations.AddLast(animation)
	End Method

	Rem
	bbdoc: Packs the collected source images into a new texture atlas.
	End Rem
	Method Build:TTextureAtlas()
		Local atlas:TTextureAtlas=TTextureAtlas.Create(pageSize,flags,padding)
		If Not inputs.Length Then Return atlas
		Local packer:TRectPacker=New TRectPacker
		packer.maxWidth=pageSize; packer.maxHeight=pageSize
		packer.maxSheets=inputs.Length
		packer.allowRotate=False
		packer.powerOfTwo=False
		Local prepared:TAtlasPixels[]=New TAtlasPixels[inputs.Length]
		Local frames:TImage[]=New TImage[inputs.Length]
		For Local i:Int=0 Until inputs.Length
			prepared[i]=TAtlasPixels.Prepare(inputs[i],trimTransparent,flags & FILTEREDIMAGE)
			Local w:Int=prepared[i].pixmap.width+2*padding,h:Int=prepared[i].pixmap.height+2*padding
			If w>pageSize Or h>pageSize Then Throw "Max2D atlas: input exceeds the configured page size"
			packer.Add(w,h,i)
		Next
		Local sheets:TPackedSheet[]=packer.Pack()
		Local packed:Int
		For Local sheet:TPackedSheet = EachIn sheets
			Local page:TImage=atlas.AddPage(sheet.width,sheet.height)
			For Local rect:SPackedRect = EachIn sheet.rects
				If rect.rotated Then Throw "Max2D atlas: unexpected rotated region"
				Local image:TImage=TTextureAtlas.Place(page,prepared[rect.id].pixmap,rect.x,rect.y,padding)
				prepared[rect.id].Apply(image)
				frames[rect.id]=image
				If names[rect.id] Then atlas.images.Insert(names[rect.id],image)
				packed:+1
			Next
		Next
		If packed<>inputs.Length Then Throw "Max2D atlas: packer could not place every input"
		For Local animation:TAtlasAnimationInput=EachIn animations
			atlas.AddAnimation(animation.name,frames[animation.start..animation.start+animation.count],animation.durations)
		Next
		Return atlas
	End Method

End Type
