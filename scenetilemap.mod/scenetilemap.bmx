SuperStrict
Rem
bbdoc: Optional scene adapter for shared Max2D tilemaps.
about: Draws using the scene transform, inherited tint/alpha and layer view. Tilemap artwork remains application-owned. External map edits require InvalidateContent. Bounds are unknown by default; explicit SetSelfBounds must include all artwork and offsets.
End Rem
Module Max2D.SceneTileMap
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"
Import Max2D.Scene
Import Max2D.TileMap

Rem
bbdoc: A scene drawable referencing a shared tilemap and an independent animation clock.
about: Static by default. SetProcessing(True) advances animated tiles through Scene.Update in seconds and invalidates captures. Without processing, SetElapsedMilliseconds controls the clock explicitly. Unknown default bounds preserve tilemap view culling and avoid guessing bounds for sparse maps, oversized art or parallax layers. Parallax and repeating image layers are view-dependent: keep them outside cached/effect composites.
End Rem
Type TTileMapNode Extends TCustomDrawNode
 Private
 Field map:TTileMap
 Field elapsed:Double
 Public
 Rem
 bbdoc: Creates a node referencing a non-null shared tilemap.
 param: Required shared tilemap; ownership remains with the application.
 returns: A new #TTileMapNode instance configured with the supplied settings.
 End Rem
 Function Create:TTileMapNode(map:TTileMap)
  Local node:TTileMapNode=New TTileMapNode
  node.SetMap(map)
  Return node
 End Function
 Rem
 bbdoc: Changes the shared map, resets the animation clock and clears previously declared bounds.
 param: Required shared tilemap; ownership remains with the application.
 End Rem
 Method SetMap(value:TTileMap)
  If Not value Then Throw "Max2D SceneTileMap: map is null"
  ClearSelfBounds();map=value;elapsed=0
 End Method
 Rem
 bbdoc: Returns the shared map; edits require InvalidateContent on every referencing node.
 returns: The shared map; edits require InvalidateContent on every referencing node.
 End Rem
 Method GetMap:TTileMap()
  Return map
 End Method
 Rem
 bbdoc: Sets a nonnegative animation time in milliseconds, invalidating this drawable.
 param: Nonnegative animation time in whole milliseconds.
 End Rem
 Method SetElapsedMilliseconds(value:Long)
  If value<0 Or value>9007199254740991:Long Then Throw "Max2D SceneTileMap: animation time outside exact millisecond range"
  InvalidateContent();elapsed=Double(value)
 End Method
 Rem
 bbdoc: Returns the current whole animation milliseconds without advancing time.
 returns: The current whole animation milliseconds without advancing time.
 End Rem
 Method ElapsedMilliseconds:Long()
  Return Long(elapsed)
 End Method
 Rem
 bbdoc: Advances the animation clock when processing is enabled; dt is in seconds.
 param: Finite nonnegative elapsed time in seconds, supplied by the application.
 End Rem
 Method OnUpdate(dt:Double) Override
  If IsNan(dt) Or IsInf(dt) Or dt<0 Then Throw "Max2D SceneTileMap: invalid time step"
  Local nextTime:Double=elapsed+dt*1000
  If IsInf(nextTime) Or nextTime>9007199254740991:Long Then Throw "Max2D SceneTileMap: animation clock overflow"
  If nextTime=elapsed Then Return
  InvalidateContent();elapsed=nextTime
 End Method
 Rem
 bbdoc: Draws the shared map at local origin using the retained animation clock.
 param: Borrowed draw context valid only during this callback; do not retain it.
 End Rem
 Method OnDraw(context:TSceneDrawContext) Override
  If map Then map.Draw(0,0,Long(elapsed))
 End Method
 Rem
 bbdoc: Drops the map reference without releasing shared artwork.
 End Rem
 Method OnDestroy() Override
  map=Null
 End Method
End Type
