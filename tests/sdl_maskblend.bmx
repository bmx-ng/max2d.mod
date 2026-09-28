SuperStrict
Framework Max2D.SDL3RenderMax2D
Import BRL.StandardIO

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function

Try
	Local software:Int = AppArgs.Length > 1 And AppArgs[1] = "--software"
	If software Then
		Check(SetSDLRenderMax2DRenderer("software"),"Renderer hint rejected")
	Else
		Check(SetSDLRenderMax2DRenderer("gpu"),"Renderer hint rejected")
	End If
	Local window:TGraphics = Graphics(64,64,0,0)
	Print "Renderer: " + SDLRenderMax2DRendererName()
	If software Then
		Check(Not Max2DSupportsBlend(MASKBLEND),"Software must report no mask support")
		Local rejected:Int
		Try
			SetBlend(MASKBLEND)
			DrawRect(0,0,1,1)
			FlushMax2D()
		Catch error:Object
			rejected = True
		End Try
		Check(rejected,"Unsupported masking must be rejected")
	Else
		Local context:TSDLRenderContext = TSDLRenderContext(TMax2DGraphics.Current().context)
		Check(Max2DSupportsBlend(MASKBLEND),"GPU masking unavailable: " + context.maskUnavailableReason)
		Local image:TImage = CreateImage(4,1,1,DYNAMICIMAGE)
		Local p:TPixmap = LockImage(image)
		p.WritePixel(0,0,$7fff0000)
		p.WritePixel(1,0,$8000ff00)
		p.WritePixel(2,0,$c000ffff)
		p.WritePixel(3,0,$ffffffff)
		UnlockImage(image)
		Local dest:TRenderImage = CreateRenderImage(32,16,0)
		SetRenderImage(dest)
		SetClsColor(0,0,255,1); Cls
		SetBlend(MASKBLEND)
		DrawImage(image,0,0)
		SetAlpha(0.5); DrawImage(image,0,1)
		SetAlpha(0.49); SetColor(255,0,0); DrawRect(0,2,4,1)
		SetAlpha(0.5); DrawRect(0,3,4,1)
		SetAlpha(1); SetColor(255,255,255)
		p = ReadRenderImage(dest)
		Check(p.ReadPixel(0,0)=$ff0000ff,"127 alpha must discard")
		Check((p.ReadPixel(1,0)&$ffffff)=$00ff00,"128 alpha must write without blending")
		Check(Abs(((p.ReadPixel(1,0) Shr 24)&255)-128)<=1,"Mask preserves surviving alpha")
		Check(p.ReadPixel(2,1)=$ff0000ff,"Test includes drawing alpha")
		Check((p.ReadPixel(3,1)&$ffffff)=$ffffff,"Exactly half alpha must survive")
		Check(p.ReadPixel(0,2)=$ff0000ff,"Untextured primitive below threshold")
		Check((p.ReadPixel(0,3)&$ffffff)=$ff0000,"Untextured primitive at threshold")

		' Filter first, then test alpha: the surviving colour must not blend blue.
		Local filtered:TImage = CreateImage(2,1,1,FILTEREDIMAGE|DYNAMICIMAGE)
		p=LockImage(filtered); p.WritePixel(0,0,$00ff0000); p.WritePixel(1,0,$ffff0000); UnlockImage(filtered)
		DrawImageRect(filtered,0,4,8,1)
		p=ReadRenderImage(dest)
		Check(p.ReadPixel(3,4)=$ff0000ff,"Filtered alpha below threshold")
		Check((p.ReadPixel(4,4)&$ffffff)=$ff0000,"Filtered alpha above threshold overwrites")

		' Dynamic uploads must be visible without rebuilding a precomputed mask.
		p=LockImage(image); p.WritePixel(0,0,$ff00ff00); UnlockImage(image)
		DrawImage(image,0,5)
		p=ReadRenderImage(dest)
		Check((p.ReadPixel(0,5)&$ffffff)=$00ff00,"Dynamic alpha edit")

		' Filtered animation cells are packed into an atlas by LoadAnimImage.
		Local sheet:TPixmap=CreatePixmap(4,1,PF_RGBA8888)
		sheet.WritePixel(0,0,$00ff0000); sheet.WritePixel(1,0,$ffff0000)
		sheet.WritePixel(2,0,$0000ff00); sheet.WritePixel(3,0,$ff00ff00)
		Local animation:TImage=LoadAnimImage(sheet,2,1,0,2,FILTEREDIMAGE)
		DrawImageRect(animation,0,6,8,1,0)
		DrawImageRect(animation,0,7,8,1,1)
		p=ReadRenderImage(dest)
		Check(p.ReadPixel(3,6)=$ff0000ff And p.ReadPixel(3,7)=$ff0000ff,"Atlas transparent edges")
		Check((p.ReadPixel(4,6)&$ffffff)=$ff0000,"Atlas first animation frame")
		Check((p.ReadPixel(4,7)&$ffffff)=$00ff00,"Atlas second animation frame")

		' Sample premultiplied targets into another target, then the window.
		Local other:TRenderImage = CreateRenderImage(32,16,0)
		SetRenderImage(other); SetClsColor(0,0,0,0); Cls
		DrawImage(dest,0,0)
		p=ReadRenderImage(other)
		Check((p.ReadPixel(1,0)&$ffffff)=$00ff00,"Target source unpremultiplies before masking")
		Check(Abs(((p.ReadPixel(1,0) Shr 24)&255)-128)<=1,"Target alpha preserved")
		' Switching to ordinary drawing/clear must reset the custom shader.
		SetBlend(SOLIDBLEND); SetColor(255,0,255); SetAlpha(0.25); DrawRect(8,0,1,1)
		p=ReadRenderImage(other)
		Check((p.ReadPixel(8,0)&$ffffff)=$ff00ff,"Shader reset for ordinary drawing")
		SetRenderImage(Null); SetAlpha(1); SetColor(255,255,255); SetBlend(MASKBLEND)
		DrawImage(other,0,0); FlushMax2D()
		Local screen:TPixmap=GrabPixmap(0,0,NativeResolutionWidth(),NativeResolutionHeight())
		Local scaleX:Int=NativeResolutionWidth()/64
		Check((screen.ReadPixel(scaleX,0)&$ffffff)=$00ff00,"Target-to-window mask colour")
		' Closing a second context must leave the first context usable.
		Local second:TGraphics=CreateGraphics(32,32,0,0,0,-1,-1)
		SetGraphics(second); Check(Max2DSupportsBlend(MASKBLEND),"Second context mask support")
		SetBlend(MASKBLEND); DrawImage(image,0,0); FlushMax2D()
		second.Close(); SetGraphics(window)
		DrawImage(image,0,8); FlushMax2D()
	End If
	EndGraphics()
	Print "Max2D SDL MASKBLEND tests passed"
Catch error:Object
	Print "FAILED: " + error.ToString()
	EndWithCode(1)
End Try
