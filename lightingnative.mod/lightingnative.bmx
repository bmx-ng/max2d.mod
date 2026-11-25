SuperStrict
Rem
bbdoc: Native grouped-light implementation for the optional Max2D lighting renderer contract.
End Rem
Module Max2D.LightingNative
ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"
Import Max2D.LightingDriver
Import Max2D.ShaderEffects
Import "shaders/lightgroup_assets.c"
Import "shaders/lightgroup16_assets.c"
Import "shaders/lightmaterial_assets.c"
Import "shaders/lightmaterial16_assets.c"
Import "shaders/lightspecular_assets.c"
Import "shaders/lightspecular16_assets.c"

Import "atlas.bmx"

Private

Extern "C"
 Function m2d_native_lighting_assets_specular:Byte Ptr()
 Function m2d_native_lighting_assets_specular_16:Byte Ptr()
 Function m2d_native_lighting_assets_material:Byte Ptr()
 Function m2d_native_lighting_assets_material_16:Byte Ptr()
 Function m2d_native_lighting_assets_16:Byte Ptr()
 Function m2d_native_lighting_assets:Byte Ptr()
End Extern

Type TMax2DNativeLightingRenderer Extends TMax2DLightingRenderer
 Field context:TMax2DContext
 Field adapter:TMax2DShaderPackageBackend
 Field shader:Byte Ptr
 Field lightCount:Int,userSlots:Int
 Field assets:Byte Ptr
 Field values:Float[]
 Field textures:TImageFrame[4]
 Field extended:Int
 Field screen:Float[6]
 Field atlas:TMax2DLightingAtlas=New TMax2DLightingAtlas
 Field groupTiles:TMax2DLightingAtlasTile[]
 Field limits:TMax2DLightingCapabilities
 Field blend:Int=CreateBlendMode(BLEND_ONE,BLEND_ONE,BLEND_OP_ADD,BLEND_ZERO,BLEND_ONE)
 Field composite:Int=CreateBlendMode(BLEND_ONE,BLEND_ONE_MINUS_SRC_ALPHA,BLEND_OP_ADD,BLEND_ONE,BLEND_ONE_MINUS_SRC_ALPHA)
 Method Capabilities:TMax2DLightingCapabilities() Override
  Return limits
 End Method
 Method Supports:Int(canvas:TMax2DGraphics,draw:TMax2DLightingDraw) Override
  If canvas.context<>context Or draw.count<1 Or draw.count>lightCount Then Return False
  If draw.deformed And Not ScreenMapping(canvas,draw) Then Return False
  If draw.sourceFormat=PF_RGBA16F Or draw.sourceFormat=PF_RGBA32F Then Return False
  If draw.includeAmbient And draw.emissionMap And draw.targetFormat<>PF_RGBA16F And draw.targetFormat<>PF_RGBA32F Then
   Local source:TImageSource=draw.emissionMap.sources[draw.emissionFrame]
   Local format:Int=source.targetFormat
   If source.pixmap Then format=source.pixmap.format
   If source.textureData Then format=source.textureData.Format()
   ' Signed emission must be clamped before adding direct light on normalized
   ' targets. Preserve the separate ambient pass for floating-point artwork.
   If format=PF_RGBA16F Or format=PF_RGBA32F Then Return False
  End If
  Local mapped:Int
  For Local i:Int=0 Until draw.count
   Local light:TMax2DLightingDrawLight=draw.lights[i]
   If light.hasMap Then
    mapped=True
    If light.mapFormat<>PF_RGBA8888 And light.mapFormat<>PF_A8 Then Return False
    If light.mapFlags & MIPMAPPEDIMAGE Then Return False
    If light.mapWidth<1 Or light.mapHeight<1 Or light.mapWidth>512 Or light.mapHeight>512 Then Return False
    If Not atlas.owner And Not Max2DSupportsRenderImage(2048,2048,0,PF_RGBA8888) Then Return False
   End If
  Next
  ' Short groups use the smaller uniform block and shader on every backend.
  assets=m2d_native_lighting_assets();userSlots=56
  If draw.count>8 Then assets=m2d_native_lighting_assets_16();userSlots=104
  extended=False
  If draw.specularMap Then
   If adapter.MaximumTextures(context)<5 Then Return False
   If draw.specularMap.sources[draw.specularFrame].locked Then Return False
   ' The packer's byte flat normal has small nonzero XY components. A custom
   ' strength scales those too; retain its result for this uncommon setting.
   If Not draw.normalMap And draw.normalStrength<>1 Then Return False
   If draw.normalMap And draw.normalMap.sources[draw.normalFrame].locked Then Return False
   ' Packed normals inherit the gloss filtering mode. Keep that exact result
   ' when separately authored maps request different filtering.
   If draw.normalMap And ((draw.normalMap.flags ~ draw.specularMap.flags) & FILTEREDIMAGE) Then Return False
   assets=m2d_native_lighting_assets_specular()
   If draw.count>8 Then assets=m2d_native_lighting_assets_specular_16()
   shader=adapter.Shader(context,assets)
   If Not shader Then Return False
   extended=2
  Else If draw.includeAmbient And draw.emissionMap And adapter.MaximumTextures(context)>=4 Then
   Local materialAssets:Byte Ptr=m2d_native_lighting_assets_material()
   If draw.count>8 Then materialAssets=m2d_native_lighting_assets_material_16()
   shader=adapter.Shader(context,materialAssets)
   If shader Then assets=materialAssets;extended=True
  End If
  If Not extended Then
   If mapped And draw.includeAmbient And draw.emissionMap Then Return False
   shader=adapter.Shader(context,assets)
  End If
  If Not shader Then Return False
  Local previous:Int=GetBlend()
  Try
   If draw.includeAmbient Then SetBlend(composite) Else SetBlend(blend)
   Return adapter.SupportsShader(canvas,shader)
  Finally
   SetBlend(previous)
  End Try
 End Method
 Method ScreenMapping:Int(canvas:TMax2DGraphics,draw:TMax2DLightingDraw,checkGradients:Int=True)
  Local state:TMax2DState=canvas.state
  Local a:Double,b:Double,c:Double,d:Double
  state.DrawingMatrix(a,b,c,d)
  Local x:Double=draw.x+state.originX-state.ix*state.handleX-state.iy*state.handleY
  Local y:Double=draw.y+state.originY-state.jx*state.handleX-state.jy*state.handleY
  Local cx:Double=state.coordXX*x+state.coordXY*y+state.coordTX
  Local cy:Double=state.coordYX*x+state.coordYY*y+state.coordTY
  x=state.cameraXX*cx+state.cameraXY*cy+state.cameraTX
  y=state.cameraYX*cx+state.cameraYY*cy+state.cameraTY
  a:*context.pixelScaleX;b:*context.pixelScaleX;c:*context.pixelScaleY;d:*context.pixelScaleY
  x=x*context.pixelScaleX+context.pixelOffsetX;y=y*context.pixelScaleY+context.pixelOffsetY
  Local determinant:Double=a*d-b*c
  If Abs(determinant)<0.000000000001 Then Return False
  If checkGradients Then
   Local source:TImageSource=draw.source.sources[draw.frame]
   Local us:Double=Double(draw.source.width)/source.width,vs:Double=Double(draw.source.height)/source.height
   For Local triangle:Int=0 Until draw.mesh.indices.Length Step 3
    Local i:Int=draw.mesh.indices[triangle]*2,j:Int=draw.mesh.indices[triangle+1]*2,k:Int=draw.mesh.indices[triangle+2]*2
    Local dx:Double=Double(draw.mesh.xy[j])-draw.mesh.xy[i],dy:Double=Double(draw.mesh.xy[j+1])-draw.mesh.xy[i+1]
    Local ex:Double=Double(draw.mesh.xy[k])-draw.mesh.xy[i],ey:Double=Double(draw.mesh.xy[k+1])-draw.mesh.xy[i+1]
    Local sx:Double=a*dx+b*dy,sy:Double=c*dx+d*dy,tx:Double=a*ex+b*ey,ty:Double=c*ex+d*ey
    Local area:Double=sx*ty-sy*tx
    If area=0 Then Return False
    Local du:Double=(Double(draw.mesh.uv[j])-draw.mesh.uv[i])*us,dv:Double=(Double(draw.mesh.uv[j+1])-draw.mesh.uv[i+1])*vs
    Local eu:Double=(Double(draw.mesh.uv[k])-draw.mesh.uv[i])*us,ev:Double=(Double(draw.mesh.uv[k+1])-draw.mesh.uv[i+1])*vs
    Local ux:Double=(du*ty-eu*sy)/area,uy:Double=(eu*sx-du*tx)/area
    Local vx:Double=(dv*ty-ev*sy)/area,vy:Double=(ev*sx-dv*tx)/area
    ' Reject tiny/ill-conditioned texture gradients before fragment precision
    ' can erase a triangle's normal basis. Atlas scale is part of this test.
    Local largest:Double=Max(Abs(ux)+Abs(uy),Abs(vx)+Abs(vy))
    If largest=0 Or Abs(ux*vy-uy*vx)<largest*0.00002 Then Return False
   Next
  End If
  Local ax:Double=(draw.xx*d-draw.xy*c)/determinant,ay:Double=(draw.xy*a-draw.xx*b)/determinant
  Local bx:Double=(draw.yx*d-draw.yy*c)/determinant,by:Double=(draw.yy*a-draw.yx*b)/determinant
  screen[0]=ax;screen[1]=ay;screen[2]=draw.xx*(draw.x-state.handleX)+draw.xy*(draw.y-state.handleY)+draw.tx-ax*x-ay*y
  screen[3]=bx;screen[4]=by;screen[5]=draw.yx*(draw.x-state.handleX)+draw.yy*(draw.y-state.handleY)+draw.ty-bx*x-by*y
  For Local value:Float=EachIn screen
   If IsNan(value) Or IsInf(value) Then Return False
  Next
  Return True
 End Method
 Method Bounds(image:TImage,frame:Int,slot:Int)
  image.CheckIndex(frame)
  If image.Trim(frame) Then Throw "Max2D Lighting: native grouped lighting requires untrimmed images"
  Local source:TImageSource=image.sources[frame]
  Local offset:Int=slot*4
  values[offset]=Float(image.sourceX[frame])/source.width
  values[offset+1]=Float(image.sourceY[frame])/source.height
  values[offset+2]=Float(image.width)/source.width;values[offset+3]=Float(image.height)/source.height
  values[offset+4]=1.0/source.width;values[offset+5]=1.0/source.height
  values[offset+6]=0;values[offset+7]=(image.flags & FILTEREDIMAGE)<>0
 End Method
 Method canvasTargetFeedback:Int(light:TMax2DLightingDrawLight)
  Local target:TRenderImage=TMax2DGraphics.Current().renderImage
  Return target And light.map.sources[light.mapFrame]=target.sources[0]
 End Method
 Method PrepareMaps(draw:TMax2DLightingDraw)
  Local needed:Int
  For Local i:Int=0 Until draw.count
   groupTiles[i]=Null
   If draw.lights[i].hasMap Then
    needed=True
    If canvasTargetFeedback(draw.lights[i]) Then Throw "Max2D Lighting: projected map is the current render target"
   End If
  Next
  If Not needed Then Return
  If Not atlas.owner Then atlas.Prepare(2048,2048,256)
  ' A fresh page always fits sixteen maps of at most 512x512. Retire older
  ' assignments only between receiver submissions, never inside a group.
  For Local attempt:Int=0 To 1
   Local complete:Int=True
   For Local i:Int=0 Until draw.count
    If Not draw.lights[i].hasMap Then Continue
    groupTiles[i]=atlas.Resolve(draw.lights[i])
    If Not groupTiles[i] Then complete=False;Exit
   Next
   If complete Then Return
   atlas.Reset()
  Next
  Throw "Max2D Lighting: accepted shadow group exceeds atlas capacity"
 End Method
 Method Draw(canvas:TMax2DGraphics,draw:TMax2DLightingDraw) Override
  Local normal:TImage=draw.normalMap,normalFrame:Int=draw.normalFrame
  Local strength:Float=-2
  If draw.specularStrength>0 Then strength=-1
  If normal Then strength=draw.normalStrength Else normal=draw.source;normalFrame=draw.frame
  normal=normal.SamplingImage(normalFrame)
  If normal=canvas.renderImage Then Throw "Max2D Lighting: normal map is the current render target"
  Local specular:TImage,specularFrame:Int=draw.specularFrame,specularAlpha:Int
  If draw.specularMap Then
   specular=draw.specularMap.SamplingImage(specularFrame)
   If canvas.renderImage And specular.sources[specularFrame]=canvas.renderImage.sources[0] Then Throw "Max2D Lighting: specular map is the current render target"
   Local source:TImageSource=specular.sources[specularFrame]
   Local format:Int=source.targetFormat
   If source.pixmap Then format=source.pixmap.format
   If source.textureData Then format=source.textureData.Format()
   specularAlpha=format=PF_A8
   Bounds(specular,specularFrame,userSlots+8)
  End If
  PrepareMaps(draw)
  If draw.deformed Then
   ' The fragment shader reconstructs position and normal basis from screen
   ' coordinates and UV gradients. Keep unused affine coefficients identical.
   values[0]=0;values[1]=0;values[2]=0
   values[4]=0;values[5]=0;values[6]=0
  Else
   values[0]=draw.xx*draw.source.width;values[1]=draw.xy*draw.source.height;values[2]=draw.tx
   values[4]=draw.yx*draw.source.width;values[5]=draw.yy*draw.source.height;values[6]=draw.ty
  End If
  values[3]=1.0/draw.source.width;values[7]=1.0/draw.source.height
  values[8]=strength;values[9]=draw.specularStrength;values[10]=draw.shininess;values[11]=draw.specularFromNormalAlpha
  If specular Then values[11]=2+specularAlpha
  values[12]=draw.count;values[13]=draw.targetFormat<>PF_RGBA16F And draw.targetFormat<>PF_RGBA32F
  values[14]=1.0/2048;values[15]=1.0/2048
  For Local i:Int=0 Until draw.count
   Local light:TMax2DLightingDrawLight=draw.lights[i],offset:Int=(4+i*6)*4
   values[offset]=light.x;values[offset+1]=light.y;values[offset+2]=light.radius;values[offset+3]=light.height
   values[offset+4]=light.red;values[offset+5]=light.green;values[offset+6]=light.blue;values[offset+7]=light.intensity
   values[offset+8]=light.falloff;values[offset+9]=light.hasMap
   If light.hasMap Then
    Local tile:TMax2DLightingAtlasTile=groupTiles[i]
    values[offset+10]=light.mapClamp;values[offset+11]=(light.map.flags & FILTEREDIMAGE)<>0
    values[offset+12]=light.mapXX;values[offset+13]=light.mapXY;values[offset+14]=light.mapTX;values[offset+15]=tile.premultiplied
    values[offset+16]=light.mapYX;values[offset+17]=light.mapYY;values[offset+18]=light.mapTY
    values[offset+20]=Float(tile.x)/2048;values[offset+21]=Float(tile.y)/2048
    values[offset+22]=Float(tile.width)/2048;values[offset+23]=Float(tile.height)/2048
   End If
   If light.directional Then values[offset+2]=light.z;values[offset+8]=-1
  Next
  Local screenOffset:Int=(userSlots-3)*4
  values[screenOffset+3]=draw.deformed;values[screenOffset+7]=context.pixelHeight
  If draw.deformed Then
   If Not ScreenMapping(canvas,draw,False) Then Throw "Max2D Lighting: drawing transform changed after acceptance"
   values[screenOffset]=screen[0];values[screenOffset+1]=screen[1];values[screenOffset+2]=screen[2]
   values[screenOffset+4]=screen[3];values[screenOffset+5]=screen[4];values[screenOffset+6]=screen[5]
  End If
  Local emissionOffset:Int=(userSlots-4)*4
  values[emissionOffset+3]=0
  Local emission:TImage,emissionFrame:Int=draw.emissionFrame
  If draw.includeAmbient And draw.emissionMap Then
   emission=draw.emissionMap.SamplingImage(emissionFrame)
   If canvas.renderImage And emission.sources[emissionFrame]=canvas.renderImage.sources[0] Then Throw "Max2D Lighting: emission map is the current render target"
   values[emissionOffset]=draw.emissionRed;values[emissionOffset+1]=draw.emissionGreen;values[emissionOffset+2]=draw.emissionBlue;values[emissionOffset+3]=draw.emissionIntensity
   Local emissionSlot:Int=userSlots+4
   If extended Then emissionSlot=userSlots+6
   Bounds(emission,emissionFrame,emissionSlot)
  End If
  Local ambientOffset:Int=(userSlots-1)*4
  values[ambientOffset]=draw.ambientRed;values[ambientOffset+1]=draw.ambientGreen;values[ambientOffset+2]=draw.ambientBlue;values[ambientOffset+3]=draw.includeAmbient
  Bounds(draw.source,draw.frame,userSlots)
  Bounds(normal,normalFrame,userSlots+2)
  Local second:TImageFrame=normal.Frame(normalFrame,canvas)
  Local third:TImageFrame=second
  If atlas.image Then third=atlas.image.Frame(0,canvas)
  Local fourth:TImageFrame=second
  If emission Then
   If extended Then fourth=emission.Frame(emissionFrame,canvas) Else third=emission.Frame(emissionFrame,canvas)
  End If
  Local previous:Int=GetBlend()
  Try
   If draw.includeAmbient Then SetBlend(composite) Else SetBlend(blend)
   context.Flush()
   shader=adapter.Shader(context,assets)
   If Not shader Then Throw "Max2D Lighting: native shader unavailable after device refresh"
   textures[0]=second;textures[1]=third
   Local textureCount:Int=2
   If extended Then textures[2]=fourth;textureCount=3
   If extended=2 Then textures[3]=specular.Frame(specularFrame,canvas);textureCount=4
   adapter.SelectTextureSet(context,shader,values,textures,textureCount)
   If draw.mesh Then
    canvas.DrawTexturedMesh(draw.mesh,draw.source,draw.x,draw.y,draw.frame)
   Else
    canvas.DrawImage(draw.source,draw.x,draw.y,draw.frame)
   End If
   context.Flush()
  Catch error:Object
   context.batchCount=0;context.batchFrame=Null
   Throw error
  Finally
   textures[0]=Null;textures[1]=Null;textures[2]=Null;textures[3]=Null
   adapter.ClearShader(context)
   SetBlend(previous)
  End Try
 End Method
 Method MapUploads:Long() Override;Return atlas.uploads;End Method
 Method MapCacheHits:Long() Override;Return atlas.hits;End Method
 Method MapStorageBytes:Long() Override
  If atlas.image Then Return Long(atlas.width)*atlas.height*4
  Return 0
 End Method
 Method Release() Override
  textures[0]=Null;textures[1]=Null;textures[2]=Null;textures[3]=Null
  atlas.Release()
  For Local i:Int=0 Until lightCount
   groupTiles[i]=Null
  Next
  shader=Null;adapter=Null;context=Null
 End Method
End Type

Public
Rem
bbdoc: Creates the built-in native grouped-light renderer for a context, or Null when its shader transport/assets are unavailable.
about: Processor integration only. maximumLights must be positive and defaults to 16; values at most eight select the smaller shader. Short groups use that shader even on sixteen-light renderers. Supports up to sixteen point/directional lights where shader support permits, otherwise eight (including native D3D9) with projected patterns and optional hard or filtered shadows, using flat, normal-mapped or specular receivers. The first group can include ambient and receiver coverage using alpha composition; later groups preserve destination alpha. Independent emission artwork can join that first group alongside shadow/pattern textures using a fourth sampler where the shader transport supports it. Separate specular artwork uses a fifth sampler, avoiding CPU packing when shader support and normal/gloss filtering settings permit. Eight/sixteen-light variants keep their existing light capacity. Unsupported combinations retry packed normal alpha. Three-texture providers retain combined emission for groups without light maps and otherwise use a separate mapped ambient pass. Floating-point emission artwork retains separate ambient on normalized targets to preserve signed-colour clamping. Non-overlapping deformed meshes use screen-to-lighting reconstruction and per-fragment UV gradients for normal bases. Singular drawing transforms and texture gradients too small or ill-conditioned for reliable fragment precision are rejected; degenerate fragment gradients use a viewer-facing normal. Public image-effect package schemas are unchanged; this renderer uses its own fixed light-buffer layout. Contexts own native shader resources. The caller owns the session and calls Release. Normalized targets preserve per-light clamping; floating-point targets retain HDR range. Shadow maps and RGBA8888/A8 patterns up to 512 by 512 pixels share a retained 2048 by 2048 atlas, allocated on demand. Larger maps, floating-point source artwork, and direct mipmapped, compressed or floating-point patterns use compatibility paths.
End Rem
Function CreateNativeMax2DLightingRenderer:TMax2DLightingRenderer(context:TMax2DContext,maximumLights:Int=16)
 If maximumLights<1 Then Throw "Max2D Lighting: maximum group size must be positive"
 Local adapter:TMax2DShaderPackageBackend=Max2DShaderPackageAdapter(context)
 If Not adapter Then Return Null
 Local capacity:Int=16,assets:Byte Ptr=m2d_native_lighting_assets_16(),shader:Byte Ptr
 If maximumLights>8 Then shader=adapter.Shader(context,assets)
 If Not shader Then
  capacity=8;assets=m2d_native_lighting_assets()
  shader=adapter.Shader(context,assets)
 End If
 If Not shader Then Return Null
 Local renderer:TMax2DNativeLightingRenderer=New TMax2DNativeLightingRenderer
 renderer.lightCount=capacity;renderer.userSlots=8+capacity*6;renderer.assets=assets
 renderer.values=New Float[(renderer.userSlots+14)*4]
 renderer.groupTiles=New TMax2DLightingAtlasTile[capacity]
 renderer.limits=TMax2DLightingCapabilities.Create(1,Min(capacity,maximumLights),True,True,True,True,True,True,True,True,True,True,True,True)
 renderer.context=context;renderer.adapter=adapter;renderer.shader=shader
 Return renderer
End Function
