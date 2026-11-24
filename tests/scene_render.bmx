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
Import Max2D.Scene
Global checks:Int
Function Check(ok:Int, message:String)
 If Not ok Then Throw "FAIL: "+message
 checks :+ 1
End Function
Function Pixel:Int(x:Int,y:Int)
 Return GrabPixmap(x,y,1,1).ReadPixel(0,0)&$ffffff
End Function
Type TBox Extends TCustomDrawNode
 Field corrupt:Int, fail:Int, visits:Int
 Field leaked:TMax2DStateScope
 Field remembered:TSceneDrawContext
 Method OnDraw(context:TSceneDrawContext)
  visits :+ 1
  remembered = context
  context.SetColor(200,255,255)
  context.SetAlpha(1)
  DrawRect(0,0,10,10)
  If corrupt Then
   SetColor(1,2,3); Max2D.Core.SetAlpha(0.01); SetBlend(SOLIDBLEND)
   SetHandle(999,999); SetOrigin(200,200); Max2D.Core.SetTransform(37,8,9)
   TranslateCoordinates(100,100); SetLineWidth(9)
  End If
  Select fail
   Case 1
    SetPosition(99,99)
   Case 2
    Throw "draw failed"
   Case 3
    SetViewport(0,0,1,1)
   Case 4
    PushMax2DState()
   Case 5
    Scene().Destroy()
   Case 6
    SetGraphics(Null)
   Case 7
    SetRenderImage(Null)
   Case 8
    leaked=ScopedMax2DState()
    Throw "scope leaked"
  End Select
 End Method
End Type

Global drawTrace:String, updateTrace:String
Type TOrderBox Extends TCustomDrawNode
 Method OnDraw(context:TSceneDrawContext)
  drawTrace :+ GetName()
  context.SetColor(255,255,255)
  DrawRect(0,0,10,10)
 End Method
 Method OnUpdate(dt:Double)
  updateTrace :+ GetName()
 End Method
 Function Make:TOrderBox(name:String,red:Int,green:Int,blue:Int)
  Local node:TOrderBox=New TOrderBox
  node.SetName(name); node.SetTint(red,green,blue); node.SetProcessing(True)
  Return node
 End Function
End Type
Function DrawOrder(scene:TScene, expected:String)
 drawTrace=""
 scene.Render()
 Check(drawTrace=expected,"stable draw order: "+expected)
End Function

Try
 Graphics(180,120,0,0)
 Local target:TRenderImage=CreateRenderImage(180,120,0)
 SetRenderImage(target)
 SetClsColor(0,0,0); Cls()
 Local scene:TScene=TScene.Create()
 Local layer:TLayerNode=TLayerNode.Create()
 scene.Root().AddChild(layer)
 Local parent:TSceneNode2D=New TSceneNode2D
 parent.SetPosition(20,20); parent.SetTint(128,255,255); parent.SetAlpha(0.5)
 layer.AddChild(parent)
 Local logic:TSceneNode=New TSceneNode
 parent.AddChild(logic)
 Local box:TBox=New TBox
 box.SetPosition(5,0); box.SetAlpha(0.5); box.corrupt=True
 logic.AddChild(box)
 Local nextBox:TBox=New TBox
 nextBox.SetPosition(60,20)
 layer.AddChild(nextBox)
 Local rotated:TBox=New TBox
 rotated.SetTransform(110,20,90)
 layer.AddChild(rotated)
 Local image:TImage=CreateImage(4,4,1,0)
 ClearImage(image,New SColor8(255,255,255,255)); SetImageHandle(image,2,2)
 Local sprite:TSpriteNode=TSpriteNode.Create(image)
 sprite.SetPosition(10,60); sprite.SetTint(0,255,0)
 layer.AddChild(sprite)
 Local mesh:TMeshNode=TMeshNode.Create(TMesh2D.Create([0.0,0.0,10.0,0.0,0.0,10.0]))
 mesh.SetPosition(40,60); mesh.SetTint(0,0,255)
 layer.AddChild(mesh)
 Local text:TTextNode=TTextNode.Create("A",TImageFont.DefaultFont())
 text.SetPosition(70,60); layer.AddChild(text)
 Local bounds:TSceneRect=New TSceneRect
 sprite.GetSelfBounds(bounds)
 Check(bounds.x=-2 And bounds.y=-2 And bounds.width=4,"sprite bounds include handle")
 mesh.GetSelfBounds(bounds)
 Check(bounds.width=10 And bounds.height=10,"mesh bounds")
 Check(Not box.GetSelfBounds(bounds),"custom bounds unknown")
 box.SetSelfBounds(TSceneRect.Create(0,0,10,10))
 Check(box.GetSelfBounds(bounds) And bounds.width=10,"declared custom bounds")
 Check(text.GetSelfBounds(bounds) And bounds.width>0,"text ink bounds")
 sprite.GetContentBounds(bounds)
 SetImageHandle(image,1,1); sprite.InvalidateContent()
 sprite.GetContentBounds(bounds)
 Check(bounds.x=-1 And bounds.y=-1,"external image handle invalidation")
 SetImageHandle(image,2,2); sprite.InvalidateContent()
 text.GetContentBounds(bounds)
 Local shortWidth:Float=bounds.width
 text.SetText("AAAA")
 text.GetContentBounds(bounds)
 Check(bounds.width>shortWidth,"text setter invalidates content bounds")
 text.SetText("A")
 ' Surrounding state must be ignored for drawing and restored afterward.
 SetColor(7,8,9); SetAlpha(0.3); SetBlend(SOLIDBLEND)
 SetTransform(31,3,4); SetOrigin(11,12); SetHandle(13,14)
 TranslateCoordinates(17,18)
 Local camera:TCamera2D=New TCamera2D
 camera.x=999; SetCamera(camera)
 scene.Render()
 Local red:Int,green:Int,blue:Int
 GetColor(red,green,blue)
 Check(red=7 And green=8 And blue=9 And Abs(GetAlpha()-0.3)<0.001 And GetBlend()=SOLIDBLEND,"caller colour and blending restored")
 Check(GetRotation()=31 And GetCamera().x=999,"caller transforms restored")
 Local ox:Float,oy:Float
 GetOrigin(ox,oy); Check(ox=11 And oy=12,"caller origin restored")
 GetHandle(ox,oy); Check(ox=13 And oy=14,"caller handle restored")
 Check(TMax2DGraphics.Current().renderImage=target,"caller target restored")
 Local pixelValue:Int=Pixel(26,21)
 Check(Abs(((pixelValue Shr 16)&255)-25)<=2 And Abs((pixelValue&255)-64)<=2,"inherited tint and alpha through nonspatial parent")
 Check(Pixel(61,21)=$c8ffff,"custom state does not leak to sibling")
 Check(Pixel(105,25)=$c8ffff,"rotated custom geometry")
 Check(Pixel(9,59)=$00ff00,"sprite drawing and image handle")
 Check(Pixel(42,62)=$0000ff,"mesh drawing")
 Local pixels:TPixmap=ReadRenderImage(target),ink:Int
 For Local y:Int=60 Until 80
  For Local x:Int=70 Until 85
   If (pixels.ReadPixel(x,y)&$ffffff)<>0 Then ink=True
  Next
 Next
 Check(ink,"text drawing")
 Local caught:Int
 Try
  box.remembered.SetAlpha(1)
 Catch error:Object
  caught=True
 End Try
 Check(caught,"borrowed context rejects use outside callback")
 parent.SetVisible(False)
 Local previous:Int=box.visits
 scene.Render()
 Check(box.visits=previous,"hidden parent suppresses descendants")
 parent.SetVisible(True)
 ' Layer view snapshots and outer clipping.
 camera.x=0; camera.offsetX=20; camera.offsetY=0; camera.zoom=2
 layer.SetCamera(camera); camera.offsetX=999
 layer.SetViewport(TSceneRect.Create(140,0,40,120))
 SetViewport(0,0,150,120)
 SetClsColor(0,0,0); Cls()
 scene.Render()
 Check(Pixel(145,45)=$c8ffff And Pixel(155,45)=0,"layer camera snapshot and caller clip intersection")
 Local vx:Int,vy:Int,vw:Int,vh:Int
 GetViewport(vx,vy,vw,vh)
 Check(vx=0 And vw=150,"caller clip restored")
 layer.SetCamera(Null); layer.ClearViewport(); SetViewport(0,0,180,120)
 ' Failed hooks restore state and release the render guard.
 For Local failure:Int=1 To 8
  box.fail=failure; caught=False
  Try
   scene.Render()
  Catch error:Object
   caught=True
  End Try
  Check(caught,"invalid or throwing draw callback rejected")
  GetColor(red,green,blue); GetViewport(vx,vy,vw,vh)
  Check(red=7 And green=8 And blue=9 And vw=180 And GetRotation()=31,"state restored after draw failure")
  box.fail=0
  box.SetPosition(5,0)
  scene.Update(0)
 Next
 scene.Render()
 Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
 Local callerState:TMax2DState=canvas.state
 scene.Render()
 Check(canvas.state=callerState,"scene restores the caller's state object")
 box.leaked.Close(); box.leaked.Close()
 GetColor(red,green,blue)
 Check(red=7 And canvas.saved.IsEmpty(),"stale public scope remains inactive after boundary reuse")
 ' Alternate a retained scene between canvases: snapshots must not alias either.
 Local other:TMax2DGraphics=TMax2DGraphics(CreateGraphics(80,60,0,0,0,-1,-1))
 SetGraphics(other)
 SetColor(41,42,43); SetRotation(19)
 scene.Render()
 Check(other.state.red<>canvas.state.red And canvas.state.rotation=31,"second canvas cannot overwrite first canvas state")
 SetGraphics(canvas)
 scene.Render()
 Check(other.state.rotation=19,"first canvas cannot overwrite second canvas state")
 other.Close()
 ' A surrounding public scope must still unwind normally after repeated renders.
 Local outer:TMax2DStateScope=ScopedMax2DState()
 SetRotation(77); scene.Render(); scene.Render()
 Check(GetRotation()=77,"retained boundary preserves state inside public scope")
 outer.Close()
 Check(GetRotation()=31 And canvas.saved.IsEmpty(),"public scope restores after retained renders")
 scene.Destroy()
 ' Sorting never rewrites ownership or update order.
 Local ordered:TScene=TScene.Create(), orderLayer:TLayerNode=TLayerNode.Create()
 ordered.Root().AddChild(orderLayer)
 Local first:TOrderBox=TOrderBox.Make("A",255,0,0)
 Local second:TOrderBox=TOrderBox.Make("B",0,255,0)
 Local third:TOrderBox=TOrderBox.Make("C",0,0,255)
 orderLayer.AddChild(first); orderLayer.AddChild(second); orderLayer.AddChild(third)
 first.SetZIndex(2); second.SetZIndex(-1); third.SetZIndex(2)
 DrawOrder(ordered,"ABC")
 Check(Pixel(3,3)=$0000ff,"default insertion-order pixels")
 orderLayer.SetSortableChildren(True)
 DrawOrder(ordered,"BAC")
 third.SetZIndex(-2)
 DrawOrder(ordered,"CBA")
 Check(Pixel(3,3)=$ff0000,"changed z-index affects visible overlap")
 Check(orderLayer.ChildAt(0)=first And orderLayer.ChildAt(1)=second,"sorting preserves child indices")
 updateTrace=""; ordered.Update(0)
 Check(updateTrace="ABC","update order remains insertion order")
 first.SetZIndex(-2147483648); second.SetZIndex(2147483647); third.SetZIndex(0)
 DrawOrder(ordered,"ACB")
 first.SetZIndex(0); second.SetZIndex(0)
 DrawOrder(ordered,"ABC")
 Local logicOrder:TSceneNode=New TSceneNode
 Local nested:TOrderBox=TOrderBox.Make("D",255,255,255)
 nested.SetZIndex(-100)
 logicOrder.AddChild(nested); orderLayer.AddChild(logicOrder)
 DrawOrder(ordered,"ABCD")
 Local inserted:TOrderBox=TOrderBox.Make("E",255,0,255)
 orderLayer.AddChild(inserted,1)
 DrawOrder(ordered,"AEBCD")
 orderLayer.RemoveChild(second)
 DrawOrder(ordered,"AECD")
 orderLayer.AddChild(second)
 DrawOrder(ordered,"AECDB")
 second.SetZIndex(-1)
 DrawOrder(ordered,"BAECD")
 ordered.TrimStorage()
 DrawOrder(ordered,"BAECD")
 orderLayer.SetSortableChildren(False)
 DrawOrder(ordered,"AECDB")
 ordered.Destroy()
 ' Compare rendering overhead with one versus 1,000 empty drawables.
 Local perf:TScene=TScene.Create(), perfLayer:TLayerNode=TLayerNode.Create()
 perf.Root().AddChild(perfLayer); perf.Reserve(1100)
 perfLayer.ReserveChildren(1000)
 perfLayer.AddChild(New TCustomDrawNode)
 perf.Render()
 Local s0:SGCStats,s1:SGCStats
 GCCollect(); GCGetStats(s0)
 For Local i:Int=0 Until 100
  perf.Render()
 Next
 GCGetStats(s1)
 Local small:ULongInt=(s1.allocedBytesBeforeGC+s1.bytesAllocedSinceGC)-(s0.allocedBytesBeforeGC+s0.bytesAllocedSinceGC)
 For Local i:Int=1 Until 1000
  perfLayer.AddChild(New TCustomDrawNode)
 Next
 perf.Render()
 GCCollect(); GCGetStats(s0)
 For Local i:Int=0 Until 100
  perf.Render()
 Next
 GCGetStats(s1)
 Local large:ULongInt=(s1.allocedBytesBeforeGC+s1.bytesAllocedSinceGC)-(s0.allocedBytesBeforeGC+s0.bytesAllocedSinceGC)
 Print "100 render calls, one node: "+small+" GC bytes; 1,000 nodes: "+large+" GC bytes"
 Check(small=large,"scene traversal introduces no allocation per drawable")
 perfLayer.SetSortableChildren(True)
 perf.Render()
 GCCollect(); GCGetStats(s0)
 For Local i:Int=0 Until 100
  TSceneNode2D(perfLayer.ChildAt(i)).SetZIndex(100-i)
  perf.Render()
 Next
 GCGetStats(s1)
 Local sorted:ULongInt=(s1.allocedBytesBeforeGC+s1.bytesAllocedSinceGC)-(s0.allocedBytesBeforeGC+s0.bytesAllocedSinceGC)
 Print "100 render calls with dirty sorting of 1,000 nodes: "+sorted+" GC bytes"
 Check(sorted=small,"warm sorting rebuilds add no allocation")
 perf.Destroy()
 SetRenderImage(Null)
 EndGraphics()
 Print "PASS: "+checks+" scene rendering checks"
Catch error:Object
 Print error.ToString()
 Throw error
End Try
