SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_sdlgpu And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3RenderMax2D
?
Import BRL.StandardIO
Import Max2D.SceneEffects
Global checks:Int
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
 checks:+1
End Function
Function Same:Int(a:TPixmap,b:TPixmap)
 For Local y:Int=0 Until a.height
  For Local x:Int=0 Until a.width
   For Local shift:Int=0 To 24 Step 8
    If Abs((a.ReadPixel(x,y) Shr shift & 255)-(b.ReadPixel(x,y) Shr shift & 255))>2 Then Return False
   Next
  Next
 Next
 Return True
End Function
Try
 Local xy:Float[]=[0.0,0.0,16.0,0.0,16.0,16.0,0.0,16.0]
 Local uv:Float[]=[0.0,0.0,1.0,0.0,1.0,1.0,0.0,1.0]
 Local mesh:TMesh2D=TMesh2D.Create(xy,[0,1,2,0,2,3],uv)
 uv[0]=0.5;xy[0]=50
 Check(mesh.uv[0]=0 And mesh.xy[0]=0,"constructor copies positions and UVs")
 For Local invalid:Int=0 Until 2
  Local values:Float[]=[0.0,0.0]
  If invalid Then values=[-1.0,0.0,1.0,0.0,1.0,1.0,0.0,1.0]
  Local rejected:Int
  Try
   mesh.SetUV(values)
  Catch error:Object
   rejected=True
  End Try
  Check(rejected And mesh.uv[0]=0 And mesh.uv.Length=8,"invalid UV replacement preserves mesh")
 Next
 Graphics(48,48)
 Local target:TRenderImage=CreateRenderImage(48,48,0)
 SetRenderImage(target);SetVirtualResolution(48,48);SetViewport(0,0,48,48)
 Local pixels:TPixmap=CreatePixmap(32,16,PF_RGBA8888)
 For Local y:Int=0 Until 16
  For Local x:Int=0 Until 32
   pixels.WritePixel(x,y,($ff Shl 24)|((x*7) Shl 16)|((y*15) Shl 8)|90)
  Next
 Next
 Local atlas:TImage=LoadImage(pixels,0)
 Local art:TImage=TImage.View(atlas,16,0,16,16)
 Local trimmed:TImage=TImage.View(atlas,16,0,16,16)
 trimmed.SetTrim(0,4,4,8,8)
 Local reference:TPixmap,actual:TPixmap
 For Local variant:Int=0 Until 4
  Local source:TImage=art
  If variant=3 Then source=trimmed
  SetClsColor(0,0,0,0);SetBlend(ALPHABLEND);SetColor(255,255,255);SetAlpha(1);SetRotation(0);SetScale(1,1)
  If variant=1 Then SetColor(120,200,160);SetAlpha(0.5)
  If variant=2 Then SetRotation(25);SetScale(-1,0.8)
  SetImageHandle(source,0,0)
  Cls;DrawImage(source,24,16);reference=ReadRenderImage(target)
  SetImageHandle(source,7,9)
  Cls;DrawTexturedMesh(mesh,source,24,16);actual=ReadRenderImage(target)
  Check(Same(reference,actual),"mesh/image parity with atlas tint transform or trim "+variant)
 Next
 SetRotation(0);SetScale(1,1);SetColor(255,255,255);SetAlpha(1)
 ResetMax2DStats();Cls;DrawTexturedMesh(mesh,trimmed,0,0);FlushMax2D()
 Check(CaptureMax2DStats().textureCreations=0,"warm trimmed mesh reuses sampling textures")
 Local triangle:TMesh2D=TMesh2D.Create([0.0,0.0,16.0,0.0,0.0,16.0],Null,[0.0,0.0,1.0,0.0,0.0,1.0])
 Cls;DrawTexturedMesh(triangle,art,0,0);actual=ReadRenderImage(target)
 Check((actual.ReadPixel(2,2) Shr 24 & 255)=255 And actual.ReadPixel(14,14)=0,"triangle has geometry coverage rather than a rectangular image")
 Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
 scene.Root().AddChild(layer)
 Local group:TCompositeNode=TCompositeNode.Create();group.SetCacheMode(ESceneCacheMode.Automatic);layer.AddChild(group)
 Local node:TMeshNode=TMeshNode.Create(mesh,art);node.SetPosition(8,8);group.AddChild(node)
 Cls;scene.Render();reference=ReadRenderImage(target)
 Cls;DrawTexturedMesh(mesh,art,8,8);actual=ReadRenderImage(target)
 Check(Same(reference,actual),"textured scene mesh matches immediate drawing")
 Cls;scene.Render();Check(scene.CaptureStats().Captures()=0,"textured mesh cached")
 mesh.SetUV([1.0,0.0,0.0,0.0,0.0,1.0,1.0,1.0]);node.InvalidateContent()
 Cls;scene.Render();actual=ReadRenderImage(target)
 Check(scene.CaptureStats().Captures()=1 And Not Same(reference,actual),"UV edit explicitly invalidates cache and changes artwork")
 node.SetImage(Null);Cls;scene.Render();actual=ReadRenderImage(target)
 Check(actual.ReadPixel(10,10)=$ffffffff,"clearing artwork restores filled mesh")
 Local bounds:TSceneRect=New TSceneRect
 node.GetSelfBounds(bounds);Check(bounds.x=0 And bounds.y=0 And bounds.width=16 And bounds.height=16,"image handle does not alter mesh bounds")
 node.SetImage(art);node.SetFrame(0);Cls;scene.Render()
 ResetMax2DStats();Cls;scene.Render();FlushMax2D()
 Check(CaptureMax2DStats().textureCreations=0 And scene.CaptureStats().Captures()=0,"warm scene mesh creates no textures or captures")
 scene.Destroy();SetRenderImage(Null);target.ReleaseFrames();trimmed.ReleaseFrames();art.ReleaseFrames();atlas.ReleaseFrames();EndGraphics()
 Print "PASS: "+checks+" textured mesh checks"
Catch error:Object
 Print "FAIL: after "+checks+" checks: "+error.ToString()
 EndGraphics();EndWithCode(1)
End Try
