SuperStrict

Framework Max2D.Tiled
Import BRL.StandardIO

' Both inputs below are unmodified upstream Tiled examples.
Local projectPath:String = AppDir + "/maps/examples.tiled-project"
Local mapPath:String = AppDir + "/maps/orthogonal-outside.tmx"
If AppArgs.Length > 1 Then projectPath = AppArgs[1]
If AppArgs.Length > 2 Then mapPath = AppArgs[2]

Local project:TTiledProject = TTiledProject.Load(projectPath)
Local map:TTiledMap = project.LoadMap(mapPath, 0)

Local fixture:TTileProperties = map.ObjectByID(3).properties
Print "Unreachable area:"
Print "  friction: " + fixture.GetDouble("friction")
Print "  category bits: " + fixture.GetClass("filter").GetLong("categoryBits")
Print "  mask bits: " + fixture.GetClass("filter").GetLong("maskBits")

Local body:TTileProperties = project.ClassDefaults("Body")
Print "Body default: " + body.GetString("type")
Print "Enum schema: " + body.Get("type").CustomType()
Local enumeration:TTiledEnum = project.EnumType(body.Get("type").CustomType())
Print "Allowed body types: " + ", ".Join(enumeration.values)

Local trigger:TTileProperty = map.ObjectByID(2).Property("script")
Print "Trigger script (" + trigger.ValueType() + "): " + trigger.AsString()

' Default snapshots and loaded instances have independent nested storage.
body.GetClass("fixture").SetDouble("friction", 0.25)
Print "Edited snapshot friction: " + body.GetClass("fixture").GetDouble("friction")
Print "Project default remains: " + project.ClassDefaults("Body").GetClass("fixture").GetDouble("friction")
