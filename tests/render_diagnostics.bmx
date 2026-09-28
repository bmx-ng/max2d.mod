SuperStrict
?max2d_sdlgpu
Framework Max2D.SDL3GPUMax2D
?max2d_gl
Framework Max2D.GLMax2D
?max2d_d3d9
Framework Max2D.D3D9Max2D
?max2d_d3d11
Framework Max2D.D3D11Max2D
?Not max2d_gl And Not max2d_d3d9 And Not max2d_d3d11 And Not max2d_sdlgpu
Framework Max2D.SDL3RenderMax2D
?
Import BRL.StandardIO
Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Try
	Local first:TGraphics=Graphics(320,240,0,0)
	Check(first<>Null,"Initial graphics context created")
	Check(Max2DTextureFormatSupport(PF_RGBA8888)=ETextureFormatSupport.Native,"RGBA channel storage is native")
	Check(Max2DTextureFormatSupport(PF_A8,$40000000)=ETextureFormatSupport.Unsupported,"Unknown storage flags rejected")
	Check(Max2DTextureFormatSupport(-100)=ETextureFormatSupport.Unsupported,"Unknown storage format rejected")
	Check(Max2DTextureFormatSupport(PF_RGB565)=ETextureFormatSupport.Unsupported,"Packed storage not yet exposed")
?max2d_gl Or max2d_d3d11 Or max2d_sdlgpu
	Check(Max2DTextureFormatSupport(PF_A8,FILTEREDIMAGE)=ETextureFormatSupport.Native,"Test device has native coverage")
?Not max2d_gl And Not max2d_d3d11 And Not max2d_sdlgpu
	Check(Max2DTextureFormatSupport(PF_A8,FILTEREDIMAGE)=ETextureFormatSupport.Converted,"Coverage fallback reported")
?
	If Max2DSupportsImageFlags(MIPMAPPEDIMAGE) Then
?max2d_sdlgpu
		Check(Max2DTextureFormatSupport(PF_A8,MIPMAPPEDIMAGE)=ETextureFormatSupport.Native,"Mipmapped coverage remains native")
?Not max2d_sdlgpu
		Check(Max2DTextureFormatSupport(PF_A8,MIPMAPPEDIMAGE)=ETextureFormatSupport.Converted,"Mipmapped coverage expands to RGBA")
?
	Else
		Check(Max2DTextureFormatSupport(PF_A8,MIPMAPPEDIMAGE)=ETextureFormatSupport.Unsupported,"Unsupported mipmaps rejected")
	End If
	Local width:Int,height:Int
	GetMax2DTextureSize(width,height)
	Check(width>=0 And height>=0,"Nonnegative limits")
	Check(Max2DSupportsRenderImage(32,32,0),"Small RGBA render image supported")
	Check(Not Max2DSupportsRenderImage(0,32,0),"Zero width rejected")
	Check(Not Max2DSupportsRenderImage(32,-1,0),"Negative height rejected")
	Check(Not Max2DSupportsRenderImage(32,32,$40000000),"Unknown flags rejected")
	If width>0 And width<2147483647 Then Check(Not Max2DSupportsRenderImage(width+1,32,0),"Width limit checked")
	If height>0 And height<2147483647 Then Check(Not Max2DSupportsRenderImage(32,height+1,0),"Height limit checked")
	Check(Max2DStats().textureCreations=0,"Queries do not create image frames")
	AutoImageFlags(MIPMAPPEDIMAGE)
	Check(Max2DSupportsRenderImage(32,32)=Max2DSupportsRenderImage(32,32,MIPMAPPEDIMAGE),"Default flags respected")
	AutoImageFlags(0)
	Local target:TRenderImage=CreateRenderImage(32,32,0)
	SetRenderImage(target)
	SetClsColor(0,0,0); Cls()
	ResetMax2DStats()
	SetBlend(SOLIDBLEND); SetColor(255,0,0)
	DrawRect(0,0,8,8); DrawRect(8,0,8,8)
	Local pending:TMax2DStats=CaptureMax2DStats(False)
	Check(pending.submissions=0,"Non-flushing capture preserves batching")
	Local firstBatch:TMax2DStats=CaptureMax2DStats()
	Check(firstBatch.submissions=1 And firstBatch.vertices=12,"Adjacent rectangles form one batch")
	DrawRect(16,0,8,8)
	Local secondBatch:TMax2DStats=CaptureMax2DStats()
	Check(secondBatch.submissions=2 And firstBatch.submissions=1,"Snapshots remain detached")
	Local pixels:TPixmap=ReadRenderImage(target)
	Check((pixels.ReadPixel(4,4)&$ffffff)=$ff0000,"Queried render image draws correctly")
	Check(Max2DStats().readbacks=1,"Readback counted")
	DrawRect(24,0,8,8)
	ResetMax2DStats()
	Check(Max2DStats().submissions=0 And Max2DStats().readbacks=0,"Reset establishes clean interval")
	Check(CaptureMax2DStats().submissions=0,"Reset submitted old pending geometry")
	pixels=ReadRenderImage(target)
	Check((pixels.ReadPixel(28,4)&$ffffff)=$ff0000,"Reset preserves pending drawing")
	SetRenderImage(Null)
?Not max2d_d3d9 And Not max2d_d3d11
	Local other:TGraphics=CreateGraphics(320,240,0,0,0,-1,-1)
	Check(other<>Null,"Second graphics context created")
	SetGraphics(other)
	Check(Max2DStats().readbacks=0,"Counters belong to each context")
	SetGraphics(first)
	Check(Max2DStats().readbacks=1,"First context counters preserved")
	other.Close()
?max2d_d3d9 Or max2d_d3d11
	EndGraphics()
	Check(Graphics(320,240,0,0)<>Null,"Reopened graphics context created")
	Check(Max2DStats().readbacks=0 And Max2DStats().submissions=0,"Reopened context has fresh counters")
	Check(firstBatch.submissions=1,"Snapshot survives context closure")
?
	EndGraphics()
	Print "Max2D rendering diagnostics passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
