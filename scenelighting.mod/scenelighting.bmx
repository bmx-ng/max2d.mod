SuperStrict
Rem
bbdoc: Optional scene light nodes and material-based drawable illumination.
about: Use a TSceneLighting environment per layer, attach point or directional lights and lit receivers to that layer's subtree, then call lighting.Prepare before scene.Render. Objects retain individual receiver materials and painter order. Ordinary scene nodes and HUD layers remain unlit. Max2D.SceneEffects also offers optional lighting of flattened artwork.
End Rem
Module Max2D.SceneLighting
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"
Import Max2D.Scene
Import Max2D.Lighting

Rem
bbdoc: Common scene-node settings for point and directional lights.
about: Colour, intensity, receiver masks and enabled state are independent of inherited visual tint and visibility. Lights must be registered with an environment for their layer. Use TPointLightNode or TDirectionalLightNode.
End Rem
Type TLightNode2D Extends TSceneNode2D Abstract
 Internal
 Field intensity:Float = 1
 Field red:Int = 255, green:Int = 255, blue:Int = 255
 Field mask:Int = -1, enabled:Int = True
 Field shadowSoftness:Float
 Field shadows:Int,shadowResolution:Int=512,shadowMask:Int=-1
 Public
 Rem
 bbdoc: Enables light shadows, choosing mask resolution and a separate caster mask.
 param: True to enable shadow generation for this light, False to disable it.
 param: Shadow-image resolution from 16 to 4096 pixels.
 param: 32-bit caster selection mask; only overlapping caster bits block this light.
 about: Disabled by default. Resolution is 16..4096. Only registered enabled occluders with matching caster bits block this light. Receiver materials can independently bypass shadows. Storage is allocated on first drawing and retained across frames. Disabling shadows releases it at the next environment Prepare; ReleaseResources also releases it. Directional lights require SetShadowBounds before rendering.
 End Rem
 Method SetShadows(enabled:Int=True,resolution:Int=512,casterMask:Int=-1)
  If resolution<16 Or resolution>4096 Then Throw "Max2D SceneLighting: invalid shadow resolution"
  enabled=enabled<>0
  If shadows=enabled And shadowResolution=resolution And shadowMask=casterMask Then Return
  InvalidateContent();shadows=enabled;shadowResolution=resolution;shadowMask=casterMask
 End Method
 Rem
 bbdoc: Sets shadow filter radius in shadow-image pixels, from zero (hard) to 4.
 param: Shadow filter radius from zero to four shadow-image pixels.
 about: Stored independently of whether shadows are enabled. Filtering affects visibility only, preserving projected pattern detail. Width is constant in mask pixels, so its world size scales with point-light diameter or directional bounds size divided by shadow resolution. Blur resources are retained after first use.
 End Rem
 Method SetShadowSoftness(radius:Float)
  If IsNan(radius) Or IsInf(radius) Or radius<0 Or radius>4 Then Throw "Max2D SceneLighting: shadow softness must be 0..4"
  If shadowSoftness=radius Then Return
  InvalidateContent();shadowSoftness=radius
 End Method
 Rem
 bbdoc: Returns the shadow filter radius in shadow-image pixels.
 returns: The shadow filter radius in shadow-image pixels.
 End Rem
 Method GetShadowSoftness:Float()
  Return shadowSoftness
 End Method
 Rem
 bbdoc: Reports whether light shadows are enabled.
 returns: True if light shadows are enabled, False otherwise.
 End Rem
 Method GetShadows:Int()
  Return shadows
 End Method
 Rem
 bbdoc: Returns the square shadow image resolution.
 returns: The square shadow image resolution.
 End Rem
 Method GetShadowResolution:Int()
  Return shadowResolution
 End Method
 Rem
 bbdoc: Returns the mask selecting shadow casters for this light.
 returns: The mask selecting shadow casters for this light.
 End Rem
 Method GetShadowCasterMask:Int()
  Return shadowMask
 End Method

 Rem
 bbdoc: Sets RGB components in 0..255.
 param: Red component in the inclusive range 0..255.
 param: Green component in the inclusive range 0..255.
 param: Blue component in the inclusive range 0..255.
 End Rem
 Method SetColor(r:Int,g:Int,b:Int)
  If r < 0 Or r > 255 Or g < 0 Or g > 255 Or b < 0 Or b > 255 Then Throw "Max2D SceneLighting: invalid light colour"
  InvalidateContent(); red = r; green = g; blue = b
 End Method
 Rem
 bbdoc: Sets finite nonnegative intensity; zero contributes no light.
 param: Finite nonnegative colour multiplier; zero removes this contribution.
 End Rem
 Method SetIntensity(value:Float)
  CheckLightValue(value,False); InvalidateContent(); intensity = value
 End Method
 Rem
 bbdoc: Returns intensity.
 returns: Intensity.
 End Rem
 Method GetIntensity:Float()
  Return intensity
 End Method
 Rem
 bbdoc: Sets the 32-bit mask selecting receivers; default all bits.
 param: 32-bit light-selection mask; zero excludes direct lights and -1 enables all bits.
 End Rem
 Method SetReceiverMask(value:Int)
  InvalidateContent(); mask = value
 End Method
 Rem
 bbdoc: Returns this light's receiver-selection mask.
 returns: This light's receiver-selection mask.
 End Rem
 Method GetReceiverMask:Int()
  Return mask
 End Method
 Rem
 bbdoc: Enables or disables this light independently of node visibility.
 param: True to enable this light or caster, False to disable it without changing ownership.
 End Rem
 Method SetEnabled(value:Int)
  InvalidateContent(); enabled = value <> 0
 End Method
 Rem
 bbdoc: Reports whether this light is enabled.
 returns: True if this light is enabled, False otherwise.
 End Rem
 Method GetEnabled:Int()
  Return enabled
 End Method
End Type

Rem
bbdoc: A positional light whose centre follows its scene transform.
about: Radius is measured in layer-world units; node scale and rotation do not change its circular footprint. Parent transforms move its centre. Register lights with a TSceneLighting environment. Enabled state is explicit and independent of inherited drawing visibility or tint. No image or graphics resource is owned.
End Rem
Type TPointLightNode Extends TLightNode2D
 Internal
 Field radius:Float = 128, falloff:Float = 2, height:Float = 128
 Field texture:TMax2DLightTexture
 Public
 Rem
 bbdoc: Sets a shared projected light pattern; Null restores analytic illumination.
 param: Shared projected pattern; Null restores analytic illumination.
 about: Pattern RGB and alpha multiply direct lighting, including normal/specular response. Placement uses world units relative to this node's world centre, with explicit size, offset and angle independent of parent scale/rotation. Shared edits are observed at the next environment Prepare.
 End Rem
 Method SetTexture(value:TMax2DLightTexture)
  If value And Not value.GetImage() Then Throw "Max2D SceneLighting: uninitialized light texture"
  If texture=value Then Return
  InvalidateContent();texture=value
 End Method
 Rem
 bbdoc: Returns the shared projected light pattern, or Null.
 returns: The shared projected light pattern, or Null.
 End Rem
 Method GetTexture:TMax2DLightTexture()
  Return texture
 End Method
 Rem
 bbdoc: Creates an unattached white point light with positive finite radius.
 param: Finite positive light radius in lighting/world units.
 returns: A new #TPointLightNode instance configured with the supplied settings.
 End Rem
 Function Create:TPointLightNode(radius:Float = 128)
  Local light:TPointLightNode = New TPointLightNode
  light.SetRadius(radius)
  Return light
 End Function
 Rem
 bbdoc: Sets positive finite radius in layer-world units.
 param: Finite positive light radius in layer-world units.
 End Rem
 Method SetRadius(value:Float)
  CheckLightValue(value,True); InvalidateContent(); radius = value
 End Method
 Rem
 bbdoc: Returns radius in layer-world units.
 returns: Radius in layer-world units.
 End Rem
 Method GetRadius:Float()
  Return radius
 End Method
 Rem
 bbdoc: Sets finite nonnegative height above the receiving plane in layer-world units; default 128.
 param: Finite nonnegative light height above the receiving plane in layer-world units.
 about: Height affects diffuse and specular direction, independently of the XY radius and scene node scale. Height also controls shadow projection for finite-height occluders.
 End Rem
 Method SetHeight(value:Float)
  CheckLightValue(value,False)
  If height = value Then Return
  InvalidateContent(); height = value
 End Method
 Rem
 bbdoc: Returns height above receivers.
 returns: Height above receivers.
 End Rem
 Method GetHeight:Float()
  Return height
 End Method
 Rem
 bbdoc: Sets positive finite falloff exponent; one is linear, two quadratic.
 param: Finite positive attenuation exponent; one is linear and two is quadratic.
 End Rem
 Method SetFalloff(value:Float)
  CheckLightValue(value,True); InvalidateContent(); falloff = value
 End Method
 Rem
 bbdoc: Returns the falloff exponent.
 returns: The falloff exponent.
 End Rem
 Method GetFalloff:Float()
  Return falloff
 End Method
End Type

Rem
bbdoc: A light arriving from a constant direction, without distance attenuation.
about: Direction points from the surface toward the light. Its XY components follow the node and parent linear transforms; Z is unchanged before normalization. Translation has no effect, while rotation, reflection, scale and shear can change the direction. A transform that collapses the direction to zero is rejected by environment Prepare. Register this node with its layer's lighting environment. No image or GPU resource is owned.
End Rem
Type TDirectionalLightNode Extends TLightNode2D
 Internal
 Field shadowX:Float,shadowY:Float,shadowWidth:Float,shadowHeight:Float
 Field directionX:Float, directionY:Float = -1, directionZ:Float = 1
 Field directionTransform:TSceneTransform = New TSceneTransform
 Public
 Rem
 bbdoc: Sets the axis-aligned world rectangle covered by this directional light's shadows.
 param: Finite horizontal coordinate in lighting/world units.
 param: Finite vertical coordinate in lighting/world units.
 param: Width in lighting/world units; finite and positive.
 param: Height in lighting/world units; finite and positive.
 about: Required before rendering with shadows enabled. Bounds are explicit world coordinates independent of node translation, rotation, camera and parent transforms. Outside the rectangle the light is unshadowed. A one-mask-pixel guard border transitions to unshadowed illumination. Positive finite dimensions are required. Moving the rectangle reuses shadow images; use this to follow a camera when appropriate.
 End Rem
 Method SetShadowBounds(x:Float,y:Float,width:Float,height:Float)
  CheckDirectionalShadowBounds(x,y,width,height)
  If shadowX=x And shadowY=y And shadowWidth=width And shadowHeight=height Then Return
  InvalidateContent();shadowX=x;shadowY=y;shadowWidth=width;shadowHeight=height
 End Method
 Rem
 bbdoc: Copies directional shadow bounds without allocating a rectangle.
 param: Receives finite horizontal coordinate in lighting/world units.
 param: Receives finite vertical coordinate in lighting/world units.
 param: Receives width in lighting/world units; finite and positive.
 param: Receives height in lighting/world units; finite and positive.
 End Rem
 Method GetShadowBounds(x:Float Var,y:Float Var,width:Float Var,height:Float Var)
  x=shadowX;y=shadowY;width=shadowWidth;height=shadowHeight
 End Method
 Rem
 bbdoc: Creates an unattached white directional light using a finite nonzero vector toward the source.
 param: Horizontal component of the finite, nonzero vector toward the light.
 param: Vertical component of the finite, nonzero vector toward the light.
 param: Depth component of the finite, nonzero vector toward the light.
 returns: A new #TDirectionalLightNode instance configured with the supplied settings.
 End Rem
 Function Create:TDirectionalLightNode(x:Float = 0, y:Float = -1, z:Float = 1)
  Local light:TDirectionalLightNode = New TDirectionalLightNode
  light.SetDirection(x,y,z)
  Return light
 End Function
 Rem
 bbdoc: Sets the local vector toward the light; positive X is right, Y down and Z toward the viewer.
 param: Horizontal component of the finite, nonzero vector toward the light.
 param: Vertical component of the finite, nonzero vector toward the light.
 param: Depth component of the finite, nonzero vector toward the light.
 about: Components must be finite and at least one nonzero. Magnitude does not affect intensity. Scene transforms are applied and the vector is normalized during Prepare. Components are retained exactly for GetDirection.
 End Rem
 Method SetDirection(x:Float,y:Float,z:Float)
  If IsNan(x) Or IsInf(x) Or IsNan(y) Or IsInf(y) Or IsNan(z) Or IsInf(z) Or (x=0 And y=0 And z=0) Then Throw "Max2D SceneLighting: invalid light direction"
  If directionX=x And directionY=y And directionZ=z Then Return
  InvalidateContent(); directionX=x; directionY=y; directionZ=z
 End Method
 Rem
 bbdoc: Copies the authored local direction into caller variables without allocation.
 param: Receives horizontal component of the finite, nonzero vector toward the light.
 param: Receives vertical component of the finite, nonzero vector toward the light.
 param: Receives depth component of the finite, nonzero vector toward the light.
 End Rem
 Method GetDirection(x:Float Var,y:Float Var,z:Float Var)
  x=directionX; y=directionY; z=directionZ
 End Method
End Type

Rem
bbdoc: Invisible polygon shadow caster transformed with its scene parents.
about: Register it with TSceneLighting.SetOccluders. Visual artwork is independent; neither visibility nor inherited tint controls casting. Detached nodes stop casting. Geometry is local to this node; either winding is accepted. Simple concave outlines are supported; holes and self-intersections are not.
End Rem
Type TLightOccluderNode Extends TSceneNode2D
 Internal
 Field localPolygon:TMax2DLightOccluder
 Field worldPolygon:TMax2DLightOccluder
 Field matrix:TSceneTransform=New TSceneTransform
 Field enabled:Int=True
 Public
 Rem
 bbdoc: Creates an unattached occluder from alternating local X,Y coordinates.
 param: Alternating finite X,Y coordinates of a simple polygon with at least three vertices; do not repeat the first vertex.
 returns: A new #TLightOccluderNode instance configured with the supplied settings.
 End Rem
 Function Create:TLightOccluderNode(points:Float[])
  Local result:TLightOccluderNode=New TLightOccluderNode
  result.SetPolygon(points)
  Return result
 End Function
 Rem
 bbdoc: Replaces local simple polygon geometry, copying and validating all coordinates before replacement.
 param: Alternating finite X,Y coordinates of a simple polygon with at least three vertices; do not repeat the first vertex.
 End Rem
 Method SetPolygon(points:Float[])
  Local candidate:TMax2DLightOccluder=TMax2DLightOccluder.Create(points)
  Local mask:Int=-1
  Local height:Float=-1
  If worldPolygon Then mask=worldPolygon.GetCasterMask();height=worldPolygon.GetHeight()
  localPolygon=candidate;worldPolygon=TMax2DLightOccluder.Create(points)
  worldPolygon.SetCasterMask(mask);worldPolygon.SetHeight(height);InvalidateContent()
 End Method
 Rem
 bbdoc: Sets caster height above Z=0 in world units, or -1 for infinite height (default).
 param: Height in lighting/world units; -1 means infinite caster height.
 about: Independent of node and parent transforms. Zero blocks only the footprint. See TMax2DLightOccluder.SetHeight for projection rules.
 End Rem
 Method SetHeight(value:Float)
  worldPolygon.SetHeight(value)
 End Method
 Rem
 bbdoc: Returns caster height, or -1 for infinite height.
 returns: Caster height, or -1 for infinite height.
 End Rem
 Method GetHeight:Float()
  Return worldPolygon.GetHeight()
 End Method
 Rem
 bbdoc: Selects the 32-bit caster mask independently of light receiver masks.
 param: 32-bit caster-selection mask; -1 enables all bits.
 End Rem
 Method SetCasterMask(value:Int)
  worldPolygon.SetCasterMask(value)
 End Method
 Rem
 bbdoc: Enables or disables casting; default True.
 param: True to enable this light or caster, False to disable it without changing ownership.
 End Rem
 Method SetEnabled(value:Int)
  enabled=value<>0
 End Method
 Rem
 bbdoc: Reports whether casting is enabled, independently of scene attachment.
 returns: True if casting is enabled, independently of scene attachment, False otherwise.
 End Rem
 Method GetEnabled:Int()
  Return enabled
 End Method
 Rem
 bbdoc: Returns the caster selection mask.
 returns: The caster selection mask.
 End Rem
 Method GetCasterMask:Int()
  Return worldPolygon.GetCasterMask()
 End Method
 Internal
 Method Synchronize()
  If Not Scene() Then
   worldPolygon.SetEnabled(False)
   Return
  End If
  CopyWorldTransform(matrix)
  worldPolygon.SetTransformFrom(localPolygon,matrix.xx,matrix.xy,matrix.yx,matrix.yy,matrix.tx,matrix.ty)
  worldPolygon.SetEnabled(enabled And matrix.xx*matrix.yy-matrix.xy*matrix.yx<>0)
 End Method
End Type

Rem
bbdoc: Shared lighting environment for one scene layer, with explicit preparation before rendering.
about: Retains registered light nodes and tracks lit drawable dependencies. Prepare resolves world positions and directions and invalidates affected cached artwork after light, material or receiver-placement changes. Call after all movement/material edits and before each scene.Render, including renders without Update. No graphics context or textures are needed by preparation. Per-object drawing supports optional grouped lighting and combined ambient through SetLightBatching, with SetLightBatchLimit controlling the requested group size. Destroying the scene detaches receivers; registered light references remain until SetLights or the environment is released by the application.
End Rem
Type TSceneLighting
 Internal
 Field layer:TLayerNode
 Field lights:TLightNode2D[]
 Field occluders:TLightOccluderNode[]
 Field polygons:TMax2DLightOccluder[]
 Field receivers:TLitNode[]
 Field receiverCount:Int
 Field processor:TMax2DLighting = TMax2DLighting.Create()
 Field appliedRevision:Long = -1
 Public
 Rem
 bbdoc: Creates an environment associated with a nonnull layer and white ambient illumination.
 param: Required layer whose world coordinates define this lighting environment.
 returns: A new #TSceneLighting instance configured with the supplied settings.
 End Rem
 Function Create:TSceneLighting(layer:TLayerNode)
  If Not layer Then Throw "Max2D SceneLighting: layer is null"
  Local result:TSceneLighting = New TSceneLighting
  result.layer = layer
  Return result
 End Function
 Rem
 bbdoc: Copies an ordered light list, rejecting null or duplicate entries.
 param: Ordered borrowed light nodes; the array is copied and Null clears it.
 about: Accepts point and directional nodes through their common TLightNode2D base. Lights attached beneath a different layer are rejected by Prepare. Detached lights contribute nothing until attached to this layer. Sharing lights between environments does not transfer tree ownership.
 End Rem
 Method SetLights(values:TLightNode2D[])
  For Local i:Int = 0 Until values.Length
   If Not values[i] Then Throw "Max2D SceneLighting: null light"
   If Not TPointLightNode(values[i]) And Not TDirectionalLightNode(values[i]) Then Throw "Max2D SceneLighting: unsupported light node"
   For Local j:Int = 0 Until i
    If values[i] = values[j] Then Throw "Max2D SceneLighting: duplicate light"
   Next
  Next
  lights = values[..]; processor.SetLightCount(lights.Length)
  appliedRevision = -1
 End Method
 Rem
 bbdoc: Copies the list of scene occluders used by shadow-enabled lights.
 param: Borrowed occluder nodes; the array is copied and Null clears it.
 about: Null clears the list. Null, uninitialized and duplicate nodes are rejected. Prepare checks that attached casters belong to this environment's layer.
 End Rem
 Method SetOccluders(values:TLightOccluderNode[])
  For Local i:Int=0 Until values.Length
   If Not values[i] Or Not values[i].worldPolygon Then Throw "Max2D SceneLighting: invalid occluder"
   For Local j:Int=0 Until i
    If values[i]=values[j] Then Throw "Max2D SceneLighting: duplicate occluder"
   Next
  Next
  occluders=values[..];polygons=New TMax2DLightOccluder[values.Length]
  For Local i:Int=0 Until values.Length
   polygons[i]=values[i].worldPolygon
  Next
  processor.SetOccluders(polygons)
 End Method
 Rem
 bbdoc: Enables optional spatial selection for receivers in this environment.
 param: True to enable spatial selection of receiver lights, False to disable it.
 about: See TMax2DLighting.SetSpatialSelection. Disabled by default; unchanged scene caches are preserved because rendering output does not change.
 End Rem
 Method SetSpatialSelection(enabled:Int)
  processor.SetSpatialSelection(enabled)
 End Method
 Rem
 bbdoc: Returns whether spatial receiver selection is enabled.
 returns: Whether spatial receiver selection is enabled.
 End Rem
 Method GetSpatialSelection:Int()
  Return processor.GetSpatialSelection()
 End Method

 Rem
 bbdoc: Enables optional grouped direct-light drawing; default False.
 param: True to enable grouped direct-light drawing, False to disable it.
 about: See TMax2DLighting.SetLightBatching for eligibility and fallback rules. Cached scene output refreshes at the next Prepare.
 End Rem
 Method SetLightBatching(enabled:Int)
  processor.SetLightBatching(enabled)
 End Method
 Rem
 bbdoc: Returns whether optional grouped direct-light drawing is enabled.
 returns: Whether optional grouped direct-light drawing is enabled.
 End Rem
 Method GetLightBatching:Int()
  Return processor.GetLightBatching()
 End Method
 Rem
 bbdoc: Sets the maximum direct lights per group; default 16.
 param: Positive maximum direct lights per submitted group; the provider may use a smaller capacity.
 about: See TMax2DLighting.SetLightBatchLimit. The renderer may use a smaller capacity. Changes refresh cached scene output at the next Prepare.
 End Rem
 Method SetLightBatchLimit(maximum:Int)
  processor.SetLightBatchLimit(maximum)
 End Method
 Rem
 bbdoc: Returns the requested maximum lights per group.
 returns: The requested maximum lights per group.
 End Rem
 Method GetLightBatchLimit:Int()
  Return processor.GetLightBatchLimit()
 End Method
 Rem
 bbdoc: Enables CPU-side stage timings for draws using this lighting environment.
 param: True to collect timings in lighting statistics. Defaults to False.
 End Rem
 Method SetStageTiming(enabled:Int)
  processor.SetStageTiming(enabled)
 End Method
 Rem
 bbdoc: Clears cumulative lighting work counters without invalidating scene caches.
 about: Scene Prepare does not reset these counters. Reset before the interval being measured; cached scene receivers may produce no lighting work. See TMax2DLightingStats for counter definitions.
 End Rem
 Method ResetStats()
  processor.ResetStats()
 End Method
 Rem
 bbdoc: Copies cumulative lighting work counters and shadow memory into reusable storage.
 param: Required reusable destination lighting-statistics snapshot.
 about: Scene Prepare does not reset these counters. Reset before the interval being measured; cached scene receivers may produce no lighting work. See TMax2DLightingStats for counter definitions.
 End Rem
 Method CopyStats(output:TMax2DLightingStats)
  processor.CopyStats(output)
 End Method
 Rem
 bbdoc: Allocates a snapshot of cumulative lighting counters and current shadow storage.
 returns: A new independent statistics snapshot.
 about: Scene Prepare does not reset these counters. Reset before the interval being measured; cached scene receivers may produce no lighting work. See TMax2DLightingStats for counter definitions.
 End Rem
 Method CaptureStats:TMax2DLightingStats()
  Return processor.CaptureStats()
 End Method
 Rem
 bbdoc: Releases retained lighting images while preserving lights, occluders and receiver registrations.
 about: Call before closing the graphics context. Subsequent drawing lazily recreates shadow storage.
 End Rem
 Method ReleaseResources()
  processor.Release()
 End Method
 Rem
 bbdoc: Sets ambient RGB (0..255) and finite nonnegative intensity.
 param: Red component in the inclusive range 0..255.
 param: Green component in the inclusive range 0..255.
 param: Blue component in the inclusive range 0..255.
 param: Finite nonnegative colour multiplier; zero removes this contribution.
 End Rem
 Method SetAmbient(red:Int,green:Int,blue:Int,intensity:Float = 1)
  processor.SetAmbient(red,green,blue,intensity)
 End Method
 Rem
 bbdoc: Resolves light positions, directions and material dependencies before scene rendering, without per-frame arrays or textures.
 about: Prepare all environments after movement and before rendering. Changes to a light invalidate registered receivers; unchanged frames preserve automatic composite caches. Receiver transforms are tracked even when an enclosing cached group moves. This explicit boundary also permits applications to synchronize ECS-driven lights before rendering.
 End Rem
 Method Prepare()
  Local replaced:Int
  For Local i:Int=0 Until occluders.Length
   Local node:TLightOccluderNode=occluders[i]
   If node.Scene() And LightingLayer(node)<>layer Then Throw "Max2D SceneLighting: occluder belongs to another layer"
   node.Synchronize()
   If polygons[i]<>node.worldPolygon Then polygons[i]=node.worldPolygon;replaced=True
  Next
  If replaced Then processor.SetOccluders(polygons)
  For Local i:Int = 0 Until lights.Length
   Local light:TLightNode2D = lights[i]
   Local energy:Float
   If light.Scene() Then
    If LightingLayer(light) <> layer Then Throw "Max2D SceneLighting: light belongs to another layer"
    If light.enabled Then energy = light.intensity
   End If
   Local point:TPointLightNode = TPointLightNode(light)
   If point Then
    Local x:Float,y:Float
    If light.Scene() And Not point.LocalToWorld(0,0,x,y) Then Throw "Max2D SceneLighting: light position overflow"
    processor.SetPointLight(i,x,y,point.radius,light.red,light.green,light.blue,energy,point.falloff)
    processor.SetLightHeight(i,point.height)
    processor.SetLightTexture(i,point.texture)
    processor.SetLightShadows(i,point.shadows,point.shadowResolution,point.shadowMask)
    If point.shadows Then processor.SetLightShadowSoftness(i,point.shadowSoftness)
   Else
    Local sun:TDirectionalLightNode = TDirectionalLightNode(light)
    Local x:Double = sun.directionX, y:Double = sun.directionY, z:Double = sun.directionZ
    If light.Scene() Then
     sun.CopyWorldTransform(sun.directionTransform)
     Local t:TSceneTransform = sun.directionTransform
     x = t.xx*sun.directionX+t.xy*sun.directionY
     y = t.yx*sun.directionX+t.yy*sun.directionY
    End If
    If IsNan(x) Or IsInf(x) Or IsNan(y) Or IsInf(y) Then Throw "Max2D SceneLighting: nonfinite light direction"
    Local magnitude:Double = Max(Abs(x),Max(Abs(y),Abs(z)))
    If IsNan(magnitude) Or IsInf(magnitude) Or magnitude=0 Then Throw "Max2D SceneLighting: collapsed or nonfinite light direction"
    processor.SetLightTexture(i,Null)
    processor.SetDirectionalLight(i,Float(x/magnitude),Float(y/magnitude),Float(z/magnitude),light.red,light.green,light.blue,energy)
    processor.SetLightShadows(i,sun.shadows,sun.shadowResolution,sun.shadowMask)
    If sun.shadows Then
     processor.SetDirectionalShadowBounds(i,sun.shadowX,sun.shadowY,sun.shadowWidth,sun.shadowHeight)
     processor.SetLightShadowSoftness(i,sun.shadowSoftness)
    End If
   End If
   processor.SetLightMask(i,light.mask)
  Next
  Local changed:Int = appliedRevision <> processor.Revision()
  For Local i:Int = 0 Until receiverCount
   Local node:TLitNode = receivers[i]
   If Not node.Scene() Then Continue
   If LightingLayer(node) <> layer Then Throw "Max2D SceneLighting: receiver belongs to another layer"
   node.CopyWorldTransform(node.pendingTransform)
   Local a:TSceneTransform = node.transform, b:TSceneTransform = node.pendingTransform
   If changed Or node.materialRevision <> node.material.Revision() Or a.xx <> b.xx Or a.xy <> b.xy Or a.yx <> b.yx Or a.yy <> b.yy Or a.tx <> b.tx Or a.ty <> b.ty Then
    node.InvalidateContent()
    node.materialRevision = node.material.Revision()
    node.transform = b; node.pendingTransform = a
   End If
  Next
  appliedRevision = processor.Revision()
 End Method
 Internal
 Method AddReceiver(node:TLitNode)
  If receiverCount = receivers.Length Then receivers = receivers[..Max(8,receiverCount*2)]
  receivers[receiverCount] = node; receiverCount :+ 1
 End Method
 Method RemoveReceiver(node:TLitNode)
  For Local i:Int = 0 Until receiverCount
   If receivers[i] <> node Then Continue
   receiverCount :- 1; receivers[i] = receivers[receiverCount]; receivers[receiverCount] = Null
   Return
  Next
 End Method
End Type

Rem
bbdoc: Shared scene receiver material, environment and placement for lit drawables.
about: Subclasses initialize once before attachment and draw through DrawLitImage. Call the environment's Prepare after edits and before rendering. Children are independent scene drawables and do not inherit lighting automatically.
End Rem
Type TLitNode Extends TCustomDrawNode Abstract
 Internal
 Field lighting:TSceneLighting
 Field material:TMax2DLightingMaterial
 Field materialRevision:Long = -1
 Field transform:TSceneTransform = New TSceneTransform
 Field pendingTransform:TSceneTransform = New TSceneTransform
 Public
 Rem
 bbdoc: Initializes a receiver once, before attachment, with a required environment.
 param: Required scene lighting environment associated with the receiver layer.
 param: Optional shared material; Null uses default lighting settings.
 about: A null material creates a default material. Subclasses call this during construction.
 End Rem
 Method InitializeLighting(value:TSceneLighting,material:TMax2DLightingMaterial=Null)
  If Not value Then Throw "Max2D SceneLighting: environment is null"
  If lighting Or Scene() Then Throw "Max2D SceneLighting: receiver already initialized or attached"
  If Not material Then material=TMax2DLightingMaterial.Create()
  lighting=value;Self.material=material
 End Method
 Rem
 bbdoc: References a nonnull shared receiver material.
 param: Required shared lighting material; ownership remains with the application.
 End Rem
 Method SetMaterial(value:TMax2DLightingMaterial)
  If Not value Then Throw "Max2D SceneLighting: material is null"
  InvalidateContent(); material = value; materialRevision = -1
 End Method
 Rem
 bbdoc: Returns the shared receiver material.
 returns: The shared receiver material.
 End Rem
 Method GetMaterial:TMax2DLightingMaterial()
  Return material
 End Method
 Rem
 bbdoc: Registers this attached receiver with its lighting environment.
 End Rem
 Method OnEnterScene() Override
  If Not lighting Then Throw "Max2D SceneLighting: initialize receiver before attachment"
  lighting.AddReceiver(Self)
 End Method
 Rem
 bbdoc: Removes this detached receiver from dependency tracking.
 End Rem
 Method OnExitScene() Override
  If lighting Then lighting.RemoveReceiver(Self)
 End Method
 Rem
 bbdoc: Draws an image at this receiver's local origin using its prepared material and world transform.
 param: Borrowed image; its lifetime remains application-owned.
 param: Zero-based frame index in the supplied image.
 about: Intended for subclass OnDraw callbacks. The image handle determines its local placement. The image is borrowed. Unlit materials use ordinary drawing.
 End Rem
 Method DrawLitImage(image:TImage,frame:Int=0)
  If Not image Then Return
  If material.GetUnlit() Then
   DrawImage(image,0,0,frame)
  Else
   lighting.processor.DrawImage(image,0,0,frame,material.GetReceiverMask(),Float(transform.xx),Float(transform.xy),Float(transform.yx),Float(transform.yy),Float(transform.tx),Float(transform.ty),material)
  End If
 End Method
 Rem
 bbdoc: Draws textured mesh geometry using this receiver's prepared placement and material.
 param: Borrowed triangle mesh with finite positions and valid UVs and indices.
 param: Borrowed image; its lifetime remains application-owned.
 param: Zero-based frame index in the supplied image.
 about: Intended for subclass OnDraw callbacks. Image handles are ignored. Lit triangles require nonsingular UV mappings. Capable providers can submit compatible mesh geometry in grouped lighting passes; unsupported combinations use ordered fallback drawing.
 End Rem
 Method DrawLitMesh(mesh:TMesh2D,image:TImage,frame:Int=0)
  lighting.processor.DrawMesh(mesh,image,0,0,frame,material.GetReceiverMask(),Float(transform.xx),Float(transform.xy),Float(transform.yx),Float(transform.yy),Float(transform.tx),Float(transform.ty),material)
 End Method

End Type

Rem
bbdoc: An individually lit sprite with a shared receiver material and environment.
about: Keeps painter order, per-object alpha and lighting coordinates before composition. Ordinary TSpriteNode remains unlit. Image and material are shared, not owned. Register light nodes through the environment and call its Prepare after movement/material edits, before rendering. Supports ordinary images and trimmed byte atlas frames under the coordinate shader contract.
End Rem
Type TLitSpriteNode Extends TLitNode
 Internal
 Field image:TImage
 Field frame:Int
 Public
 Rem
 bbdoc: Creates an unattached sprite referencing a required lighting environment and optional shared material.
 param: Borrowed image; its lifetime remains application-owned.
 param: Required lighting environment for the receiver's layer.
 param: Optional shared material; Null uses default lighting settings.
 returns: A new #TLitSpriteNode instance configured with the supplied settings.
 about: A null material creates a default lit material. Image may be null.
 End Rem
 Function Create:TLitSpriteNode(image:TImage,lighting:TSceneLighting,material:TMax2DLightingMaterial = Null)
  If Not lighting Then Throw "Max2D SceneLighting: environment is null"
  Local result:TLitSpriteNode = New TLitSpriteNode
  result.InitializeLighting(lighting,material)
  result.SetImage(image)
  Return result
 End Function
 Rem
 bbdoc: References an image and resets frame zero; does not release the previous image.
 param: Borrowed image; replacing it does not release the previous image.
 End Rem
 Method SetImage(value:TImage)
  InvalidateContent(); image = value; frame = 0
 End Method
 Rem
 bbdoc: Selects an existing image frame.
 param: Zero-based index of an existing image frame.
 End Rem
 Method SetFrame(value:Int)
  If value < 0 Then Throw "Max2D SceneLighting: negative frame"
  If image Then
   If value >= image.sources.Length Then Throw "Max2D SceneLighting: frame out of range"
  Else
   If value <> 0 Then Throw "Max2D SceneLighting: null image requires frame zero"
  End If
  InvalidateContent(); frame = value
 End Method
 Rem
 bbdoc: Reports image bounds, respecting its shared handle.
 param: Required reusable rectangle receiving local bounds when the result is True.
 returns: True when bounds are known and written to the destination; False when unknown.
 End Rem
 Method GetSelfBounds:Int(bounds:TSceneRect) Override
  If Not bounds Then Throw "Max2D SceneLighting: bounds destination is null"
  Super.GetSelfBounds(bounds)
  If Not image Then
   bounds.x = 0; bounds.y = 0; bounds.width = 0; bounds.height = 0
   Return True
  End If
  bounds.x = -image.handle_x; bounds.y = -image.handle_y; bounds.width = image.width; bounds.height = image.height
  Return True
 End Method
 Rem
 bbdoc: Draws using prepared world placement and material settings; invoked by the scene renderer.
 param: Borrowed draw context valid only during this callback; do not retain it.
 End Rem
 Method OnDraw(context:TSceneDrawContext) Override
  DrawLitImage(image,frame)
 End Method
End Type

Include "canvas.bmx"
Include "mesh.bmx"

Private
Function CheckLightValue(value:Float,positive:Int)
 If IsNan(value) Or IsInf(value) Or value < 0 Or (positive And value = 0) Then Throw "Max2D SceneLighting: invalid light value"
End Function
Function LightingLayer:TLayerNode(node:TSceneNode)
 While node
  If TLayerNode(node) Then Return TLayerNode(node)
  node = node.Parent()
 Wend
 Return Null
End Function
