Rem
bbdoc: A retained canvas for lighting text, meshes and custom Max2D drawing as one receiver.
about: Subclass OnPaint, call InitializeLighting and SetCanvas before attaching. The canvas captures at one pixel per local unit into a filtered RGBA8 render image. Lighting, transforms, inherited tint and alpha are applied afterward. Normal maps cover the complete canvas. Overlapping paint operations flatten before lighting; use separate receivers for separate materials or painter order. Children render independently. Call InvalidateCanvas after changing paint data or shared assets. Light/material/transform changes reuse captured pixels. Storage is allocated lazily and released by scene resource release or destruction.
End Rem
Type TLitCanvasNode Extends TLitNode Abstract
 Private
 Field canvas:TRenderImage
 Field canvasX:Int,canvasY:Int,canvasWidth:Int,canvasHeight:Int
 Field painted:Int
 Public
 Rem
 bbdoc: Sets an integer local capture rectangle with positive width and height.
 param: Finite horizontal coordinate in node-local units.
 param: Finite vertical coordinate in node-local units.
 param: Width in logical units; finite and positive.
 param: Height in logical units; finite and positive.
 about: Painting outside this rectangle is clipped. Identical settings retain the capture. Allocation occurs on the next visible draw; unsupported dimensions throw then. The canvas includes transparent margins in both bounds and material coordinates.
 End Rem
 Method SetCanvas(x:Int,y:Int,width:Int,height:Int)
  If width<=0 Or height<=0 Then Throw "Max2D SceneLighting: canvas dimensions must be positive"
  If canvasX=x And canvasY=y And canvasWidth=width And canvasHeight=height Then Return
  InvalidateContent()
  canvasX=x;canvasY=y;canvasWidth=width;canvasHeight=height;painted=False
 End Method
 Rem
 bbdoc: Invalidates retained paint after application data, text, mesh or texture edits.
 about: Also invalidates enclosing automatic scene caches. This does not allocate or repaint until the next visible render.
 End Rem
 Method InvalidateCanvas()
  InvalidateContent();painted=False
 End Method
 Rem
 bbdoc: Paints unlit local artwork into the canvas when invalidated.
 about: Use ordinary Max2D drawing, including DrawText and DrawMesh. Qualify drawing setters that share node method names, such as Max2D.Core.SetAlpha, SetScale and SetRotation; inherited setters change the node. State starts with identity coordinates, the canvas offset, white tint, full alpha, alpha blending and a transparent clear. Set required fonts and other drawing styles explicitly. Do not change the render target or mutate the scene. Exceptions leave the canvas invalid and restore caller drawing state. This callback must not depend on inherited tint, camera or lighting.
 End Rem
 Method OnPaint() Abstract
 Rem
 bbdoc: Reports the configured local canvas rectangle.
 param: Required reusable rectangle receiving local bounds when the result is True.
 returns: True when bounds are known and written to the destination; False when unknown.
 End Rem
 Method GetSelfBounds:Int(bounds:TSceneRect) Override
  If Not bounds Then Throw "Max2D SceneLighting: bounds destination is null"
  bounds.x=canvasX;bounds.y=canvasY;bounds.width=canvasWidth;bounds.height=canvasHeight
  Return True
 End Method
 Rem
 bbdoc: Captures changed artwork and draws it with the prepared receiver material.
 param: Borrowed draw context valid only during this callback; do not retain it.
 End Rem
 Method OnDraw(context:TSceneDrawContext) Override
  If canvasWidth<=0 Or canvasHeight<=0 Then Throw "Max2D SceneLighting: configure canvas before drawing"
  Local owner:TMax2DContext=TMax2DGraphics.Current().context
  If canvas Then
   If canvas.width<>canvasWidth Or canvas.height<>canvasHeight Or canvas.sources[0].targetOwner<>owner Then
    canvas.ReleaseFrames();canvas=Null;painted=False
   End If
  End If
  If Not canvas Then
   canvas=CreateRenderImage(UInt(canvasWidth),UInt(canvasHeight),FILTEREDIMAGE)
   painted=False
  End If
  canvas.handle_x=-canvasX;canvas.handle_y=-canvasY
  If Not painted Then
   Local scope:TMax2DStateScope=ScopedMax2DState()
   Try
    SetRenderImage(canvas);SetVirtualResolution(canvasWidth,canvasHeight);SetViewport(0,0,canvasWidth,canvasHeight)
    SetCamera(Null);ResetCoordinates();SetAffineTransform(1,0,0,1)
    SetOrigin(-canvasX,-canvasY);SetHandle(0,0)
    SetColor(255,255,255);Max2D.Core.SetAlpha(1);SetBlend(ALPHABLEND)
    SetClsColor(0,0,0,0);Cls
    OnPaint()
    owner.Flush()
    painted=True
   Finally
    scope.Close()
   End Try
  End If
  DrawLitImage(canvas)
 End Method
 Rem
 bbdoc: Releases owned canvas storage.
 about: Idempotent; shared fonts, images, meshes and materials are not released. The next render recaptures artwork.
 End Rem
 Method OnReleaseResources() Override
  If canvas Then canvas.ReleaseFrames();canvas=Null
  painted=False
 End Method
End Type
