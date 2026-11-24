SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?max2d_d3d9
Framework Max2D.D3D9Max2D
Import Max2D.D3D9Effects
?max2d_d3d11
Framework Max2D.D3D11Max2D
Import Max2D.D3D11Effects
?Not max2d_gl And Not max2d_sdlgpu And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.SceneEffects
Import BRL.StandardIO

Global checks:Int
Function Check(ok:Int, message:String)
 If Not ok Then Throw message
 checks :+ 1
End Function

Try
 Local rect:TSceneRect = TSceneRect.Create(-2.25, 3.5, 10.5, 8.25)
 Local layout:TSceneStageLayout = TSceneStageLayout.Create(rect, 2)
 Check(layout.PixelWidth() = 24 And layout.PixelHeight() = 18, "outward rounding before resolution scaling")
 rect.x = 999
 Local copied:TSceneRect = layout.CanvasRect()
 Check(copied.x = -3 And copied.y = 3 And copied.width = 12 And copied.height = 9, "layout owns detached bounds")
 copied.x = 999; layout.CopyCanvasRect(copied)
 Check(copied.x = -3, "copy query preserves immutable layout")
 Check(layout.EstimateImageBytes() = 24*18*4, "RGBA8 storage estimate")
 Local floating:TSceneStageLayout = TSceneStageLayout.Create(copied, 2, PF_RGBA16F)
 Check(floating.EstimateImageBytes(2) = 24*18*8*2, "float texture estimate")
 Local rejected:Int
 Try
  TSceneStageLayout.Create(TSceneRect.Create(0,0,2147483520.0,2147483520.0), 1, PF_RGBA16F)
 Catch error:Object
  rejected = True
 End Try
 Check(rejected, "byte overflow rejected without graphics")
 rejected = False
 Try
  TSceneStageLayout.Create(copied, 0)
 Catch error:Object
  rejected = True
 End Try
 Check(rejected, "zero resolution rejected")
 rejected = False
 Try
  TSceneChainStage.Create(Null, -1)
 Catch error:Object
  rejected = True
 End Try
 Check(rejected, "negative padding rejected")
 Local copy:TSceneChainStage = TSceneChainStage.Create(Null, 1.5, 2, 3, 4)
 Local input:TSceneRect = TSceneRect.Create(-5, -3, 10, 8)
 copy.ExpandBounds(input, input)
 Check(input.x = -6.5 And input.y = -5 And input.width = 14.5 And input.height = 14, "aliased fractional asymmetric expansion")
 Check(copy.EstimateStorageBytes(layout) = layout.EstimateImageBytes(), "copy owns one output")
 Local revision:Long = copy.Revision()
 copy.Invalidate()
 Check(copy.Revision() = revision+1, "explicit configuration revision")

 Graphics(64,64)
 Local canvas:TMax2DGraphics = TMax2DGraphics.Current()
?max2d_sdlgpu
 Check(Not Max2DSupportsRenderImage(16385,1,FILTEREDIMAGE), "SDL GPU query rejects oversized textures")
 rejected = False
 Try
  Local oversized:TRenderImage = CreateRenderImage(16385,1,FILTEREDIMAGE)
  oversized.Frame(0,canvas)
 Catch error:Object
  rejected = True
 End Try
 Check(rejected, "SDL GPU direct allocation rejects oversized textures safely")
?
 Local layer:TMax2DEffectLayer = New TMax2DEffectLayer
 layer.Prepare(12,9,0,0,0,0,2)
 Using
  Local capture:TMax2DStateScope = layer.Capture()
 Do
  SetColor(255,0,0); DrawRect(0,0,6,9)
  SetColor(0,255,0); DrawRect(6,0,6,9)
 End Using
 SetColor(12,34,56); SetAlpha(0.25); SetScale(2,3); SetOrigin(7,9)
 ResetMax2DStats()
 copy.Prepare(layout)
 Check(CaptureMax2DStats().textureCreations = 1, "copy preparation owns one texture")
 Local output:TRenderImage = copy.Update(layer.Image())
 Check(output <> layer.Image(), "output distinct from source")
 Check(ReadRenderImage(output).ReadPixel(3,3) = $ffff0000, "copy ignores caller transform and tint")
 Check(ReadRenderImage(output).ReadPixel(20,3) = $ff00ff00, "complete source copied")
 Check(ReadRenderImage(layer.Image()).ReadPixel(3,3) = $ffff0000, "source unmodified")
 Local r:Int,g:Int,b:Int,sx:Float,sy:Float,ox:Float,oy:Float
 GetColor(r,g,b); GetScale(sx,sy); GetOrigin(ox,oy)
 Check(r = 12 And g = 34 And b = 56 And GetAlpha() = 0.25, "stage restores tint and alpha")
 Check(sx = 2 And sy = 3 And ox = 7 And oy = 9 And canvas.renderImage = Null, "stage restores target and transform")
 ResetMax2DStats()
 copy.Prepare(layout)
 Check(copy.Update(layer.Image()) = output And CaptureMax2DStats().textureCreations = 0, "warm prepare/update retain texture identity")
 Local moved:TSceneStageLayout = TSceneStageLayout.Create(TSceneRect.Create(99,100,24,18))
 copy.Prepare(moved)
 Check(copy.Update(layer.Image()) = output, "logical origin and scale changes preserve matching pixel storage")
 rejected = False
 Try
  copy.Update(output)
 Catch error:Object
  rejected = True
 End Try
 Check(rejected, "output source alias rejected")
 Check(copy.Update(layer.Image()) = output, "recovers after rejected update")
 rejected = False
 Try
  copy.Prepare(TSceneStageLayout.Create(TSceneRect.Create(0,0,2147483520.0,2)))
 Catch error:Object
  rejected = True
 End Try
 Check(rejected And copy.Update(layer.Image()) = output, "unsupported replacement preserves old storage and preparation")
 Local wrong:TRenderImage = CreateRenderImage(3,3,FILTEREDIMAGE)
 rejected = False
 Try
  copy.Update(wrong)
 Catch error:Object
  rejected = True
 End Try
 Check(rejected, "source dimensions must match")
 wrong = CreateRenderImage(24,18,FILTEREDIMAGE,PF_RGBA16F)
 rejected = False
 Try
  copy.Update(wrong)
 Catch error:Object
  rejected = True
 End Try
 Check(rejected, "source format must match before materialization")
 SetRenderImage(output)
 rejected = False
 Try
  copy.Prepare(TSceneStageLayout.Create(TSceneRect.Create(0,0,32,32)))
 Catch error:Object
  rejected = True
 End Try
 Check(rejected And canvas.renderImage = output, "selected output cannot be replaced")
 SetRenderImage(Null)
 Local effects:TMax2DImageEffect[] = [TMax2DImageEffect(CreateSaturationEffect(0)),TMax2DImageEffect(CreateColorizeEffect(0,255,0))]
 Local shader:TSceneChainStage = TSceneChainStage.Create(effects)
 effects[0] = Null
 Check(shader.EstimateStorageBytes(layout) = layout.EstimateImageBytes(2), "two effects estimate output and scratch")
 rejected = False
 Try
  shader.Prepare(layout)
 Catch error:Object
  rejected = True
 End Try
?max2d_gl Or max2d_sdlgpu Or max2d_d3d9 Or max2d_d3d11
 Check(Not rejected, "shader stage support checked on real output")
 Local processed:TRenderImage = shader.Update(layer.Image())
 Local pixel:UInt = ReadRenderImage(processed).ReadPixel(3,3)
 Check((pixel & $ff0000ff) = $ff000000 And ((pixel Shr 8) & 255) > 30, "chain array copied and ordered effects applied")
 ResetMax2DStats()
 For Local i:Int = 0 Until 20
  Check(shader.Update(layer.Image()) = processed, "warm shader output identity")
 Next
 Check(CaptureMax2DStats().textureCreations = 0, "warm shader processing allocates no textures")
?Not max2d_gl And Not max2d_sdlgpu And Not max2d_d3d9 And Not max2d_d3d11
 Check(rejected, "missing shader provider rejected during preparation")
 Check(canvas.renderImage = Null, "failed support check restores target")
?
 shader.ReleaseResources(); shader.ReleaseResources()
 copy.ReleaseResources(); copy.ReleaseResources()
 rejected = False
 Try
  copy.Update(layer.Image())
 Catch error:Object
  rejected = True
 End Try
 Check(rejected, "released stage requires preparation")
 copy.Prepare(layout)
 copy.Update(layer.Image())
 EndGraphics
 copy.ReleaseResources(); layer.Release()
 Graphics(32,32)
 copy.Prepare(layout)
 copy.ReleaseResources()
 EndGraphics
 Print "PASS: "+checks+" scene stage checks"
Catch error:Object
 Print "FAIL: "+error.ToString()
 EndGraphics
 EndWithCode(1)
End Try
