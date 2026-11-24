SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_sdlgpu And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3RenderMax2D
?
Import BRL.StandardIO
Import Max2D.Scene
Graphics(640,480)
SetVirtualResolution(640,480)
Local pix:TPixmap=CreatePixmap(128,64,PF_RGBA8888)
For Local y:Int=0 Until 64
 For Local x:Int=0 Until 128
  Local r:Int=45+x,g:Int=110+y,b:Int=210
  If x Mod 16<2 Or y Mod 16<2 Then r=230;g=245;b=255
  pix.WritePixel(x,y,($ff Shl 24)|(r Shl 16)|(g Shl 8)|b)
 Next
Next
Local image:TImage=LoadImage(pix,FILTEREDIMAGE)
Local xy:Float[90],uv:Float[90],indices:Int[192],cursor:Int
For Local row:Int=0 Until 5
 For Local col:Int=0 Until 9
  Local i:Int=(row*9+col)*2
  xy[i]=col*64;xy[i+1]=row*40
  uv[i]=col/8.0;uv[i+1]=row/4.0
  If row<4 And col<8 Then
   Local v:Int=row*9+col
   indices[cursor]=v;indices[cursor+1]=v+1;indices[cursor+2]=v+10
   indices[cursor+3]=v;indices[cursor+4]=v+10;indices[cursor+5]=v+9;cursor:+6
  End If
 Next
Next
Local mesh:TMesh2D=TMesh2D.Create(xy,indices,uv)
Local scene:TScene=TScene.Create(),layer:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(layer)
Local heading:TTextNode=TTextNode.Create("TEXTURED MESH",GetImageFont())
heading.SetPosition(32,24);layer.AddChild(heading)
Local hint:TTextNode=TTextNode.Create("Image above; animated mesh below. Space pauses. Escape closes.",GetImageFont())
hint.SetPosition(32,48);layer.AddChild(hint)
Local sprite:TSpriteNode=TSpriteNode.Create(image)
sprite.SetPosition(32,84);layer.AddChild(sprite)
Local node:TMeshNode=TMeshNode.Create(mesh,image)
node.SetPosition(32,240);layer.AddChild(node)
Local paused:Int,phase:Float,previous:Int=MilliSecs(),frames:Int
Local testing:Int=AppArgs.Length>1 And AppArgs[1]="--test"
While Not AppTerminate() And Not KeyDown(KEY_ESCAPE)
 Local now:Int=MilliSecs(),dt:Float=Min(0.05:Float,(now-previous)*0.001)
 previous=now
 If KeyHit(KEY_SPACE) Then paused=Not paused
 If Not paused Then
  phase:+dt*90
  For Local row:Int=0 Until 5
   For Local col:Int=0 Until 9
    Local i:Int=(row*9+col)*2
    mesh.xy[i+1]=row*40+Sin(phase+col*32+row*8)*22
   Next
  Next
  node.InvalidateContent()
 End If
 scene.Update(dt);SetClsColor(12,20,32);Cls;scene.Render();Flip
 frames:+1
 If testing And frames=3 Then Exit
Wend
scene.Destroy();image.ReleaseFrames();EndGraphics()
If testing Then Print "PASS: textured mesh example"
