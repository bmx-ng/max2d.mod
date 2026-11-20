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
bbdoc: Immutable colour (ABI 1), coordinate (ABI 2) or two-texture (ABI 3/4) shader package with optional renderer-specific assets.
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
	bbdoc: Creates a package with typed parameters: one to eight for ABI 1, one to six for ABI 2, or one to three for ABI 3/4.
	about: Names must be unique identifiers. Assets may omit unsupported platforms, but at least one is required. Metal source uses m2dEffectMain; SPIR-V uses main; DXBC uses m2dEffectMain. The optional glsl argument supplies desktop GLSL 1.20 for ABI 1–4; d3d11 and d3d9 supply native ps_4_0 DXBC and ps_3_0 bytecode. SDL DXBC uses a separate binding contract. Use the package generator for the fixed sampling/alpha ABI. ABI 2 reserves two slots for source bounds and edge settings; ABI 3 reserves five for both images and second-image alpha interpretation; ABI 4 reserves seven, adding two map-transform rows. Each asset is limited to 4 MiB. Invalid versions, schemas and malformed containers throw before graphics allocation. Display names do not determine native cache identity.
	End Rem
	Function Create:TMax2DShaderPackage(name:String, parameterNames:String[], parameterTypes:Int[], metal:Byte[], spirv:Byte[], dxbc:Byte[], abiVersion:Int = 1, glsl:Byte[] = Null, d3d11:Byte[] = Null, d3d9:Byte[] = Null)
		If name = "" Or parameterNames.Length < 1 Or parameterNames.Length > 8 Or parameterNames.Length <> parameterTypes.Length Then Throw "Max2D package: invalid name or schema size"
		If abiVersion<>1 And abiVersion<>2 And abiVersion<>3 And abiVersion<>4 Then Throw "Max2D package: unsupported ABI version"
		If abiVersion>=3 And parameterNames.Length>3 Then Throw "Max2D package: two-texture packages allow at most three parameters"
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
		package.native = m2d_package_create(metal, metal.Length, spirv, spirv.Length, dxbc, dxbc.Length, parameterNames.Length, abiVersion, glsl, glsl.Length, d3d11, d3d11.Length, d3d9, d3d9.Length)
		If Not package.native Then Throw "Max2D package: " + String.FromUTF8String(m2d_package_error())
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
	bbdoc: Returns the immutable shader ABI version (1 for colour, 2 for coordinates, 3 for two textures, 4 for transformed maps).
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
	Method NativeShader:Byte Ptr(context:TMax2DContext)
		If Not native Then Return Null
		context.CheckOpen()
		Local backend:TMax2DShaderPackageBackend = FindShaderPackageBackend(context)
		If Not backend Then Return Null
		Return backend.Shader(context, native)
	End Method
	Method Delete()
		m2d_package_free(native)
	End Method
End Type

Rem
bbdoc: Reusable typed parameters and an optional second texture for packaged image effects.
about: Values start at zero. Updates affect subsequent draws; queued draws retain their snapshots. Named setters allocate no parameter arrays. Shader package assets are immutable and shared by instances.
End Rem
Type TMax2DShaderEffect Extends TMax2DImageEffect
	Private
	Field package:TMax2DShaderPackage
	Field values:Float[40]
	Field edgeMode:Int
	Field texture:TImage
	Field textureFrame:Int, textureEdgeMode:Int
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
		If package.ABIVersion()=4 Then effect.SetTextureTransform()
		Return effect
	End Function
	Rem
	bbdoc: Backend integration: resolves this effect's context-owned shader.
	End Rem
	Method NativeShader:Byte Ptr(context:TMax2DContext)
		If Not package Then Return Null
		Return package.NativeShader(context)
	End Method
	Rem
	bbdoc: Backend integration: submits packaged draws and always clears native effect selection.
	End Rem
	Method DrawNative(canvas:TMax2DGraphics, image:TImage, positions:Float[], x:Float, y:Float, frame:Int)
		Local context:TMax2DContext = canvas.context
		Local backend:TMax2DShaderPackageBackend = FindShaderPackageBackend(context)
		If Not backend Then Throw "Max2D package: no provider for this context"
		context.Flush()
		Local shader:Byte Ptr = NativeShader(context)
		If Not shader Then Throw "Max2D package: shader asset unavailable or compilation failed"
		If package.ABIVersion()>=2 Then
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
		Local second:TImageFrame
		If package.ABIVersion()>=3 Then
			If Not texture Then Throw "Max2D package: second texture is required"
			texture.CheckIndex(textureFrame)
			If texture.Trim(textureFrame) Then Throw "Max2D package: second texture must be untrimmed"
			second=texture.Frame(textureFrame,canvas)
			Local source:TImageSource=texture.sources[textureFrame]
			Local offset:Int=(package.ParameterCount()+2)*4
			values[offset]=Float(texture.sourceX[textureFrame])/source.width
			values[offset+1]=Float(texture.sourceY[textureFrame])/source.height
			values[offset+2]=Float(texture.width)/source.width
			values[offset+3]=Float(texture.height)/source.height
			values[offset+4]=1.0/source.width; values[offset+5]=1.0/source.height
			values[offset+6]=textureEdgeMode; values[offset+7]=(texture.flags & FILTEREDIMAGE)<>0
		End If
		context.Flush()
		backend.SelectShader(context,shader,values,second)
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
			backend.ClearShader(context)
		End Try
	End Method
	Rem
	bbdoc: Sets coordinate sampling to transparent (default), clamp, or repeat at image boundaries.
	about: ABI 2–4 support source edge modes. Repeat filters across the image's own seam; atlas neighbours are excluded. Sampling uses mip level zero.
	End Rem
	Method SetEdgeMode(mode:Int)
		If Not package Or package.ABIVersion()<2 Then Throw "Max2D package: edge modes require a coordinate package"
		If mode<MAX2D_EDGE_TRANSPARENT Or mode>MAX2D_EDGE_REPEAT Then Throw "Max2D package: invalid edge mode"
		edgeMode=mode
	End Method
	Rem
	bbdoc: Sets the second image of an ABI 3/4 effect, retaining it for subsequent draws.
	about: The selected frame maps across image-local UVs. Trimmed images are rejected. Passing Null clears the binding; drawing then throws. Queued draws retain the submitted texture binding.
	End Rem
	Method SetTexture(image:TImage, frame:Int=0)
		If Not package Or package.ABIVersion()<3 Then Throw "Max2D package: second texture requires ABI 3 or 4"
		If image Then
			image.CheckIndex(frame)
			If image.Trim(frame) Then Throw "Max2D package: second texture must be untrimmed"
		End If
		texture=image; textureFrame=frame
	End Method
	Rem
	bbdoc: Sets second-image boundary sampling to transparent, clamp or repeat.
	End Rem
	Method SetTextureEdgeMode(mode:Int)
		If Not package Or package.ABIVersion()<3 Then Throw "Max2D package: second texture requires ABI 3 or 4"
		If mode<MAX2D_EDGE_TRANSPARENT Or mode>MAX2D_EDGE_REPEAT Then Throw "Max2D package: invalid edge mode"
		textureEdgeMode=mode
	End Method
	Rem
	bbdoc: Positions, scales and rotates the second image within source-local normalized coordinates.
	about: Requires ABI 4. Offset is measured in source widths/heights; positive offsets move the map right/down. Scale is visible map size (1 fills the source), with negative values mirroring it. Rotation is clockwise in degrees around the map centre. Sampling applies the inverse transform before edge handling. Defaults restore identity. All arguments and derived coefficients must be finite; zero scales are rejected atomically.
	End Rem
	Method SetTextureTransform(offsetX:Float=0, offsetY:Float=0, scaleX:Float=1, scaleY:Float=1, rotation:Float=0)
		If Not package Or package.ABIVersion()<>4 Then Throw "Max2D package: texture transforms require ABI 4"
		If IsNan(offsetX) Or IsInf(offsetX) Or IsNan(offsetY) Or IsInf(offsetY) Or IsNan(scaleX) Or IsInf(scaleX) Or IsNan(scaleY) Or IsInf(scaleY) Or IsNan(rotation) Or IsInf(rotation) Or scaleX=0 Or scaleY=0 Then Throw "Max2D package: invalid texture transform"
		Local cosine:Double=Cos(rotation), sine:Double=Sin(rotation)
		Local xx:Float=Float(cosine/scaleX), xy:Float=Float(sine/scaleX)
		Local yx:Float=Float(-sine/scaleY), yy:Float=Float(cosine/scaleY)
		Local tx:Float=Float(0.5-Double(xx)*(0.5+offsetX)-Double(xy)*(0.5+offsetY))
		Local ty:Float=Float(0.5-Double(yx)*(0.5+offsetX)-Double(yy)*(0.5+offsetY))
		If IsNan(xx) Or IsInf(xx) Or IsNan(xy) Or IsInf(xy) Or IsNan(yx) Or IsInf(yx) Or IsNan(yy) Or IsInf(yy) Or IsNan(tx) Or IsInf(tx) Or IsNan(ty) Or IsInf(ty) Then Throw "Max2D package: texture transform is out of range"
		Local slot:Int=(package.ParameterCount()+4)*4
		values[slot]=xx; values[slot+1]=xy; values[slot+2]=tx
		values[slot+4]=yx; values[slot+5]=yy; values[slot+6]=ty
	End Method
	Rem
	bbdoc: Aligns the second texture to a captured map placement for an upcoming image draw.
	about: Requires ABI 4 and a bound second texture. Capture the map placement with CaptureImageTransform using that texture's pixel dimensions and handle. This method captures the source image at drawX/drawY in the current drawing state, including its handle, object transform, parent coordinates and camera. Call immediately before the matching DrawImageEffect; each sprite needs its own mapping update. Map placement and source placement must use the same virtual coordinate space. Singular or non-finite map transforms throw atomically. The supplied transform is read but not modified or retained.
	End Rem
	Method SetTextureMapping(mapTransform:TMax2DDrawTransform,image:TImage,drawX:Float,drawY:Float)
		If Not package Or package.ABIVersion()<>4 Then Throw "Max2D package: texture mapping requires ABI 4"
		If Not mapTransform Or Not image Or Not texture Then Throw "Max2D package: mapping requires a transform, source image and second texture"
		If image.width<=0 Or image.height<=0 Or texture.width<=0 Or texture.height<=0 Then Throw "Max2D package: mapping requires nonempty images"
		Local a:Double=mapTransform.xx,b:Double=mapTransform.xy,c:Double=mapTransform.yx,d:Double=mapTransform.yy
		Local ox:Double=mapTransform.tx,oy:Double=mapTransform.ty
		Local determinant:Double=a*d-b*c
		If IsNan(a) Or IsInf(a) Or IsNan(b) Or IsInf(b) Or IsNan(c) Or IsInf(c) Or IsNan(d) Or IsInf(d) Or IsNan(ox) Or IsInf(ox) Or IsNan(oy) Or IsInf(oy) Or IsNan(determinant) Or IsInf(determinant) Or determinant=0 Then Throw "Max2D package: invalid map placement"
		Local source:TMax2DDrawTransform=CaptureImageTransform(image,drawX,drawY)
		Local xx:Float=Float(((d*source.xx-b*source.yx)/determinant)*image.width/texture.width)
		Local xy:Float=Float(((d*source.xy-b*source.yy)/determinant)*image.height/texture.width)
		Local yx:Float=Float(((a*source.yx-c*source.xx)/determinant)*image.width/texture.height)
		Local yy:Float=Float(((a*source.yy-c*source.xy)/determinant)*image.height/texture.height)
		Local tx:Float=Float((d*(source.tx-ox)-b*(source.ty-oy))/determinant/texture.width)
		Local ty:Float=Float((a*(source.ty-oy)-c*(source.tx-ox))/determinant/texture.height)
		If IsNan(xx) Or IsInf(xx) Or IsNan(xy) Or IsInf(xy) Or IsNan(yx) Or IsInf(yx) Or IsNan(yy) Or IsInf(yy) Or IsNan(tx) Or IsInf(tx) Or IsNan(ty) Or IsInf(ty) Then Throw "Max2D package: texture mapping is out of range"
		Local slot:Int=(package.ParameterCount()+4)*4
		values[slot]=xx; values[slot+1]=xy; values[slot+2]=tx
		values[slot+4]=yx; values[slot+5]=yy; values[slot+6]=ty
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
	Function m2d_package_create:Byte Ptr(metal:Byte Ptr,nm:Int,spirv:Byte Ptr,ns:Int,dxbc:Byte Ptr,nd:Int,slots:Int,abi:Int,glsl:Byte Ptr,ng:Int,d3d11:Byte Ptr,n11:Int,d3d9:Byte Ptr,n9:Int)
	Function m2d_package_free(package:Byte Ptr)
	Function m2d_package_error:Byte Ptr()
End Extern
Global packageBackends:TMax2DShaderPackageBackend
Function FindShaderPackageBackend:TMax2DShaderPackageBackend(context:TMax2DContext)
	Local backend:TMax2DShaderPackageBackend=packageBackends
	While backend
		If backend.Handles(context) Then Return backend
		backend=backend.nextBackend
	Wend
End Function
Public

Rem
bbdoc: Renderer adapter for immutable packages and captured shader parameters.
End Rem
Type TMax2DShaderPackageBackend Abstract
	Field nextBackend:TMax2DShaderPackageBackend
	Method Handles:Int(context:TMax2DContext) Abstract
	Method Shader:Byte Ptr(context:TMax2DContext, package:Byte Ptr) Abstract
	Method SelectShader(context:TMax2DContext, shader:Byte Ptr, values:Float Ptr, second:TImageFrame) Abstract
	Method ClearShader(context:TMax2DContext) Abstract
End Type
Rem
bbdoc: Registers an optional renderer's package adapter.
End Rem
Function RegisterShaderPackageBackend(backend:TMax2DShaderPackageBackend)
	backend.nextBackend=packageBackends
	packageBackends=backend
End Function

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

Private
Global defaultDisplacementPackage:TMax2DShaderPackage
Global defaultDissolvePackage:TMax2DShaderPackage
Public
Rem
bbdoc: Creates texture-driven displacement using the map's straight red and green channels.
about: Map values 0.5 leave coordinates unchanged; 0 and 1 offset by minus and plus strength, measured as fractions of source width and height. The map uses image-local UVs and is not tinted. Source and map bounds have separate edge modes.
End Rem
Function CreateDisplacementEffect:TMax2DShaderEffect(map:TImage, strengthX:Float=0.03, strengthY:Float=0.03)
	If Not defaultDisplacementPackage Then defaultDisplacementPackage=CreateDisplacementPackage()
	Local effect:TMax2DShaderEffect=CreateShaderEffect(defaultDisplacementPackage)
	effect.SetFloat4("amount",strengthX,strengthY,0,0)
	effect.SetTexture(map)
	Return effect
End Function

Rem
bbdoc: Creates a texture-driven dissolve with an optional HDR edge glow.
about: Set progress from 0 (fully visible) to 1 (invisible). Intermediate values retain pixels whose map red channel is at least progress. width controls the soft glow band in map-value units; edge is RGB colour and intensity in its fourth component. Glow preserves source alpha. Defaults are progress 0, width 0.1 and edge (4,1,0.1,1). Map alpha does not affect the threshold.
End Rem
Function CreateDissolveEffect:TMax2DShaderEffect(map:TImage)
	If Not defaultDissolvePackage Then defaultDissolvePackage=CreateDissolvePackage()
	Local effect:TMax2DShaderEffect=CreateShaderEffect(defaultDissolvePackage)
	effect.SetTexture(map)
	effect.SetFloat("width",0.1)
	effect.SetFloat4("edge",4,1,0.1,1)
	Return effect
End Function

Private
Global defaultTextureMaskPackage:TMax2DShaderPackage
Public
Rem
bbdoc: Creates a reusable mask that multiplies source alpha by a second image's coverage.
about: Defaults to the mask alpha channel, including R8 coverage images. Set channels to RGBA weights with SetFloat4; the weighted sum is clamped to 0–1 before inversion. Set invert above 0.5 to invert coverage. Source straight RGB is unchanged, preserving HDR; drawing tint and alpha still apply. Map filtering, atlas bounds and render-image alpha interpretation follow the two-texture ABI.
End Rem
Function CreateTextureMaskEffect:TMax2DShaderEffect(mask:TImage, inverted:Int=False)
	If Not defaultTextureMaskPackage Then defaultTextureMaskPackage=CreateTextureMaskPackage()
	Local effect:TMax2DShaderEffect=CreateShaderEffect(defaultTextureMaskPackage)
	effect.SetTexture(mask)
	effect.SetFloat4("channels",0,0,0,1)
	effect.SetFloat("invert",inverted<>0)
	Return effect
End Function

Private
Global defaultThresholdMaskPackage:TMax2DShaderPackage
Public
Rem
bbdoc: Creates a texture threshold mask with a smooth transition between low and high.
about: Defaults to map alpha. Set channels with SetFloat4 to select RGBA weights; their sum is clamped to 0–1 before thresholding. Set range with SetFloat4("range",low,high,0,0). Values at or below low are hidden and values at or above high are visible when high exceeds low. Otherwise a hard cut retains values at least low. Inversion is applied after thresholding. Source straight RGB, including HDR, is preserved; drawing tint and alpha still apply. Supports independent map transforms and shared texture mapping.
End Rem
Function CreateThresholdMaskEffect:TMax2DShaderEffect(map:TImage, low:Float=0.4, high:Float=0.6, inverted:Int=False)
	If Not defaultThresholdMaskPackage Then defaultThresholdMaskPackage=CreateThresholdMaskPackage()
	Local effect:TMax2DShaderEffect=CreateShaderEffect(defaultThresholdMaskPackage)
	effect.SetTexture(map)
	effect.SetFloat4("channels",0,0,0,1)
	effect.SetFloat4("range",low,high,0,0)
	effect.SetFloat("invert",inverted<>0)
	Return effect
End Function
