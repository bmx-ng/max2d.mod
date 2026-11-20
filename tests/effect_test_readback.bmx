?max2d_d3d9
Const effectTestFormat:Int=PF_RGBA8888
Const effectTestBloomFormat:Int=PF_RGBA8888
Const effectTestTolerance:Float=0.012
Const effectTestShadowTolerance:Float=0.012
?Not max2d_d3d9
Const effectTestFormat:Int=PF_RGBA32F
Const effectTestBloomFormat:Int=PF_RGBA16F
Const effectTestTolerance:Float=0.00002
Const effectTestShadowTolerance:Float=0.00001
?

' Read RGBA8 and float pipelines into the same straight-colour reference format.
Function ReadEffectTestTexture:TTextureData(target:TRenderImage)
?max2d_d3d9
 Local pixels:TPixmap=ReadRenderImage(target)
 Local bytes:Byte[]=New Byte[pixels.width*pixels.height*16]
 Local values:Float Ptr=Float Ptr(Varptr bytes[0])
 For Local y:Int=0 Until pixels.height
  For Local x:Int=0 Until pixels.width
   Local c:Int=pixels.ReadPixel(x,y), offset:Int=(y*pixels.width+x)*4
   values[offset]=((c Shr 16)&255)/255.0
   values[offset+1]=((c Shr 8)&255)/255.0
   values[offset+2]=(c&255)/255.0
   values[offset+3]=((c Shr 24)&255)/255.0
  Next
 Next
 Return TTextureData.Create([TTextureLevel.Create(pixels.width,pixels.height,PF_RGBA32F,bytes)])
?Not max2d_d3d9
 Return ReadRenderTextureData(target)
?
End Function
