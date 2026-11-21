Rem
bbdoc: Retained image-effect chain with automatically sized output and scratch storage.
about: Configure effects before Prepare. Update always renders; Result reuses the last successful output. Descriptions are retained by reference, but the supplied array is copied. Parameter changes take effect on the next Update. No source changes are detected automatically.
End Rem
Type TMax2DEffectChain
	Private
	Field buffers:TMax2DEffectBuffers = New TMax2DEffectBuffers
	Field effects:TMax2DImageEffect[]
	Field cached:TRenderImage
	Field valid:Int
	Field prepared:Int

	Public
	Rem
	bbdoc: Replaces the ordered effect descriptions and invalidates the result.
	param: Effects in processing order; Null or empty means copy.
	about: Null or an empty array means a plain copy. Null entries are rejected without changing the chain. Call Prepare again after changing the chain; identical buffer requirements reuse storage. The descriptions themselves remain shared and mutable.
	End Rem
	Method SetEffects(effects:TMax2DImageEffect[])
		For Local effect:TMax2DImageEffect = EachIn effects
			If Not effect Then Throw "Max2D Effects: chain entries must not be null"
		Next
		Self.effects = effects[..]
		valid = False; prepared = False
	End Method

	Rem
	bbdoc: Prepares an output image and, for two or more effects, one scratch image.
	param: Positive source width in pixels.
	param: Positive source height in pixels.
	param: Storage format for the output and scratch; defaults to RGBA8888.
	about: Dimensions must match the source passed to Update; pixelFormat selects the owned output storage. Identical preparation preserves a valid result. Changed storage invalidates it. Context ownership and transactional allocation follow TMax2DEffectBuffers. Shader support is checked by Update against each actual output target.
	End Rem
	Method Prepare(width:Int, height:Int, pixelFormat:Int = PF_RGBA8888)
		Local count:Int = 1
		If effects.Length > 1 Then count = 2
		buffers.Prepare(width, height, count, -1, pixelFormat)
		Local image:TRenderImage = buffers.Image(0)
		If image <> cached Then valid = False
		cached = image
		prepared = True
	End Method

	Rem
	bbdoc: Applies all stages and returns the borrowed output, preserving caller drawing state.
	param: Same-sized source render image, distinct from the owned output.
	about: Requires Prepare after SetEffects. An empty chain copies the source. Source and output must be distinct and equal in size. Every call rebuilds the result. A failed update invalidates Result because output pixels may have changed. No render images or effect arrays are allocated during updates.
	End Rem
	Method Update:TRenderImage(source:TRenderImage)
		If Not prepared Then Throw "Max2D Effects: prepare the chain before updating"
		valid = False
		Local image:TRenderImage = buffers.ApplyChain(source, 0, effects)
		valid = True
		Return image
	End Method

	Rem
	bbdoc: Returns the last successful borrowed output without rendering.
	about: Throws before a successful Update, after configuration changes, failed updates, changed storage or release, and on the wrong or closed context. Do not release the returned image independently or retain it across reconfiguration.
	End Rem
	Method Result:TRenderImage()
		Local image:TRenderImage = buffers.Image(0)
		If Not valid Then Throw "Max2D Effects: chain result requires a successful Update"
		Return image
	End Method

	Rem
	bbdoc: Releases owned storage and invalidates the result, retaining effect descriptions.
	about: Repeated calls are harmless. Deselect owned images before release. Prepare is required before the next Update.
	End Rem
	Method Release()
		buffers.Release()
		cached = Null; valid = False; prepared = False
	End Method
End Type

Rem
bbdoc: Creates a retained chain description without allocating graphics resources.
param: Ordered effects; an empty array produces a plain copy.
End Rem
Function CreateEffectChain:TMax2DEffectChain(effects:TMax2DImageEffect[])
	Local chain:TMax2DEffectChain = New TMax2DEffectChain
	chain.SetEffects(effects)
	Return chain
End Function
