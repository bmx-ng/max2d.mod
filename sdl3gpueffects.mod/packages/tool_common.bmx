' Shared validation and generation for the build-time tools.
Include "templates.bmx"

Function Identifier:Int(value:String)
	If Not value.Length Then Return False
	For Local i:Int = 0 Until value.Length
		Local c:Int = value[i]
		If Not ((c>=65 And c<=90) Or (c>=97 And c<=122) Or c=95 Or (i>0 And c>=48 And c<=57)) Then Return False
	Next
	Return True
End Function

Function Fields(value:TJSONObject, names:String[])
	If Not value Then Throw "Expected an object"
	If value.Size()<>names.Length Then Throw "Unexpected manifest fields"
	For Local name:String = EachIn names
		If Not value.Get(name) Then Throw "Missing field: "+name
	Next
End Function

Function TextValue:String(value:TJSON)
	If Not TJSONString(value) Then Throw "Expected a string"
	Return TJSONString(value).Value()
End Function

Function ReadManifest:TJSONObject(path:String)
	Local error:TJSONError
	Local root:TJSONObject = TJSONObject(TJSON.Load(LoadText(path),0,error))
	If Not root Then Throw "Expected a package manifest object"
	If root.Get("colourBodies") Then
		Fields(root,["abi","name","factory","parameters","bodies","colourBodies"])
	Else
		Fields(root,["abi","name","factory","parameters","bodies"])
	End If
	If Not TJSONInteger(root.Get("abi")) Then Throw "Expected integer ABI version"
	Local abi:Long=root.GetInteger("abi")
	If abi<>1 And abi<>2 And abi<>3 And abi<>4 Then Throw "Expected package ABI 1, 2, 3 or 4"
	If root.Get("colourBodies") And abi<2 Then Throw "colourBodies requires coordinate ABI 2 or 3"
	If Not Identifier(TextValue(root.Get("name"))) Or Not Identifier(TextValue(root.Get("factory"))) Then Throw "Name and factory must be identifiers"
	Local params:TJSONArray = TJSONArray(root.Get("parameters"))
	If Not params Then Throw "Expected parameters array"
	Local limit:Int=8
	If abi=2 Then limit=6
	If abi>=3 Then limit=3
	If params.Size()<1 Or params.Size()>limit Then Throw "Too many or too few parameters for package ABI"
	Local names:String[] = New String[params.Size()]
	For Local i:Int = 0 Until params.Size()
		Local p:TJSONObject = TJSONObject(params.Get(i))
		Fields(p,["name","type"])
		Local name:String = TextValue(p.Get("name")), kind:String = TextValue(p.Get("type"))
		If Not Identifier(name) Then Throw "Invalid parameter name"
		For Local reserved:String = EachIn ["c","p","image","mode","input","result"]
			If name=reserved Then Throw "Reserved parameter name: "+name
		Next
		If abi>=2 And name="uv" Then Throw "Reserved coordinate parameter name: uv"
		If abi>=3 And (name="m" Or name="secondImage" Or name="localUV") Then Throw "Reserved two-texture parameter name"
		If abi=4 And name="mapUV" Then Throw "Reserved transformed-map parameter name"
		For Local j:Int = 0 Until i
			If name=names[j] Then Throw "Duplicate parameter name: "+name
		Next
		names[i]=name
		If kind<>"float" And kind<>"float4" Then Throw "Only float and float4 are supported"
	Next
	ValidateBodies(TJSONObject(root.Get("bodies")))
	If root.Get("colourBodies") Then ValidateBodies(TJSONObject(root.Get("colourBodies")))
	Return root
End Function

Function ValidateBodies(bodies:TJSONObject)
	Fields(bodies,["metal","glsl","hlsl"])
	For Local lang:String = EachIn ["metal","glsl","hlsl"]
		Local body:String = TextValue(bodies.Get(lang)), depth:Int
		If body.Length>65536 Or body.Contains("#") Then Throw "Invalid function body"
		For Local i:Int = 0 Until body.Length
			If body[i]=123 Then depth:+1
			If body[i]=125 Then depth:-1
			If depth<0 Then Throw "Body escapes its function"
		Next
		If depth Then Throw "Unbalanced function body"
	Next
End Function

Function WriteTextFile(path:String, value:String)
	If Not SaveText(value,path) Then Throw "Cannot write: "+path
End Function

Function GeneratePackage(manifest:String, output:String, prefix:String="")
	Local root:TJSONObject = ReadManifest(manifest)
	For Local i:Int = 0 Until prefix.Length
		Local c:Int=prefix[i]
		If Not ((c>=65 And c<=90) Or (c>=97 And c<=122) Or (c>=48 And c<=57) Or c=95 Or c=46 Or c=47 Or c=45) Then Throw "Invalid asset prefix"
	Next
	For Local part:String = EachIn prefix.Split("/")
		If part=".." Then Throw "Invalid asset prefix"
	Next
	If Not CreateDir(output,True) Then Throw "Cannot create output directory"
	Local name:String=root.GetString("name"), factory:String=root.GetString("factory")
	Local params:TJSONArray=TJSONArray(root.Get("parameters"))
	Local bodies:TJSONObject=TJSONObject(root.Get("bodies"))
	Local colourBodies:TJSONObject=TJSONObject(root.Get("colourBodies"))
	Local abi:Int=Int(root.GetInteger("abi")), count:Int=params.Size()
	If abi=2 Then count:+2
	If abi=3 Then count:+5
	If abi=4 Then count:+7
	For Local lang:String = EachIn ["metal","glsl","hlsl"]
		Local vec:String="float4", head:String, tail:String, ext:String=lang
		Select lang
			Case "metal"
				head=HEAD_metal; tail=TAIL_metal
			Case "glsl"
				head=HEAD_glsl; tail=TAIL_glsl; vec="vec4"; ext="frag"
			Case "hlsl"
				head=HEAD_hlsl; tail=TAIL_hlsl
		End Select
		Local argument:String=vec+" c", resultType:String=vec
		If abi>=2 Then
			resultType="float2"
			If lang="glsl" Then resultType="vec2"
			argument=resultType+" uv"
		End If
		If abi>=3 Then argument:+", "+vec+" m"
		Local helper:String=resultType+" userEffect("+argument
		If lang="metal" Then helper:+", constant float4 *p"
		helper:+") {~n"
		Local declarations:String
		For Local i:Int=0 Until params.Size()
			Local p:TJSONObject=TJSONObject(params.Get(i))
			Local kind:String=vec, suffix:String
			If p.GetString("type")="float" Then kind="float"; suffix=".x"
			declarations:+"    "+kind+" "+p.GetString("name")+" = p["+i+"]"+suffix+";~n"
		Next
		helper:+declarations+bodies.GetString(lang)+"~n}~n"
		If abi>=2 Then
			Local samplerArgs:String, sample:String, callArgs:String, mixName:String="mix", originalSample:String, originalCall:String
			Select lang
				Case "metal"
					samplerArgs=", texture2d<float> image, sampler sampleState, constant float4 *p"
					sample="image.read(uint2(q),0)"; callArgs=",image,sampleState,p"
					originalSample="float4 c=image.sample(sampleState,input.uv);"
					originalCall="c=userEffect(c,p);~n"
				Case "glsl"
					sample="texelFetch(image,ivec2(q),0)"
					originalSample="vec4 c=texture(image,texcoord);"
					originalCall="c=userEffect(c);~n"
				Case "hlsl"
					sample="image.Load(int3(q,0))"; mixName="lerp"
					originalSample="float4 c=image.Sample(sampleState,input.uv);"
					originalCall="c=userEffect(c);~n"
			End Select
			Local sampling:String=UV_SAMPLE.Replace("@VEC4@",vec).Replace("@VEC2@",resultType).Replace("@SAMPLER_ARGS@",samplerArgs)
			sampling=sampling.Replace("@SAMPLE@",sample).Replace("@MIX@",mixName).Replace("@SLOTS@",String(params.Size())).Replace("@INFO@",String(params.Size()+1))
			Local inputUV:String="input.uv", parameterArgs:String
			If lang="glsl" Then inputUV="texcoord"
			If lang="metal" Then parameterArgs=",p"
			Local uvCall:String="userEffect(("+inputUV+"-p["+params.Size()+"].xy)/p["+params.Size()+"].zw"+parameterArgs+")"
			tail=tail.Replace(originalSample,vec+" c=sampleRegion("+uvCall+callArgs+");").Replace(originalCall,"")
			If colourBodies Then
				helper:+vec+" userColour("+vec+" c"
				If abi>=3 Then helper:+", "+vec+" m"
				If lang="metal" Then helper:+", constant float4 *p"
				helper:+") {~n"+declarations+colourBodies.GetString(lang)+"~n}~n"
				' Run after source alpha interpretation and drawing tint, before
				' alpha clamp, mask discard and output premultiplication.
				tail=tail.Replace("c.a=clamp(c.a,0.0,1.0);","c=userColour(c"+parameterArgs+");~nc.a=clamp(c.a,0.0,1.0);")
			End If
			If abi>=3 Then
				Local mapSampling:String=UV_SAMPLE.Replace("@VEC4@",vec).Replace("@VEC2@",resultType).Replace("@SAMPLER_ARGS@",samplerArgs)
				mapSampling=mapSampling.Replace("@SAMPLE@",sample).Replace("@MIX@",mixName).Replace("@SLOTS@",String(params.Size()+2)).Replace("@INFO@",String(params.Size()+3))
				mapSampling=mapSampling.Replace("sampleRegion","sampleMap").Replace("image","secondImage").Replace("sampleState","secondState")
				Local mapArgs:String=callArgs.Replace("image","secondImage").Replace("sampleState","secondState")
				Local prefix:String=resultType+" localUV=("+inputUV+"-p["+params.Size()+"].xy)/p["+params.Size()+"].zw;~n"
				Local mapUV:String="localUV", modeSlot:Int=params.Size()+4
				If abi=4 Then
					mapUV="mapUV"; modeSlot:+2
					prefix:+resultType+" mapUV="+resultType+"(dot(p["+(params.Size()+4)+"].xy,localUV)+p["+(params.Size()+4)+"].z,dot(p["+(params.Size()+5)+"].xy,localUV)+p["+(params.Size()+5)+"].z);~n"
				End If
				prefix:+vec+" m=sampleMap("+mapUV+mapArgs+");~n"
				prefix:+"if(p["+modeSlot+"].x!=0) m="+vec+"(1,1,1,m.r);~n"
				prefix:+"if(p["+modeSlot+"].y!=0) m.rgb=m.a>0?m.rgb/m.a:"+vec.Replace("4","3")+"(0,0,0);~n"
				tail=tail.Replace(vec+" c=sampleRegion("+uvCall, prefix+vec+" c=sampleRegion(userEffect(localUV,m"+parameterArgs+")")
				tail=tail.Replace("c=userColour(c"+parameterArgs+")","c=userColour(c,m"+parameterArgs+")")
				Select lang
					Case "metal"
						tail=tail.Replace("constant float4 &mode [[buffer(0)]]","texture2d<float> secondImage [[texture(1)]], sampler secondState [[sampler(1)]], constant float4 &mode [[buffer(0)]]")
					Case "glsl"
						head:+"layout(set=2,binding=1) uniform sampler2D secondImage;~n"
					Case "hlsl"
						head:+"Texture2D secondImage : register(t1, space2);~nSamplerState secondState : register(s1, space2);~n"
				End Select
				helper:+mapSampling
			End If
			helper:+sampling
		End If
		WriteTextFile(output+"/"+name+"."+ext,head.Replace("@COUNT@",String(count))+helper+tail)
	Next
	Local names:String[], kinds:String[], arguments:String[]
	names=New String[params.Size()]; kinds=New String[params.Size()]; arguments=New String[3]
	For Local i:Int=0 Until params.Size()
		Local p:TJSONObject=TJSONObject(params.Get(i))
		names[i]="~q"+p.GetString("name")+"~q"
		kinds[i]="MAX2D_PARAMETER_"+p.GetString("type").ToUpper()
	Next
	For Local i:Int=0 Until 3
		arguments[i]=factory+"Data("+factory+"Asset("+i+"), "+factory+"Size("+i+"))"
	Next
	Local source:String=BMX_WRAPPER.Replace("@PREFIX@",prefix).Replace("@NAME@",name).Replace("@FACTORY@",factory)
	source=source.Replace("@NAMES@",", ".Join(names)).Replace("@KINDS@",", ".Join(kinds)).Replace("@ARGUMENTS@",", ".Join(arguments))
	Local abiArgument:String
	If abi>=2 Then abiArgument=", "+abi
	source=source.Replace("@ABI_ARGUMENT@",abiArgument)
	WriteTextFile(output+"/"+name+".bmx",source)
End Function

Function EmbedPackage(manifest:String, output:String)
	Local root:TJSONObject=ReadManifest(manifest)
	Local name:String=root.GetString("name"), factory:String=root.GetString("factory")
	Local text:String="/* Generated shader assets. */~n"
	Local sizes:String[3], extensions:String[]=["metal","frag.spv","dxbc"]
	For Local i:Int=0 Until 3
		Local blob:TBank=LoadBank(output+"/"+name+"."+extensions[i])
		If Not blob Then Throw "Cannot read shader asset: "+extensions[i]
		If blob.Size()<1 Or blob.Size()>4194304 Then Throw "Shader assets must contain 1 to 4194304 bytes"
		sizes[i]=String(blob.Size())
		text:+"static const unsigned char asset"+i+"[] = {~n"
		For Local j:Int=0 Until Int(blob.Size())
			text:+blob.PeekByte(j)+","
			If (j+1) Mod 24=0 And j+1<Int(blob.Size()) Then text:+"~n"
		Next
		text:+"~n};~n"
	Next
	text:+C_ASSET_FOOTER.Replace("@SIZES@",",".Join(sizes)).Replace("@FACTORY@",factory)
	WriteTextFile(output+"/"+name+"_assets.c",text)
End Function
