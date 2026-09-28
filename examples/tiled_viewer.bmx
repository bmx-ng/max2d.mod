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

Local mapPaths:String[]=[AppDir+"/tiled/demo.tmx",AppDir+"/tiled/transformations.tmx",AppDir+"/tiled/hex-transformations.tmx"]
Local mapHelp:String="1: demo   2: flips   3: hex rotations"

RunTiledViewer(mapPaths,mapHelp)

Include "../tiled.mod/examples/viewer_common.bmx"
