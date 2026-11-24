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
	If root.Get("secondBodies") Then
		Fields(root,["abi","name","factory","parameters","bodies","colourBodies","colourUV","thirdBodies","secondBodies"])
	Else If root.Get("thirdBodies") Then
		Fields(root,["abi","name","factory","parameters","bodies","colourBodies","colourUV","thirdBodies"])
	Else If root.Get("colourBodies") Then
		If root.Get("colourUV") Then
			Fields(root,["abi","name","factory","parameters","bodies","colourBodies","colourUV"])
		Else
			Fields(root,["abi","name","factory","parameters","bodies","colourBodies"])
		End If
	Else
		Fields(root,["abi","name","factory","parameters","bodies"])
	End If
	If Not TJSONInteger(root.Get("abi")) Then Throw "Expected integer ABI version"
	Local abi:Long=root.GetInteger("abi")
	If abi<>1 And abi<>2 And abi<>3 And abi<>4 And abi<>5 Then Throw "Expected package ABI 1, 2, 3, 4 or 5"
	If abi=5 And Not root.Get("thirdBodies") Then Throw "ABI 5 requires thirdBodies"
	If root.Get("secondBodies") Then
		If abi<>5 Then Throw "secondBodies requires ABI 5"
		ValidateBodies(TJSONObject(root.Get("secondBodies")))
	End If
	If root.Get("thirdBodies") Then
		If abi<>5 Then Throw "thirdBodies requires ABI 5"
		ValidateBodies(TJSONObject(root.Get("thirdBodies")))
	End If
	If root.Get("colourUV") Then
		If Not TJSONBool(root.Get("colourUV")) Then Throw "colourUV must be boolean"
	End If
	If root.Get("colourBodies") And abi<2 Then Throw "colourBodies requires coordinate ABI 2 or 3"
	If Not Identifier(TextValue(root.Get("name"))) Or Not Identifier(TextValue(root.Get("factory"))) Then Throw "Name and factory must be identifiers"
	Local params:TJSONArray = TJSONArray(root.Get("parameters"))
	If Not params Then Throw "Expected parameters array"
	Local limit:Int=8
	If abi=2 Then limit=6
	If abi=3 Then limit=5
	If abi=4 Then limit=3
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
		If abi=5 And (name="t" Or name="thirdImage" Or name="thirdUV") Then Throw "Reserved third-texture parameter name"
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
	If abi=5 Then count:+8
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
		If abi=5 Then argument:+", "+vec+" t"
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
			Local colourCoordinates:String
			If colourBodies Then
				helper:+vec+" userColour("+vec+" c"
				If root.GetBool("colourUV") Then
					helper:+", "+resultType+" uv"
					colourCoordinates=",("+inputUV+"-p["+params.Size()+"].xy)/p["+params.Size()+"].zw"
				End If
				If abi>=3 Then helper:+", "+vec+" m"
				If abi=5 Then helper:+", "+vec+" t"
				If lang="metal" Then helper:+", constant float4 *p"
				helper:+") {~n"+declarations+colourBodies.GetString(lang)+"~n}~n"
				' Run after source alpha interpretation and drawing tint, before
				' alpha clamp, mask discard and output premultiplication.
				tail=tail.Replace("c.a=clamp(c.a,0.0,1.0);","c=userColour(c"+colourCoordinates+parameterArgs+");~nc.a=clamp(c.a,0.0,1.0);")
			End If
			If abi>=3 Then
				Local mapSampling:String=UV_SAMPLE.Replace("@VEC4@",vec).Replace("@VEC2@",resultType).Replace("@SAMPLER_ARGS@",samplerArgs)
				mapSampling=mapSampling.Replace("@SAMPLE@",sample).Replace("@MIX@",mixName).Replace("@SLOTS@",String(params.Size()+2)).Replace("@INFO@",String(params.Size()+3))
				mapSampling=mapSampling.Replace("sampleRegion","sampleMap").Replace("image","secondImage").Replace("sampleState","secondState")
				Local mapArgs:String=callArgs.Replace("image","secondImage").Replace("sampleState","secondState")
				Local prefix:String=resultType+" localUV=("+inputUV+"-p["+params.Size()+"].xy)/p["+params.Size()+"].zw;~n"
				Local mapUV:String="localUV", modeSlot:Int=params.Size()+4
				If abi=5 Then modeSlot=params.Size()+6
				If abi=4 Then
					mapUV="mapUV"; modeSlot:+2
					prefix:+resultType+" mapUV="+resultType+"(dot(p["+(params.Size()+4)+"].xy,localUV)+p["+(params.Size()+4)+"].z,dot(p["+(params.Size()+5)+"].xy,localUV)+p["+(params.Size()+5)+"].z);~n"
				End If
				If abi=5 And root.Get("secondBodies") Then
					Local secondHelper:String=resultType+" userSecondUV("+resultType+" uv"
					If lang="metal" Then secondHelper:+", constant float4 *p"
					secondHelper:+") {~n"+declarations+TJSONObject(root.Get("secondBodies")).GetString(lang)+"~n}~n"
					helper:+secondHelper
					mapUV="userSecondUV(localUV"+parameterArgs+")"
				End If
				prefix:+vec+" m=sampleMap("+mapUV+mapArgs+");~n"
				prefix:+"if(p["+modeSlot+"].x!=0) m="+vec+"(1,1,1,m.r);~n"
				prefix:+"if(p["+modeSlot+"].y!=0) m.rgb=m.a>0?m.rgb/m.a:"+vec.Replace("4","3")+"(0,0,0);~n"
				tail=tail.Replace(vec+" c=sampleRegion("+uvCall, prefix+vec+" c=sampleRegion(userEffect(localUV,m"+parameterArgs+")")
				tail=tail.Replace("c=userColour(c"+colourCoordinates+parameterArgs+")","c=userColour(c"+colourCoordinates+",m"+parameterArgs+")")
				Select lang
					Case "metal"
						tail=tail.Replace("constant float4 &mode [[buffer(0)]]","texture2d<float> secondImage [[texture(1)]], sampler secondState [[sampler(1)]], constant float4 &mode [[buffer(0)]]")
					Case "glsl"
						head:+"layout(set=2,binding=1) uniform sampler2D secondImage;~n"
					Case "hlsl"
						head:+"Texture2D secondImage : register(t1, space2);~nSamplerState secondState : register(s1, space2);~n"
				End Select
				If abi=5 Then
					Local thirdSampling:String=mapSampling.Replace("sampleMap","sampleThird").Replace("secondImage","thirdImage").Replace("secondState","thirdState")
					thirdSampling=thirdSampling.Replace("p["+(params.Size()+2)+"]","p["+(params.Size()+4)+"]").Replace("p["+(params.Size()+3)+"]","p["+(params.Size()+5)+"]")
					Local thirdHelper:String=resultType+" userThirdUV("+resultType+" uv"
					If lang="metal" Then thirdHelper:+", constant float4 *p"
					thirdHelper:+") {~n"+declarations+TJSONObject(root.Get("thirdBodies")).GetString(lang)+"~n}~n"
					helper:+thirdHelper+thirdSampling
					Local thirdCall:String=vec+" t=sampleThird(userThirdUV(localUV"+parameterArgs+")"+mapArgs.Replace("secondImage","thirdImage").Replace("secondState","thirdState")+");~n"
					thirdCall:+"if(p["+(params.Size()+7)+"].x!=0) t="+vec+"(1,1,1,t.r);~n"
					thirdCall:+"if(p["+(params.Size()+7)+"].y!=0) t.rgb=t.a>0?t.rgb/t.a:"+vec.Replace("4","3")+"(0,0,0);~n"
					tail=tail.Replace(vec+" m=sampleMap",thirdCall+vec+" m=sampleMap")
					tail=tail.Replace("userEffect(localUV,m"+parameterArgs+")","userEffect(localUV,m,t"+parameterArgs+")")
					tail=tail.Replace("c=userColour(c"+colourCoordinates+",m"+parameterArgs+")","c=userColour(c"+colourCoordinates+",m,t"+parameterArgs+")")
					Select lang
						Case "metal"
							tail=tail.Replace("constant float4 &mode [[buffer(0)]]","texture2d<float> thirdImage [[texture(2)]], sampler thirdState [[sampler(2)]], constant float4 &mode [[buffer(0)]]")
						Case "glsl"
							head:+"layout(set=2,binding=2) uniform sampler2D thirdImage;~n"
						Case "hlsl"
							head:+"Texture2D thirdImage : register(t2, space2);~nSamplerState thirdState : register(s2, space2);~n"
					End Select
				End If
				helper:+mapSampling
			End If
			helper:+sampling
		End If
		WriteTextFile(output+"/"+name+"."+ext,head.Replace("@COUNT@",String(count))+helper+tail)
		If lang="hlsl" Then
			Local nativeCode:String=(head.Replace("@COUNT@",String(count))+helper+tail).Replace(", space3", "").Replace(", space2", "")
			nativeCode=nativeCode.Replace("colour: TEXCOORD0", "colour: COLOR0").Replace("uv: TEXCOORD1", "uv: TEXCOORD0")
			WriteTextFile(output+"/"+name+".d3d11.hlsl",nativeCode)
			Local legacy:String=nativeCode.Replace("cbuffer Modes : register(b0) { float4 mode; };", "float4 mode : register(c0);")
			legacy=legacy.Replace("cbuffer Parameters : register(b1) { float4 p["+count+"]; };", "float4 p["+count+"] : register(c1);~nfloat4 sourceScale : register(c11);~nfloat4 mapScale : register(c12);")
			legacy=legacy.Replace("Texture2D image : register(t0);~nSamplerState sampleState : register(s0);", "sampler2D image : register(s0);")
			legacy=legacy.Replace("Texture2D secondImage : register(t1);~nSamplerState secondState : register(s1);", "sampler2D secondImage : register(s1);")
			legacy=legacy.Replace("float4 position: SV_Position; ", "").Replace("SV_Target0", "COLOR0").Replace("colour: COLOR0", "colour: TEXCOORD1")
			legacy=legacy.Replace("float2 lo=floor(pixel), weight=pixel-lo;", "float2 lo=floor(pixel), weight=pixel-lo;~n        weight=lerp(weight,float2(0,0),step(weight,float2(0.000001,0.000001)));~n        weight=lerp(weight,float2(1,1),step(float2(0.999999,0.999999),weight));")
			legacy=legacy.Replace("image.Sample(sampleState,input.uv)", "tex2D(image,input.uv*sourceScale.xy)")
			legacy=legacy.Replace("image.Load(int3(q,0))", "tex2Dlod(image,float4((q+0.5)*sourceScale.zw,0,0))")
			legacy=legacy.Replace("secondImage.Load(int3(q,0))", "tex2Dlod(secondImage,float4((q+0.5)*mapScale.zw,0,0))")
			legacy=legacy.Replace("float2 uv: TEXCOORD0;", "float2 uv: TEXCOORD0; float2 screen:TEXCOORD2;")
			legacy=legacy.Replace("m2dEffectMain(Output input): COLOR0 {", "m2dEffectMain(Output input,float2 pixel:VPOS): COLOR0 {~ninput.uv+=ddx(input.uv)*(pixel.x-input.screen.x)+ddy(input.uv)*(pixel.y-input.screen.y);")
			If abi=1 Then legacy=legacy.Replace("float4 m2dEffectMain",D3D9_COLOUR_SAMPLE+"float4 m2dEffectMain").Replace("tex2D(image,input.uv*sourceScale.xy)","sourceColour(input.uv)")
			If abi=5 Then
				legacy=legacy.Replace("register(c11)","register(c17)").Replace("register(c12)","register(c18)")
				legacy="float4 thirdScale : register(c19);~n"+legacy
				legacy=legacy.Replace("Texture2D thirdImage : register(t2);~nSamplerState thirdState : register(s2);", "sampler2D thirdImage : register(s2);")
				legacy=legacy.Replace("thirdImage.Load(int3(q,0))", "tex2Dlod(thirdImage,float4((q+0.5)*thirdScale.zw,0,0))")
			End If
			WriteTextFile(output+"/"+name+".d3d9.hlsl",legacy)
		End If
		If lang="glsl" Then
			Local desktopHelper:String=helper, desktopTail:String=TAIL_gl120, desktopHead:String=HEAD_gl120
			If abi>=2 Then
				desktopHelper=GL120_TEXEL+helper.Replace("texelFetch(image,ivec2(q),0)","m2dTexel(q,info.xy)")
				desktopTail=tail.Replace("mode.x","coverage").Replace("mode.y","sourcePremult").Replace("mode.z","mask").Replace("mode.w","premultiply")
				desktopTail=desktopTail.Replace("c=vec4(1,1,1,c.r)","c=vec4(1,1,1,c.a)").Replace("result=c;","gl_FragColor=c;")
				If abi>=3 Then
					desktopHead:+"uniform sampler2D secondImage;~nuniform int secondTarget;~n"
					desktopHelper=GL120_TEXEL.Replace("m2dTexel","m2dMapTexel").Replace("sourceTarget","secondTarget").Replace("texture2D(image,","texture2D(secondImage,")+desktopHelper.Replace("texelFetch(secondImage,ivec2(q),0)","m2dMapTexel(q,info.xy)")
					desktopTail=desktopTail.Replace("m=vec4(1,1,1,m.r)","m=vec4(1,1,1,m.a)")
				End If
			End If
			If abi=5 Then
				desktopHead:+"uniform sampler2D thirdImage;~nuniform int thirdTarget;~n"
				desktopHelper=GL120_TEXEL.Replace("m2dTexel","m2dThirdTexel").Replace("sourceTarget","thirdTarget").Replace("texture2D(image,","texture2D(thirdImage,")+desktopHelper.Replace("texelFetch(thirdImage,ivec2(q),0)","m2dThirdTexel(q,info.xy)")
				desktopTail=desktopTail.Replace("t=vec4(1,1,1,t.r)","t=vec4(1,1,1,t.a)")
			End If
			WriteTextFile(output+"/"+name+".glsl",desktopHead.Replace("@COUNT@",String(count))+desktopHelper+desktopTail)
		End If
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
	Local abiArgument:String=", "+abi+", "+factory+"Data("+factory+"Asset(3), "+factory+"Size(3))"
	For Local asset:Int=4 Until 6
		abiArgument:+", "+factory+"Data("+factory+"Asset("+asset+"), "+factory+"Size("+asset+"))"
	Next
	source=source.Replace("@ABI_ARGUMENT@",abiArgument)
	WriteTextFile(output+"/"+name+".bmx",source)
End Function

Function EmbedPackage(manifest:String, output:String)
	Local root:TJSONObject=ReadManifest(manifest)
	Local name:String=root.GetString("name"), factory:String=root.GetString("factory")
	Local text:String="/* Generated shader assets. */~n"
	Local extensions:String[]=["metal","frag.spv","dxbc","glsl","d3d11.dxbc","d3d9.bin"]
	Local sizes:String[]=New String[extensions.Length]
	For Local i:Int=0 Until extensions.Length
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
