Private

' Compatibility renderer for the existing three-texture paired shader.
' Dedicated renderer providers use LightingDriver directly, without this package ABI.
Type TMax2DPairedLightingRenderer Extends TMax2DLightingRenderer
	Field limits:TMax2DLightingCapabilities = TMax2DLightingCapabilities.Create(2, 2, False, False, False, False, True)
	Field effect:TMax2DShaderEffect = CreateShaderEffect(lightPairPackage)
	Field blend:Int = CreateBlendMode(BLEND_ONE, BLEND_ONE, BLEND_OP_ADD, BLEND_ZERO, BLEND_ONE)
	Method Capabilities:TMax2DLightingCapabilities() Override
		Return limits
	End Method

	Method Supports:Int(canvas:TMax2DGraphics, draw:TMax2DLightingDraw) Override
		If draw.count <> 2 Or draw.normalMap Or draw.specularStrength > 0 Then
			Return False
		End If

		If draw.sourceFormat = PF_RGBA16F Or draw.sourceFormat = PF_RGBA32F Then
			Return False
		End If

		For Local i:Int = 0 Until draw.count
			Local light:TMax2DLightingDrawLight = draw.lights[i]
			If light.directional Or light.patterned Or light.intensity > 1 Then
				Return False
			End If
		Next

		Local previous:Int = GetBlend()
		Try
			SetBlend(blend)
			Return Max2DSupportsImageEffect(effect)
		Finally
			SetBlend(previous)
		End Try
	End Method

	Method Draw(canvas:TMax2DGraphics, draw:TMax2DLightingDraw) Override
		Local a:TMax2DLightingDrawLight = draw.lights[0], b:TMax2DLightingDrawLight = draw.lights[1]
		effect.SetTexture(draw.source, draw.frame)
		effect.SetThirdTexture(draw.source, draw.frame)
		If a.map Then
			effect.SetTexture(a.map, a.mapFrame)
		End If

		If b.map Then
			effect.SetThirdTexture(b.map, b.mapFrame)
		End If

		effect.SetFloat4("lightA", a.x, a.y, a.radius, a.falloff)
		effect.SetFloat4("colourA", a.red, a.green, a.blue, a.intensity)
		effect.SetFloat4("lightB", b.x, b.y, b.radius, b.falloff)
		effect.SetFloat4("colourB", b.red, b.green, b.blue, b.intensity)
		effect.SetFloat4("basisX", draw.xx * draw.source.width, draw.xy * draw.source.height, draw.tx, 0)
		effect.SetFloat4("basisY", draw.yx * draw.source.width, draw.yy * draw.source.height, draw.ty, 0)
		Local normalized:Int = draw.targetFormat <> PF_RGBA16F And draw.targetFormat <> PF_RGBA32F
		effect.SetFloat4("options", a.map <> Null, b.map <> Null, normalized, 0)
		Local previous:Int = GetBlend()
		Try
			SetBlend(blend)
			DrawImageEffect(draw.source, effect, draw.x, draw.y, draw.frame)
		Finally
			SetBlend(previous)
			effect.SetTexture(Null)
			effect.SetThirdTexture(Null)
		End Try
	End Method

	Method Release() Override
		effect.SetTexture(Null)
		effect.SetThirdTexture(Null)
	End Method
End Type

Public
