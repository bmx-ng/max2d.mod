SuperStrict
Framework Max2D.SDL3RenderMax2D

AppTitle="Max2D presentation and editable atlases"

Graphics 900,640,0

Local mode:Int=VIRTUAL_INTEGER
Local modeName:String="Integer fit"
Local large:Int=True
Local atlas:TTextureAtlas=TTextureAtlas.Create(64,FILTEREDIMAGE)
Local pixels:TPixmap=CreatePixmap(12,12,PF_RGBA8888)
pixels.ClearPixels($ffff8000)
Local sprite:TImage=atlas.AddPixmap(pixels,"sprite")
Local alternate:Int

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
    If KeyHit(KEY_1) Then mode=VIRTUAL_LETTERBOX; modeName="Fractional fit"
    If KeyHit(KEY_2) Then mode=VIRTUAL_INTEGER; modeName="Integer fit"
    If KeyHit(KEY_3) Then mode=VIRTUAL_STRETCH; modeName="Stretch"
    If KeyHit(KEY_R) Then
        large=Not large
        If large Then GraphicsResize(900,640) Else GraphicsResize(700,500)
    End If
    If KeyHit(KEY_SPACE) Then
        alternate=Not alternate
        If alternate Then pixels.ClearPixels($ff40c0ff) Else pixels.ClearPixels($ffff8000)
        atlas.UpdatePixmap("sprite",pixels)
    End If
    SetVirtualResolution(320,180,mode)
    SetVirtualBarColor(8,12,20)
    SetClsColor(24,32,48)
    Cls()
    SetColor(48,64,80)
    For Local x:Int=0 Until 320 Step 20
        DrawLine(x,0,x,180)
    Next
    For Local y:Int=0 Until 180 Step 20
        DrawLine(0,y,320,y)
    Next
    SetColor(255,255,255)
    DrawImageRect(sprite,40,60,40,40)
    DrawImageRect(sprite,100,60,40,40)
    DrawOval(VirtualMouseX()-2,VirtualMouseY()-2,4,4)

    PushMax2DState()
    SetNativeResolution()
    SetColor(255,255,255)
    DrawText(modeName+" - 320 x 180 virtual scene",16,16)
    DrawText("1: Fit  2: Integer  3: Stretch  R: Resize  Space: Edit atlas",16,36)
    DrawText("The white dot follows the mouse in virtual coordinates.",16,56)
    PopMax2DState()

    Flip()
Wend
EndGraphics()
