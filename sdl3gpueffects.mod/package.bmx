Rem
bbdoc: Out-of-range coordinate samples are transparent.
End Rem
Const MAX2D_EDGE_TRANSPARENT:Int = 0
Rem
bbdoc: Coordinate samples clamp to the image's edge texel centres.
End Rem
Const MAX2D_EDGE_CLAMP:Int = 1
Rem
bbdoc: Coordinate samples wrap within the image, including filtered seams.
End Rem
Const MAX2D_EDGE_REPEAT:Int = 2

Rem
bbdoc: Scalar float parameter occupying one 16-byte uniform slot.
End Rem
Const MAX2D_PARAMETER_FLOAT:Int = 1
Rem
bbdoc: Four-component float parameter occupying one 16-byte uniform slot.
End Rem
Const MAX2D_PARAMETER_FLOAT4:Int = 4

Rem
bbdoc: Immutable single-source colour (ABI 1) or coordinate (ABI 2) shader package for SDL GPU.
about: Create with generated wrapper assets. Assets and schema are copied. Manifest/container validation is not shader reflection or a security boundary; backend support queries compile shaders and pipelines. Packages may outlive contexts, whose native resources are released on close.
End Rem
Type TMax2DShaderPackage
	Private
	Field native:Byte Ptr
	Field names:String[]
	Field kinds:Int[]
	Field label:String
	Field version:Int
	Public
	Rem
	bbdoc: Creates a package with typed parameters: one to eight for colour ABI 1, or one to six for coordinate ABI 2.
	about: Names must be unique identifiers. Assets may omit unsupported platforms, but at least one is required. Metal source uses m2dEffectMain; SPIR-V uses main; DXBC uses m2dEffectMain. Use the package generator for the fixed sampling/alpha ABI. Coordinate packages reserve two extra slots for image bounds and edge settings. Each asset is limited to 4 MiB. Invalid versions, schemas and malformed containers throw before graphics allocation. Display names do not determine native cache identity.
	End Rem
	Function Create:TMax2DShaderPackage(name:String, parameterNames:String[], parameterTypes:Int[], metal:Byte[], spirv:Byte[], dxbc:Byte[], abiVersion:Int = 1)
		If name = "" Or parameterNames.Length < 1 Or parameterNames.Length > 8 Or parameterNames.Length <> parameterTypes.Length Then Throw "Max2D package: invalid name or schema size"
		If abiVersion<>1 And abiVersion<>2 Then Throw "Max2D package: unsupported ABI version"
		If abiVersion=2 And parameterNames.Length>6 Then Throw "Max2D package: coordinate packages allow at most six parameters"
		For Local i:Int = 0 Until parameterNames.Length
			Local value:String = parameterNames[i]
			If value = "" Then Throw "Max2D package: empty parameter name"
			For Local c:Int = 0 Until value.Length
				Local ch:Int = value[c]
				If Not ((ch >= 65 And ch <= 90) Or (ch >= 97 And ch <= 122) Or ch = 95 Or (c > 0 And ch >= 48 And ch <= 57)) Then Throw "Max2D package: invalid parameter name"
			Next
			For Local j:Int = 0 Until i
				If parameterNames[j] = value Then Throw "Max2D package: duplicate parameter name"
			Next
			If parameterTypes[i] <> MAX2D_PARAMETER_FLOAT And parameterTypes[i] <> MAX2D_PARAMETER_FLOAT4 Then Throw "Max2D package: unsupported parameter type"
		Next
		Local package:TMax2DShaderPackage = New TMax2DShaderPackage
		package.names = parameterNames[..]; package.kinds = parameterTypes[..]; package.label = name; package.version = abiVersion
		package.native = m2d_package_create(metal, metal.Length, spirv, spirv.Length, dxbc, dxbc.Length, parameterNames.Length, abiVersion)
		If Not package.native Then Throw "Max2D package: " + SDL_GetError()
		Return package
	End Function
	Rem
	bbdoc: Returns the package display name.
	End Rem
	Method Name:String()
		Return label
	End Method
	Rem
	bbdoc: Returns the immutable parameter-slot count, or zero for an uninitialized package.
	End Rem
	Method ParameterCount:Int()
		If Not native Then Return 0
		Return names.Length
	End Method
	Rem
	bbdoc: Returns the immutable shader ABI version (1 for colour, 2 for coordinates).
	End Rem
	Method ABIVersion:Int()
		Return version
	End Method
	Rem
	bbdoc: Resolves a named parameter of the requested type to its float-array offset.
	End Rem
	Method ParameterOffset:Int(name:String, kind:Int)
		For Local i:Int = 0 Until names.Length
			If names[i] = name Then
				If kinds[i] <> kind Then Throw "Max2D package: parameter type mismatch: " + name
				Return i*4
			End If
		Next
		Throw "Max2D package: unknown parameter: " + name
	End Method
	Rem
	bbdoc: Backend integration: resolves a context-owned shader without exposing mutable assets.
	End Rem
	Method NativeShader:Byte Ptr(context:TSDLGPUMax2DContext)
		If Not native Then Return Null
		context.CheckOpen()
		Return m2d_package_shader(context.native, context.GetGPUDevice(), native)
	End Method
	Method Delete()
		m2d_package_free(native)
	End Method
End Type

Rem
bbdoc: Reusable typed parameters for a single-source packaged colour or coordinate effect.
about: Values start at zero. Updates affect subsequent draws; queued draws retain their snapshots. Named setters allocate no parameter arrays. Shader package assets are immutable and shared by instances.
End Rem
Type TMax2DShaderEffect Extends TMax2DImageEffect
	Private
	Field package:TMax2DShaderPackage
	Field values:Float[32]
	Field edgeMode:Int
	Method Slot:Int(name:String, kind:Int)
		If Not package Then Throw "Max2D package: use CreateShaderEffect"
		Return package.ParameterOffset(name, kind)
	End Method
	Public
	Rem
	bbdoc: Creates zero-initialized parameters for an immutable package.
	End Rem
	Function Create:TMax2DShaderEffect(package:TMax2DShaderPackage)
		If Not package Or package.ParameterCount() = 0 Then Throw "Max2D package: package is null or uninitialized"
		Local effect:TMax2DShaderEffect = New TMax2DShaderEffect
		effect.package = package
		Return effect
	End Function
	Rem
	bbdoc: Backend integration: resolves this effect's context-owned shader.
	End Rem
	Method NativeShader:Byte Ptr(context:TSDLGPUMax2DContext)
		If Not package Then Return Null
		Return package.NativeShader(context)
	End Method
	Rem
	bbdoc: Backend integration: submits packaged draws and always clears native effect selection.
	End Rem
	Method DrawNative(canvas:TMax2DGraphics, image:TImage, positions:Float[], x:Float, y:Float, frame:Int)
		Local context:TSDLGPUMax2DContext = TSDLGPUMax2DContext(canvas.context)
		If Not context Then Throw "Max2D package: native SDL GPU context required"
		Local shader:Byte Ptr = NativeShader(context)
		If Not shader Then Throw "Max2D package: " + SDL_GetError()
		If package.ABIVersion()=2 Then
			image.CheckIndex(frame)
			If image.Trim(frame) Then Throw "Max2D package: coordinate effects require untrimmed images; render the trimmed image into a layer first"
			Local source:TImageSource=image.sources[frame]
			Local offset:Int=package.ParameterCount()*4
			values[offset]=Float(image.sourceX[frame])/source.width
			values[offset+1]=Float(image.sourceY[frame])/source.height
			values[offset+2]=Float(image.width)/source.width
			values[offset+3]=Float(image.height)/source.height
			values[offset+4]=1.0/source.width; values[offset+5]=1.0/source.height
			values[offset+6]=edgeMode; values[offset+7]=(image.flags & FILTEREDIMAGE)<>0
		End If
		context.Flush()
		m2d_gpu_select_package_effect(context.native, shader, values)
		Try
			If positions Then
				For Local i:Int = 0 Until positions.Length Step 2
					canvas.DrawImage(image, positions[i], positions[i+1], frame)
				Next
			Else
				canvas.DrawImage(image,x,y,frame)
			End If
			context.Flush()
		Catch error:Object
			context.batchCount = 0
			context.batchFrame = Null
			Throw error
		Finally
			m2d_gpu_select_image_effect(context.native, Null, 0, 0, 0, 0)
		End Try
	End Method
	Rem
	bbdoc: Sets coordinate sampling to transparent (default), clamp, or repeat at image boundaries.
	about: Only ABI 2 supports edge modes. Repeat filters across the image's own seam; atlas neighbours are excluded. Sampling uses mip level zero.
	End Rem
	Method SetEdgeMode(mode:Int)
		If Not package Or package.ABIVersion()<>2 Then Throw "Max2D package: edge modes require a coordinate package"
		If mode<MAX2D_EDGE_TRANSPARENT Or mode>MAX2D_EDGE_REPEAT Then Throw "Max2D package: invalid edge mode"
		edgeMode=mode
	End Method
	Rem
	bbdoc: Sets a finite scalar parameter by its declared name.
	End Rem
	Method SetFloat(name:String, value:Float)
		Local i:Int = Slot(name, MAX2D_PARAMETER_FLOAT)
		If IsNan(value) Or IsInf(value) Then Throw "Max2D package: parameters must be finite"
		values[i] = value
	End Method
	Rem
	bbdoc: Sets a finite four-component parameter atomically by its declared name.
	End Rem
	Method SetFloat4(name:String, x:Float, y:Float, z:Float, w:Float)
		Local i:Int = Slot(name, MAX2D_PARAMETER_FLOAT4)
		If IsNan(x) Or IsInf(x) Or IsNan(y) Or IsInf(y) Or IsNan(z) Or IsInf(z) Or IsNan(w) Or IsInf(w) Then Throw "Max2D package: parameters must be finite"
		values[i] = x; values[i+1] = y; values[i+2] = z; values[i+3] = w
	End Method
End Type

Rem
bbdoc: Creates zero-initialized typed parameters for an immutable shader package.
End Rem
Function CreateShaderEffect:TMax2DShaderEffect(package:TMax2DShaderPackage)
	Return TMax2DShaderEffect.Create(package)
End Function

Private
Extern "C"
	Function m2d_package_create:Byte Ptr(metal:Byte Ptr, nm:Int, spirv:Byte Ptr, ns:Int, dxbc:Byte Ptr, nd:Int, slots:Int, abi:Int)
	Function m2d_package_free(package:Byte Ptr)
	Function m2d_package_shader:Byte Ptr(context:Byte Ptr, device:Byte Ptr, package:Byte Ptr)
	Function m2d_gpu_select_package_effect(context:Byte Ptr, effect:Byte Ptr, values:Float Ptr)
End Extern
Public

Private
Global defaultColorMatrixPackage:TMax2DShaderPackage
Public
Rem
bbdoc: Creates an identity RGBA colour matrix using the public shader-package API.
about: Set row0, row1, row2 and row3 with SetFloat4, and bias with SetFloat4. Output is four row dot-products with tinted straight RGBA plus bias. Alpha is clamped to 0–1; RGB retains HDR range. No implicit colour-space conversion is performed.
End Rem
Function CreateColorMatrixEffect:TMax2DShaderEffect()
	If Not defaultColorMatrixPackage Then defaultColorMatrixPackage = CreateColorMatrixPackage()
	Local effect:TMax2DShaderEffect = CreateShaderEffect(defaultColorMatrixPackage)
	effect.SetFloat4("row0",1,0,0,0)
	effect.SetFloat4("row1",0,1,0,0)
	effect.SetFloat4("row2",0,0,1,0)
	effect.SetFloat4("row3",0,0,0,1)
	Return effect
End Function

Private
Global defaultDistortionPackage:TMax2DShaderPackage
Public
Rem
bbdoc: Creates a reusable animated wave or radial ripple coordinate effect.
about: Parameters time, strength, frequency and ripple are scalars. Time and frequency use radians; strength is a fraction of image size. Set ripple above 0.5 for radial ripples, otherwise waves. Edge sampling defaults to transparent. Use SetEdgeMode to select clamp or repeat. Coordinates are image-local; aspect ratio is not corrected automatically.
End Rem
Function CreateDistortionEffect:TMax2DShaderEffect(strength:Float=0.03, frequency:Float=20)
	If Not defaultDistortionPackage Then defaultDistortionPackage=CreateDistortionPackage()
	Local effect:TMax2DShaderEffect=CreateShaderEffect(defaultDistortionPackage)
	effect.SetFloat("strength",strength)
	effect.SetFloat("frequency",frequency)
	Return effect
End Function

Private
Global defaultGradedDistortionPackage:TMax2DShaderPackage
Public
Rem
bbdoc: Creates a reusable wave/ripple and colour-grade effect executed in one draw.
about: Uses time, strength, frequency and ripple as CreateDistortionEffect. The grade float4 contains saturation, exposure multiplier, contrast around 0.5 and brightness offset. gradeTint multiplies RGBA after grading. Defaults preserve colour and alpha. Colour processing follows drawing tint; no implicit colour-space conversion is performed. RGB remains unclamped, and final alpha is clamped to 0–1. All six parameter slots share one snapshot with coordinate edge settings.
End Rem
Function CreateGradedDistortionEffect:TMax2DShaderEffect(strength:Float=0.03, frequency:Float=20)
	If Not defaultGradedDistortionPackage Then defaultGradedDistortionPackage=CreateGradedDistortionPackage()
	Local effect:TMax2DShaderEffect=CreateShaderEffect(defaultGradedDistortionPackage)
	effect.SetFloat("strength",strength)
	effect.SetFloat("frequency",frequency)
	effect.SetFloat4("grade",1,1,1,0)
	effect.SetFloat4("gradeTint",1,1,1,1)
	Return effect
End Function
