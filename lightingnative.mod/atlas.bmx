SuperStrict
Import Max2D.LightingDriver

' Internal retained page. Tiles have no gutters: shader sampling must clamp each
' individual texel lookup to the tile rectangle, including bilinear neighbours.
Type TMax2DLightingAtlasTile
 Field key:Object,image:TImage,frame:Int,revision:Long
 Field x:Int,y:Int,width:Int,height:Int,valid:Int,premultiplied:Int
End Type

Type TMax2DLightingAtlas
 Field owner:TMax2DContext
 Field image:TRenderImage
 Field width:Int,height:Int,count:Int
 Field cursorX:Int,cursorY:Int,rowHeight:Int
 Field tiles:TMax2DLightingAtlasTile[]
 Field uploads:Long,hits:Long
 Field copyState:TMax2DState=New TMax2DState
 Field rawCopy:Int=CreateBlendMode(BLEND_ONE,BLEND_ZERO,BLEND_OP_ADD,BLEND_ONE,BLEND_ZERO)

 Method Prepare(width:Int,height:Int,capacity:Int)
  If width<=0 Or height<=0 Or capacity<=0 Then Throw "Max2D Lighting: invalid atlas dimensions or capacity"
  If owner Then Throw "Max2D Lighting: release atlas before preparing again"
  Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
  If Not Max2DSupportsRenderImage(width,height,0,PF_RGBA8888) Then Throw "Max2D Lighting: unsupported atlas dimensions"
  Self.width=width;Self.height=height
  tiles=New TMax2DLightingAtlasTile[capacity]
  For Local i:Int=0 Until capacity
   tiles[i]=New TMax2DLightingAtlasTile
  Next
  image=TRenderImage.Create(width,height,0)
  owner=canvas.context
 End Method

 ' Returns Null without copying or evicting anything when the page is full.
 ' The caller can choose another page or split its group before drawing.
 Method Resolve:TMax2DLightingAtlasTile(light:TMax2DLightingDrawLight)
  If Not owner Then Throw "Max2D Lighting: atlas is not prepared"
  owner.CheckOpen()
  Local canvas:TMax2DGraphics=TMax2DGraphics.Current()
  If canvas.context<>owner Then Throw "Max2D Lighting: atlas belongs to another context"
  If canvas.renderImage=image Then Throw "Max2D Lighting: atlas is the current target"
  If Not light Or Not light.map Or Not light.mapKey Then Throw "Max2D Lighting: unresolved atlas map"
  Local source:TImage=light.map
  source.CheckIndex(light.mapFrame)
  If source.sources[light.mapFrame]=image.sources[0] Then Throw "Max2D Lighting: invalid atlas source"
  Local format:Int=source.sources[light.mapFrame].targetFormat
  If format=PF_RGBA16F Or format=PF_RGBA32F Then Throw "Max2D Lighting: atlas requires normalized maps"
  Local tile:TMax2DLightingAtlasTile
  For Local i:Int=0 Until count
   Local candidate:TMax2DLightingAtlasTile=tiles[i]
   If candidate.key=light.mapKey And candidate.image=source And candidate.frame=light.mapFrame Then
    tile=candidate;Exit
   End If
  Next
  Local fresh:Int=Not tile
  Local px:Int=cursorX,py:Int=cursorY,nextRow:Int=rowHeight
  If fresh Then
   If count=tiles.Length Or source.width>width Or source.height>height Then Return Null
   If px+source.width>width Then px=0;py:+rowHeight;nextRow=0
   If py+source.height>height Then Return Null
   tile=tiles[count]
  Else If tile.valid And tile.revision=light.mapRevision Then
   hits:+1;Return tile
  Else
   px=tile.x;py=tile.y
  End If
  Local samplingFrame:Int=light.mapFrame
  Local sampling:TImage=source.SamplingImage(samplingFrame)
  tile.valid=False
  tile.premultiplied=source.sources[light.mapFrame].renderTarget Or (source.sources[light.mapFrame].flags & MIPMAPPEDIMAGE)
  ' The atlas is distinct from the caller target (checked above). Its copy
  ' changes only its own view and this retained state, never the caller's state.
  Local callerState:TMax2DState=canvas.state
  Local callerTarget:TRenderImage=canvas.renderImage
  canvas.state=copyState
  Try
   SetRenderImage(image)
   SetVirtualResolution(width,height);SetViewport(px,py,source.width,source.height)
   SetCamera(Null);ResetCoordinates();SetAffineTransform(1,0,0,1)
   SetOrigin(0,0);SetHandle(0,0);SetColor(255,255,255);SetAlpha(1);SetBlend(SOLIDBLEND)
   If Not tile.premultiplied Then SetBlend(rawCopy)
   Max2D.Core.DrawImage(sampling,px+sampling.handle_x,py+sampling.handle_y,samplingFrame)
   owner.Flush()
  Finally
   canvas.state=callerState
   If Not owner.closed Then canvas.SetRenderImage(callerTarget)
  End Try
  If fresh Then
   tile.key=light.mapKey;tile.image=source;tile.frame=light.mapFrame
   tile.x=px;tile.y=py;tile.width=source.width;tile.height=source.height
   cursorX=px+source.width;cursorY=py;rowHeight=Max(nextRow,source.height)
   count:+1
  End If
  tile.revision=light.mapRevision;tile.valid=True;uploads:+1
  Return tile
 End Method

 ' Discards tile assignments while retaining GPU storage and record capacity.
 Method Reset()
  If owner And Not owner.closed Then owner.Flush()
  For Local i:Int=0 Until count
   tiles[i].key=Null;tiles[i].image=Null;tiles[i].valid=False
  Next
  count=0;cursorX=0;cursorY=0;rowHeight=0
 End Method

 Method Release()
  If owner And Not owner.closed And owner.target And image Then
   For Local frame:TImageFrame=EachIn image.sources[0].frames
    If frame=owner.target Then Throw "Max2D Lighting: deselect atlas before release"
   Next
  End If
  If image Then image.ReleaseFrames()
  image=Null;owner=Null;tiles=Null
  width=0;height=0;count=0;cursorX=0;cursorY=0;rowHeight=0;uploads=0;hits=0
 End Method
End Type
