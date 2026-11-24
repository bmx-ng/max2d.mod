SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?max2d_d3d9
Framework Max2D.D3D9Max2D
Import Max2D.D3D9Effects
?max2d_d3d11
Framework Max2D.D3D11Max2D
Import Max2D.D3D11Effects
?Not max2d_gl And Not max2d_sdlgpu And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?
Import BRL.StandardIO
Import Max2D.SceneLighting
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
' Build a gently ridged normal map once; the mesh and images are shared.
For Local y:Int=0 Until 64
 For Local x:Int=0 Until 128
  Local nx:Float=Sin(x*360.0/32)*0.65,ny:Float=Sin(y*360.0/32)*0.35
  Local nz:Float=Sqr(1-nx*nx-ny*ny)
  pix.WritePixel(x,y,($ff Shl 24)|(Int(127.5+nx*127.5) Shl 16)|(Int(127.5+ny*127.5) Shl 8)|Int(127.5+nz*127.5))
 Next
Next
Local normals:TImage=LoadImage(pix,FILTEREDIMAGE)
Local emissionPixels:TPixmap=CreatePixmap(128,64,PF_RGBA8888)
Local specularPixels:TPixmap=CreatePixmap(128,64,PF_RGBA8888)
For Local y:Int=0 Until 64
 For Local x:Int=0 Until 128
  Local emissionColour:Int=$ff000000,specularColour:Int=$ff101010
  If y>24 And y<38 And x Mod 32<22 Then emissionColour=$ff20ff90
  If y<20 Or y>44 Then specularColour=$ffffffff
  emissionPixels.WritePixel(x,y,emissionColour);specularPixels.WritePixel(x,y,specularColour)
 Next
Next
Local emission:TImage=LoadImage(emissionPixels,FILTEREDIMAGE)
Local specular:TImage=LoadImage(specularPixels,FILTEREDIMAGE)
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
Local lighting:TSceneLighting=TSceneLighting.Create(layer)
lighting.SetAmbient(100,140,210,0.25);lighting.SetLightBatching(True)
Local light:TPointLightNode=TPointLightNode.Create(420)
light.SetColor(255,205,140);light.SetIntensity(1.7);light.SetHeight(60)
layer.AddChild(light);lighting.SetLights([TLightNode2D(light)])
Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
material.SetNormalMap(normals);material.SetSpecular(0.65,28)
material.SetSpecularMap(specular);material.SetEmission(255,255,255,2);material.SetEmissionMap(emission)
Local heading:TTextNode=TTextNode.Create("EMISSION + SPECULAR MAPS",GetImageFont())
heading.SetPosition(32,24);layer.AddChild(heading)
Local hint:TTextNode=TTextNode.Create("Mouse: light  E: emission  S: specular map  G: grouping  Space: pause",GetImageFont())
hint.SetPosition(32,48);layer.AddChild(hint)
Local sprite:TLitSpriteNode=TLitSpriteNode.Create(image,lighting,material)
sprite.SetPosition(32,84);sprite.SetScale(2,2);layer.AddChild(sprite)
Local emissionPreview:TSpriteNode=TSpriteNode.Create(emission)
emissionPreview.SetPosition(320,100);layer.AddChild(emissionPreview)
Local specularPreview:TSpriteNode=TSpriteNode.Create(specular)
specularPreview.SetPosition(464,100);layer.AddChild(specularPreview)
Local legend:TTextNode=TTextNode.Create("Lit sprite                       Emission map      Specular map",GetImageFont())
legend.SetPosition(32,216);layer.AddChild(legend)
Local node:TLitMeshNode=TLitMeshNode.Create(mesh,image,lighting,material)
node.SetPosition(32,240);layer.AddChild(node)
Local emissionOn:Int=True,specularOn:Int=True,grouped:Int=True
Local paused:Int,phase:Float,previous:Int=MilliSecs(),frames:Int
Local testing:Int=AppArgs.Length>1 And AppArgs[1]="--test"
While Not AppTerminate() And Not KeyDown(KEY_ESCAPE)
 Local now:Int=MilliSecs(),dt:Float=Min(0.05:Float,(now-previous)*0.001)
 previous=now
 If KeyHit(KEY_SPACE) Then paused=Not paused
 If KeyHit(KEY_E) Then
  emissionOn=Not emissionOn;material.SetEmission(255,255,255,emissionOn*2)
 End If
 If KeyHit(KEY_S) Then
  specularOn=Not specularOn
  If specularOn Then material.SetSpecularMap(specular) Else material.SetSpecularMap(Null)
 End If
 If KeyHit(KEY_G) Then grouped=Not grouped;lighting.SetLightBatching(grouped)
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
 light.SetPosition(MouseX(),MouseY());lighting.Prepare()
 scene.Update(dt);SetClsColor(12,20,32);Cls;scene.Render();Flip
 frames:+1
 If testing And frames=3 Then Exit
Wend
scene.Destroy();lighting.ReleaseResources();material.ReleaseResources();image.ReleaseFrames();normals.ReleaseFrames();emission.ReleaseFrames();specular.ReleaseFrames();EndGraphics()
If testing Then Print "PASS: material maps example"
