SuperStrict
Framework Max2D.AtlasIO
Import Max2D.Atlas
Import BRL.StandardIO

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Function SamePixels(a:TPixmap,b:TPixmap)
	Check(a.width=b.width And a.height=b.height,"Logical pixel dimensions")
	For Local y:Int=0 Until a.height
		For Local x:Int=0 Until a.width
			Check(a.ReadPixel(x,y)=b.ReadPixel(x,y),"Pixel mismatch at "+x+","+y)
		Next
	Next
End Function
Function RejectManifest(root:TJSONObject,directory:String)
	SaveText(root.SaveString(0,2),directory+"/atlas.json")
	Local rejected:Int
	Try
		LoadTextureAtlas(directory)
	Catch error:Object
		rejected=True
	End Try
	Check(rejected,"Malformed animation metadata rejected")
End Function

Try
	If AppArgs.Length<>2 Then Throw "Supply a new package directory"
	Local frames:TPixmap[]=New TPixmap[3]
	For Local i:Int=0 Until 3
		frames[i]=CreatePixmap(32,24,PF_RGBA8888); frames[i].ClearPixels(0)
		If i=2 Then Continue
		For Local y:Int=6+i Until 12+i
			For Local x:Int=5+i*8 Until 13+i*8
				frames[i].WritePixel(x,y,$ffff8000)
			Next
		Next
	Next
	Local builder:TAtlasBuilder=New TAtlasBuilder
	builder.pageSize=12; builder.flags=DYNAMICIMAGE; builder.trimTransparent=True
	builder.AddAnimation("walk",frames,[100,200,50])
	Local atlas:TTextureAtlas=builder.Build()
	Local image:TImage=atlas.GetImage("walk")
	Check(atlas.PageCount()>=2,"Frames may span pages")
	Check(image.width=32 And image.height=24,"Original canvas retained")
	Check(image.Trim(0).x=5 And image.Trim(1).x=13,"Independent trim offsets")
	Check(image.Trim(2).width=0,"Fully transparent frame")
	Check(image.AnimationDuration()=350,"Total duration")
	Check(image.FrameAtTime(-1)=0 And image.FrameAtTime(99)=0 And image.FrameAtTime(100)=1,"Time boundaries")
	Check(image.FrameAtTime(300)=2 And image.FrameAtTime(350)=0 And image.FrameAtTime(350,False)=2,"Loop and clamp")
	Check(image.FrameAtTime(350000000000:Long+100)=1,"Long elapsed times")
	For Local i:Int=0 Until 3
		SamePixels(image.Lock(i,True,False),frames[i]); image.Unlock(i)
	Next
	Local view:TImage=TImage.View(image,3,4,14,12,0)
	SamePixels(view.Lock(0,True,False),frames[0].Window(3,4,14,12)); view.Unlock()
	Local nested:TImage=TImage.View(view,1,1,8,8)
	SamePixels(nested.Lock(0,True,False),frames[0].Window(4,5,8,8)); nested.Unlock()
	Local empty:TImage=TImage.View(image,0,0,3,3)
	Check(empty.Trim().width=0,"Empty logical subview")
	Local original:TImage=TImage.FromPixmap(frames[0])
	SetImageHandle(image,16,12); SetImageHandle(original,16,12)
	Check(Not TCollisionShape.Image(image,0,0,2).valid,"Empty frame has no collision geometry")
	For Local i:Int=0 Until 12
		Local state:TMax2DState=New TMax2DState
		state.rotation=i*30; state.scaleX=1.5; state.scaleY=-2; state.Transform()
		Local a:TCollisionShape=TCollisionShape.Image(image,20,20,0,state)
		Local b:TCollisionShape=TCollisionShape.Image(original,20,20,0,state)
		For Local y:Int=-60 Until 80
			For Local x:Int=-60 Until 80
				Check(a.Solid(x+0.5,y+0.5)=b.Solid(x+0.5,y+0.5),"Trimmed collision transform")
			Next
		Next
	Next
	image.handle_x=16; image.handle_y=12
	SaveTextureAtlas(atlas,AppArgs[1])
	Local loaded:TTextureAtlas=LoadTextureAtlas(AppArgs[1])
	Local animation:TImage=loaded.GetImage("walk")
	Check(animation.handle_x=16 And animation.handle_y=12,"Animation handle roundtrip")
	Check(animation.AnimationDuration()=350 And animation.sources.Length=3,"Timing and frame count roundtrip")
	For Local i:Int=0 Until 3
		SamePixels(animation.Lock(i,True,False),frames[i]); animation.Unlock(i)
	Next
	Local pixels:TPixmap=animation.Lock(1)
	pixels.WritePixel(14,8,$ff00ff00); animation.Unlock(1)
	Check(animation.sources[1].pixmap.ReadPixel(animation.sourceX[1]+1,animation.sourceY[1]+1)=$ff00ff00,"Write within trimmed footprint")
	Local version:Long=animation.sources[1].version
	pixels=animation.Lock(1); pixels.WritePixel(0,0,$ffffffff)
	Local rejected:Int
	Try
		animation.Unlock(1)
	Catch error:Object
		rejected=True
	End Try
	Check(rejected And Not animation.sources[1].locked And animation.sources[1].version=version,"Failed write is atomic and releases lock")
	loaded.UpdatePixmap("walk",frames[1],1)
	SamePixels(animation.Lock(1,True,False),frames[1]); animation.Unlock(1)
	Local filtered:TTextureAtlas=TTextureAtlas.Create(32,FILTEREDIMAGE)
	Local soft:TImage=filtered.AddPixmap(frames[0],"soft",True)
	Check(soft.Trim().x=4 And soft.Trim().y=5 And soft.Trim().width=10 And soft.Trim().height=8,"Transparent filtering fringe")
	Local untrimmed:TImage=filtered.AddPixmap(frames[0],"normal")
	Check(Not untrimmed.trims,"Trimming defaults off")
	Local error:TJSONError
	Local manifest:String=LoadText(AppArgs[1]+"/atlas.json")
	Local root:TJSONObject=TJSONObject(TJSON.Load(manifest,0,error))
	Check(root.GetInteger("version")=2,"Extended package version")
	Local entry:TJSONObject=TJSONObject(TJSONArray(root.Get("images")).Get(0))
	Local rect:TJSONObject=TJSONObject(TJSONArray(entry.Get("frames")).Get(0))
	rect.Set("offsetX",32); RejectManifest(root,AppArgs[1]); rect.Set("offsetX",5)
	rect.Set("duration",-1); RejectManifest(root,AppArgs[1]); rect.Set("duration",100)
	rect.Set("width",0); RejectManifest(root,AppArgs[1]); rect.Set("width",8)
	rect.Set("page",999); RejectManifest(root,AppArgs[1]); rect.Set("page",0)
	SaveText(manifest,AppArgs[1]+"/atlas.json")
	SaveTextureAtlas(loaded,AppArgs[1]+"-resaved")
	Check(LoadTextureAtlas(AppArgs[1]+"-resaved").GetImage("walk").FrameAtTime(310)=2,"Extended package can be saved again")
	Print "Max2D trimmed atlas and animation tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
