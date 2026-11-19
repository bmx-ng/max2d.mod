SuperStrict
Framework BRL.StandardIO
Import Text.JSON
Import BRL.FileSystem
Import BRL.BankStream
Include "../sdl3gpueffects.mod/packages/tool_common.bmx"

Function Check(ok:Int, message:String)
	If Not ok Then Throw message
End Function

ChangeDir(LaunchDir)
Try
	If AppArgs.Length<>3 Then Throw "Usage: shader_package_generator repository-root empty-scratch-directory"
	Local root:String=RealPath(AppArgs[1]), scratch:String=RealPath(AppArgs[2])
	If FileType(scratch) Then Throw "Scratch directory must not already exist"
	CreateDir(scratch,True)
	For Local directory:String=EachIn [root+"/sdl3gpueffects.mod/packages/colormatrix",root+"/tests/data/shaderpackage",root+"/tests/data/coordinates",root+"/sdl3gpueffects.mod/packages/distortion",root+"/sdl3gpueffects.mod/packages/graded_distortion",root+"/tests/data/combined"]
		Local manifest:String=directory+"/manifest.json"
		Local parsed:TJSONObject=ReadManifest(manifest), name:String=parsed.GetString("name")
		Local output:String=scratch+"/"+name
		GeneratePackage(manifest,output)
		For Local ext:String=EachIn ["metal","frag","hlsl","bmx"]
			Check(LoadText(output+"/"+name+"."+ext)=LoadText(directory+"/"+name+"."+ext),"Reproducible "+name+"."+ext)
		Next
		For Local ext:String=EachIn ["frag.spv","dxbc"]
			Check(CopyFile(directory+"/"+name+"."+ext,output+"/"+name+"."+ext),"Copy compiled fixture")
		Next
		EmbedPackage(manifest,output)
		Check(LoadText(output+"/"+name+"_assets.c")=LoadText(directory+"/"+name+"_assets.c"),"Reproducible embedded assets")
	Next
	Local manifest:String=root+"/sdl3gpueffects.mod/packages/colormatrix/manifest.json"
	For Local invalid:Int=0 Until 17
		Local data:TJSONObject=ReadManifest(manifest)
		Local params:TJSONArray=TJSONArray(data.Get("parameters"))
		Local first:TJSONObject=TJSONObject(params.Get(0)), bodies:TJSONObject=TJSONObject(data.Get("bodies"))
		Select invalid
			Case 0
				data.Set("abi",New TJSONInteger.Create(99))
			Case 1
				data.Set("parameters",New TJSONArray.Create())
			Case 2
				TJSONObject(params.Get(1)).Set("name",New TJSONString.Create("row0"))
			Case 3
				first.Set("type",New TJSONString.Create("texture"))
			Case 4
				first.Set("name",New TJSONString.Create("c"))
			Case 5
				bodies.Set("glsl",New TJSONString.Create("} void main() {"))
			Case 6
				bodies.Set("metal",New TJSONString.Create("#include ~qother.h~q"))
			Case 7
				data.Set("name",New TJSONString.Create("../escape"))
			Case 8
				data.Set("extra",New TJSONString.Create("unexpected"))
			Case 9
				bodies.Set("glsl",New TJSONInteger.Create(1))
			Case 10
				data.Set("abi",New TJSONInteger.Create(2))
				For Local i:Int=5 Until 7
					Local extra:TJSONObject=New TJSONObject.Create()
					extra.Set("name",New TJSONString.Create("extra"+i)); extra.Set("type",New TJSONString.Create("float"))
					params.Append(extra)
				Next
			Case 11
				data.Set("abi",New TJSONInteger.Create(2))
				first.Set("name",New TJSONString.Create("uv"))
			Case 12
				data.Set("abi",New TJSONInteger.Create(4294967297:Long))
			Case 13
				data.Set("colourBodies",bodies)
			Case 14
				data.Set("abi",New TJSONInteger.Create(2))
				data.Set("colourBodies",New TJSONString.Create("invalid"))
			Case 15
				data.Set("abi",New TJSONInteger.Create(2))
				data.Set("colourBodies",New TJSONObject.Create())
			Case 16
				data.Set("abi",New TJSONInteger.Create(2))
				Local colour:TJSONObject=New TJSONObject.Create()
				colour.Set("metal",New TJSONString.Create("return c;"))
				colour.Set("glsl",New TJSONString.Create("#error invalid"))
				colour.Set("hlsl",New TJSONString.Create("return c;"))
				data.Set("colourBodies",colour)
		End Select
		Local path:String=scratch+"/invalid.json", rejected:Int
		SaveText(data.SaveString(),path)
		Try
			GeneratePackage(path,scratch+"/invalid")
		Catch error:Object
			rejected=True
		End Try
		Check(rejected,"Reject invalid manifest "+invalid)
	Next
	Local rejected:Int
	Try
		GeneratePackage(manifest,scratch+"/invalid","../")
	Catch error:Object
		rejected=True
	End Try
	Check(rejected,"Reject invalid prefix")
	Print "shader_package_generator passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
