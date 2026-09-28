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
Import BRL.StandardIO
Import BRL.FileSystem
Import Pub.StdC
Import Max2D.ScalableFont

' Use a system outline font when available; no font asset is bundled.
Local fontPath:String
?osx
fontPath = "/System/Library/Fonts/Supplemental/Arial.ttf"
?win32
fontPath = getenv_("WINDIR") + "/Fonts/segoeui.ttf"
?linux
fontPath = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
?
Local font:TScalableImageFont
If FileType(fontPath) = FILETYPE_FILE Then font = LoadScalableImageFont(fontPath, 18)
AppTitle = "Max2D cameras — main view and minimap"

Graphics 960, 540
SetVirtualResolution(640, 360, VIRTUAL_LETTERBOX)
If font Then SetImageFont(font)

Local camera:TCamera2D = New TCamera2D
camera.offsetX = 320
camera.offsetY = 180

Local minimap:TCamera2D = New TCamera2D
minimap.offsetX = 550
minimap.offsetY = 95
minimap.zoom = 0.15

Local previous:Int = MilliSecs()
Local frames:Int
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
    PollSystem()
    Local now:Int = MilliSecs()
    Local dt:Float = Min(0.1, Float(now - previous) / 1000)
    previous = now

    camera.x :+ (KeyDown(KEY_RIGHT) - KeyDown(KEY_LEFT)) * 200 * dt / camera.zoom
    camera.y :+ (KeyDown(KEY_DOWN) - KeyDown(KEY_UP)) * 200 * dt / camera.zoom
    camera.rotation :+ (KeyDown(KEY_X) - KeyDown(KEY_Z)) * 60 * dt
    If KeyHit(KEY_SPACE) Then
        camera.x = 0
        camera.y = 0
        camera.zoom = 1
        camera.rotation = 0
    End If

    SetClsColor(18, 23, 32)
    Cls()
    Local viewX:Float, viewY:Float
    Local mouseInside:Int = GetVirtualMouse(viewX, viewY)
    Local overMinimap:Int = mouseInside And viewX >= 475 And viewX < 625 And viewY >= 40 And viewY < 150
    Local zoomInput:Float = (KeyDown(KEY_E) - KeyDown(KEY_Q)) * dt + MouseZSpeed() * 0.1
    Local newZoom:Float = Max(0.25, Min(4.0, camera.zoom * Float(Exp(zoomInput))))
    If mouseInside And Not overMinimap Then
        camera.ZoomAt(newZoom, viewX, viewY)
    Else
        camera.ZoomAt(newZoom, camera.offsetX, camera.offsetY)
    End If
    Local corners:Float[] = camera.WorldCorners(0, 0, 640, 360)
    Local worldX:Float, worldY:Float, inside:Int
    Using
        Local scene:TMax2DStateScope = ScopedMax2DState()
    Do
        SetCamera(camera)
        inside = GetWorldMouse(worldX, worldY) And Not overMinimap
        DrawScene()
        If inside Then
            SetColor(80, 235, 255)
            DrawOval(worldX - 5, worldY - 5, 10, 10)
        End If
    End Using

    ' The same scene in a different camera. Viewport clipping is independent.
    PushMax2DState()
    SetViewport(475, 40, 150, 110)
    SetColor(8, 12, 20)
    DrawRect(475, 40, 150, 110)
    SetCamera(minimap)
    DrawScene()
    SetColor(255, 230, 100)
    DrawOval(camera.x - 15, camera.y - 15, 30, 30)
    SetLineWidth(1 / minimap.zoom)
    For Local i:Int = 0 Until 4
        Local nextCorner:Int = (i + 1) Mod 4
        DrawLine(corners[i * 2], corners[i * 2 + 1], corners[nextCorner * 2], corners[nextCorner * 2 + 1], False)
    Next
    If inside Then
        SetColor(80, 235, 255)
        DrawOval(worldX - 15, worldY - 15, 30, 30)
    End If
    PopMax2DState()

    ' Interface labels use drawable coordinates, independently of the scene.
    Local labelX:Float, labelY:Float
    VirtualToNative(475, 155, labelX, labelY)
    Using
        Local overlay:TMax2DStateScope = ScopedMax2DState()
    Do
        SetCamera(Null)
        SetNativeResolution()
        Local density:Float = Float(NativeResolutionWidth()) / GraphicsWidth()
        If Not font Then density = Max(1, Floor(density + 0.5))
        SetScale(density, density)
        SetColor(255, 255, 255)
        DrawText("Arrows: pan   Wheel or Q/E: zoom at mouse   Z/X: rotate   Space: reset", 12 * density, 12 * density)
        DrawText("Mouse world: " + Int(worldX) + ", " + Int(worldY), 12 * density, NativeResolutionHeight() - 30 * density)
        SetColor(255, 230, 100)
        DrawText("View", labelX, labelY)
        SetColor(80, 235, 255)
        DrawText("Mouse", labelX + 55 * density, labelY)
    End Using
    Flip()
    frames :+ 1
    If AppArgs.Length > 1 And AppArgs[1] = "--test" And frames = 3 Then Exit
Wend
EndGraphics()

Function DrawScene()
    For Local y:Int = -5 To 5
        For Local x:Int = -8 To 8
            SetColor(55 + (x + 8) * 10, 75 + (y + 5) * 12, 170)
            DrawRect(x * 70, y * 70, 45, 45)
        Next
    Next
    SetColor(255, 255, 255)
    DrawText("World origin", 0, -20)
End Function
