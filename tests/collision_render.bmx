SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
?Not max2d_gl
Framework Max2D.SDL3RenderMax2D
?
Import BRL.StandardIO
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Try
 Local g:TGraphics=Graphics(64,64,0,0)
 Local p:TPixmap=CreatePixmap(8,8,PF_RGBA8888)
 p.ClearPixels(0)
 For Local y:Int=0 Until 8
  For Local x:Int=0 Until 8
   If x<2 Or y<2 Or x>=6 Or y>=6 Then p.WritePixel(x,y,$ffffffff)
  Next
 Next
 Local image:TImage=TImage.FromPixmap(p,0)
 SetImageHandle(image,4,4)
 Local target:TRenderImage=CreateRenderImage(64,64,0)
 SetRenderImage(target)
 SetOrigin(3,2);SetClsColor(0,0,0,0);SetBlend(ALPHABLEND)
 SetTransform(23,2,1.5);Cls;DrawImage(image,20.25,20.25)
 Local first:TPixmap=ReadRenderImage(target)
 Local hitCount:Int,missCount:Int,edgeDifferences:Int
 For Local stepX:Int=0 Until 25
  Local x:Double=stepX*2+0.25
  SetTransform(-17,1.5,1.25);Cls;DrawImage(image,x,20.25)
  Local second:TPixmap=ReadRenderImage(target)
  Local expected:Int
  For Local py:Int=0 Until 64
   For Local px:Int=0 Until 64
    If ((first.ReadPixel(px,py) Shr 24)&255)>=128 And ((second.ReadPixel(px,py) Shr 24)&255)>=128 Then expected=True
   Next
  Next
  Local reads:Long=Max2DStats().readbacks
  Local actual:Int=ImagesCollide2(image,20.25,20.25,0,23,2,1.5,image,x,20.25,0,-17,1.5,1.25)
?max2d_gl
  Check(expected=actual,"Collision matches GL rendered alpha at position "+x)
?Not max2d_gl
  ' Software triangle rasterizers can choose different edge texels. Interior
  ' overlap must hit; separated dilated silhouettes must miss. Report edge-only
  ' differences rather than changing the backend-independent collision rule.
  Local interior:Int,nearby:Int
  For Local py:Int=1 Until 63
   For Local px:Int=1 Until 63
    Local firstCount:Int,secondCount:Int
    For Local dy:Int=-1 To 1
     For Local dx:Int=-1 To 1
      If ((first.ReadPixel(px+dx,py+dy) Shr 24)&255)>=128 Then firstCount:+1
      If ((second.ReadPixel(px+dx,py+dy) Shr 24)&255)>=128 Then secondCount:+1
     Next
    Next
    If firstCount=9 And secondCount=9 Then interior=True
    If firstCount And secondCount Then nearby=True
   Next
  Next
  If interior Then Check(actual,"Rendered interior overlap must collide")
  If Not nearby Then Check(Not actual,"Separated silhouettes must not collide")
  If expected<>actual Then edgeDifferences:+1
?
  Check(Max2DStats().readbacks=reads,"Pairwise queries never read back")
  Check(GetRotation()=-17,"Explicit transforms leave drawing state unchanged")
  If actual Then hitCount:+1 Else missCount:+1
 Next
 Check(hitCount>0 And missCount>0,"Pixel reference covers hits and misses")
 SetTransform();SetOrigin(0,0);Cls;DrawImage(image,20,20)
 Local before:Long=Max2DStats().readbacks
 Local rejected:Int
 Try
  ImagesCollide(target,0,0,0,image,20,20,0)
 Catch e:Object
  rejected=True
 End Try
 Check(rejected And Max2DStats().readbacks=before,"Direct target collision rejected without readback")
 Local snapshot:TImage=CreateCollisionImage(target)
 Check(Max2DStats().readbacks=before+1,"Snapshot performs one explicit readback")
 Check(ImagesCollide(snapshot,0,0,0,image,20,20,0),"Render snapshot collision")
 Cls
 Check(ImagesCollide(snapshot,0,0,0,image,20,20,0),"Snapshot survives later target changes")
 SetRenderImage(Null)
 ResetCollisions()
 SetTransform(0,-1,1);SetOrigin(10,4)
 CollideImage(image,0,0,0,0,COLLISION_LAYER_1,"sprite")
 SetNativeResolution();SetViewport(0,0,0,0);SetAlpha(0)
 Check(Hits(CollideImage(image,0,0,0,COLLISION_LAYER_1,0))=1,"Presentation, clipping and draw alpha do not alter collision space")
 ResetCollisions();EndGraphics()
 Print "Raster edge-only differences: "+edgeDifferences
 Print "Max2D rendered collision tests passed"
Catch error:Object
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
Function Hits:Int(items:Object[])
 If items Then Return items.Length
 Return 0
End Function
