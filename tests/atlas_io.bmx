SuperStrict
Framework Max2D.AtlasIO
Import Max2D.Atlas
Import BRL.StandardIO

Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Function RejectLoad(directory:String,message:String,budget:Long=64000000)
 Local rejected:Int
 Try
  LoadTextureAtlas(directory,budget)
 Catch error:Object
  rejected=True
 End Try
 Check(rejected,message)
End Function
Function WriteManifest(root:TJSONObject,directory:String)
 SaveText(root.SaveString(JSON_ENSURE_ASCII,2),directory+"/atlas.json")
End Function

If AppArgs.Length<>2 Then Throw "Supply an empty scratch directory"
Local directory:String=AppArgs[1]+"/package"
Local builder:TAtlasBuilder=New TAtlasBuilder
builder.pageSize=16; builder.padding=2; builder.flags=FILTEREDIMAGE|DYNAMICIMAGE
Local p:TPixmap=CreatePixmap(8,8,PF_RGBA8888)
p.ClearPixels($80ff0000); builder.Add(p,"hero / Ω ~qtest~q")
p.ClearPixels($ff00ff00); builder.Add(p,"green")
p.ClearPixels($ff0000ff); builder.Add(p,"blue")
Local original:TTextureAtlas=builder.Build()
original.GetImage("green").handle_x=2.5
original.GetImage("green").handle_y=-3
Check(original.PageCount()=3,"Fixture requires multiple pages")
Check(SaveTextureAtlas(original,directory),"Save package")
Local loaded:TTextureAtlas=LoadTextureAtlas(directory)
Check(loaded.PageCount()=3,"Page count round trip")
For Local i:Int=0 Until original.PageCount()
 Local a:TPixmap=original.Page(i).sources[0].pixmap,b:TPixmap=loaded.Page(i).sources[0].pixmap
 Check(a.width=b.width And a.height=b.height,"Page dimensions")
 For Local y:Int=0 Until a.height
  For Local x:Int=0 Until a.width
   Check(a.ReadPixel(x,y)=b.ReadPixel(x,y),"Exact RGBA PNG round trip")
  Next
 Next
Next
Check(loaded.GetImage("hero / Ω ~qtest~q")<>Null,"Unicode and escaped name round trip")
Local green:TImage=loaded.GetImage("green")
Check(green.handle_x=2.5 And green.handle_y=-3,"Fractional and negative handles")
Local pixels:TPixmap=LockImage(green)
pixels.WritePixel(0,0,$ffffffff)
UnlockImage(green)
Check(green.sources[0].pixmap.ReadPixel(green.sourceX[0]-2,green.sourceY[0]-2)=$ffffffff,"Loaded dynamic border metadata")
Local source:TImageSource=green.sources[0]
loaded.AddPixmap(p,"new")
Check(loaded.PageCount()=4 And green.sources[0]=source,"Appending does not relocate loaded regions")
SaveTextureAtlas(loaded,AppArgs[1]+"/second")
Check(LoadTextureAtlas(AppArgs[1]+"/second").GetImage("new")<>Null,"Save a loaded and extended atlas")
Local rejected:Int
Try
 SaveTextureAtlas(original,directory)
Catch error:Object
 rejected=True
End Try
Check(rejected,"Existing output must not be overwritten")
RejectLoad(directory,"Allocation budget enforced",1)
Local manifest:String=LoadText(directory+"/atlas.json")
Local error:TJSONError
Local root:TJSONObject=TJSONObject(TJSON.Load(manifest,0,error))
SaveText(root.SaveString(0,2),directory+"/atlas.json",ETextStreamFormat.UTF8,False)
Check(LoadTextureAtlas(directory).GetImage("hero / Ω ~qtest~q")<>Null,"Unescaped UTF-8 manifest names")
root.Set("version",99); WriteManifest(root,directory)
RejectLoad(directory,"Unknown version rejected")
root.Set("version",1)
Local images:TJSONArray=TJSONArray(root.Get("images"))
Local image:TJSONObject=TJSONObject(images.Get(0))
Local pageIndex:Long=image.GetInteger("page")
image.Set("page",999); WriteManifest(root,directory)
RejectLoad(directory,"Invalid page rejected")
image.Set("page",pageIndex)
Local x:Long=image.GetInteger("x")
image.Set("x",999); WriteManifest(root,directory)
RejectLoad(directory,"Out-of-bounds image rejected")
image.Set("x",x)
images.Append(images.Get(0)); WriteManifest(root,directory)
RejectLoad(directory,"Duplicate names rejected")
images.Remove(images.Size()-1)
Local pages:TJSONArray=TJSONArray(root.Get("pages"))
Local regions:TJSONArray=TJSONArray(TJSONObject(pages.Get(0)).Get("regions"))
regions.Append(regions.Get(0)); WriteManifest(root,directory)
RejectLoad(directory,"Overlapping padding rejected")
regions.Remove(regions.Size()-1)
WriteManifest(root,directory)
Local small:TPixmap=CreatePixmap(1,1,PF_RGBA8888)
small.ClearPixels(0)
SavePixmapPNG(small,directory+"/page-0.png")
RejectLoad(directory,"PNG header must match declared dimensions")
SavePixmapPNG(original.Page(0).sources[0].pixmap,directory+"/page-0.png")
SaveText("{broken",directory+"/atlas.json")
RejectLoad(directory,"Malformed JSON rejected")
SaveText(manifest,directory+"/atlas.json")
Check(LoadTextureAtlas(directory)<>Null,"Restored package remains valid")
Local empty:TTextureAtlas=TTextureAtlas.Create()
SaveTextureAtlas(empty,AppArgs[1]+"/empty")
Check(LoadTextureAtlas(AppArgs[1]+"/empty").PageCount()=0,"Empty atlas round trip")
Print "Max2D atlas IO tests passed"
