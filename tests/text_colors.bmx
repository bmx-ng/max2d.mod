SuperStrict
Framework Max2D.Core
Import Text.Unibreak
Import BRL.StandardIO
Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function
Local font:TImageFont=TImageFont.DefaultFont()
Local prepared:TPreparedText=PrepareText("  AB CD",font,ETextBreakMode.Auto,"",True)
Local layout:TParagraphLayout=prepared.Layout(24)
Check(layout.PrepareLinePaint(0)=Null,"Unstyled text has no paint cache")
Local foreground:TTextColorSpan=TTextColorSpan.Create(2,4)
foreground.SetForeground(255,0,0,0.5)
Local background:TTextColorSpan=TTextColorSpan.Create(2,7)
background.SetBackground(0,0,255,0.4)
prepared.SetColorSpans([foreground,background])
foreground.red=0
Local paint:TTextPaint=layout.PrepareLinePaint(0)
Check(paint.glyphColors[0].red=255 And paint.glyphColors[1].opacity=0.5,"Foreground uses original offsets and a copied snapshot")
Check(paint.backgrounds.Length=1 And paint.backgrounds[0].width=16,"Background covers line advance")
Check(layout.PrepareLinePaint(1).glyphColors[0]=Null,"Unset glyph colour inherits drawing colour")
Check(layout.PrepareLinePaint(1).backgrounds[0].y=16,"Background follows wrapping")
Local flows:Long=prepared.reflowBuilds,builds:Long=font.layoutBuilds
Local carets:TTextCaret[]=layout.lines[0].carets
foreground.SetForeground(0,255,0)
prepared.SetColorSpans([foreground,background])
Check(layout.PrepareLinePaint(0).glyphColors[0].green=255,"Repainting updates held layout")
Check(prepared.reflowBuilds=flows And font.layoutBuilds=builds And layout.lines[0].carets=carets,"Colour changes reuse layout and carets")
Check(paint.glyphColors[0].red=255,"Old paint snapshot remains unchanged")
prepared.ClearCache()
prepared.SetColorSpans(Null)
Check(layout.PrepareLinePaint(0)=Null,"Clearing spans affects evicted held layouts")
Local boxed:TParagraphLayout=prepared.LayoutBox(40,16)
foreground=TTextColorSpan.Create(0,7);foreground.SetForeground(255,0,0)
prepared.SetColorSpans([foreground])
paint=boxed.PrepareLinePaint(0)
For Local i:Int=0 Until boxed.lines[0].layout.glyphs.Length
	If boxed.lines[0].layout.glyphs[i].sourceOffset>=boxed.lines[0].sourceContentLength Then Check(paint.glyphColors[i]=Null,"Synthetic ellipsis stays unstyled")
Next
Local other:TPreparedText=PrepareText("AB",font,ETextBreakMode.Auto,"",True)
Local plain:TParagraphLayout=other.Layout(24)
Check(plain.PrepareLinePaint(0)=Null,"Shared font layout is not painted by another paragraph")
Local foregroundOnly:TTextColorSpan=TTextColorSpan.Create(0,2)
foregroundOnly.SetForeground(100,200,255)
other.SetColorSpans([foregroundOnly])
plain.PrepareLinePaint(0)
Check(plain.interactionBuilds=0 And Not other.interaction.wordBreaks,"Foreground-only paint does not build caret or word data")
Print "Max2D text colour tests passed"
