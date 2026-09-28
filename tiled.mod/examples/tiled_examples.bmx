SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3RenderMax2D
?
Import Max2D.Tiled
Import Max2D.ScalableFont
Import Pub.StdC
Import BRL.StandardIO

Local mapPaths:String[]=[ ..
	AppDir+"/maps/desert.tmx", ..
	AppDir+"/maps/sewers.tmx", ..
	AppDir+"/maps/perspective_walls.tmx", ..
	AppDir+"/maps/isometric_grass_and_water.tmx", ..
	AppDir+"/maps/isometric_staggered_grass_and_water.tmx", ..
	AppDir+"/maps/hexagonal-mini.tmx", ..
	AppDir+"/maps/orthogonal-outside.tmx", ..
	AppDir+"/maps/forest/forest.tmx", ..
	AppDir+"/maps/sticker-knight/map/sandbox.tmx", ..
	AppDir+"/maps/sticker-knight/ui/title.json"]
Local mapHelp:String="1–9, 0: maps  O: object outlines"

RunTiledViewer(mapPaths,mapHelp,AppDir+"/maps/examples.tiled-project")

Include "viewer_common.bmx"
