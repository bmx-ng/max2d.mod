Const effectTestFormat:Int=PF_RGBA32F
Const effectTestBloomFormat:Int=PF_RGBA16F
Const effectTestTolerance:Float=0.00002
Const effectTestShadowTolerance:Float=0.00001

Function ReadEffectTestTexture:TTextureData(target:TRenderImage)
 Return ReadRenderTextureData(target)
End Function
