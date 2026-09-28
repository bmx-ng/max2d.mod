SuperStrict
Framework Max2D.SDL3RenderMax2D

Graphics 800,600,0
SetVirtualResolution(400,300,VIRTUAL_LETTERBOX)
Local p:TPixmap=CreatePixmap(48,48,PF_RGBA8888)
p.ClearPixels(0)

For Local y:Int=0 Until 48
    For Local x:Int=0 Until 48
        Local d:Int=(x-24)*(x-24)+(y-24)*(y-24)
        If d<24*24 And d>12*12 Then p.WritePixel(x,y,$ffffffff)
    Next
Next

Local atlas:TTextureAtlas=TTextureAtlas.Create(128,0)
Local ring:TImage=atlas.AddPixmap(p,"ring")
SetImageHandle(ring,24,24)
Local cursor:TImage=CreateImage(8,8,1,0)
p=LockImage(cursor)
p.ClearPixels($ffffffff)
UnlockImage(cursor)
SetImageHandle(cursor,4,4)
Local angle:Float

While Not KeyDown(KEY_ESCAPE) And Not AppTerminate()
    PollSystem()
    Local mx:Float,my:Float
    Local inside:Int=WindowToVirtual(MouseX(),MouseY(),mx,my)
    angle:+0.4
    Local touching:Int
    If inside Then touching=ImagesCollide2(ring,200,150,0,angle,2,1,cursor,mx,my,0,0,1,1)
    SetClsColor(20,24,36)

    Cls
    SetTransform(angle,2,1)
    If touching Then SetColor(255,100,80) Else SetColor(80,180,240)
    DrawImage(ring,200,150)
    SetTransform()
    SetColor(255,255,255)

    If inside Then DrawImage(cursor,mx,my)
    DrawText("Move the square over the rotating ring",12,12)
    DrawText("The transparent hole does not collide",12,32)
    If touching Then DrawText("Collision",12,270)

    Flip()
Wend
EndGraphics()
