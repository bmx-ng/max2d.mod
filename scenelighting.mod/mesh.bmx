Rem
bbdoc: A textured mesh receiver with a shared lighting environment and material.
about: Borrows geometry and artwork. Call InvalidateContent after editing shared positions, UVs or image content, and prepare the environment before rendering. Image handles are ignored. Lit triangles require nonsingular UV mappings. Supports grouped lights per triangle when the environment enables batching and its provider accepts mesh geometry.
End Rem
Type TLitMeshNode Extends TLitNode
 Private
 Field mesh:TMesh2D
 Field image:TImage
 Field frame:Int
 Public
 Rem
 bbdoc: Creates an unattached mesh receiver; null geometry or artwork draws nothing.
 param: Borrowed triangle mesh with finite positions and valid UVs and indices.
 param: Borrowed image; its lifetime remains application-owned.
 param: Required lighting environment for the receiver's layer.
 param: Optional shared material; Null uses default lighting settings.
 returns: A new #TLitMeshNode instance configured with the supplied settings.
 End Rem
 Function Create:TLitMeshNode(mesh:TMesh2D,image:TImage,lighting:TSceneLighting,material:TMax2DLightingMaterial=Null)
  Local result:TLitMeshNode=New TLitMeshNode
  result.InitializeLighting(lighting,material)
  result.SetMesh(mesh);result.SetImage(image)
  Return result
 End Function
 Rem
 bbdoc: References shared geometry without taking ownership.
 param: Borrowed mesh geometry; Null disables geometry drawing.
 End Rem
 Method SetMesh(value:TMesh2D)
  InvalidateContent();mesh=value
 End Method
 Rem
 bbdoc: References shared artwork and resets its frame to zero.
 param: Borrowed image; replacing it does not release the previous image.
 End Rem
 Method SetImage(value:TImage)
  InvalidateContent();image=value;frame=0
 End Method
 Rem
 bbdoc: Selects an existing artwork frame.
 param: Zero-based index of an existing image frame.
 End Rem
 Method SetFrame(value:Int)
  If value<0 Then Throw "Max2D SceneLighting: negative frame"
  If image Then
   image.CheckIndex(value)
  Else If value<>0 Then
   Throw "Max2D SceneLighting: null image requires frame zero"
  End If
  InvalidateContent();frame=value
 End Method
 Rem
 bbdoc: Reports local geometry bounds, ignoring the image handle.
 param: Required reusable rectangle receiving local bounds when the result is True.
 returns: True when bounds are known and written to the destination; False when unknown.
 End Rem
 Method GetSelfBounds:Int(bounds:TSceneRect) Override
  If Not bounds Then Throw "Max2D SceneLighting: bounds destination is null"
  Super.GetSelfBounds(bounds)
  bounds.x=0;bounds.y=0;bounds.width=0;bounds.height=0
  If Not mesh Or Not image Then Return True
  If mesh.xy.Length<2 Then Return True
  Local left:Float=mesh.xy[0],right:Float=left,top:Float=mesh.xy[1],bottom:Float=top
  For Local i:Int=2 Until mesh.xy.Length-1 Step 2
   left=Min(left,mesh.xy[i]);right=Max(right,mesh.xy[i])
   top=Min(top,mesh.xy[i+1]);bottom=Max(bottom,mesh.xy[i+1])
  Next
  bounds.x=left;bounds.y=top;bounds.width=right-left;bounds.height=bottom-top
  Return True
 End Method
 Rem
 bbdoc: Draws with the prepared lighting environment; invoked by the scene renderer.
 param: Borrowed draw context valid only during this callback; do not retain it.
 End Rem
 Method OnDraw(context:TSceneDrawContext) Override
  DrawLitMesh(mesh,image,frame)
 End Method
End Type
