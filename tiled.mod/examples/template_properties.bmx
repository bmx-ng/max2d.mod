SuperStrict
Framework Max2D.Tiled
Import BRL.StandardIO

' Build as a console application. No graphics context is required.
Local path:String=AppDir+"/data/templates/gameplay.tmx"
If AppArgs.Length>1 Then path=AppArgs[1]
Local map:TTiledMap=LoadTiledMap(path)
For Local obj:TTileObject=EachIn map.layers[0].objects
	If obj.className<>"Enemy" Then Continue
	Local stats:TTileProperties=obj.properties.GetClass("stats")
	Print obj.name+": health="+stats.GetLong("health")+", speed="+stats.GetDouble("speed")
	Local door:TTileObject=map.ObjectByID(Int(obj.properties.GetLong("opens")))
	If door Then Print "  Opens: "+door.name
Next

' Editing one instance leaves the template defaults and other instances alone.
map.ObjectByID(2).properties.GetClass("stats").SetLong("health",200)
Print "Guard health remains "+map.ObjectByID(1).properties.GetClass("stats").GetLong("health")
