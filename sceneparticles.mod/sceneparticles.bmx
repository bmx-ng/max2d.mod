SuperStrict
Rem
bbdoc: Optional fixed-capacity scene particle batches.
about: Explicit emission and constant-velocity movement reuse inline particle slots. Rendering supports shared square sprites or procedural discs, inherited colour/alpha, and automatically maintained local bounds. No per-particle scene nodes or warm emission/update allocations are needed.
End Rem
Module Max2D.SceneParticles
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"
Import Max2D.Scene

Private
Struct SSceneParticle
 Field x:Float,y:Float,vx:Float,vy:Float,size:Float
 Field age:Double,life:Double
 Field red:Int,green:Int,blue:Int
End Struct
Function ParticleFinite(value:Double)
 If IsNan(value) Or IsInf(value) Then Throw "Max2D SceneParticles: finite numbers required"
End Function
Public
Rem
bbdoc: A retained batch of constant-velocity particles with lifetime opacity fading.
about: Create allocates all slots. Emit returns False at capacity, without eviction or growth. Particles are local to the node and follow its later transforms. Updates compact survivors in emission order for stable alpha blending. Scene pause and detachment suspend automatic simulation. Images are shared, frame zero, stretched to each particle's square size; image handles are ignored. Without an image, particles are discs.
End Rem
Type TSceneParticleNode Extends TCustomDrawNode
 Private
 Field particles:SSceneParticle[]
 Field count:Int
 Field image:TImage
 Field bounds:TSceneRect=New TSceneRect
 Field disposed:Int
 Field left:Double,right:Double,top:Double,bottom:Double
 Method IncludeBounds(p:SSceneParticle,first:Int)
  If first Then
   left=Double(p.x)-p.size/2;right=Double(p.x)+p.size/2
   top=Double(p.y)-p.size/2;bottom=Double(p.y)+p.size/2
  Else
   left=Min(left,Double(p.x)-p.size/2);right=Max(right,Double(p.x)+p.size/2)
   top=Min(top,Double(p.y)-p.size/2);bottom=Max(bottom,Double(p.y)+p.size/2)
  End If
 End Method
 Method PublishBounds()
  bounds.x=Float(left);bounds.y=Float(top);bounds.width=Float(right-left);bounds.height=Float(bottom-top)
  SetSelfBounds(bounds)
 End Method
 Method RefreshBounds()
  left=0;right=0;top=0;bottom=0
  For Local i:Int=0 Until count
   IncludeBounds(particles[i],i=0)
  Next
  PublishBounds()
 End Method
 Public
 Rem
 bbdoc: Creates an empty particle batch with a positive fixed capacity and optional shared image.
 param: Positive fixed particle capacity; emission never grows this storage.
 param: Borrowed image; its lifetime remains application-owned.
 returns: A new #TSceneParticleNode instance configured with the supplied settings.
 End Rem
 Function Create:TSceneParticleNode(capacity:Int=256,image:TImage=Null)
  If capacity<1 Then Throw "Max2D SceneParticles: capacity must be positive"
  Local node:TSceneParticleNode=New TSceneParticleNode
  node.particles=New SSceneParticle[capacity];node.image=image
  node.RefreshBounds()
  Return node
 End Function
 Rem
 bbdoc: Emits a local particle, returning False when the retained pool is full.
 param: Finite horizontal coordinate in node-local units.
 param: Finite vertical coordinate in node-local units.
 param: Finite horizontal velocity in node-local units per second.
 param: Finite vertical velocity in node-local units per second.
 param: Finite positive lifetime in seconds.
 param: Finite positive square extent in node-local units.
 param: Red component in the inclusive range 0..255.
 param: Green component in the inclusive range 0..255.
 param: Blue component in the inclusive range 0..255.
 returns: True when a particle was emitted, False when the pool is full.
 about: Velocity is local units per second, lifetime is positive seconds, and size is a positive square extent. RGB channels must be 0..255. Successful emission enables variable-step processing. Opacity fades linearly from one to zero over the lifetime.
 End Rem
 Method Emit:Int(x:Float,y:Float,vx:Float,vy:Float,lifetime:Double,size:Float,red:Int=255,green:Int=255,blue:Int=255)
  If disposed Then Throw "Max2D SceneParticles: node destroyed"
  ParticleFinite(x);ParticleFinite(y);ParticleFinite(vx);ParticleFinite(vy);ParticleFinite(lifetime);ParticleFinite(size)
  If lifetime<=0 Or size<=0 Then Throw "Max2D SceneParticles: positive lifetime and size required"
  If red<0 Or red>255 Or green<0 Or green>255 Or blue<0 Or blue>255 Then Throw "Max2D SceneParticles: colour outside 0..255"
  ' Ensure the entire constant-velocity trajectory and bounds fit finite Float coordinates.
  If Abs(Double(x))+Abs(Double(vx)*lifetime)+size>1e30 Or Abs(Double(y))+Abs(Double(vy)*lifetime)+size>1e30 Then Throw "Max2D SceneParticles: trajectory too large"
  If count=particles.Length Then Return False
  SetProcessing(True)
  Local p:SSceneParticle
  p.x=x;p.y=y;p.vx=vx;p.vy=vy;p.life=lifetime;p.age=0;p.size=size;p.red=red;p.green=green;p.blue=blue
  particles[count]=p;IncludeBounds(p,count=0);count:+1;PublishBounds()
  Return True
 End Method
 Rem
 bbdoc: Returns the number of live particles without allocating.
 returns: The number of live particles without allocating.
 End Rem
 Method Count:Int()
  Return count
 End Method
 Rem
 bbdoc: Returns the fixed number of retained slots.
 returns: The fixed number of retained slots.
 End Rem
 Method Capacity:Int()
  Return particles.Length
 End Method
 Rem
 bbdoc: Removes live particles and stops processing while retaining the pool and shared image.
 End Rem
 Method Clear()
  If disposed Then Throw "Max2D SceneParticles: node destroyed"
  SetProcessing(False);count=0;RefreshBounds()
 End Method
 Rem
 bbdoc: Advances live particles and fades their opacity; called by Scene.Update in seconds.
 param: Finite nonnegative elapsed time in seconds, supplied by the application.
 End Rem
 Method OnUpdate(dt:Double) Override
  If disposed Then Throw "Max2D SceneParticles: node destroyed"
  ParticleFinite(dt)
  If dt<0 Then Throw "Max2D SceneParticles: negative time step"
  If count=0 Or dt=0 Then Return
  Local kept:Int
  For Local i:Int=0 Until count
   Local p:SSceneParticle=particles[i]
   If dt>=p.life-p.age Then Continue
   p.age:+dt;p.x=Float(Double(p.x)+p.vx*dt);p.y=Float(Double(p.y)+p.vy*dt)
   particles[kept]=p;kept:+1
  Next
  count=kept;RefreshBounds()
  If count=0 Then SetProcessing(False)
 End Method
 Rem
 bbdoc: Draws live particles with inherited scene colour and opacity.
 param: Borrowed draw context valid only during this callback; do not retain it.
 End Rem
 Method OnDraw(context:TSceneDrawContext) Override
  For Local i:Int=0 Until count
   Local p:SSceneParticle=particles[i]
   context.SetColor(p.red,p.green,p.blue);context.SetAlpha(Float(1-p.age/p.life))
   If image Then
    DrawSubImageRect(image,p.x-p.size/2,p.y-p.size/2,p.size,p.size,0,0,image.width,image.height)
   Else
    DrawOval(p.x-p.size/2,p.y-p.size/2,p.size,p.size)
   End If
  Next
 End Method
 Rem
 bbdoc: Releases owned CPU slots and the image reference without releasing shared artwork.
 End Rem
 Method OnDestroy() Override
  particles=Null;image=Null;count=0;disposed=True
 End Method
End Type
