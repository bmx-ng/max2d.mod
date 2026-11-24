SuperStrict
?max2d_gl
Framework Max2D.GLMax2D
Import Max2D.GLEffects
?max2d_d3d9
Framework Max2D.D3D9Max2D
Import Max2D.D3D9Effects
?max2d_d3d11
Framework Max2D.D3D11Max2D
Import Max2D.D3D11Effects
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11
Framework Max2D.SDL3GPUMax2D
Import Max2D.SDL3GPUEffects
?
Import Max2D.SceneLighting
Import Max2D.ScalableFont
Import BRL.FileSystem
Import BRL.StandardIO
Import Pub.StdC

AppTitle="Max2D / Light Lab"
Graphics(1100,740)
SetVirtualResolution(1100,740,VIRTUAL_LETTERBOX)
Local path:String
?osx
path="/System/Library/Fonts/Supplemental/Arial.ttf"
?win32
path=getenv_("WINDIR")+"/Fonts/segoeui.ttf"
?linux
path="/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
?
Local font:TImageFont=TImageFont.DefaultFont(),title:TImageFont=font
If FileType(path)=FILETYPE_FILE Then
 font=LoadScalableImageFont(path,16); title=LoadScalableImageFont(path,34)
End If
Local scene:TScene=TScene.Create(),world:TLayerNode=TLayerNode.Create(),hud:TLayerNode=TLayerNode.Create()
scene.Root().AddChild(world); scene.Root().AddChild(hud)
world.SetViewport(TSceneRect.Create(30,135,750,565))
Local lighting:TSceneLighting=TSceneLighting.Create(world)
lighting.SetAmbient(150,175,220,0.14)
Local floorImage:TRenderImage=MakeFloor()
Local floorMap:TMax2DLightingMaterialMap=TMax2DLightingMaterialMap.Create()
Local panelMap:TMax2DLightingMaterialMap=TMax2DLightingMaterialMap.Create()
Local floorNormal:TImage=floorMap.Update(MakeNormals(750,565,False),MakeGloss(750,565,False))
Local panelNormal:TImage=panelMap.Update(MakeNormals(140,120,True),MakeGloss(140,120,True))
Local materials:TMax2DLightingMaterial[5]
materials[0]=TMax2DLightingMaterial.Create(); materials[0].SetNormalMap(floorNormal)
materials[0].SetSpecular(0.8,48);materials[0].SetSpecularFromNormalAlpha(True)
Local floorNode:TLitSpriteNode=TLitSpriteNode.Create(floorImage,lighting,materials[0])
floorNode.SetPosition(30,135); world.AddChild(floorNode)
Local panelImage:TRenderImage=MakePanel(),markerImage:TRenderImage=MakeMarker()
Local names:String[]=["ALL LIGHTS","AMBER / SUN","CYAN ONLY","UNLIT"]
For Local i:Int=0 Until 4
 Local material:TMax2DLightingMaterial=TMax2DLightingMaterial.Create()
 materials[i+1]=material; material.SetNormalMap(panelNormal); material.SetSpecular(1.1,32);material.SetSpecularFromNormalAlpha(True)
 If i=1 Then material.SetReceiverMask(1)
 If i=2 Then material.SetReceiverMask(2)
 If i=3 Then material.SetUnlit(True)
 Local node:TLitSpriteNode=TLitSpriteNode.Create(panelImage,lighting,material)
 node.SetPosition(70+i*178,350); world.AddChild(node)
 AddLabel(hud,names[i],font,70+i*178,485,175,191,213)
Next
Local amber:TPointLightNode=TPointLightNode.Create(360),cyan:TPointLightNode=TPointLightNode.Create(320)
amber.SetColor(255,145,55); amber.SetIntensity(2.3); amber.SetReceiverMask(1)
cyan.SetColor(65,200,255); cyan.SetIntensity(2.1); cyan.SetReceiverMask(2)
world.AddChild(amber); world.AddChild(cyan)
Local patternImage:TImage=MakeLightPattern(),pattern:TMax2DLightTexture=TMax2DLightTexture.Create(patternImage)
pattern.SetPlacement(620,620)
Local patterned:Int=False
Local shadows:Int=True,softShadows:Int=True
amber.SetShadows(True,512);cyan.SetShadows(True,512)
amber.SetShadowSoftness(4);cyan.SetShadowSoftness(4)
Local a:TSpriteNode=TSpriteNode.Create(markerImage),b:TSpriteNode=TSpriteNode.Create(markerImage)
a.SetTint(255,175,85); b.SetTint(90,220,255); amber.AddChild(a); cyan.AddChild(b)
Local sun:TDirectionalLightNode=TDirectionalLightNode.Create()
sun.SetColor(255,235,200); sun.SetIntensity(0.9); sun.SetReceiverMask(1)
world.AddChild(sun)
sun.SetShadowBounds(0,105,810,625);sun.SetShadows(True,512);sun.SetShadowSoftness(4)
lighting.SetLights([TLightNode2D(amber),cyan,sun])
Local blockImage:TRenderImage=MakeBlock(),cornerImage:TRenderImage=MakeCornerBlock()
Local blockers:TLightOccluderNode[3]
For Local i:Int=0 Until 3
 blockers[i]=TLightOccluderNode.Create([0.0,0.0,48.0,0.0,48.0,48.0,0.0,48.0])
 If i=2 Then blockers[i].SetPolygon([0.0,0.0,48.0,0.0,48.0,16.0,16.0,16.0,16.0,48.0,0.0,48.0])
 blockers[i].SetHeight(32)
 blockers[i].SetPosition(180+i*200,250+(i Mod 2)*310);world.AddChild(blockers[i])
 Local artwork:TImage=blockImage
 If i=2 Then artwork=cornerImage
 Local block:TSpriteNode=TSpriteNode.Create(artwork)
 blockers[i].AddChild(block)
Next
lighting.SetOccluders(blockers)
Local directionalMode:Int=True,sunAngle:Float=-50,sunElevation:Float=65
sun.SetEnabled(True);amber.SetEnabled(False);cyan.SetEnabled(False)
a.SetVisible(False);b.SetVisible(False)
AddLabel(hud,"LIGHT LAB",title,30,28,235,243,255)
AddLabel(hud,"Point + directional shadows / normal + specular materials / textured lights / unlit HUD",font,32,81,155,177,204)
AddLabel(hud,"LIVE CONTROLS",font,814,146,235,243,255)
AddLabel(hud,"1  Amber light",font,814,180,255,185,100)
AddLabel(hud,"2  Cyan light",font,814,205,100,218,255)
AddLabel(hud,"D  Sunlight / point lights",font,814,230,235,243,255)
Local moveHint:TTextNode=AddLabel(hud,"Arrows steer sunlight",font,814,258,175,191,213)
Local radiusHint:TTextNode=AddLabel(hud,"Left / right   Sun direction",font,814,295,175,191,213)
AddLabel(hud,"Up / down    Intensity",font,814,325,175,191,213)
AddLabel(hud,"F                  Cycle falloff",font,814,355,175,191,213)
AddLabel(hud,"A                 Ambient on/off",font,814,385,175,191,213)
AddLabel(hud,"Space          Pause motion",font,814,415,175,191,213)
AddLabel(hud,"N                 Normal maps on/off",font,814,445,175,191,213)
Local heightHint:TTextNode=AddLabel(hud,"Q / E           Sun elevation",font,814,475,175,191,213)
AddLabel(hud,"S                 Specular on/off",font,814,505,175,191,213)
AddLabel(hud,"R                 Cycle shininess",font,814,535,175,191,213)
AddLabel(hud,"T                 Light pattern on/off",font,814,563,175,191,213)
Local info:TTextNode=AddLabel(hud,"",font,814,597,235,243,255)
Local info2:TTextNode=AddLabel(hud,"",font,814,623,175,191,213)
AddLabel(hud,"G   Gloss map on/off",font,814,654,130,212,180)
AddLabel(hud,"H Shadows   /   B Soft edges",font,814,683,140,157,180)
AddLabel(hud,"M   Emissive panels on/off",font,32,708,130,212,180)
Local emissive:Int
Local mappedGloss:Int=True
Local glossy:Int=True
Local normalMaps:Int=True
Local selected:TPointLightNode=amber,paused:Int,ambient:Int=True,previous:Int=MilliSecs()
Local elapsed:Double,testing:Int=AppArgs.Length>1 And AppArgs[1]="--test",frames:Int
While Not AppTerminate() And Not KeyDown(KEY_ESCAPE)
 Local now:Int=MilliSecs(),dt:Float=Float(Min(0.05,Max(0.0,(now-previous)*0.001)))
 previous=now
 If KeyHit(KEY_M) Then
  emissive=Not emissive
  For Local i:Int=1 To 3
   materials[i].SetEmission(90,200,255,0.65*emissive)
  Next
 End If
 If KeyHit(KEY_B) Then
  softShadows=Not softShadows
  amber.SetShadowSoftness(4*softShadows);cyan.SetShadowSoftness(4*softShadows);sun.SetShadowSoftness(4*softShadows)
 End If
 If KeyHit(KEY_H) Then
  shadows=Not shadows
  amber.SetShadows(shadows,512);cyan.SetShadows(shadows,512);sun.SetShadows(shadows,512)
 End If
 If KeyHit(KEY_T) Then
  patterned=Not patterned
  If patterned Then amber.SetTexture(pattern) Else amber.SetTexture(Null)
 End If
 If KeyHit(KEY_1) Then selected=amber
 If KeyHit(KEY_2) Then selected=cyan
 If KeyHit(KEY_SPACE) Then paused=Not paused
 If KeyHit(KEY_D) Then
  directionalMode=Not directionalMode
  sun.SetEnabled(directionalMode); amber.SetEnabled(Not directionalMode); cyan.SetEnabled(Not directionalMode)
  a.SetVisible(Not directionalMode); b.SetVisible(Not directionalMode)
  If directionalMode Then
   moveHint.SetText("Arrows steer sunlight"); radiusHint.SetText("Left / right   Sun direction"); heightHint.SetText("Q / E           Sun elevation")
  Else
   moveHint.SetText("Drag in the room to move"); radiusHint.SetText("Left / right   Radius"); heightHint.SetText("Q / E           Light height")
  End If
 End If
 If KeyHit(KEY_A) Then
  ambient=Not ambient; lighting.SetAmbient(150,175,220,0.14*ambient)
 End If
 If KeyHit(KEY_G) Then
  mappedGloss=Not mappedGloss
  For Local material:TMax2DLightingMaterial=EachIn materials
   material.SetSpecularFromNormalAlpha(mappedGloss)
  Next
 End If
 If KeyHit(KEY_S) Then
  glossy=Not glossy
  materials[0].SetSpecular(0.8*glossy,materials[0].GetShininess())
  For Local i:Int=1 Until 5
   materials[i].SetSpecular(1.1*glossy,materials[i].GetShininess())
  Next
 End If
 If KeyHit(KEY_R) Then
  Local shininess:Float=materials[1].GetShininess()*2
  If shininess>128 Then shininess=8
  For Local material:TMax2DLightingMaterial=EachIn materials
   material.SetSpecular(material.GetSpecularStrength(),shininess)
  Next
 End If
 If KeyHit(KEY_N) Then
  normalMaps=Not normalMaps
  If normalMaps Then
   materials[0].SetNormalMap(floorNormal)
   For Local i:Int=1 Until 5
    materials[i].SetNormalMap(panelNormal)
   Next
  Else
   For Local material:TMax2DLightingMaterial=EachIn materials
    material.SetNormalMap(Null)
   Next
  End If
 End If
 Local active:TLightNode2D=selected
 If directionalMode Then
  active=sun
  sunAngle:+Float(KeyDown(KEY_RIGHT)-KeyDown(KEY_LEFT))*dt*80
  sunElevation=Max(0.0:Float,Min(90.0:Float,sunElevation+Float(KeyDown(KEY_E)-KeyDown(KEY_Q))*dt*40))
  If Not paused Then sunAngle:+dt*18
 Else
  Local height:Float=selected.GetHeight()+Float(KeyDown(KEY_E)-KeyDown(KEY_Q))*dt*160
  If height<>selected.GetHeight() Then selected.SetHeight(Max(0.0:Float,Min(600.0:Float,height)))
  Local radius:Float=selected.GetRadius()+Float(KeyDown(KEY_RIGHT)-KeyDown(KEY_LEFT))*dt*180
  If radius<>selected.GetRadius() Then selected.SetRadius(Max(40.0:Float,Min(650.0:Float,radius)))
 End If
 sun.SetDirection(Float(Cos(sunAngle)*Cos(sunElevation)),Float(Sin(sunAngle)*Cos(sunElevation)),Float(Sin(sunElevation)))
 If KeyHit(KEY_F) And Not directionalMode Then
  Local value:Float=selected.GetFalloff()+1
  If value>4 Then value=1
  selected.SetFalloff(value)
 End If
 Local intensity:Float=active.GetIntensity()+Float(KeyDown(KEY_UP)-KeyDown(KEY_DOWN))*dt*1.5
 If intensity<>active.GetIntensity() Then active.SetIntensity(Max(0.0:Float,Min(5.0:Float,intensity)))
 If Not paused Then elapsed:+dt
 pattern.SetPlacement(620,620,0,0,Float(elapsed*12))
 If Not paused Or frames=0 Then
  amber.SetPosition(330+Float(Cos(elapsed*27))*145,365+Float(Sin(elapsed*39))*135)
  cyan.SetPosition(485+Float(Sin(elapsed*32))*155,385+Float(Cos(elapsed*24))*140)
 End If
 Local mx:Float,my:Float
 If Not directionalMode And GetVirtualMouse(mx,my) And MouseDown(1) And mx>=30 And mx<780 And my>=135 And my<700 Then
  paused=True; selected.SetPosition(mx,my)
 End If
 Local label:String="AMBER"
 If selected=cyan Then label="CYAN"
 info.SetText(label+"  /  height "+Int(selected.GetHeight()))
 info2.SetText("Intensity "+Float(Int(selected.GetIntensity()*10)/10.0)+"  /  falloff "+Int(selected.GetFalloff()))
 If directionalMode Then
  info.SetText("SUN  /  elevation "+Int(sunElevation))
  info2.SetText("Intensity "+Float(Int(sun.GetIntensity()*10)/10.0)+"  /  no attenuation")
 End If
 lighting.Prepare()
 SetClsColor(10,15,24); Cls
 scene.Render(); Flip
 frames:+1
 If testing And frames=3 Then Exit
Wend
For Local material:TMax2DLightingMaterial=EachIn materials
 material.SetNormalMap(Null)
Next
lighting.ReleaseResources();scene.Destroy();blockImage.ReleaseFrames();cornerImage.ReleaseFrames(); patternImage.ReleaseFrames(); floorMap.Release(); panelMap.Release(); floorImage.ReleaseFrames(); panelImage.ReleaseFrames(); markerImage.ReleaseFrames()
EndGraphics()
If testing Then Print "PASS: light lab example"

Function AddLabel:TTextNode(layer:TLayerNode,text:String,font:TImageFont,x:Float,y:Float,r:Int,g:Int,b:Int)
 Local node:TTextNode=TTextNode.Create(text,font)
 node.SetPosition(x,y); node.SetTint(r,g,b); layer.AddChild(node)
 Return node
End Function

Function MakeFloor:TRenderImage()
 Local image:TRenderImage=CreateRenderImage(750,565,FILTEREDIMAGE)
 Using
  Local scope:TMax2DStateScope=ScopedMax2DState()
 Do
  SetRenderImage(image); SetClsColor(65,72,82); Cls
  SetBlend(SOLIDBLEND)
  For Local y:Int=0 Until 565 Step 64
   For Local x:Int=0 Until 750 Step 64
    Local value:Int=88+((x/64+y/64) Mod 3)*9
    SetColor(value,value+4,value+10); DrawRect(x+2,y+2,60,60)
    SetColor(130,138,148); DrawLine(x+3,y+3,x+60,y+3)
    SetColor(50,55,62); DrawLine(x+60,y+5,x+60,y+60)
    For Local corner:Int=0 Until 2
     SetColor(53,57,64); DrawOval(x+7+corner*43,y+8,5,5)
     SetColor(160,166,176); DrawRect(x+8+corner*43,y+9,2,1)
    Next
   Next
  Next
  SetColor(150,154,163); DrawRect(30,105,690,3); DrawRect(30,445,690,3)
  SetColor(48,52,58); DrawRect(28,109,694,9); DrawRect(28,449,694,9)
  For Local i:Int=0 Until 20
   SetColor(175,178,183); DrawRect(42+i*34,112,18,3); DrawRect(42+i*34,452,18,3)
  Next
 End Using
 Return image
End Function

Function MakePanel:TRenderImage()
 Local image:TRenderImage=CreateRenderImage(140,120,FILTEREDIMAGE)
 Using
  Local scope:TMax2DStateScope=ScopedMax2DState()
 Do
  SetRenderImage(image); SetClsColor(0,0,0,0); Cls
  SetColor(45,48,54); DrawRect(0,0,140,120)
  SetColor(180,184,190); DrawRect(2,2,136,116)
  SetColor(95,100,108); DrawRect(5,5,130,110)
  SetColor(210,213,218); DrawRect(6,6,128,2)
  For Local i:Int=0 Until 6
   SetColor(40,44,50); DrawRect(18,18+i*12,104,7)
   SetColor(160,168,176); DrawRect(18,25+i*12,104,2)
  Next
  SetColor(205,210,218); DrawRect(18,101,46,5)
  SetColor(120,128,138); DrawRect(70,101,52,5)
 End Using
 Return image
End Function

Function MakeMarker:TRenderImage()
 Local image:TRenderImage=CreateRenderImage(20,20,FILTEREDIMAGE)
 Using
  Local scope:TMax2DStateScope=ScopedMax2DState()
 Do
  SetRenderImage(image); SetClsColor(0,0,0,0); Cls
  SetColor(255,255,255); SetAlpha(0.2); DrawOval(0,0,20,20)
  SetAlpha(0.7); DrawOval(4,4,12,12)
  SetAlpha(1); DrawOval(7,7,6,6)
 End Using
 MidHandleImage(image)
 Return image
End Function

' Generate opaque normal data once from a simple relief profile.
Function MakeNormals:TImage(width:Int,height:Int,panel:Int)
 Local map:TPixmap=CreatePixmap(width,height,PF_RGBA8888)
 For Local y:Int=0 Until height
  For Local x:Int=0 Until width
   Local nx:Float=(Relief(x-1,y,panel)-Relief(x+1,y,panel))*0.5
   Local ny:Float=(Relief(x,y-1,panel)-Relief(x,y+1,panel))*0.5
   Local length:Float=Sqr(nx*nx+ny*ny+1)
   Local r:Int=Int((nx/length*0.5+0.5)*255+0.5)
   Local g:Int=Int((ny/length*0.5+0.5)*255+0.5)
   Local b:Int=Int((1/length*0.5+0.5)*255+0.5)
   map.WritePixel(x,y,$ff000000 | r Shl 16 | g Shl 8 | b)
  Next
 Next
 Return LoadImage(map,FILTEREDIMAGE)
End Function
 ' Author gloss independently; the material-map builder packs it for rendering.
Function MakeGloss:TImage(width:Int,height:Int,panel:Int)
 Local map:TPixmap=CreatePixmap(width,height,PF_A8)
 For Local y:Int=0 Until height
  For Local x:Int=0 Until width
   Local gloss:Int=255
   If panel Then
    If (x/20) Mod 2=0 Then gloss=24
   Else
    If ((x/64)+(y/64)) Mod 2=0 Then gloss=32
   End If
   map.WritePixel(x,y,gloss Shl 24)
  Next
 Next
 Return TImage.FromPixmap(map,0,PF_A8)
End Function
Function Relief:Float(x:Int,y:Int,panel:Int)
 If panel Then
  Local edge:Int=Min(Min(x,139-x),Min(y,119-y))
  Local height:Float=Min(4.0:Float,Max(0.0:Float,Float(edge)))*1.5
  If x>=18 And x<122 And y>=18 And y<90 Then
   Local rib:Int=(y-18) Mod 12
   height:-Max(0.0:Float,3.0:Float-Abs(Float(rib)-3))*1.8
  End If
  Return height
 End If
 Local u:Int=((x Mod 64)+64) Mod 64,v:Int=((y Mod 64)+64) Mod 64
 Local edge:Int=Min(Min(u,63-u),Min(v,63-v))
 Return Min(5.0:Float,Max(0.0:Float,Float(edge-1)))*1.2
End Function

' A translucent coloured window pattern, generated once and shared by the light.
Function MakeLightPattern:TImage()
 Local pixels:TPixmap=CreatePixmap(128,128,PF_RGBA8888)
 For Local y:Int=0 Until 128
  For Local x:Int=0 Until 128
   Local alpha:Int=255
   If x Mod 32<5 Or y Mod 32<5 Then alpha=24
   Local r:Int=255,g:Int=230,b:Int=180
   If ((x/32)+(y/32)) Mod 2 Then g=160;b=100
   pixels.WritePixel(x,y,alpha Shl 24 | r Shl 16 | g Shl 8 | b)
  Next
 Next
 Return LoadImage(pixels,FILTEREDIMAGE)
End Function

Function MakeBlock:TRenderImage()
 Local image:TRenderImage=CreateRenderImage(48,48,FILTEREDIMAGE)
 Using
  Local scope:TMax2DStateScope=ScopedMax2DState()
 Do
  SetRenderImage(image);SetClsColor(28,35,45,1);Cls
  SetBlend(SOLIDBLEND);SetColor(125,145,165);DrawRect(0,0,48,3);DrawRect(0,0,3,48)
  SetColor(65,78,94);DrawRect(5,5,38,38)
  SetColor(95,180,205);DrawRect(11,22,26,4)
 End Using
 Return image
End Function

Function MakeCornerBlock:TRenderImage()
 Local image:TRenderImage=CreateRenderImage(48,48,FILTEREDIMAGE)
 Using
  Local scope:TMax2DStateScope=ScopedMax2DState()
 Do
  SetRenderImage(image);SetClsColor(0,0,0,0);Cls
  SetBlend(SOLIDBLEND);SetColor(28,35,45)
  DrawRect(0,0,48,16);DrawRect(0,16,16,32)
  SetColor(125,145,165);DrawRect(0,0,48,3);DrawRect(0,0,3,48)
  SetColor(65,78,94);DrawRect(5,5,38,6);DrawRect(5,11,6,32)
  SetColor(95,180,205);DrawRect(22,6,16,3)
 End Using
 Return image
End Function
