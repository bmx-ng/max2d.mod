SuperStrict
Framework Max2D.SDL3RenderMax2D
Import Max2D.AtlasIO
Import BRL.StandardIO

If AppArgs.Length<>2 Then
    Print "Usage: atlas_viewer ATLAS_DIRECTORY"
    EndWithCode(1)
End If
Local atlas:TTextureAtlas=LoadTextureAtlas(AppArgs[1])
AppTitle="Max2D atlas viewer"
Graphics 960,720,0
Local scroll:Int

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
    If KeyDown(KEY_DOWN) Then scroll:+4
    If KeyDown(KEY_UP) Then scroll=Max(0,scroll-4)
    SetClsColor(24,32,48); Cls()
    SetColor(255,255,255)
    DrawText("Loaded "+atlas.PageCount()+" atlas pages. Up/Down scroll; Escape exits.",16,12)
    SetViewport(0,40,960,680)
    Local index:Int
    For Local name:String=EachIn atlas.images.Keys()
        Local image:TImage=atlas.GetImage(name)
        Local x:Int=16+(index Mod 6)*156,y:Int=60+(index/6)*140-scroll
        Local scale:Float=Min(1.0,Min(130.0/image.width,95.0/image.height))
        ' Display thumbnails without modifying the saved image handles.
        DrawSubImageRect(image,x,y,image.width*scale,image.height*scale,0,0,image.width,image.height)
        DrawText(name,x,y+100)
        index:+1
    Next
    SetViewport(0,0,960,720)

    Flip()
Wend
EndGraphics()
