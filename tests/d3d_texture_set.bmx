SuperStrict
?max2d_d3d9
Framework Max2D.D3D9Max2D
Import Max2D.D3D9Effects
?max2d_d3d11
Framework Max2D.D3D11Max2D
Import Max2D.D3D11Effects
?
Import BRL.StandardIO
Import "support/d3d_texture_set.c"
Extern "C"
 Function m2d_test_d3d_texture_set:Byte Ptr(d3d9:Byte Ptr,size9:Int,d3d11:Byte Ptr,size11:Int)
End Extern
Incbin "data/texture-set/probe.d3d9.bin"
Incbin "data/texture-set/probe.d3d11.dxbc"
Global checks:Int
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
 checks:+1
End Function
Function Near(actual:Float,expected:Float,message:String)
 Check(Abs(actual-expected)<0.006,message+": "+actual+" expected "+expected)
End Function
Try
 For Local lifetime:Int=0 Until 2
  Graphics(32,32)
  Local canvas:TMax2DGraphics=TMax2DGraphics.Current(),context:TMax2DContext=canvas.context
  Local adapter:TMax2DShaderPackageBackend=Max2DShaderPackageAdapter(context)
  Local shader:Byte Ptr=adapter.Shader(context,m2d_test_d3d_texture_set(IncbinPtr("data/texture-set/probe.d3d9.bin"),IncbinLen("data/texture-set/probe.d3d9.bin"),IncbinPtr("data/texture-set/probe.d3d11.dxbc"),IncbinLen("data/texture-set/probe.d3d11.dxbc")))
  Check(shader<>Null,"Five-texture native shader compiles")
  Local white:TPixmap=CreatePixmap(2,2,PF_RGBA8888)
  For Local y:Int=0 Until 2
   For Local x:Int=0 Until 2
    white.WritePixel(x,y,$ffffffff)
   Next
  Next
  Local source:TImage=LoadImage(white,MIPMAPPEDIMAGE|FILTEREDIMAGE)
  Local images:TImage[4]
  Local coloured:TPixmap=CreatePixmap(2,2,PF_RGBA8888)
  For Local y:Int=0 Until 2
   For Local x:Int=0 Until 2
    coloured.WritePixel(x,y,$ff400000)
   Next
  Next
  images[0]=LoadImage(coloured,MIPMAPPEDIMAGE|FILTEREDIMAGE)
  For Local i:Int=1 To 3 Step 2
   Local layer:TRenderImage=CreateRenderImage(2,2,MIPMAPPEDIMAGE|FILTEREDIMAGE)
   SetRenderImage(layer);SetBlend(SOLIDBLEND);SetAlpha(1)
   SetColor(64*i,0,0);DrawRect(0,0,2,1)
   SetColor(32*i,0,0);DrawRect(0,1,2,1)
   images[i]=layer
  Next
  Local coverage:TPixmap=CreatePixmap(2,2,PF_A8)
  coverage.pixels[0]=32;coverage.pixels[1]=32
  coverage.pixels[coverage.pitch]=160;coverage.pixels[coverage.pitch+1]=160
  images[2]=TImage.FromPixmap(coverage,FILTEREDIMAGE,PF_A8)
  Local output:TRenderImage=CreateRenderImage(2,2,0,PF_RGBA32F)
  SetRenderImage(output);SetColor(255,255,255);SetAlpha(1);SetBlend(SOLIDBLEND)
  Local frames:TImageFrame[4],values:Float[20]
  For Local i:Int=0 Until 4
   frames[i]=images[i].Frame(0,canvas)
  Next
  For Local selected:Int=0 Until 4
   values[0]=selected
   context.Flush()
   adapter.SelectTextureSet(context,shader,values,frames,4)
   DrawImage(source,0,0);context.Flush()
   adapter.ClearShader(context)
   Local data:TTextureData=ReadRenderTextureData(output)
   Local pixels:Float Ptr=Float Ptr(data.Level().Data())
   For Local y:Int=0 Until 2
    Local red:Float=64.0/255,alpha:Float=1,premult:Float=1
    If selected=1 Or selected=3 Then red=Float((64-32*y)*selected)/255
    If selected=2 Then red=1;alpha=Float(32+128*y)/255;premult=0
    Near(pixels[y*8],red,"Binding "+selected+" colour/orientation")
    Near(pixels[y*8+1],alpha,"Binding "+selected+" alpha/orientation")
    Near(pixels[y*8+2],premult,"Binding "+selected+" native mode")
   Next

  Next
  ' Aliases include the source and repeated auxiliary frames. A rejected count
  ' must leave the previous native selection available for the following draw.
  frames[0]=source.Frame(0,canvas);frames[1]=frames[0];frames[2]=frames[3]
  values[0]=3
  adapter.SelectTextureSet(context,shader,values,frames,4)
  Local rejected:Int
  Try
   adapter.SelectTextureSet(context,shader,values,frames,3)
  Catch error:Object
   rejected=True
  End Try
  Check(rejected,"Shader-specific texture count rejected")
  Local last:TImageFrame=frames[3]
  frames[3]=context.target;rejected=False
  Try
   adapter.SelectTextureSet(context,shader,values,frames,4)
  Catch error:Object
   rejected=True
  End Try
  Check(rejected,"Fifth binding rejects destination feedback")
  frames[3]=Null
  DrawImage(source,0,0);context.Flush();adapter.ClearShader(context)
  frames[3]=last
  Local data:TTextureData=ReadRenderTextureData(output)
  Near(Float Ptr(data.Level().Data())[0],192.0/255,"Rejected selection preserves fifth texture")
  ' Ordinary drawing must recover after all four auxiliary bindings are cleared.
  DrawImage(source,0,0)
  data=ReadRenderTextureData(output)
  Near(Float Ptr(data.Level().Data())[0],1,"Ordinary drawing resumes")
  ' A texture last sampled in the fifth slot becomes the next destination.
  SetRenderImage(TRenderImage(images[3]));DrawImage(source,0,0)
  SetRenderImage(output)
  For Local i:Int=0 Until 4
   frames[i]=images[i].Frame(0,canvas)
  Next
  adapter.SelectTextureSet(context,shader,values,frames,4)
  DrawImage(source,0,0);context.Flush();adapter.ClearShader(context)
  data=ReadRenderTextureData(output)
  Near(Float Ptr(data.Level().Data())[0],1,"Fifth texture can become a destination and resume sampling")
  EndGraphics
 Next
 Print "PASS: "+checks+" Direct3D texture-set checks"
Catch error:Object
 Print "FAIL: "+error.ToString()
 EndWithCode(1)
End Try
