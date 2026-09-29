SuperStrict
Rem
bbdoc: PNG and JSON storage for Max2D texture atlases.
End Rem
Module Max2D.AtlasIO
ModuleInfo "Version: 0.02"
ModuleInfo "License: zlib/libpng"
Import Max2D.Core
Import Image.PNG
Import Text.JSON
Import BRL.FileSystem
Import BRL.TextStream

Private
Function AtlasInteger:Int(obj:TJSONObject,key:String,minimum:Int=0,maximum:Int=$7fffffff)
	Local value:TJSONInteger=TJSONInteger(obj.Get(key))
	If Not value Then Throw "Max2D atlas: missing or invalid integer: "+key
	Local number:Long=value.Value()
	If number<minimum Or number>maximum Then Throw "Max2D atlas: integer out of range: "+key
	Return Int(number)
End Function

Function AtlasNumber:Float(obj:TJSONObject,key:String)
	Local value:TJSON=obj.Get(key)
	Local number:Double
	If TJSONInteger(value) Then
		number=TJSONInteger(value).Value()
	Else If TJSONReal(value) Then
		number=TJSONReal(value).Value()
	Else
		Throw "Max2D atlas: missing or invalid number: "+key
	End If
	If Abs(number)>3.4028234e38 Then Throw "Max2D atlas: number out of range: "+key
	Return Float(number)
End Function

Function AtlasObject:TJSONObject(value:TJSON)
	Local obj:TJSONObject=TJSONObject(value)
	If Not obj Then Throw "Max2D atlas: expected an object"
	Return obj
End Function

Function AtlasArray:TJSONArray(obj:TJSONObject,key:String)
	Local array:TJSONArray=TJSONArray(obj.Get(key))
	If Not array Then Throw "Max2D atlas: missing or invalid array: "+key
	Return array
End Function

Function AtlasRect(obj:TJSONObject,width:Int,height:Int,x:Int Var,y:Int Var,w:Int Var,h:Int Var,padding:Int=0)
	x=AtlasInteger(obj,"x",padding,width)
	y=AtlasInteger(obj,"y",padding,height)
	w=AtlasInteger(obj,"width",1,width)
	h=AtlasInteger(obj,"height",1,height)
	If Long(x)+w+padding>width Or Long(y)+h+padding>height Then Throw "Max2D atlas: region outside page"
End Function

Function AtlasRectJSON:TJSONObject(x:Int,y:Int,w:Int,h:Int)
	Local result:TJSONObject=New TJSONObject.Create()
	result.Set("x",x); result.Set("y",y); result.Set("width",w); result.Set("height",h)
	Return result
End Function

Function AtlasPagePath:String(directory:String,index:Int)
	Return directory+"/page-"+index+".png"
End Function

Function CheckAtlasPNGHeader(path:String,width:Int,height:Int)
	Local stream:TStream=ReadFile(path)
	If Not stream Then Throw "Max2D atlas: cannot open PNG page"
	Try
		Local signature:Int[]=[137,80,78,71,13,10,26,10,0,0,0,13,73,72,68,82]
		For Local value:Int=EachIn signature
			If stream.ReadByte()<>value Then Throw "Max2D atlas: invalid PNG header"
		Next
		Local w:Long,h:Long
		For Local i:Int=0 Until 4
			w=(w Shl 8)|stream.ReadByte()
		Next
		For Local i:Int=0 Until 4
			h=(h Shl 8)|stream.ReadByte()
		Next
		If w<>width Or h<>height Then Throw "Max2D atlas: PNG dimensions do not match manifest"
	Catch error:Object
		stream.Close()
		Throw error
	End Try
	stream.Close()
End Function

Public

Rem
bbdoc: Saves PNG pages and atlas.json into a new directory. Existing paths are rejected.
param: Atlas whose pages and named entries will be saved.
param: Atlas package directory or supported filesystem URL.
about: Saves all named image views, their handles, and all padding regions. No graphics context is needed.
End Rem
Function SaveTextureAtlas:Int(atlas:TTextureAtlas,directory:String)
	If Not atlas Then Throw "Max2D atlas: atlas is null"
	If Not directory Or FileType(directory) Then Throw "Max2D atlas: output directory must be new"
	If atlas.pageSize<4 Or atlas.pageSize>16384 Or atlas.padding<1 Or atlas.padding*2>=atlas.pageSize Then Throw "Max2D atlas: invalid atlas dimensions"
	If atlas.flags & ~(MASKEDIMAGE|FILTEREDIMAGE|DYNAMICIMAGE) Then Throw "Max2D atlas: unsupported image flags"
	Local root:TJSONObject=New TJSONObject.Create()
	root.Set("format","max2d-atlas"); root.Set("version",1)
	root.Set("pageSize",atlas.pageSize); root.Set("padding",atlas.padding); root.Set("flags",atlas.flags)
	Local pages:TJSONArray=New TJSONArray.Create()
	For Local page:TImage=EachIn atlas.pages
		If Not page Then Throw "Max2D atlas: page is null"
		If page.width<1 Or page.height<1 Or page.width>16384 Or page.height>16384 Then Throw "Max2D atlas: page dimensions out of range"
		Local source:TImageSource=page.sources[0]
		If source.locked Or Not source.pixmap Then Throw "Max2D atlas: page must have unlocked CPU pixels"
		Local entry:TJSONObject=New TJSONObject.Create()
		entry.Set("width",page.width); entry.Set("height",page.height)
		Local regions:TJSONArray=New TJSONArray.Create()
		For Local region:TImageRegion=EachIn source.regions
			Local rect:TJSONObject=AtlasRectJSON(region.x,region.y,region.width,region.height)
			rect.Set("padding",region.padding); regions.Append(rect)
		Next
		entry.Set("regions",regions); pages.Append(entry)
	Next
	root.Set("pages",pages)
	Local version:Int=1
	For Local name:String=EachIn atlas.images.Keys()
		Local image:TImage=atlas.GetImage(name)
		If Not image Then Throw "Max2D atlas: invalid named image"
		If image.sources.Length<>1 Or image.trims Then version=2
		For Local duration:Int=EachIn image.frameDuration
			If duration<>0 Then version=2
		Next
	Next
	root.Set("version",version)
	Local images:TJSONArray=New TJSONArray.Create()
	For Local name:String=EachIn atlas.images.Keys()
		Local image:TImage=atlas.GetImage(name)
		If Not name Or Not image Then Throw "Max2D atlas: invalid named image"
		If Not image.sources Or image.width<1 Or image.height<1 Or image.width>16384 Or image.height>16384 Or image.flags<>atlas.flags Then Throw "Max2D atlas: invalid image canvas or flags"
		Local entry:TJSONObject=New TJSONObject.Create()
		entry.Set("name",name); entry.Set("width",image.width); entry.Set("height",image.height)
		entry.Set("handleX",image.handle_x); entry.Set("handleY",image.handle_y)
		Local frames:TJSONArray=New TJSONArray.Create()
		For Local frame:Int=0 Until image.sources.Length
			Local pageIndex:Int=-1
			For Local i:Int=0 Until atlas.pages.Length
				If atlas.pages[i].sources[0]=image.sources[frame] Then pageIndex=i; Exit
			Next
			If pageIndex<0 Then Throw "Max2D atlas: image source is not an atlas page"
			Local w:Int=image.width,h:Int=image.height,ox:Int,oy:Int
			Local trim:TImageTrim=image.Trim(frame)
			If trim Then
				w=trim.width; h=trim.height; ox=trim.x; oy=trim.y
			End If
			Local page:TImage=atlas.pages[pageIndex]
			Local x:Int=image.sourceX[frame],y:Int=image.sourceY[frame]
			If x<0 Or y<0 Or Long(x)+Max(1,w)>page.width Or Long(y)+Max(1,h)>page.height Then Throw "Max2D atlas: image region outside page"
			If ox<0 Or oy<0 Or w<0 Or h<0 Or ((w=0)<>(h=0)) Or Long(ox)+w>image.width Or Long(oy)+h>image.height Then Throw "Max2D atlas: invalid trim rectangle"
			If image.frameDuration[frame]<0 Then Throw "Max2D atlas: invalid frame duration"
			If version=1 Then
				entry.Set("x",x); entry.Set("y",y); entry.Set("page",pageIndex)
			Else
				Local rect:TJSONObject=AtlasRectJSON(x,y,w,h)
				rect.Set("page",pageIndex); rect.Set("offsetX",ox); rect.Set("offsetY",oy)
				rect.Set("duration",image.frameDuration[frame]); frames.Append(rect)
			End If
		Next
		If version=2 Then entry.Set("frames",frames)
		images.Append(entry)
	Next
	root.Set("images",images)
	If Not CreateDir(directory,True) Then Throw "Max2D atlas: cannot create output directory"
	Local startedPages:Int
	Try
		For Local i:Int=0 Until atlas.pages.Length
			startedPages=i+1
			If Not SavePixmapPNG(atlas.pages[i].sources[0].pixmap,AtlasPagePath(directory,i)) Then Throw "Max2D atlas: cannot save PNG page"
		Next
		' Write the manifest last: it is the marker for a complete package.
		SaveText(root.SaveString(JSON_ENSURE_ASCII|JSON_SORT_KEYS,2),directory+"/atlas.json")
	Catch error:Object
		For Local i:Int=0 Until startedPages
			DeleteFile(AtlasPagePath(directory,i))
		Next
		DeleteFile(directory+"/atlas.json")
		DeleteDir(directory)
		Throw error
	End Try
	Return True
End Function

Rem
bbdoc: Loads an atlas package directory, preserving named views and editable borders.
param: Atlas package directory or supported filesystem URL.
param: Maximum total decoded page pixels allowed when loading the atlas.
about: Validates the manifest and page dimensions. The sum of page pixel counts is limited by maxPixels (64 million by default).
End Rem
Function LoadTextureAtlas:TTextureAtlas(directory:String,maxPixels:Long=64000000)
	If maxPixels<=0 Then Throw "Max2D atlas: pixel budget must be positive"
	Local error:TJSONError
	Local stream:TStream=ReadFile(directory+"/atlas.json")
	If Not stream Then Throw "Max2D atlas: cannot open manifest"
	Local document:TJSON
	Try
		document=TJSON.Load(stream,JSON_REJECT_DUPLICATES,error)
	Catch failure:Object
		stream.Close()
		Throw failure
	End Try
	stream.Close()
	If Not document Then Throw "Max2D atlas: invalid JSON manifest"
	Local root:TJSONObject=AtlasObject(document)
	Local version:Int=AtlasInteger(root,"version",1,2)
	If root.GetString("format")<>"max2d-atlas" Then Throw "Max2D atlas: unsupported format"
	Local size:Int=AtlasInteger(root,"pageSize",4,16384)
	Local padding:Int=AtlasInteger(root,"padding",1,size/2)
	Local flags:Int=AtlasInteger(root,"flags",0,MASKEDIMAGE|FILTEREDIMAGE|DYNAMICIMAGE)
	If flags & ~(MASKEDIMAGE|FILTEREDIMAGE|DYNAMICIMAGE) Then Throw "Max2D atlas: unsupported image flags"
	Local atlas:TTextureAtlas=TTextureAtlas.Create(size,flags,padding)
	Local pages:TJSONArray=AtlasArray(root,"pages")
	Local total:Long
	' Validate all declared dimensions before decoding PNG data.
	For Local i:Int=0 Until pages.Size()
		Local entry:TJSONObject=AtlasObject(pages.Get(i))
		Local w:Int=AtlasInteger(entry,"width",1,16384),h:Int=AtlasInteger(entry,"height",1,16384)
		total:+Long(w)*h
		If total>maxPixels Then Throw "Max2D atlas: pixel budget exceeded"
	Next
	For Local i:Int=0 Until pages.Size()
		Local entry:TJSONObject=AtlasObject(pages.Get(i))
		Local w:Int=AtlasInteger(entry,"width",1,16384),h:Int=AtlasInteger(entry,"height",1,16384)
		CheckAtlasPNGHeader(AtlasPagePath(directory,i),w,h)
		Local pixmap:TPixmap=LoadPixmapPNG(AtlasPagePath(directory,i))
		If Not pixmap Then Throw "Max2D atlas: cannot load PNG page "+i
		If pixmap.width<>w Or pixmap.height<>h Then Throw "Max2D atlas: PNG dimensions do not match manifest"
		Local page:TImage=TImage.FromPixmap(pixmap,flags)
		atlas.pages=atlas.pages[..atlas.pages.Length+1]; atlas.pages[i]=page
		Local regions:TJSONArray=AtlasArray(entry,"regions")
		For Local j:Int=0 Until regions.Size()
			Local rect:TJSONObject=AtlasObject(regions.Get(j))
			Local region:TImageRegion=New TImageRegion
			region.padding=AtlasInteger(rect,"padding",1,Min(w,h)/2)
			AtlasRect(rect,w,h,region.x,region.y,region.width,region.height,region.padding)
			For Local previous:TImageRegion=EachIn page.sources[0].regions
				If Long(region.x)-region.padding<Long(previous.x)+previous.width+previous.padding And Long(region.x)+region.width+region.padding>Long(previous.x)-previous.padding And Long(region.y)-region.padding<Long(previous.y)+previous.height+previous.padding And Long(region.y)+region.height+region.padding>Long(previous.y)-previous.padding Then Throw "Max2D atlas: overlapping padded regions"
			Next
			page.sources[0].regions.AddLast(region)
		Next
		' Recreate borders from the interior pixels, including packages edited externally.
		For Local region:TImageRegion=EachIn page.sources[0].regions
			region.Extrude(page.sources[0].pixmap)
		Next
	Next
	Local images:TJSONArray=AtlasArray(root,"images")
	For Local i:Int=0 Until images.Size()
		Local entry:TJSONObject=AtlasObject(images.Get(i))
		Local name:String=entry.GetString("name")
		If Not name Or atlas.images.Contains(name) Then Throw "Max2D atlas: missing or duplicate image name"
		Local image:TImage
		If version=1 Then
			Local pageIndex:Int=AtlasInteger(entry,"page",0,atlas.pages.Length-1)
			Local page:TImage=atlas.pages[pageIndex]
			Local x:Int,y:Int,w:Int,h:Int
			AtlasRect(entry,page.width,page.height,x,y,w,h)
			image=TImage.View(page,x,y,w,h)
		Else
			Local width:Int=AtlasInteger(entry,"width",1,16384),height:Int=AtlasInteger(entry,"height",1,16384)
			Local frames:TJSONArray=AtlasArray(entry,"frames")
			If frames.Size()=0 Then Throw "Max2D atlas: image has no frames"
			Local views:TImage[]=New TImage[frames.Size()]
			Local durations:Int[]=New Int[frames.Size()]
			For Local j:Int=0 Until frames.Size()
				Local rect:TJSONObject=AtlasObject(frames.Get(j))
				Local pageIndex:Int=AtlasInteger(rect,"page",0,atlas.pages.Length-1)
				Local page:TImage=atlas.pages[pageIndex]
				Local x:Int=AtlasInteger(rect,"x",0,page.width-1),y:Int=AtlasInteger(rect,"y",0,page.height-1)
				Local w:Int=AtlasInteger(rect,"width",0,width),h:Int=AtlasInteger(rect,"height",0,height)
				Local ox:Int=AtlasInteger(rect,"offsetX",0,width),oy:Int=AtlasInteger(rect,"offsetY",0,height)
				If ((w=0)<>(h=0)) Or Long(ox)+w>width Or Long(oy)+h>height Then Throw "Max2D atlas: invalid trim rectangle"
				If Long(x)+Max(1,w)>page.width Or Long(y)+Max(1,h)>page.height Then Throw "Max2D atlas: frame outside page"
				Local view:TImage=TImage.View(page,x,y,Max(1,w),Max(1,h))
				view.width=width; view.height=height
				If ox Or oy Or w<>width Or h<>height Then view.SetTrim(0,ox,oy,w,h)
				views[j]=view; durations[j]=AtlasInteger(rect,"duration")
			Next
			image=TImage.Animation(views,durations)
		End If
		image.handle_x=AtlasNumber(entry,"handleX"); image.handle_y=AtlasNumber(entry,"handleY")
		atlas.images.Insert(name,image)
	Next
	' Existing pages stay fixed; subsequent runtime insertion starts a new page.
	Return atlas
End Function
