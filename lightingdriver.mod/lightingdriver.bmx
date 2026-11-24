SuperStrict
Rem
bbdoc: Optional renderer contract for grouped Max2D lighting.
End Rem
Module Max2D.LightingDriver
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"
Import Max2D.Core

Rem
bbdoc: Immutable limits for one renderer's lighting submission.
about: Limits describe groups, not the total scene light count. Supports still checks the actual material, lights and drawing target. No shader parameter layout or texture-slot count is imposed by this interface.
End Rem
Type TMax2DLightingCapabilities
 Private
 Field minimum:Int,maximum:Int
 Field normals:Int,specular:Int,directional:Int,patterns:Int,shadows:Int,ambient:Int,specularMaps:Int,meshes:Int
 Field affineMeshes:Int,deformedMeshes:Int,mappedEmission:Int,mappedSpecular:Int
 Public
 Rem
 bbdoc: Creates validated renderer limits and supported feature categories.
 param: Positive minimum number of lights accepted in a native group.
 param: Maximum lights per group; must be at least minimum.
 param: True if the provider can support normal maps, False otherwise.
 param: True if the provider can support specular highlights, False otherwise.
 param: True if the provider can support directional lights, False otherwise.
 param: True if the provider can support projected light patterns, False otherwise.
 param: True if the provider can support occluder shadows, False otherwise.
 param: True if the provider can support ambient composition in the first light group, False otherwise.
 param: True if the provider can support packed specular-strength maps, False otherwise.
 param: True if the provider can support mesh drawing, False otherwise.
 param: True if the provider can support grouped affine mesh sections, False otherwise.
 param: True if the provider can support grouped deformed meshes, False otherwise.
 param: True if the provider can support independent emission maps, False otherwise.
 param: True if the provider can support independent specular maps, False otherwise.
 returns: A new #TMax2DLightingCapabilities instance configured with the supplied settings.
 about: Light counts must be positive and maximum must be at least minimum. Feature flags are upper bounds; Supports may reject particular combinations. Optional ambient, specular-map, mesh, affine-mesh, deformed-mesh and mapped-emission support default to False for compatibility. Affine-mesh support requires mesh support; deformed-mesh support requires affine-mesh support. Mapped emission requires ambient composition. Independent mapped specular support defaults to False and requires specular support.
 End Rem
 Function Create:TMax2DLightingCapabilities(minimum:Int,maximum:Int,normals:Int=False,specular:Int=False,directional:Int=False,patterns:Int=False,shadows:Int=False,ambient:Int=False,specularMaps:Int=False,meshes:Int=False,affineMeshes:Int=False,deformedMeshes:Int=False,mappedEmission:Int=False,mappedSpecular:Int=False)
  If minimum<1 Or maximum<minimum Then Throw "Max2D Lighting: invalid renderer light limits"
  If affineMeshes And Not meshes Then Throw "Max2D Lighting: affine meshes require mesh geometry support"
  If deformedMeshes And Not affineMeshes Then Throw "Max2D Lighting: deformed meshes require affine mesh support"
  If mappedSpecular And Not specular Then Throw "Max2D Lighting: mapped specular requires specular support"
  If mappedEmission And Not ambient Then Throw "Max2D Lighting: mapped emission requires ambient composition"
  Local result:TMax2DLightingCapabilities=New TMax2DLightingCapabilities
  result.minimum=minimum;result.maximum=maximum
  result.normals=normals<>0;result.specular=specular<>0;result.directional=directional<>0
  result.patterns=patterns<>0;result.shadows=shadows<>0;result.ambient=ambient<>0;result.specularMaps=specularMaps<>0;result.meshes=meshes<>0
  result.affineMeshes=affineMeshes<>0;result.deformedMeshes=deformedMeshes<>0;result.mappedEmission=mappedEmission<>0;result.mappedSpecular=mappedSpecular<>0
  Return result
 End Function
 Rem
 bbdoc: Returns the minimum number of lights accepted in a group.
 returns: The minimum number of lights accepted in a group.
 End Rem
 Method MinimumLights:Int();Return minimum;End Method
 Rem
 bbdoc: Returns the maximum number of lights accepted in a group.
 returns: The maximum number of lights accepted in a group.
 End Rem
 Method MaximumLights:Int();Return maximum;End Method
 Rem
 bbdoc: Reports normal-map support, subject to Supports for the requested combination.
 returns: True when this feature is supported, subject to Supports for each requested combination; False otherwise.
 End Rem
 Method NormalMaps:Int();Return normals;End Method
 Rem
 bbdoc: Reports specular support, subject to Supports for the requested combination.
 returns: True when this feature is supported, subject to Supports for each requested combination; False otherwise.
 End Rem
 Method Specular:Int();Return specular;End Method
 Rem
 bbdoc: Reports support for normal-map alpha modulating specular strength; default False.
 returns: True when this feature is supported, subject to Supports for each requested combination; False otherwise.
 End Rem
 Method SpecularMaps:Int();Return specularMaps;End Method
 Rem
 bbdoc: Reports independent specular-map sampling support; default False.
 returns: True when this feature is supported, subject to Supports for each requested combination; False otherwise.
 about: Requires Specular. Supports may reject individual combinations. Providers without this capability receive retained CPU-packed normal alpha where supported. This is separate from SpecularMaps, which describes normal-alpha modulation.
 End Rem
 Method MappedSpecular:Int();Return mappedSpecular;End Method
 Rem
 bbdoc: Reports directional-light support, subject to Supports for the requested combination.
 returns: True when this feature is supported, subject to Supports for each requested combination; False otherwise.
 End Rem
 Method DirectionalLights:Int();Return directional;End Method
 Rem
 bbdoc: Reports projected-pattern support, subject to Supports for the requested combination.
 returns: True when this feature is supported, subject to Supports for each requested combination; False otherwise.
 End Rem
 Method ProjectedPatterns:Int();Return patterns;End Method
 Rem
 bbdoc: Reports shadow support, subject to Supports for the requested combination.
 returns: True when this feature is supported, subject to Supports for each requested combination; False otherwise.
 End Rem
 Method Shadows:Int();Return shadows;End Method
 Rem
 bbdoc: Reports support for composing ambient and receiver coverage in the first group.
 returns: True when this feature is supported, subject to Supports for each requested combination; False otherwise.
 about: False by default for existing providers. A request with includeAmbient requires ordinary alpha composition; subsequent groups preserve destination alpha.
 End Rem
 Method AmbientComposition:Int();Return ambient;End Method
 Rem
 bbdoc: Reports support for independent emission-map sampling during ambient composition; default False.
 returns: True when this feature is supported, subject to Supports for each requested combination; False otherwise.
 about: Requires AmbientComposition. Supports may reject combinations with other material/light maps. Direct-only groups ignore emission fields.
 End Rem
 Method MappedEmission:Int();Return mappedEmission;End Method
 Rem
 bbdoc: Reports support for borrowed textured mesh geometry; default False.
 returns: True when this feature is supported, subject to Supports for each requested combination; False otherwise.
 about: Mesh draws use the supplied UV-to-lighting affine basis and drawing position, ignoring image handles. Geometry must be consumed before Draw returns.
 End Rem
 Method MeshGeometry:Int();Return meshes;End Method
 Rem
 bbdoc: Reports support for multiple non-overlapping triangles sharing one affine UV-to-geometry mapping; default False.
 returns: True when this feature is supported, subject to Supports for each requested combination; False otherwise.
 about: Requires MeshGeometry. The processor verifies the shared basis and disjoint interiors. Providers must draw all supplied indices and consume borrowed arrays before returning. Existing mesh providers receive only single triangles unless they opt in.
 End Rem
 Method AffineMeshGeometry:Int();Return affineMeshes;End Method
 Rem
 bbdoc: Reports support for non-overlapping triangles with independent UV mappings; default False.
 returns: True when this feature is supported, subject to Supports for each requested combination; False otherwise.
 about: Requires AffineMeshGeometry. A deformed request supplies a geometry-to-lighting transform instead of an image-to-lighting basis. Supports may reject singular drawing transforms.
 End Rem
 Method DeformedMeshGeometry:Int();Return deformedMeshes;End Method
End Type

Rem
bbdoc: Borrowed direct-light description supplied to a lighting renderer.
about: Provider integration only. The processor owns and reuses these records; providers must not modify or retain them. Position/direction, radius and height use lighting coordinates. Colour is normalized RGB with a separate nonnegative intensity. map is a resolved shadow/pattern image supplied only for Draw; Supports uses hasMap, shadowed, patterned and mapWidth/mapHeight instead. Dimensions, mapFormat and mapFlags describe resolved map storage before its image is prepared. mapXX through mapTY transform lighting coordinates into normalized map coordinates. mapKey is an opaque cache identity that providers may retain independently of the borrowed record; mapRevision changes when its pixels change, independently of placement. Both are supplied only for Draw. Cache entries must also compare image and frame. mapClamp selects edge clamping for directional shadows; other maps are transparent outside their bounds.
End Rem
Type TMax2DLightingDrawLight
 Rem
 bbdoc: Light kind and shadow/pattern feature flags.
 about: directional selects a direction vector instead of a point position. shadowed and patterned identify requested features; hasMap indicates that Draw will receive a resolved map. These flags are available during Supports.
 End Rem
 Field directional:Int,shadowed:Int,patterned:Int,hasMap:Int
 Rem
 bbdoc: Light position or direction and point-light attenuation parameters.
 about: For point lights, x/y are the centre in lighting coordinates, radius is positive, height is nonnegative and falloff is a positive exponent. For directional lights, x/y/z form the normalized vector toward the light; point attenuation fields are unused.
 End Rem
 Field x:Float,y:Float,z:Float,radius:Float,height:Float,falloff:Float
 Rem
 bbdoc: Normalized light RGB and its separate intensity.
 about: RGB components are 0..1; intensity is finite and nonnegative. Multiply them to obtain the direct-light colour.
 End Rem
 Field red:Float,green:Float,blue:Float,intensity:Float
 Rem
 bbdoc: Resolved shadow/pattern image, frame and edge policy for Draw.
 about: map is borrowed and is not resolved during Supports. mapFrame is zero-based. mapClamp selects clamping for directional shadow maps; other maps contribute no light outside their normalized rectangle.
 End Rem
 Field map:TImage,mapFrame:Int,mapClamp:Int
 Rem
 bbdoc: Opaque map-cache identity and pixel revision supplied for Draw.
 about: Providers may retain mapKey independently of this record. Cache reuse must also compare image, frame and mapRevision; placement changes are represented by the affine mapping rather than the pixel revision.
 End Rem
 Field mapKey:Object,mapRevision:Long
 Rem
 bbdoc: Expected map dimensions, pixel format and image flags.
 about: Available during Supports before the map image is prepared. Dimensions are pixels; format and flags use the ordinary Max2D image constants.
 End Rem
 Field mapWidth:Int,mapHeight:Int,mapFormat:Int,mapFlags:Int
 Rem
 bbdoc: Affine conversion from lighting coordinates to normalized map UVs.
 about: u=mapXX*x+mapXY*y+mapTX and v=mapYX*x+mapYY*y+mapTY. Placement is independent of the cached map pixel revision.
 End Rem
 Field mapXX:Float,mapXY:Float,mapYX:Float,mapYY:Float,mapTX:Float,mapTY:Float
End Type

Rem
bbdoc: Reusable receiver and ordered light group for renderer integration.
about: Providers must treat all fields and referenced arrays as borrowed read-only data. Only the first count light records are active. The affine coefficients transform source-local coordinates into lighting coordinates, independently of camera/drawing transforms. A nonnull mesh requires MeshGeometry capability: draw it at x/y using normalized UVs and the current drawing handle, ignoring the image handle. Its source-pixel-to-lighting basis includes geometry placement and the drawing handle already. When deformed is False, a request uses one affine UV mapping. Providers with AffineMeshGeometry may receive multiple non-overlapping triangles sharing that mapping; other mesh providers receive one triangle at a time. When deformed is True, DeformedMeshGeometry is required and xx through ty instead map mesh-local coordinates plus x/y minus the drawing handle into lighting coordinates. Triangles can have independent UV mappings but have disjoint geometry interiors. The provider must reconstruct each triangle's normal-map basis and preserve current drawing/camera/presentation transforms. The processor preflights every group before submitting this receiver; rejection selects ordered fallback, while changed support or failure after submission throws without redrawing. Providers must consume or copy mesh arrays before returning; they must not retain them. normalStrength is meaningful when normalMap is set; specularStrength zero disables specular. When specularFromNormalAlpha is true, normalMap alpha multiplies specular strength without affecting diffuse or coverage; it requires SpecularMaps capability. A nonnull specularMap requires MappedSpecular capability: its RGBA8888 red or A8 alpha multiplies specular strength, overriding normal-alpha modulation without changing diffuse or coverage. Full logical map UVs follow the receiver. specularFrame selects its frame. Rejection may retry with retained packed normal alpha. sourceFormat and targetFormat are logical storage formats. Providers preserve painter order, current tint, alpha, clip and drawing state. This contract adds direct light; when includeAmbient is true, also composite ambientRed/Green/Blue times source RGB and receiver coverage over the destination. Ambient colour already includes intensity. When includeAmbient and emissionMap are set, MappedEmission capability is required: add sourceRGB times emissionRed/Green/Blue times emissionIntensity times sampled emission RGB and alpha before ambient composition. Emission colours are normalized, intensity is nonnegative, and full logical map UVs follow the receiver independent of map dimensions. A8 uses white RGB and alpha. Emission does not alter coverage or direct lighting. Direct-only groups ignore emission fields; providers without this capability receive mapped emission in a separate ambient pass. Ambient must match ordinary ALPHABLEND, including backend-specific normalized RGB clamping. HDR targets retain the full range. Otherwise preserve destination alpha. Queued work must capture parameters and image resources before Draw returns. Neither this request nor its light records may be retained by a provider.
End Rem
Type TMax2DLightingDraw
 Rem
 bbdoc: Borrowed receiver artwork, zero-based frame and drawing position.
 about: Use normal image-handle placement for sprites. Mesh requests ignore the image handle and use the current drawing handle instead. Source artwork must not be retained or modified by the provider.
 End Rem
 Field source:TImage,frame:Int,x:Float,y:Float
 Rem
 bbdoc: Optional borrowed triangle geometry; Null requests a sprite.
 about: Consume vertex, UV and index arrays before Draw returns. MeshGeometry capability is required for non-null geometry.
 End Rem
 Field mesh:TMesh2D
 Rem
 bbdoc: Selects independent per-triangle UV mappings for a mesh group.
 about: True requires DeformedMeshGeometry and changes the affine coefficients to a geometry-to-lighting mapping. False uses a shared source-pixel-to-lighting basis.
 End Rem
 Field deformed:Int
 Rem
 bbdoc: Affine receiver mapping into lighting coordinates.
 about: For sprites and ordinary mesh groups this maps source-pixel coordinates; mesh placement and drawing handle are already included. For deformed meshes it maps mesh-local coordinates plus x/y minus the drawing handle. Camera and presentation transforms remain separate.
 End Rem
 Field xx:Float,xy:Float,yx:Float,yy:Float,tx:Float,ty:Float
 Rem
 bbdoc: Optional borrowed normal map, zero-based frame and XY strength.
 about: Normal RGB encodes a local vector from -1 to +1. normalStrength scales XY before normal transformation and normalization. Null selects a viewer-facing surface where directional material lighting is required.
 End Rem
 Field normalMap:TImage,normalFrame:Int,normalStrength:Float
 Rem
 bbdoc: Optional independent specular-strength map and zero-based frame.
 about: Requires MappedSpecular capability. RGBA8888 red or A8 alpha modulates specular strength and overrides specularFromNormalAlpha.
 End Rem
 Field specularMap:TImage,specularFrame:Int
 Rem
 bbdoc: Nonnegative specular intensity and positive highlight exponent.
 about: Zero strength disables specular light. Larger shininess produces narrower highlights with a fixed viewer-facing view direction.
 End Rem
 Field specularStrength:Float,shininess:Float
 Rem
 bbdoc: Enables specular-strength modulation by normal-map alpha.
 about: Requires SpecularMaps capability. Alpha changes neither diffuse light nor source coverage; a separate specularMap takes precedence.
 End Rem
 Field specularFromNormalAlpha:Int
 Rem
 bbdoc: Resolved receiver and active destination pixel formats.
 about: Available for Supports so providers can reject unsupported format combinations before submitting any receiver pixels.
 End Rem
 Field sourceFormat:Int,targetFormat:Int
 Rem
 bbdoc: Requests ambient composition and receiver coverage in this group.
 about: Requires AmbientComposition. Ambient RGB includes the processor's combined uniform contributions and can exceed one. Without includeAmbient, direct-light passes must preserve existing destination alpha.
 End Rem
 Field includeAmbient:Int,ambientRed:Float,ambientGreen:Float,ambientBlue:Float
 Rem
 bbdoc: Optional independent emission modulation map and zero-based frame.
 about: Used with includeAmbient and MappedEmission capability. It modulates source-coloured emission; it does not illuminate neighbouring receivers.
 End Rem
 Field emissionMap:TImage,emissionFrame:Int
 Rem
 bbdoc: Emission colour multipliers and nonnegative intensity.
 about: Used with the mapped emission contribution in ambient composition. Preserve the receiver's source coverage and ordinary drawing tint/alpha.
 End Rem
 Field emissionRed:Float,emissionGreen:Float,emissionBlue:Float,emissionIntensity:Float
 Rem
 bbdoc: Active light count and retained ordered light-record storage.
 about: Only entries zero through count-1 are active. All records are borrowed, read-only and reused by the processor; do not retain the array or records.
 End Rem
 Field count:Int,lights:TMax2DLightingDrawLight[]
 Rem
 bbdoc: Ensures retained light storage; existing records are reused.
 param: Nonnegative minimum retained capacity; existing storage is not reduced.
 about: Called during preparation or a capacity change, not for every light. Capacity never shrinks; negative requests throw.
 End Rem
 Method Reserve(capacity:Int)
  If capacity<0 Then Throw "Max2D Lighting: negative draw capacity"
  If capacity<=lights.Length Then Return
  Local previous:Int=lights.Length
  lights=lights[..capacity]
  For Local i:Int=previous Until capacity
   lights[i]=New TMax2DLightingDrawLight
  Next
 End Method
 Rem
 bbdoc: Clears borrowed image references after submission or error recovery, retaining record capacity.
 End Rem
 Method ClearImages()
  source=Null;normalMap=Null;specularMap=Null;specularFrame=0;emissionMap=Null;emissionIntensity=0;mesh=Null;deformed=False
  For Local light:TMax2DLightingDrawLight=EachIn lights
   light.map=Null;light.mapKey=Null
  Next
  count=0;includeAmbient=False
 End Method
End Type

Rem
bbdoc: Context-specific direct-light renderer created by an optional backend.
about: The owning processor reuses this instance for its context. Native shaders, pipelines and shared atlases must be owned by the context and released when it closes. Release drops session-owned resources and is safe after context closure. Providers must not retain borrowed draw descriptions. All calls occur on the rendering thread.
End Rem
Type TMax2DLightingRenderer Abstract
 Rem
 bbdoc: Returns stable immutable limits for this renderer session.
 returns: Stable immutable limits for this renderer session.
 End Rem
 Method Capabilities:TMax2DLightingCapabilities() Abstract
 Rem
 bbdoc: Checks the complete group against the current target and drawing state without submitting geometry.
 param: Current Max2D drawing canvas, including target and drawing state.
 param: Complete borrowed light-group description; do not retain it after the call.
 returns: True when the requested operation is supported by the current provider and state, False otherwise.
 about: May compile/cache native resources. Resolved light maps are not available yet; inspect light metadata. False requests ordered fallback without changing pixels or drawing state. Unsupported input is not an exception. Genuine resource or driver failures may throw. The caller may retry a shorter prefix down to MinimumLights.
 End Rem
 Method Supports:Int(canvas:TMax2DGraphics,draw:TMax2DLightingDraw) Abstract
 Rem
 bbdoc: Submits one supported group as one pass, preserving drawing state.
 param: Current Max2D drawing canvas, including target and drawing state.
 param: Complete borrowed light-group description; do not retain it after the call.
 about: All requested light maps are resolved before entry. Preserve destination alpha unless includeAmbient requests ambient and receiver coverage composition. The provider must capture queued parameters before returning. Draw failures propagate; never silently fall back after partial submission. Providers clear native selection even on failure. Source tint, alpha, transforms and clipping follow ordinary Max2D drawing.
 End Rem
 Method Draw(canvas:TMax2DGraphics,draw:TMax2DLightingDraw) Abstract
 Rem
 bbdoc: Returns cumulative completed shared-map copies for this renderer session.
 returns: Cumulative completed shared-map copies for this renderer session.
 about: Monotonic until Release. The processor records differences around Draw, including partial work on errors. Providers without shared storage return zero.
 End Rem
 Method MapUploads:Long();Return 0;End Method
 Rem
 bbdoc: Returns cumulative unchanged shared-map lookups for this renderer session.
 returns: Cumulative unchanged shared-map lookups for this renderer session.
 End Rem
 Method MapCacheHits:Long();Return 0;End Method
 Rem
 bbdoc: Returns currently retained shared-map texture bytes, excluding source shadow masks and driver overhead.
 returns: Currently retained shared-map texture bytes, excluding source shadow masks and driver overhead.
 End Rem
 Method MapStorageBytes:Long();Return 0;End Method
 Rem
 bbdoc: Releases session-owned resources; repeated calls and calls after context closure are harmless.
 End Rem
 Method Release()
 End Method
End Type

Rem
bbdoc: Import-based factory for dedicated lighting renderers.
about: Backend modules register once during initialization. Providers may return Null for contexts they do not support. Register specific providers before generic providers; selection uses registration order. The existing effect-based lighting implementation remains available when no dedicated renderer accepts the context or draw.
End Rem
Type TMax2DLightingBackend Abstract
 Rem
 bbdoc: Creates a retained renderer for this context, or returns Null when unavailable.
 param: Graphics context for which the provider creates or selects resources.
 returns: A new renderer session owned by the caller, or Null when no provider is available; call Release when finished.
 End Rem
 Method CreateRenderer:TMax2DLightingRenderer(context:TMax2DContext) Abstract
End Type

Private
Global lightingBackends:TList=New TList
Public
Rem
bbdoc: Registers a dedicated lighting renderer factory once by object identity.
param: Non-null provider instance retained by the registration system.
about: Call only during module initialization on the rendering thread, before creating lighting processors. Null throws; duplicate registration of the same instance is ignored.
End Rem
Function RegisterMax2DLightingBackend(backend:TMax2DLightingBackend)
 If Not backend Then Throw "Max2D Lighting: backend is null"
 If lightingBackends.Contains(backend) Then Return
 lightingBackends.AddLast(backend)
End Function
Rem
bbdoc: Creates the first available dedicated lighting renderer for a context, or returns Null.
param: Graphics context for which the provider creates or selects resources.
returns: A new renderer session owned by the caller, or Null when no provider is available; call Release when finished.
about: Provider integration only. The caller owns the returned session and must call Release. A factory must return a renderer with initialized capabilities; invalid limits throw before drawing.
End Rem
Function CreateMax2DLightingRenderer:TMax2DLightingRenderer(context:TMax2DContext)
 If Not context Then Throw "Max2D Lighting: context is null"
 For Local backend:TMax2DLightingBackend=EachIn lightingBackends
  Local renderer:TMax2DLightingRenderer=backend.CreateRenderer(context)
  If Not renderer Then Continue
  Local limits:TMax2DLightingCapabilities=renderer.Capabilities()
  If Not limits Or limits.MinimumLights()<1 Or limits.MaximumLights()<limits.MinimumLights() Then
   renderer.Release()
   Throw "Max2D Lighting: renderer returned invalid capabilities"
  End If
  Return renderer
 Next
 Return Null
End Function
