SuperStrict
Framework Max2D.Core
Import BRL.StandardIO
Type TIdentity
End Type
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Function Hits:Int(items:Object[])
 If items Then Return items.Length
 Return 0
End Function
Try
 Local p:TPixmap=CreatePixmap(2,2,PF_RGBA8888)
 p.ClearPixels(0);p.WritePixel(0,0,$80ffffff);p.WritePixel(1,1,$7fffffff)
 Local dot:TImage=TImage.FromPixmap(p,DYNAMICIMAGE)
 Check(ImagesCollide(dot,0,0,0,dot,0,0,0),"Opaque pixel overlaps")
 Check(Not ImagesCollide(dot,0,0,0,dot,1,0,0),"Transparent pixel does not collide")
 Check(Not ImagesCollide(dot,0,0,0,dot,1,1,0),"Alpha 127 is transparent")
 Check(Not ImagesCollide(dot,0,0,0,dot,2,0,0),"Touching edges do not collide")
 Check(ImagesCollide(dot,-2,-3,0,dot,-2,-3,0),"Negative world positions")
 Local cached:TCollisionMask=dot.sources[0].collisionMask
 Check(ImagesCollide(dot,0,0,0,dot,0,0,0) And dot.sources[0].collisionMask=cached,"Unchanged sources reuse mask")
 Local atlas:TTextureAtlas=TTextureAtlas.Create(16,DYNAMICIMAGE|FILTEREDIMAGE)
 Local region:TImage=atlas.AddPixmap(p,"dot")
 Local empty:TImage=CreateImageView(region,1,0,1,1)
 Check(Not ImagesCollide(empty,0,0,0,dot,0,0,0),"Subview excludes neighbouring opaque atlas pixels")
 Local view:TImage=CreateImageView(region,0,0,1,1)
 Check(ImagesCollide(view,0,0,0,dot,0,0,0),"Atlas offsets and nested views")
 Local frozen:TCollisionShape=TCollisionShape.Image(region,0,0)
 p.ClearPixels(0);atlas.UpdatePixmap("dot",p)
 Check(Not ImagesCollide(region,0,0,0,dot,0,0,0),"Atlas edits invalidate mask")
 Check(frozen.Intersects(TCollisionShape.Image(dot,0,0)),"Stored shape keeps old alpha snapshot")
 Local locked:TPixmap=LockImage(dot)
 Local rejected:Int
 Try
  ImagesCollide(dot,0,0,0,dot,0,0,0)
 Catch e:Object
  rejected=True
 End Try
 Check(rejected,"Reject collision while write-locked")
 locked.ClearPixels(0);UnlockImage(dot)
 Check(Not ImagesCollide(dot,0,0,0,dot,0,0,0),"Unlock invalidates cache")
 Check(dot.sources[0].collisionMask<>cached,"Edited mask is replaced, not mutated")
 Local snapshot:TImage=CreateCollisionImage(region)
 Check(snapshot.sources[0]<>region.sources[0],"Explicit snapshot is independent")
 Local anim:TImage=CreateImage(1,1,2,0)
 locked=LockImage(anim,0);locked.ClearPixels($ffffffff);UnlockImage(anim,0)
 locked=LockImage(anim,1);locked.ClearPixels(0);UnlockImage(anim,1)
 Check(ImagesCollide(anim,0,0,0,anim,0,0,0),"Animation opaque frame")
 Check(Not ImagesCollide(anim,0,0,0,anim,0,0,1),"Animation transparent frame")
 SetImageHandle(anim,1,0)
 Check(ImagesCollide2(anim,1,0,0,0,1,1,anim,0,0,0,0,-1,1),"Handles and reflection")
 Check(Not ImagesCollide2(anim,0,0,0,0,0,1,anim,0,0,0,0,1,1),"Collapsed transform is empty")
 SetImageHandle(anim,0,0)
 Check(ImagesCollide2(anim,1,0,0,90,1,1,anim,0,0,0,0,1,1),"Quarter-turn rotation")
 Local shear:TMax2DState=New TMax2DState
 shear.iy=1;shear.originX=4;shear.originY=2
 Check(TCollisionShape.Image(anim,0,0,0,shear).Intersects(TCollisionShape.Rect(4,2,2,1)),"Shear and origin")
 Check(Not TCollisionShape.Rect(0,0,0.1,0.1).Intersects(TCollisionShape.Rect(0,0,1,1)),"Subpixel shape without a pixel centre is empty")
 Check(Not TCollisionShape.Rect(0,0,-1,1).Intersects(TCollisionShape.Rect(0,0,1,1)),"Negative rectangle width is empty")
 ResetCollisions()
 Local id:Object=New TIdentity
 Check(Not CollideImage(anim,0,0,0,0,COLLISION_LAYER_1|COLLISION_LAYER_32,id),"Write-only collision returns no hits")
 Check(Hits(CollideRect(0,0,1,1,COLLISION_LAYER_1|COLLISION_LAYER_32,0))=2,"One hit per matching layer")
 Check(CollideRect(0,0,1,1,COLLISION_LAYER_1,0)[0]=id,"Stored identity returned")
 ImagesCollide(anim,0,0,0,anim,10,0,0)
 ImagesCollide2(anim,0,0,0,0,1,1,anim,10,0,0,0,1,1)
 Check(Hits(CollideRect(0,0,1,1,COLLISION_LAYER_32,0))=1,"Pairwise checks preserve layer 32")
 ResetCollisions(COLLISION_LAYER_1)
 Check(Not CollideRect(0,0,1,1,COLLISION_LAYER_1,0),"Selective reset")
 Check(Hits(CollideRect(0,0,1,1,COLLISION_LAYER_32,0))=1,"Selective reset preserves other layers")
 ResetCollisions()
 CollideRect(0,0,1,1,0,COLLISION_LAYER_2)
 Local nullHits:Object[]=CollideRect(0,0,1,1,COLLISION_LAYER_2,COLLISION_LAYER_2)
 Check(Hits(nullHits)=1 And nullHits[0]=Null,"Null ids still produce a hit; query precedes write")
 Check(Hits(CollideRect(0,0,1,1,COLLISION_LAYER_2,0))=2,"Separate insertions remain distinct")
 Local secondId:Object=New TIdentity
 CollideRect(0,0,1,1,0,COLLISION_LAYER_2,secondId)
 Check(CollideRect(0,0,1,1,COLLISION_LAYER_2,0)[0]=secondId,"Newest insertion is returned first")
 CollideRect(0,0,1,1,0,COLLISION_LAYER_1,id)
 Check(CollideRect(0,0,1,1,COLLISION_LAYER_1|COLLISION_LAYER_2,0)[0]=id,"Lower layer returned first")
 Local world:TCollisionWorld=New TCollisionWorld
 Check(Not world.Collide(TCollisionShape.Rect(0,0,1,1),-1,0),"Independent collision worlds")
 ResetCollisions()
 Check(Not CollideRect(0,0,1,1,-1,0),"Reset all including sign-bit layer")
 Local target:TRenderImage=CreateRenderImage(4,4,0)
 rejected=False
 Try
  ImagesCollide(target,0,0,0,anim,0,0,0)
 Catch e:Object
  rejected=True
 End Try
 Check(rejected,"Render images never trigger implicit readback")
 ' Check scanline pruning against exhaustive sampling on small transformed masks.
 For Local i:Int=0 Until 60
  Local state:TMax2DState=New TMax2DState
  state.rotation=Float(i*13);state.scaleX=Float(0.5+(i Mod 5)*0.5);state.scaleY=Float(0.5+(i Mod 3))
  If i&1 Then state.scaleX=-state.scaleX
  state.Transform();state.iy:+0.15
  Local a:TCollisionShape=TCollisionShape.Image(anim,Double(i Mod 7)-3.25,Double(i Mod 5)-2.25,0,state)
  Local b:TCollisionShape=TCollisionShape.Rect(-1.25,-1.75,2.5,3.5)
  Local expected:Int
  For Local yy:Int=-12 To 12
   For Local xx:Int=-12 To 12
    If a.Solid(Double(xx)+0.5,Double(yy)+0.5) And b.Solid(Double(xx)+0.5,Double(yy)+0.5) Then expected=True
   Next
  Next
  Check(a.Intersects(b)=expected And b.Intersects(a)=expected,"Scanline pruning and symmetry "+i)
 Next
 Print "Max2D collision tests passed"
Catch error:Object
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
