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
AppTitle = "Max2D nested drawing state"
Graphics 960, 540
SetVirtualResolution(640, 360, VIRTUAL_LETTERBOX)
If font Then SetImageFont(font)
Local frames:Int
While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
    PollSystem()
    SetClsColor(18, 23, 32)
    Cls()
    SetColor(240, 245, 255)
    DrawText "Nested coordinates and viewport clips", 24, 18
    DrawText "Hover over a moving tile. Escape to exit.", 24, 46
    Local mx:Float, my:Float
    Local inside:Int = GetVirtualMouse(mx, my)
    Using
        Local panel:TMax2DStateScope = ScopedMax2DState()
    Do
        IntersectViewport(24, 90, 592, 210)
        TranslateCoordinates(24, 90)
        SetColor(32, 43, 60)
        DrawRect(0, 0, 592, 210)
        For Local row:Int = 0 Until 3
            For Local column:Int = 0 Until 6
                PushMax2DState()
                TranslateCoordinates(column * 112 + 24, row * 86 + 20)
                RotateCoordinates(Sin(MilliSecs() * 0.04 + column * 30) * 15)
                Local transform:TMax2DDrawTransform = CaptureDrawTransform(0, 0)
                Local lx:Float, ly:Float
                Local hover:Int = inside And mx >= 24 And mx < 616 And my >= 90 And my < 300
                hover = hover And transform.VirtualToLocal(mx, my, lx, ly)
                hover = hover And lx >= 0 And ly >= 0 And lx < 90 And ly < 60
                If hover Then
                    SetColor(255, 196, 72)
                Else
                    SetColor(52, 133, 177)
                End If
                DrawRect(0, 0, 90, 60)
                SetColor(255, 255, 255)
                DrawText String(row * 6 + column + 1), 12, 16
                PopMax2DState()
            Next
        Next
        ' A second clip can only narrow the panel's existing clip.
        IntersectViewport(24, 260, 592, 80)
        SetColor(18, 23, 32)
        DrawRect(0, 170, 592, 80)
        SetColor(210, 222, 238)
        DrawText "The parent clip also limits this child strip.", 12, 174
    End Using
    SetColor(240, 245, 255)
    DrawText "Outside the scope: position, colour and clip restored.", 24, 322
    Flip
    frames :+ 1
    If AppArgs.Length > 1 And AppArgs[1] = "--test" And frames >= 3 Then Exit
Wend
EndGraphics()
